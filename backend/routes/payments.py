"""
Payments Routes - Process and manage payments
Raw SQL Implementation
"""

from fastapi import APIRouter, HTTPException, Depends
from typing import List
from models.schemas import (
    ProcessPaymentRequest, PaymentResponse,
    SavePaymentMethodRequest, PaymentMethodResponse
)
from services.auth_service import get_current_user
from config.database import get_db_cursor, execute_query

router = APIRouter()


@router.post("", response_model=PaymentResponse, status_code=201)
async def process_payment(
    request: ProcessPaymentRequest,
    current_user: dict = Depends(get_current_user)
):
    """
    Process payment for a booking
    
    - Validates booking ownership
    - Simulates payment processing
    - Updates booking status to Confirmed
    """
    user_id = current_user["user_id"]
    
    with get_db_cursor(commit=False) as (cursor, conn):
        try:
            # Check if payment already exists
            cursor.execute("""
                SELECT PaymentID FROM Payment WHERE BookingID = %s
            """, (request.booking_id,))
            
            existing = cursor.fetchone()
            if existing:
                raise HTTPException(status_code=400, detail="Payment already processed for this booking")
            
            # Get booking and verify ownership
            cursor.execute("""
                SELECT BookingID, UserID, Status, TotalAmount
                FROM Booking
                WHERE BookingID = %s
                FOR UPDATE
            """, (request.booking_id,))
            
            booking = cursor.fetchone()
            
            if not booking:
                raise HTTPException(status_code=404, detail="Booking not found")
            
            if booking["UserID"] != user_id:
                raise HTTPException(status_code=403, detail="Not authorized")
            
            if booking["Status"] != "Pending":
                raise HTTPException(status_code=400, detail=f"Cannot pay: booking is {booking['Status']}")
            
            amount = float(booking["TotalAmount"])
            
            # Get or create payment method
            method_id = request.method_id
            if not method_id and request.method_type:
                # Save new payment method
                cursor.execute("""
                    INSERT INTO PaymentMethod (UserID, MethodType, CardLastFour, IsDefault)
                    VALUES (%s, %s, %s, FALSE)
                """, (user_id, request.method_type.value, request.card_last_four))
                method_id = cursor.lastrowid
            
            # Generate transaction reference
            import time
            transaction_ref = request.transaction_reference or f"TXN-{request.booking_id}-{int(time.time())}"
            
            # Create payment record (simulating successful payment)
            cursor.execute("""
                INSERT INTO Payment (BookingID, MethodID, Amount, TransactionReference, Status)
                VALUES (%s, %s, %s, %s, 'Success')
            """, (request.booking_id, method_id, amount, transaction_ref))
            
            payment_id = cursor.lastrowid
            
            # Update booking status
            cursor.execute("""
                UPDATE Booking SET Status = 'Confirmed' WHERE BookingID = %s
            """, (request.booking_id,))
            
            # Create notification
            cursor.execute("""
                INSERT INTO Notification (UserID, Title, Message, NotificationType, RelatedBookingID)
                VALUES (%s, 'Payment Successful', %s, 'Payment', %s)
            """, (user_id, f"Payment of EGP {amount:.2f} was successful.", request.booking_id))
            
            conn.commit()
            
            return PaymentResponse(
                payment_id=payment_id,
                booking_id=request.booking_id,
                amount=amount,
                status="Success",
                transaction_reference=transaction_ref
            )
            
        except HTTPException:
            conn.rollback()
            raise
        except Exception as e:
            conn.rollback()
            raise HTTPException(status_code=500, detail=str(e))


@router.get("/{payment_id}", response_model=PaymentResponse)
async def get_payment_by_id(
    payment_id: int,
    current_user: dict = Depends(get_current_user)
):
    """
    Get payment details by ID
    """
    query = """
        SELECT 
            p.PaymentID, p.BookingID, p.Amount, p.Status,
            p.PaymentDate, p.TransactionReference
        FROM Payment p
        INNER JOIN Booking b ON p.BookingID = b.BookingID
        WHERE p.PaymentID = %s AND b.UserID = %s
    """
    
    row = execute_query(query, (payment_id, current_user["user_id"]), fetch_one=True)
    
    if not row:
        raise HTTPException(status_code=404, detail="Payment not found")
    
    return PaymentResponse(
        payment_id=row["PaymentID"],
        booking_id=row["BookingID"],
        amount=float(row["Amount"]),
        status=row["Status"],
        payment_date=row["PaymentDate"],
        transaction_reference=row["TransactionReference"]
    )


