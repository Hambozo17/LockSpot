"""
Bookings Routes - Create, manage, and cancel bookings
Raw SQL Implementation with Concurrency Control
"""

from fastapi import APIRouter, HTTPException, Depends, Query
from typing import Optional, List
from datetime import datetime
from models.schemas import (
    CreateBookingRequest, BookingResponse, BookingListResponse,
    CancelBookingRequest, CancelBookingResponse, QRCodeResponse,
    BookingStatus
)
from services.auth_service import get_current_user
from services.qr_service import generate_qr_code_string, generate_qr_image_base64
from config.database import get_db_cursor, execute_query, execute_procedure

router = APIRouter()


@router.post("", response_model=BookingResponse, status_code=201)
async def create_booking(
    request: CreateBookingRequest,
    current_user: dict = Depends(get_current_user)
):
    """
    Create a new booking with concurrency control
    
    - Prevents double booking using FOR UPDATE lock
    - Validates time slots
    - Applies discount if provided
    - Calculates pricing
    """
    user_id = current_user["user_id"]
    
    # Validate dates
    if request.start_time >= request.end_time:
        raise HTTPException(status_code=400, detail="End time must be after start time")
    
    if request.start_time < datetime.now():
        raise HTTPException(status_code=400, detail="Cannot book in the past")
    
    # Use stored procedure for atomic booking creation
    # This handles concurrency with FOR UPDATE locks
    try:
        result = execute_procedure(
            "sp_CreateBooking",
            (
                user_id,
                request.locker_id,
                request.start_time,
                request.end_time,
                request.booking_type.value,
                request.discount_code,
                0,  # OUT: BookingID
                0,  # OUT: TotalAmount
                "", # OUT: Status
                ""  # OUT: Message
            )
        )
        
        output = result["output_params"]
        booking_id = output[6]
        total_amount = output[7]
        status = output[8]
        message = output[9]
        
        if status != "SUCCESS":
            raise HTTPException(status_code=400, detail=message)
        
    except HTTPException:
        raise
    except Exception as e:
        # Fallback to manual implementation if stored procedure fails
        booking_id, total_amount = await _create_booking_manual(
            user_id, request
        )
    
    # Fetch the created booking
    query = """
        SELECT 
            b.BookingID, b.UserID, b.LockerID, b.StartTime, b.EndTime,
            b.BookingType, b.SubtotalAmount, b.DiscountAmount, b.TotalAmount,
            b.Status, b.CreatedAt,
            ll.Name AS LocationName,
            lu.UnitNumber, lu.Size
        FROM Booking b
        INNER JOIN LockerUnit lu ON b.LockerID = lu.LockerID
        INNER JOIN LockerLocation ll ON lu.LocationID = ll.LocationID
        WHERE b.BookingID = %s
    """
    booking = execute_query(query, (booking_id,), fetch_one=True)
    
    return BookingResponse(
        booking_id=booking["BookingID"],
        user_id=booking["UserID"],
        locker_id=booking["LockerID"],
        location_name=booking["LocationName"],
        unit_number=booking["UnitNumber"],
        size=booking["Size"],
        start_time=booking["StartTime"],
        end_time=booking["EndTime"],
        booking_type=booking["BookingType"],
        subtotal_amount=float(booking["SubtotalAmount"]),
        discount_amount=float(booking["DiscountAmount"]),
        total_amount=float(booking["TotalAmount"]),
        status=booking["Status"],
        created_at=booking["CreatedAt"]
    )


