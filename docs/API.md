# API Documentation

Complete API reference for LockSpot backend.

**Base URL:** `http://localhost:8000/api`

---

## Authentication

All authenticated endpoints require the `Authorization` header:

```
Authorization: Bearer <access_token>
```

---

## Endpoints

### Health Check

```http
GET /api/
```

**Response:**
```json
{
    "status": "online",
    "service": "LockSpot API",
    "version": "2.0.0"
}
```

---

## Auth Endpoints

### Register User

```http
POST /api/auth/register/
```

**Request Body:**
```json
{
    "email": "user@example.com",
    "password": "securepassword",
    "first_name": "John",
    "last_name": "Doe",
    "phone_number": "+201234567890"
}
```

**Response (201):**
```json
{
    "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "token_type": "bearer",
    "expires_in": 86400,
    "user": {
        "id": 1,
        "email": "user@example.com",
        "first_name": "John",
        "last_name": "Doe",
        "phone": "+201234567890"
    }
}
```

**Errors:**
- `400` - Email already exists or validation error

---

### Login

```http
POST /api/auth/login/
```

**Request Body:**
```json
{
    "email": "user@example.com",
    "password": "securepassword"
}
```

**Response (200):**
```json
{
    "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "token_type": "bearer",
    "expires_in": 86400,
    "user": {
        "id": 1,
        "email": "user@example.com",
        "first_name": "John",
        "last_name": "Doe",
        "phone": "+201234567890"
    }
}
```

**Errors:**
- `401` - Invalid credentials

---

### Get Profile

```http
GET /api/auth/me/
Authorization: Bearer <token>
```

**Response (200):**
```json
{
    "id": 1,
    "email": "user@example.com",
    "first_name": "John",
    "last_name": "Doe",
    "phone": "+201234567890",
    "user_type": "Customer",
    "is_verified": true
}
```

---

## Location Endpoints

### List Locations

```http
GET /api/locations/
```

**Query Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `city` | string | Filter by city name |

**Response (200):**
```json
{
    "count": 3,
    "next": null,
    "previous": null,
    "results": [
        {
            "location_id": 1,
            "id": 1,
            "name": "Sheikh Zayed Mall",
            "description": "Premium smart lockers at Arkan Plaza",
            "image": null,
            "operating_hours_start": "09:00:00",
            "operating_hours_end": "23:00:00",
            "is_active": true,
            "contact_phone": "+201234567890",
            "address": {
                "id": 1,
                "street_address": "Arkan Plaza, 26th of July Corridor",
                "city": "Sheikh Zayed",
                "state": "Giza",
                "zip_code": "",
                "country": "Egypt",
                "latitude": "30.01310000",
                "longitude": "30.97180000"
            },
            "available_lockers": 5,
            "total_lockers": 15
        }
    ]
}
```

---

### Get Location Details

```http
GET /api/locations/{id}/
```

**Response (200):**
```json
{
    "location_id": 1,
    "name": "Sheikh Zayed Mall",
    "description": "Premium smart lockers at Arkan Plaza",
    "address": { ... },
    "available_lockers": 5,
    "total_lockers": 15,
    "lockers": [
        {
            "id": 1,
            "unit_number": "SZ-001",
            "size": "Small",
            "status": "Available",
            "hourly_rate": "10.00",
            "daily_rate": "60.00"
        }
    ]
}
```

---

### Get Location Pricing

```http
GET /api/locations/{id}/pricing/
```

**Response (200):**
```json
[
    {
        "tier_id": 1,
        "name": "Standard",
        "size": "Small",
        "base_price": "5.00",
        "hourly_rate": "10.00",
        "daily_rate": "60.00"
    },
    {
        "tier_id": 2,
        "name": "Standard",
        "size": "Medium",
        "base_price": "8.00",
        "hourly_rate": "15.00",
        "daily_rate": "90.00"
    }
]
```

---

## Locker Endpoints

### List Available Lockers

```http
GET /api/lockers/available/
```

**Query Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `location_id` | int | Filter by location ID |
| `size` | string | Filter by size (Small, Medium, Large) |

**Response (200):**
```json
{
    "results": [
        {
            "id": 1,
            "location_id": 1,
            "location_name": "Sheikh Zayed Mall",
            "unit_number": "SZ-001",
            "size": "Small",
            "status": "Available",
            "hourly_rate": "10.00",
            "daily_rate": "60.00"
        }
    ]
}
```

---

### Get Locker Details

```http
GET /api/lockers/{id}/
```