@router.get("/booking/{booking_id}", response_model=PaymentResponse)
async def get_payment_by_booking(
    booking_id: int,
    current_user: dict = Depends(get_current_user)
):
    """
    Get payment for a specific booking
    """
    query = """
        SELECT 
            p.PaymentID, p.BookingID, p.Amount, p.Status,
            p.PaymentDate, p.TransactionReference
        FROM Payment p
        INNER JOIN Booking b ON p.BookingID = b.BookingID
        WHERE p.BookingID = %s AND b.UserID = %s
    """
    
    row = execute_query(query, (booking_id, current_user["user_id"]), fetch_one=True)
    
    if not row:
        raise HTTPException(status_code=404, detail="Payment not found for this booking")
    
    return PaymentResponse(
        payment_id=row["PaymentID"],
        booking_id=row["BookingID"],
        amount=float(row["Amount"]),
        status=row["Status"],
        payment_date=row["PaymentDate"],
        transaction_reference=row["TransactionReference"]
    )


# ==================== Payment Methods ====================

@router.post("/methods", response_model=PaymentMethodResponse, status_code=201)
async def save_payment_method(
    request: SavePaymentMethodRequest,
    current_user: dict = Depends(get_current_user)
):
    """
    Save a new payment method for the user
    """
    user_id = current_user["user_id"]
    
    with get_db_cursor(commit=True) as (cursor, conn):
        # If setting as default, unset other defaults
        if request.is_default:
            cursor.execute("""
                UPDATE PaymentMethod SET IsDefault = FALSE WHERE UserID = %s
            """, (user_id,))
        
        cursor.execute("""
            INSERT INTO PaymentMethod (
                UserID, MethodType, CardLastFour, CardHolderName,
                ExpiryMonth, ExpiryYear, WalletPhone, IsDefault
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        """, (
            user_id, request.method_type.value, request.card_last_four,
            request.card_holder_name, request.expiry_month, request.expiry_year,
            request.wallet_phone, request.is_default
        ))
        
        method_id = cursor.lastrowid
    
    return PaymentMethodResponse(
        method_id=method_id,
        method_type=request.method_type.value,
        card_last_four=request.card_last_four,
        card_holder_name=request.card_holder_name,
        is_default=request.is_default
    )


@router.get("/methods", response_model=List[PaymentMethodResponse])
async def get_user_payment_methods(
    current_user: dict = Depends(get_current_user)
):
    """
    Get all saved payment methods for the current user
    """
    query = """
        SELECT MethodID, MethodType, CardLastFour, CardHolderName, IsDefault
        FROM PaymentMethod
        WHERE UserID = %s AND IsActive = TRUE
        ORDER BY IsDefault DESC, MethodID DESC
    """
    
    results = execute_query(query, (current_user["user_id"],), fetch_all=True)
    
    return [
        PaymentMethodResponse(
            method_id=row["MethodID"],
            method_type=row["MethodType"],
            card_last_four=row["CardLastFour"],
            card_holder_name=row["CardHolderName"],
            is_default=row["IsDefault"]
        )
        for row in results
    ]


@router.delete("/methods/{method_id}")
async def delete_payment_method(
    method_id: int,
    current_user: dict = Depends(get_current_user)
):
    """
    Delete (deactivate) a saved payment method
    """
    result = execute_query("""
        UPDATE PaymentMethod 
        SET IsActive = FALSE 
        WHERE MethodID = %s AND UserID = %s
    """, (method_id, current_user["user_id"]), commit=True)
    
    if result == 0:
        raise HTTPException(status_code=404, detail="Payment method not found")
    
    return {"status": "success", "message": "Payment method deleted"}
