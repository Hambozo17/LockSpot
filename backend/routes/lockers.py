"""
Lockers Routes - Get available lockers
Raw SQL Implementation
"""

from fastapi import APIRouter, HTTPException, Query
from typing import Optional, List
from datetime import datetime
from models.schemas import LockerResponse, LockerSize
from config.database import execute_query

router = APIRouter()


@router.get("/available", response_model=List[LockerResponse])
async def get_available_lockers(
    location_id: Optional[int] = Query(None, description="Filter by location ID"),
    size: Optional[LockerSize] = Query(None, description="Filter by size"),
    start_time: Optional[datetime] = Query(None, description="Booking start time"),
    end_time: Optional[datetime] = Query(None, description="Booking end time")
):
    """
    Get available lockers with optional filters
    
    - Filter by location
    - Filter by size
    - Check availability for specific time slot
    """
    # Base query
    query = """
        SELECT 
            lu.LockerID,
            lu.LocationID,
            ll.Name AS LocationName,
            lu.UnitNumber,
            lu.Size,
            lu.Status,
            pt.HourlyRate,
            pt.DailyRate
        FROM LockerUnit lu
        INNER JOIN LockerLocation ll ON lu.LocationID = ll.LocationID
        INNER JOIN PricingTier pt ON lu.TierID = pt.TierID
        WHERE lu.Status = 'Available'
          AND ll.IsActive = TRUE
    """
    params = []
    
    # Apply filters
    if location_id:
        query += " AND lu.LocationID = %s"
        params.append(location_id)
    
    if size:
        query += " AND lu.Size = %s"
        params.append(size.value)
    
    # Check for time slot conflicts if dates provided
    if start_time and end_time:
        # Exclude lockers that have overlapping bookings
        query += """
            AND lu.LockerID NOT IN (
                SELECT b.LockerID FROM Booking b
                WHERE b.Status IN ('Pending', 'Confirmed', 'Active')
                  AND (
                      (%s >= b.StartTime AND %s < b.EndTime) OR
                      (%s > b.StartTime AND %s <= b.EndTime) OR
                      (%s <= b.StartTime AND %s >= b.EndTime)
                  )
            )
        """
        params.extend([start_time, start_time, end_time, end_time, start_time, end_time])
    
    query += " ORDER BY ll.Name, lu.Size, lu.UnitNumber"
    
    results = execute_query(query, tuple(params), fetch_all=True)
    
    return [
        LockerResponse(
            locker_id=row["LockerID"],
            location_id=row["LocationID"],
            location_name=row["LocationName"],
            unit_number=row["UnitNumber"],
            size=row["Size"],
            status=row["Status"],
            hourly_rate=float(row["HourlyRate"]),
            daily_rate=float(row["DailyRate"])
        )
        for row in results
    ]


@router.get("/{locker_id}", response_model=LockerResponse)
async def get_locker_by_id(locker_id: int):
    """
    Get a specific locker by ID
    """
    query = """
        SELECT 
            lu.LockerID,
            lu.LocationID,
            ll.Name AS LocationName,
            lu.UnitNumber,
            lu.Size,
            lu.Status,
            pt.HourlyRate,
            pt.DailyRate
        FROM LockerUnit lu
        INNER JOIN LockerLocation ll ON lu.LocationID = ll.LocationID
        INNER JOIN PricingTier pt ON lu.TierID = pt.TierID
        WHERE lu.LockerID = %s
    """
    
    row = execute_query(query, (locker_id,), fetch_one=True)
    
    if not row:
        raise HTTPException(status_code=404, detail="Locker not found")
    
    return LockerResponse(
        locker_id=row["LockerID"],
        location_id=row["LocationID"],
        location_name=row["LocationName"],
        unit_number=row["UnitNumber"],
        size=row["Size"],
        status=row["Status"],
        hourly_rate=float(row["HourlyRate"]),
        daily_rate=float(row["DailyRate"])
    )


@router.get("/{locker_id}/availability")
async def check_locker_availability(
    locker_id: int,
    start_time: datetime = Query(..., description="Desired start time"),
    end_time: datetime = Query(..., description="Desired end time")
):
    """
    Check if a specific locker is available for a time slot
    
    Returns availability status and any conflicting bookings
    """
    # First check locker exists and current status
    locker_query = """
        SELECT LockerID, Status, Size
        FROM LockerUnit
        WHERE LockerID = %s
    """
    locker = execute_query(locker_query, (locker_id,), fetch_one=True)
    
    if not locker:
        raise HTTPException(status_code=404, detail="Locker not found")
    
    if locker["Status"] not in ["Available", "Booked"]:
        return {
            "locker_id": locker_id,
            "is_available": False,
            "reason": f"Locker is currently {locker['Status']}",
            "conflicts": []
        }
    
    # Check for overlapping bookings - RAW SQL for conflict detection
    conflict_query = """
        SELECT 
            b.BookingID,
            b.StartTime,
            b.EndTime,
            b.Status
        FROM Booking b
        WHERE b.LockerID = %s
          AND b.Status IN ('Pending', 'Confirmed', 'Active')
          AND (
              (%s >= b.StartTime AND %s < b.EndTime) OR
              (%s > b.StartTime AND %s <= b.EndTime) OR
              (%s <= b.StartTime AND %s >= b.EndTime)
          )
        ORDER BY b.StartTime
    """
    
    conflicts = execute_query(
        conflict_query, 
        (locker_id, start_time, start_time, end_time, end_time, start_time, end_time),
        fetch_all=True
    )
    
    is_available = len(conflicts) == 0
    
    return {
        "locker_id": locker_id,
        "size": locker["Size"],
        "requested_start": start_time.isoformat(),
        "requested_end": end_time.isoformat(),
        "is_available": is_available,
        "conflicts": [
            {
                "booking_id": c["BookingID"],
                "start_time": c["StartTime"].isoformat() if c["StartTime"] else None,
                "end_time": c["EndTime"].isoformat() if c["EndTime"] else None,
                "status": c["Status"]
            }
            for c in conflicts
        ]
    }
