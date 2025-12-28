"""
Discounts Routes - Validate promo codes
Raw SQL Implementation
"""

from fastapi import APIRouter, HTTPException
from models.schemas import ValidateDiscountRequest, DiscountResponse
from config.database import execute_query

router = APIRouter()


@router.post("/validate", response_model=DiscountResponse)
async def validate_discount_code(request: ValidateDiscountRequest):
    """
    Validate a discount/promo code
    
    - Checks if code exists and is active
    - Validates date range
    - Checks usage limits
    - Calculates discount amount based on booking amount
    """
    code = request.code.upper().strip()
    booking_amount = request.booking_amount
    
    # Query discount by code with all validation in SQL
    query = """
        SELECT 
            DiscountID,
            Code,
            Description,
            DiscountType,
            DiscountValue,
            MinBookingAmount,
            MaxDiscountAmount,
            ValidFrom,
            ValidTo,
            MaxUses,
            CurrentUses,
            IsActive,
            CASE 
                WHEN IsActive = FALSE THEN 'Discount code is inactive'
                WHEN NOW() < ValidFrom THEN 'Discount code is not yet valid'
                WHEN NOW() > ValidTo THEN 'Discount code has expired'
                WHEN MaxUses IS NOT NULL AND CurrentUses >= MaxUses THEN 'Discount code usage limit reached'
                WHEN %s < MinBookingAmount THEN CONCAT('Minimum booking amount is EGP ', MinBookingAmount)
                ELSE 'VALID'
            END AS ValidationStatus
        FROM Discount
        WHERE Code = %s
    """
    
    discount = execute_query(query, (booking_amount, code), fetch_one=True)
    
    if not discount:
        return DiscountResponse(
            discount_id=0,
            code=code,
            description=None,
            discount_type="",
            discount_value=0,
            calculated_discount=0,
            is_valid=False,
            message="Invalid discount code"
        )
    
    validation_status = discount["ValidationStatus"]
    is_valid = validation_status == "VALID"
    
    # Calculate discount amount
    calculated_discount = 0
    if is_valid:
        if discount["DiscountType"] == "Percentage":
            calculated_discount = booking_amount * (float(discount["DiscountValue"]) / 100)
        else:  # FixedAmount
            calculated_discount = float(discount["DiscountValue"])
        
        # Apply max discount cap
        if discount["MaxDiscountAmount"]:
            calculated_discount = min(calculated_discount, float(discount["MaxDiscountAmount"]))
        
        # Ensure discount doesn't exceed booking amount
        calculated_discount = min(calculated_discount, booking_amount)
    
    return DiscountResponse(
        discount_id=discount["DiscountID"],
        code=discount["Code"],
        description=discount["Description"],
        discount_type=discount["DiscountType"],
        discount_value=float(discount["DiscountValue"]),
        calculated_discount=round(calculated_discount, 2),
        is_valid=is_valid,
        message="Discount applied successfully!" if is_valid else validation_status
    )


@router.get("/active")
async def get_active_discounts():
    """
    Get all currently active discount codes (public)
    
    Returns non-sensitive info about available promotions
    """
    query = """
        SELECT 
            Code,
            Description,
            DiscountType,
            DiscountValue,
            MinBookingAmount,
            MaxDiscountAmount,
            ValidFrom,
            ValidTo
        FROM Discount
        WHERE IsActive = TRUE
          AND NOW() BETWEEN ValidFrom AND ValidTo
          AND (MaxUses IS NULL OR CurrentUses < MaxUses)
        ORDER BY DiscountValue DESC
    """
    
    results = execute_query(query, fetch_all=True)
    
    return {
        "active_discounts": [
            {
                "code": row["Code"],
                "description": row["Description"],
                "discount_type": row["DiscountType"],
                "discount_value": float(row["DiscountValue"]),
                "min_booking_amount": float(row["MinBookingAmount"]) if row["MinBookingAmount"] else 0,
                "max_discount_amount": float(row["MaxDiscountAmount"]) if row["MaxDiscountAmount"] else None,
                "valid_until": row["ValidTo"].isoformat() if row["ValidTo"] else None
            }
            for row in results
        ],
        "total": len(results)
    }