**Response (200):**
```json
{
    "id": 1,
    "location": {
        "id": 1,
        "name": "Sheikh Zayed Mall"
    },
    "unit_number": "SZ-001",
    "size": "Small",
    "status": "Available",
    "tier": {
        "name": "Standard",
        "hourly_rate": "10.00",
        "daily_rate": "60.00"
    }
}
```

---

## Booking Endpoints

### Create Booking

```http
POST /api/bookings/
Authorization: Bearer <token>
```

**Request Body:**
```json
{
    "locker_id": 1,
    "start_time": "2025-01-01T10:00:00Z",
    "end_time": "2025-01-01T14:00:00Z",
    "booking_type": "Storage",
    "discount_code": "FIRST10"
}
```

**Response (201):**
```json
{
    "booking_id": 1,
    "user_id": 1,
    "locker": {
        "id": 1,
        "unit_number": "SZ-001",
        "size": "Small"
    },
    "start_time": "2025-01-01T10:00:00Z",
    "end_time": "2025-01-01T14:00:00Z",
    "status": "Confirmed",
    "subtotal_amount": "40.00",
    "discount_amount": "4.00",
    "total_amount": "36.00"
}
```

**Errors:**
- `400` - Locker not available or time conflict

---

### List User Bookings

```http
GET /api/bookings/
Authorization: Bearer <token>
```

**Query Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `status` | string | Filter by status |

**Response (200):**
```json
{
    "results": [
        {
            "booking_id": 1,
            "location_name": "Sheikh Zayed Mall",
            "unit_number": "SZ-001",
            "size": "Small",
            "start_time": "2025-01-01T10:00:00Z",
            "end_time": "2025-01-01T14:00:00Z",
            "status": "Active",
            "total_amount": "36.00"
        }
    ]
}
```

---

### Get Booking Details

```http
GET /api/bookings/{id}/
Authorization: Bearer <token>
```

---

### Cancel Booking

```http
POST /api/bookings/{id}/cancel/
Authorization: Bearer <token>
```

**Request Body:**
```json
{
    "reason": "Changed plans"
}
```

**Response (200):**
```json
{
    "status": "cancelled"
}
```

---

### Get Booking QR Code

```http
GET /api/bookings/{id}/qr_code/
Authorization: Bearer <token>
```

**Response (200):**
```json
{
    "qr_id": 1,
    "booking_id": 1,
    "code": "LOCK-1-A1B2C3D4",
    "code_type": "Unlock",
    "expires_at": "2025-01-01T14:00:00Z",
    "is_used": false
}
```

---

## Discount Endpoints

### Validate Discount Code

```http
POST /api/discounts/validate/
```

**Request Body:**
```json
{
    "code": "FIRST10"
}
```

**Response (200):**
```json
{
    "code": "FIRST10",
    "discount_type": "Percentage",
    "discount_value": "10.00",
    "min_booking_amount": "20.00",
    "max_discount_amount": "50.00",
    "valid_from": "2025-01-01",
    "valid_to": "2025-12-31"
}
```

**Errors:**
- `400` - Discount code expired or invalid
- `404` - Discount code not found

---

## Error Responses

All errors follow this format:

```json
{
    "detail": "Error message describing what went wrong"
}
```

### HTTP Status Codes

| Code | Meaning |
|------|---------|
| `200` | Success |
| `201` | Created |
| `400` | Bad Request |
| `401` | Unauthorized |
| `403` | Forbidden |
| `404` | Not Found |
| `500` | Server Error |

---

## Rate Limiting

Currently no rate limiting is implemented for development. Production deployments should configure appropriate limits.

---

## Data Models

### User
- `id`: Integer
- `email`: String (unique)
- `first_name`: String
- `last_name`: String
- `phone`: String
- `user_type`: Enum (Customer, Admin)
- `is_verified`: Boolean

### Location
- `id`: Integer
- `name`: String
- `description`: Text
- `address`: Address object
- `operating_hours_start`: Time
- `operating_hours_end`: Time

### Locker
- `id`: Integer
- `location_id`: Integer (FK)
- `unit_number`: String
- `size`: Enum (Small, Medium, Large)
- `status`: Enum (Available, Booked, Maintenance)

### Booking
- `id`: Integer
- `user_id`: Integer (FK)
- `locker_id`: Integer (FK)
- `start_time`: DateTime
- `end_time`: DateTime
- `status`: Enum (Pending, Confirmed, Active, Completed, Cancelled)
- `total_amount`: Decimal