async def _create_booking_manual(user_id: int, request: CreateBookingRequest):
    """
    Manual booking creation with transaction and row locking
    Used as fallback if stored procedure is not available
    """
    with get_db_cursor(commit=False) as (cursor, conn):
        try:
            # Lock the locker row - CONCURRENCY CONTROL
            cursor.execute("""
                SELECT Status FROM LockerUnit 
                WHERE LockerID = %s 
                FOR UPDATE
            """, (request.locker_id,))
            
            locker = cursor.fetchone()
            if not locker:
                raise HTTPException(status_code=404, detail="Locker not found")
            
            if locker["Status"] != "Available":
                raise HTTPException(status_code=400, detail=f"Locker is {locker['Status']}")
            
            # Check for time conflicts - DOUBLE BOOKING PREVENTION
            cursor.execute("""
                SELECT COUNT(*) AS conflict_count FROM Booking
                WHERE LockerID = %s
                  AND Status IN ('Pending', 'Confirmed', 'Active')
                  AND (
                      (%s >= StartTime AND %s < EndTime) OR
                      (%s > StartTime AND %s <= EndTime) OR
                      (%s <= StartTime AND %s >= EndTime)
                  )
            """, (
                request.locker_id,
                request.start_time, request.start_time,
                request.end_time, request.end_time,
                request.start_time, request.end_time
            ))
            
            conflict = cursor.fetchone()
            if conflict["conflict_count"] > 0:
                raise HTTPException(status_code=400, detail="Time slot conflicts with existing booking")
            
            # Get pricing
            cursor.execute("""
                SELECT pt.HourlyRate, pt.DailyRate
                FROM LockerUnit lu
                INNER JOIN PricingTier pt ON lu.TierID = pt.TierID
                WHERE lu.LockerID = %s
            """, (request.locker_id,))
            
            pricing = cursor.fetchone()
            hours = max(1, int((request.end_time - request.start_time).total_seconds() / 3600))
            days = max(1, hours // 24)
            
            # Calculate best price
            hourly_total = hours * float(pricing["HourlyRate"])
            daily_total = days * float(pricing["DailyRate"])
            subtotal = min(hourly_total, daily_total) if days >= 1 else hourly_total
            
            # Apply discount
            discount_amount = 0
            discount_id = None
            
            if request.discount_code:
                cursor.execute("""
                    SELECT DiscountID, DiscountType, DiscountValue, MinBookingAmount, MaxDiscountAmount
                    FROM Discount
                    WHERE Code = %s
                      AND IsActive = TRUE
                      AND NOW() BETWEEN ValidFrom AND ValidTo
                      AND (MaxUses IS NULL OR CurrentUses < MaxUses)
                """, (request.discount_code.upper(),))
                
                discount = cursor.fetchone()
                if discount and subtotal >= float(discount["MinBookingAmount"]):
                    discount_id = discount["DiscountID"]
                    if discount["DiscountType"] == "Percentage":
                        discount_amount = subtotal * (float(discount["DiscountValue"]) / 100)
                    else:
                        discount_amount = float(discount["DiscountValue"])
                    
                    if discount["MaxDiscountAmount"]:
                        discount_amount = min(discount_amount, float(discount["MaxDiscountAmount"]))
                    
                    # Update discount usage
                    cursor.execute("""
                        UPDATE Discount SET CurrentUses = CurrentUses + 1 WHERE DiscountID = %s
                    """, (discount_id,))
            
            total_amount = max(0, subtotal - discount_amount)
            
            # Create booking
            cursor.execute("""
                INSERT INTO Booking (
                    UserID, LockerID, DiscountID, StartTime, EndTime,
                    BookingType, SubtotalAmount, DiscountAmount, TotalAmount, Status
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, 'Pending')
            """, (
                user_id, request.locker_id, discount_id,
                request.start_time, request.end_time, request.booking_type.value,
                subtotal, discount_amount, total_amount
            ))
            
            booking_id = cursor.lastrowid
            
            # Update locker status
            cursor.execute("""
                UPDATE LockerUnit SET Status = 'Booked' WHERE LockerID = %s
            """, (request.locker_id,))
            
            conn.commit()
            return booking_id, total_amount
            
        except HTTPException:
            conn.rollback()
            raise
        except Exception as e:
            conn.rollback()
            raise HTTPException(status_code=500, detail=str(e))


@router.get("", response_model=BookingListResponse)
async def get_user_bookings(
    status: Optional[BookingStatus] = Query(None, description="Filter by status"),
    current_user: dict = Depends(get_current_user)
):
    """
    Get all bookings for the current user
    """
    query = """
        SELECT 
            b.BookingID, b.UserID, b.LockerID, b.StartTime, b.EndTime,
            b.BookingType, b.SubtotalAmount, b.DiscountAmount, b.TotalAmount,
            b.Status, b.CreatedAt,
            ll.Name AS LocationName,
            lu.UnitNumber, lu.Size,
            p.Status AS PaymentStatus
        FROM Booking b
        INNER JOIN LockerUnit lu ON b.LockerID = lu.LockerID
        INNER JOIN LockerLocation ll ON lu.LocationID = ll.LocationID
        LEFT JOIN Payment p ON b.BookingID = p.BookingID
        WHERE b.UserID = %s
    """
    params = [current_user["user_id"]]
    
    if status:
        query += " AND b.Status = %s"
        params.append(status.value)
    
    query += " ORDER BY b.CreatedAt DESC"
    
    results = execute_query(query, tuple(params), fetch_all=True)
    
    bookings = [
        BookingResponse(
            booking_id=row["BookingID"],
            user_id=row["UserID"],
            locker_id=row["LockerID"],
            location_name=row["LocationName"],
            unit_number=row["UnitNumber"],
            size=row["Size"],
            start_time=row["StartTime"],
            end_time=row["EndTime"],
            booking_type=row["BookingType"],
            subtotal_amount=float(row["SubtotalAmount"]),
            discount_amount=float(row["DiscountAmount"]),
            total_amount=float(row["TotalAmount"]),
            status=row["Status"],
            created_at=row["CreatedAt"],
            payment_status=row["PaymentStatus"]
        )
        for row in results
    ]
    
    return BookingListResponse(bookings=bookings, total=len(bookings))


@router.get("/{booking_id}", response_model=BookingResponse)
async def get_booking_by_id(
    booking_id: int,
    current_user: dict = Depends(get_current_user)
):
    """
    Get a specific booking by ID
    """
    query = """
        SELECT 
            b.BookingID, b.UserID, b.LockerID, b.StartTime, b.EndTime,
            b.BookingType, b.SubtotalAmount, b.DiscountAmount, b.TotalAmount,
            b.Status, b.CreatedAt,
            ll.Name AS LocationName,
            lu.UnitNumber, lu.Size,
            p.Status AS PaymentStatus,
            qr.Code AS QRCode
        FROM Booking b
        INNER JOIN LockerUnit lu ON b.LockerID = lu.LockerID
        INNER JOIN LockerLocation ll ON lu.LocationID = ll.LocationID
        LEFT JOIN Payment p ON b.BookingID = p.BookingID
        LEFT JOIN QRAccessCode qr ON b.BookingID = qr.BookingID AND qr.IsUsed = FALSE
        WHERE b.BookingID = %s AND b.UserID = %s
    """
    
    row = execute_query(query, (booking_id, current_user["user_id"]), fetch_one=True)
    
    if not row:
        raise HTTPException(status_code=404, detail="Booking not found")
    
    return BookingResponse(
        booking_id=row["BookingID"],
        user_id=row["UserID"],
        locker_id=row["LockerID"],
        location_name=row["LocationName"],
        unit_number=row["UnitNumber"],
        size=row["Size"],
        start_time=row["StartTime"],
        end_time=row["EndTime"],
        booking_type=row["BookingType"],
        subtotal_amount=float(row["SubtotalAmount"]),
        discount_amount=float(row["DiscountAmount"]),
        total_amount=float(row["TotalAmount"]),
        status=row["Status"],
        created_at=row["CreatedAt"],
        qr_code=row["QRCode"],
        payment_status=row["PaymentStatus"]
    )


@router.get("/{booking_id}/qr", response_model=QRCodeResponse)
async def generate_booking_qr(
    booking_id: int,
    current_user: dict = Depends(get_current_user)
):
    """
    Generate a QR code for locker access
    """
    # Verify booking exists and belongs to user
    booking_query = """
        SELECT BookingID, Status, EndTime
        FROM Booking
        WHERE BookingID = %s AND UserID = %s
    """
    booking = execute_query(booking_query, (booking_id, current_user["user_id"]), fetch_one=True)
    
    if not booking:
        raise HTTPException(status_code=404, detail="Booking not found")
    
    if booking["Status"] not in ["Confirmed", "Active"]:
        raise HTTPException(status_code=400, detail="QR code only available for confirmed bookings")
    
    # Check for existing valid QR code
    existing_qr = execute_query("""
        SELECT QRID, Code, ExpiresAt
        FROM QRAccessCode
        WHERE BookingID = %s AND IsUsed = FALSE AND ExpiresAt > NOW()
        ORDER BY GeneratedAt DESC
        LIMIT 1
    """, (booking_id,), fetch_one=True)
    
    if existing_qr:
        qr_code = existing_qr["Code"]
        qr_id = existing_qr["QRID"]
        expires_at = existing_qr["ExpiresAt"]
    else:
        # Generate new QR code
        qr_code = generate_qr_code_string(booking_id, "UNLOCK")
        expires_at = booking["EndTime"]
        
        with get_db_cursor(commit=True) as (cursor, conn):
            cursor.execute("""
                INSERT INTO QRAccessCode (BookingID, Code, CodeType, ExpiresAt)
                VALUES (%s, %s, 'Unlock', %s)
            """, (booking_id, qr_code, expires_at))
            qr_id = cursor.lastrowid
    
    # Generate QR image
    qr_image_base64 = generate_qr_image_base64(qr_code)
    
    return QRCodeResponse(
        qr_id=qr_id,
        booking_id=booking_id,
        code=qr_code,
        code_type="Unlock",
        expires_at=expires_at,
        qr_image_base64=qr_image_base64
    )


@router.post("/{booking_id}/cancel", response_model=CancelBookingResponse)
async def cancel_booking(
    booking_id: int,
    request: CancelBookingRequest = None,
    current_user: dict = Depends(get_current_user)
):
    """
    Cancel a booking with refund calculation
    
    Refund policy:
    - 24+ hours before: Full refund
    - 2-24 hours before: 50% refund
    - Less than 2 hours: No refund
    """
    reason = request.reason if request else None
    
    with get_db_cursor(commit=False) as (cursor, conn):
        try:
            # Get booking with lock
            cursor.execute("""
                SELECT BookingID, UserID, LockerID, Status, TotalAmount, StartTime
                FROM Booking
                WHERE BookingID = %s
                FOR UPDATE
            """, (booking_id,))
            
            booking = cursor.fetchone()
            
            if not booking:
                raise HTTPException(status_code=404, detail="Booking not found")
            
            if booking["UserID"] != current_user["user_id"]:
                raise HTTPException(status_code=403, detail="Not authorized")
            
            if booking["Status"] in ["Completed", "Cancelled", "Expired"]:
                raise HTTPException(status_code=400, detail=f"Cannot cancel: booking is {booking['Status']}")
            
            # Calculate refund
            hours_until_start = (booking["StartTime"] - datetime.now()).total_seconds() / 3600
            total_amount = float(booking["TotalAmount"])
            
            if hours_until_start >= 24:
                refund_amount = total_amount
            elif hours_until_start >= 2:
                refund_amount = total_amount * 0.5
            else:
                refund_amount = 0
            
            # Update booking
            cursor.execute("""
                UPDATE Booking 
                SET Status = 'Cancelled', CancellationReason = %s
                WHERE BookingID = %s
            """, (reason, booking_id))
            
            # Release locker
            cursor.execute("""
                UPDATE LockerUnit SET Status = 'Available' WHERE LockerID = %s
            """, (booking["LockerID"],))
            
            # Process refund if applicable
            if refund_amount > 0:
                cursor.execute("""
                    UPDATE Payment 
                    SET Status = 'Refunded', RefundAmount = %s, RefundDate = NOW()
                    WHERE BookingID = %s
                """, (refund_amount, booking_id))
            
            conn.commit()
            
            return CancelBookingResponse(
                booking_id=booking_id,
                status="Cancelled",
                refund_amount=refund_amount,
                message=f"Booking cancelled. Refund: EGP {refund_amount:.2f}"
            )
            
        except HTTPException:
            conn.rollback()
            raise
        except Exception as e:
            conn.rollback()
            raise HTTPException(status_code=500, detail=str(e))
