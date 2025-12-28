"""
Locations Routes - Get locker locations
Raw SQL Implementation
"""

from fastapi import APIRouter, HTTPException, Query
from typing import Optional, List
from models.schemas import LocationResponse, LocationListResponse
from config.database import execute_query

router = APIRouter()


@router.get("", response_model=LocationListResponse)
async def get_all_locations(
    city: Optional[str] = Query(None, description="Filter by city"),
    is_active: bool = Query(True, description="Only show active locations")
):
    """
    Get all locker locations with availability info
    
    - Filter by city
    - Shows available locker count per location
    """
    # RAW SQL with JOINs and aggregations
    query = """
        SELECT 
            ll.LocationID,
            ll.Name,
            ll.Description,
            ll.ImageURL,
            TIME_FORMAT(ll.OperatingHoursStart, '%%H:%%i') AS OperatingHoursStart,
            TIME_FORMAT(ll.OperatingHoursEnd, '%%H:%%i') AS OperatingHoursEnd,
            ll.IsActive,
            la.AddressID,
            la.StreetAddress,
            la.City,
            la.State,
            la.ZipCode,
            la.Country,
            la.Latitude,
            la.Longitude,
            COUNT(lu.LockerID) AS TotalLockers,
            SUM(CASE WHEN lu.Status = 'Available' THEN 1 ELSE 0 END) AS AvailableLockers,
            COALESCE(AVG(r.Rating), 0) AS AverageRating
        FROM LockerLocation ll
        INNER JOIN LocationAddress la ON ll.AddressID = la.AddressID
        LEFT JOIN LockerUnit lu ON ll.LocationID = lu.LocationID
        LEFT JOIN Booking b ON lu.LockerID = b.LockerID AND b.Status = 'Completed'
        LEFT JOIN Review r ON b.BookingID = r.BookingID
        WHERE ll.IsActive = %s
    """
    params = [is_active]
    
    if city:
        query += " AND la.City LIKE %s"
        params.append(f"%{city}%")
    
    query += """
        GROUP BY ll.LocationID, ll.Name, ll.Description, ll.ImageURL,
                 ll.OperatingHoursStart, ll.OperatingHoursEnd, ll.IsActive,
                 la.AddressID, la.StreetAddress, la.City, la.State,
                 la.ZipCode, la.Country, la.Latitude, la.Longitude
        ORDER BY AvailableLockers DESC, ll.Name ASC
    """
    
    results = execute_query(query, tuple(params), fetch_all=True)
    
    locations = []
    for row in results:
        locations.append(LocationResponse(
            location_id=row["LocationID"],
            name=row["Name"],
            description=row["Description"],
            image_url=row["ImageURL"],
            operating_hours_start=row["OperatingHoursStart"],
            operating_hours_end=row["OperatingHoursEnd"],
            is_active=row["IsActive"],
            address={
                "address_id": row["AddressID"],
                "street_address": row["StreetAddress"],
                "city": row["City"],
                "state": row["State"],
                "zip_code": row["ZipCode"],
                "country": row["Country"],
                "latitude": float(row["Latitude"]) if row["Latitude"] else None,
                "longitude": float(row["Longitude"]) if row["Longitude"] else None
            },
            available_lockers=int(row["AvailableLockers"] or 0),
            total_lockers=int(row["TotalLockers"] or 0),
            average_rating=round(float(row["AverageRating"] or 0), 1)
        ))
    
    return LocationListResponse(locations=locations, total=len(locations))


@router.get("/{location_id}", response_model=LocationResponse)
async def get_location_by_id(location_id: int):
    """
    Get a specific location by ID with full details
    """
    query = """
        SELECT 
            ll.LocationID,
            ll.Name,
            ll.Description,
            ll.ImageURL,
            TIME_FORMAT(ll.OperatingHoursStart, '%%H:%%i') AS OperatingHoursStart,
            TIME_FORMAT(ll.OperatingHoursEnd, '%%H:%%i') AS OperatingHoursEnd,
            ll.IsActive,
            la.AddressID,
            la.StreetAddress,
            la.City,
            la.State,
            la.ZipCode,
            la.Country,
            la.Latitude,
            la.Longitude,
            COUNT(lu.LockerID) AS TotalLockers,
            SUM(CASE WHEN lu.Status = 'Available' THEN 1 ELSE 0 END) AS AvailableLockers,
            COALESCE(AVG(r.Rating), 0) AS AverageRating
        FROM LockerLocation ll
        INNER JOIN LocationAddress la ON ll.AddressID = la.AddressID
        LEFT JOIN LockerUnit lu ON ll.LocationID = lu.LocationID
        LEFT JOIN Booking b ON lu.LockerID = b.LockerID AND b.Status = 'Completed'
        LEFT JOIN Review r ON b.BookingID = r.BookingID
        WHERE ll.LocationID = %s
        GROUP BY ll.LocationID, ll.Name, ll.Description, ll.ImageURL,
                 ll.OperatingHoursStart, ll.OperatingHoursEnd, ll.IsActive,
                 la.AddressID, la.StreetAddress, la.City, la.State,
                 la.ZipCode, la.Country, la.Latitude, la.Longitude
    """
    
    row = execute_query(query, (location_id,), fetch_one=True)
    
    if not row:
        raise HTTPException(status_code=404, detail="Location not found")
    
    return LocationResponse(
        location_id=row["LocationID"],
        name=row["Name"],
        description=row["Description"],
        image_url=row["ImageURL"],
        operating_hours_start=row["OperatingHoursStart"],
        operating_hours_end=row["OperatingHoursEnd"],
        is_active=row["IsActive"],
        address={
            "address_id": row["AddressID"],
            "street_address": row["StreetAddress"],
            "city": row["City"],
            "state": row["State"],
            "zip_code": row["ZipCode"],
            "country": row["Country"],
            "latitude": float(row["Latitude"]) if row["Latitude"] else None,
            "longitude": float(row["Longitude"]) if row["Longitude"] else None
        },
        available_lockers=int(row["AvailableLockers"] or 0),
        total_lockers=int(row["TotalLockers"] or 0),
        average_rating=round(float(row["AverageRating"] or 0), 1)
    )


@router.get("/{location_id}/pricing")
async def get_location_pricing(location_id: int):
    """
    Get pricing tiers available at a specific location
    """
    query = """
        SELECT DISTINCT
            pt.TierID,
            pt.Name,
            pt.Size,
            pt.BasePrice,
            pt.HourlyRate,
            pt.DailyRate,
            pt.WeeklyRate,
            pt.Description,
            COUNT(lu.LockerID) AS AvailableCount
        FROM PricingTier pt
        INNER JOIN LockerUnit lu ON pt.TierID = lu.TierID
        WHERE lu.LocationID = %s AND lu.Status = 'Available'
        GROUP BY pt.TierID, pt.Name, pt.Size, pt.BasePrice,
                 pt.HourlyRate, pt.DailyRate, pt.WeeklyRate, pt.Description
        ORDER BY pt.Size, pt.HourlyRate
    """
    
    results = execute_query(query, (location_id,), fetch_all=True)
    
    return {
        "location_id": location_id,
        "pricing_tiers": [
            {
                "tier_id": row["TierID"],
                "name": row["Name"],
                "size": row["Size"],
                "base_price": float(row["BasePrice"]),
                "hourly_rate": float(row["HourlyRate"]),
                "daily_rate": float(row["DailyRate"]),
                "weekly_rate": float(row["WeeklyRate"]) if row["WeeklyRate"] else None,
                "description": row["Description"],
                "available_count": int(row["AvailableCount"])
            }
            for row in results
        ]
    }
