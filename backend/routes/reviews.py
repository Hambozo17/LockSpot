"""
Reviews Routes - Submit and view reviews
Raw SQL Implementation
"""

from fastapi import APIRouter, HTTPException, Depends, Query
from typing import List
from models.schemas import CreateReviewRequest, ReviewResponse, ReviewListResponse
from services.auth_service import get_current_user
from config.database import get_db_cursor, execute_query

router = APIRouter()


@router.post("", response_model=ReviewResponse, status_code=201)
async def create_review(
    request: CreateReviewRequest,
    current_user: dict = Depends(get_current_user)
):
    """
    Submit a review for a completed booking
    
    - Only for completed bookings
    - One review per booking
    - Rating 1-5 stars
    """
    user_id = current_user["user_id"]
    
    # Verify booking exists and belongs to user
    booking_query = """
        SELECT b.BookingID, b.Status, b.UserID, ll.Name AS LocationName
        FROM Booking b
        INNER JOIN LockerUnit lu ON b.LockerID = lu.LockerID
        INNER JOIN LockerLocation ll ON lu.LocationID = ll.LocationID
        WHERE b.BookingID = %s
    """
    booking = execute_query(booking_query, (request.booking_id,), fetch_one=True)
    
    if not booking:
        raise HTTPException(status_code=404, detail="Booking not found")
    
    if booking["UserID"] != user_id:
        raise HTTPException(status_code=403, detail="Not authorized")
    
    if booking["Status"] != "Completed":
        raise HTTPException(status_code=400, detail="Can only review completed bookings")
    
    # Check if review already exists
    existing = execute_query("""
        SELECT ReviewID FROM Review WHERE BookingID = %s
    """, (request.booking_id,), fetch_one=True)
    
    if existing:
        raise HTTPException(status_code=400, detail="Review already submitted for this booking")
    
    # Create review
    with get_db_cursor(commit=True) as (cursor, conn):
        cursor.execute("""
            INSERT INTO Review (BookingID, Rating, Title, Comment)
            VALUES (%s, %s, %s, %s)
        """, (request.booking_id, request.rating, request.title, request.comment))
        
        review_id = cursor.lastrowid
    
    # Get user name for response
    user = execute_query("""
        SELECT CONCAT(FirstName, ' ', LastName) AS UserName FROM User WHERE UserID = %s
    """, (user_id,), fetch_one=True)
    
    return ReviewResponse(
        review_id=review_id,
        booking_id=request.booking_id,
        user_name=user["UserName"] if user else None,
        location_name=booking["LocationName"],
        rating=request.rating,
        title=request.title,
        comment=request.comment
    )


@router.get("/my-reviews", response_model=List[ReviewResponse])
async def get_my_reviews(
    current_user: dict = Depends(get_current_user)
):
    """
    Get all reviews submitted by the current user
    """
    query = """
        SELECT 
            r.ReviewID, r.BookingID, r.Rating, r.Title, r.Comment, r.CreatedAt,
            CONCAT(u.FirstName, ' ', u.LastName) AS UserName,
            ll.Name AS LocationName
        FROM Review r
        INNER JOIN Booking b ON r.BookingID = b.BookingID
        INNER JOIN User u ON b.UserID = u.UserID
        INNER JOIN LockerUnit lu ON b.LockerID = lu.LockerID
        INNER JOIN LockerLocation ll ON lu.LocationID = ll.LocationID
        WHERE b.UserID = %s
        ORDER BY r.CreatedAt DESC
    """
    
    results = execute_query(query, (current_user["user_id"],), fetch_all=True)
    
    return [
        ReviewResponse(
            review_id=row["ReviewID"],
            booking_id=row["BookingID"],
            user_name=row["UserName"],
            location_name=row["LocationName"],
            rating=row["Rating"],
            title=row["Title"],
            comment=row["Comment"],
            created_at=row["CreatedAt"]
        )
        for row in results
    ]


@router.get("/location/{location_id}", response_model=ReviewListResponse)
async def get_location_reviews(
    location_id: int,
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0)
):
    """
    Get all reviews for a specific location
    """
    # Get reviews
    query = """
        SELECT 
            r.ReviewID, r.BookingID, r.Rating, r.Title, r.Comment, r.CreatedAt,
            CONCAT(u.FirstName, ' ', LEFT(u.LastName, 1), '.') AS UserName,
            ll.Name AS LocationName
        FROM Review r
        INNER JOIN Booking b ON r.BookingID = b.BookingID
        INNER JOIN User u ON b.UserID = u.UserID
        INNER JOIN LockerUnit lu ON b.LockerID = lu.LockerID
        INNER JOIN LockerLocation ll ON lu.LocationID = ll.LocationID
        WHERE ll.LocationID = %s
        ORDER BY r.CreatedAt DESC
        LIMIT %s OFFSET %s
    """
    
    results = execute_query(query, (location_id, limit, offset), fetch_all=True)
    
    # Get stats
    stats_query = """
        SELECT 
            COUNT(*) AS TotalReviews,
            COALESCE(AVG(r.Rating), 0) AS AvgRating
        FROM Review r
        INNER JOIN Booking b ON r.BookingID = b.BookingID
        INNER JOIN LockerUnit lu ON b.LockerID = lu.LockerID
        WHERE lu.LocationID = %s
    """
    stats = execute_query(stats_query, (location_id,), fetch_one=True)
    
    reviews = [
        ReviewResponse(
            review_id=row["ReviewID"],
            booking_id=row["BookingID"],
            user_name=row["UserName"],
            location_name=row["LocationName"],
            rating=row["Rating"],
            title=row["Title"],
            comment=row["Comment"],
            created_at=row["CreatedAt"]
        )
        for row in results
    ]
    
    return ReviewListResponse(
        reviews=reviews,
        average_rating=round(float(stats["AvgRating"]), 1),
        total=int(stats["TotalReviews"])
    )


@router.put("/{review_id}", response_model=ReviewResponse)
async def update_review(
    review_id: int,
    rating: int = Query(None, ge=1, le=5),
    title: str = None,
    comment: str = None,
    current_user: dict = Depends(get_current_user)
):
    """
    Update an existing review
    """
    # Verify ownership
    review_query = """
        SELECT r.ReviewID, b.UserID, r.Rating, r.Title, r.Comment
        FROM Review r
        INNER JOIN Booking b ON r.BookingID = b.BookingID
        WHERE r.ReviewID = %s
    """
    review = execute_query(review_query, (review_id,), fetch_one=True)
    
    if not review:
        raise HTTPException(status_code=404, detail="Review not found")
    
    if review["UserID"] != current_user["user_id"]:
        raise HTTPException(status_code=403, detail="Not authorized")
    
    # Build update query
    updates = []
    params = []
    
    if rating is not None:
        updates.append("Rating = %s")
        params.append(rating)
    if title is not None:
        updates.append("Title = %s")
        params.append(title)
    if comment is not None:
        updates.append("Comment = %s")
        params.append(comment)
    
    if not updates:
        raise HTTPException(status_code=400, detail="No fields to update")
    
    params.append(review_id)
    
    execute_query(f"""
        UPDATE Review SET {', '.join(updates)} WHERE ReviewID = %s
    """, tuple(params), commit=True)
    
    # Return updated review
    updated = execute_query("""
        SELECT 
            r.ReviewID, r.BookingID, r.Rating, r.Title, r.Comment, r.CreatedAt,
            CONCAT(u.FirstName, ' ', u.LastName) AS UserName,
            ll.Name AS LocationName
        FROM Review r
        INNER JOIN Booking b ON r.BookingID = b.BookingID
        INNER JOIN User u ON b.UserID = u.UserID
        INNER JOIN LockerUnit lu ON b.LockerID = lu.LockerID
        INNER JOIN LockerLocation ll ON lu.LocationID = ll.LocationID
        WHERE r.ReviewID = %s
    """, (review_id,), fetch_one=True)
    
    return ReviewResponse(
        review_id=updated["ReviewID"],
        booking_id=updated["BookingID"],
        user_name=updated["UserName"],
        location_name=updated["LocationName"],
        rating=updated["Rating"],
        title=updated["Title"],
        comment=updated["Comment"],
        created_at=updated["CreatedAt"]
    )


@router.delete("/{review_id}")
async def delete_review(
    review_id: int,
    current_user: dict = Depends(get_current_user)
):
    """
    Delete a review
    """
    # Verify ownership
    review = execute_query("""
        SELECT r.ReviewID, b.UserID
        FROM Review r
        INNER JOIN Booking b ON r.BookingID = b.BookingID
        WHERE r.ReviewID = %s
    """, (review_id,), fetch_one=True)
    
    if not review:
        raise HTTPException(status_code=404, detail="Review not found")
    
    if review["UserID"] != current_user["user_id"]:
        raise HTTPException(status_code=403, detail="Not authorized")
    
    execute_query("DELETE FROM Review WHERE ReviewID = %s", (review_id,), commit=True)
    
    return {"status": "success", "message": "Review deleted"}
