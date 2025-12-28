"""
Pydantic Models / Schemas for Request/Response Validation
"""

from pydantic import BaseModel, EmailStr, Field
from typing import Optional, List
from datetime import datetime
from enum import Enum


# ==================== ENUMS ====================

class UserType(str, Enum):
    CUSTOMER = "Customer"
    ADMIN = "Admin"


class LockerSize(str, Enum):
    SMALL = "Small"
    MEDIUM = "Medium"
    LARGE = "Large"


class LockerStatus(str, Enum):
    AVAILABLE = "Available"
    BOOKED = "Booked"
    MAINTENANCE = "Maintenance"
    OUT_OF_SERVICE = "OutOfService"


class BookingStatus(str, Enum):
    PENDING = "Pending"
    CONFIRMED = "Confirmed"
    ACTIVE = "Active"
    COMPLETED = "Completed"
    CANCELLED = "Cancelled"
    EXPIRED = "Expired"


class BookingType(str, Enum):
    STORAGE = "Storage"
    DELIVERY = "Delivery"


class PaymentStatus(str, Enum):
    PENDING = "Pending"
    SUCCESS = "Success"
    FAILED = "Failed"
    REFUNDED = "Refunded"


class PaymentMethodType(str, Enum):
    VISA = "Visa"
    MASTERCARD = "Mastercard"
    MOBILE_WALLET = "MobileWallet"
    CASH = "Cash"


# ==================== AUTH SCHEMAS ====================

class UserRegisterRequest(BaseModel):
    first_name: str = Field(..., min_length=2, max_length=50)
    last_name: str = Field(..., min_length=2, max_length=50)
    email: EmailStr
    phone: str = Field(..., min_length=10, max_length=20)
    password: str = Field(..., min_length=6)


class UserLoginRequest(BaseModel):
    email: EmailStr
    password: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int
    user: "UserResponse"


class UserResponse(BaseModel):
    user_id: int
    first_name: str
    last_name: str
    email: str
    phone: str
    user_type: str
    is_verified: bool
    created_at: Optional[datetime] = None


# ==================== LOCATION SCHEMAS ====================

class LocationAddressResponse(BaseModel):
    address_id: int
    street_address: str
    city: str
    state: Optional[str] = None
    zip_code: Optional[str] = None
    country: str
    latitude: Optional[float] = None
    longitude: Optional[float] = None


class LocationResponse(BaseModel):
    location_id: int
    name: str
    description: Optional[str] = None
    image_url: Optional[str] = None
    operating_hours_start: Optional[str] = None
    operating_hours_end: Optional[str] = None
    is_active: bool
    address: Optional[LocationAddressResponse] = None
    available_lockers: Optional[int] = None
    total_lockers: Optional[int] = None
    average_rating: Optional[float] = None


class LocationListResponse(BaseModel):
    locations: List[LocationResponse]
    total: int


# ==================== LOCKER SCHEMAS ====================

class PricingTierResponse(BaseModel):
    tier_id: int
    name: str
    size: str
    base_price: float
    hourly_rate: float
    daily_rate: float
    weekly_rate: Optional[float] = None
    description: Optional[str] = None


class LockerResponse(BaseModel):
    locker_id: int
    location_id: int
    location_name: Optional[str] = None
    unit_number: str
    size: str
    status: str
    hourly_rate: Optional[float] = None
    daily_rate: Optional[float] = None


class AvailableLockersRequest(BaseModel):
    location_id: Optional[int] = None
    size: Optional[LockerSize] = None
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None


# ==================== BOOKING SCHEMAS ====================

class CreateBookingRequest(BaseModel):
    locker_id: int
    start_time: datetime
    end_time: datetime
    booking_type: BookingType = BookingType.STORAGE
    discount_code: Optional[str] = None


class BookingResponse(BaseModel):
    booking_id: int
    user_id: int
    locker_id: int
    location_name: Optional[str] = None
    unit_number: Optional[str] = None
    size: Optional[str] = None
    start_time: datetime
    end_time: datetime
    booking_type: str
    subtotal_amount: float
    discount_amount: float
    total_amount: float
    status: str
    created_at: Optional[datetime] = None
    qr_code: Optional[str] = None
    payment_status: Optional[str] = None


class BookingListResponse(BaseModel):
    bookings: List[BookingResponse]
    total: int


class CancelBookingRequest(BaseModel):
    reason: Optional[str] = None


class CancelBookingResponse(BaseModel):
    booking_id: int
    status: str
    refund_amount: float
    message: str


# ==================== PAYMENT SCHEMAS ====================

class ProcessPaymentRequest(BaseModel):
    booking_id: int
    method_id: Optional[int] = None
    method_type: PaymentMethodType = PaymentMethodType.CASH
    card_last_four: Optional[str] = None
    transaction_reference: Optional[str] = None


class PaymentResponse(BaseModel):
    payment_id: int
    booking_id: int
    amount: float
    status: str
    payment_date: Optional[datetime] = None
    transaction_reference: Optional[str] = None


class SavePaymentMethodRequest(BaseModel):
    method_type: PaymentMethodType
    card_last_four: Optional[str] = None
    card_holder_name: Optional[str] = None
    expiry_month: Optional[int] = None
    expiry_year: Optional[int] = None
    wallet_phone: Optional[str] = None
    is_default: bool = False


class PaymentMethodResponse(BaseModel):
    method_id: int
    method_type: str
    card_last_four: Optional[str] = None
    card_holder_name: Optional[str] = None
    is_default: bool


# ==================== REVIEW SCHEMAS ====================

class CreateReviewRequest(BaseModel):
    booking_id: int
    rating: int = Field(..., ge=1, le=5)
    title: Optional[str] = Field(None, max_length=100)
    comment: Optional[str] = None


class ReviewResponse(BaseModel):
    review_id: int
    booking_id: int
    user_name: Optional[str] = None
    location_name: Optional[str] = None
    rating: int
    title: Optional[str] = None
    comment: Optional[str] = None
    created_at: Optional[datetime] = None


class ReviewListResponse(BaseModel):
    reviews: List[ReviewResponse]
    average_rating: float
    total: int


# ==================== DISCOUNT SCHEMAS ====================

class ValidateDiscountRequest(BaseModel):
    code: str
    booking_amount: float


class DiscountResponse(BaseModel):
    discount_id: int
    code: str
    description: Optional[str] = None
    discount_type: str
    discount_value: float
    calculated_discount: float
    is_valid: bool
    message: str


# ==================== QR CODE SCHEMAS ====================

class QRCodeResponse(BaseModel):
    qr_id: int
    booking_id: int
    code: str
    code_type: str
    expires_at: datetime
    qr_image_base64: Optional[str] = None


# ==================== NOTIFICATION SCHEMAS ====================

class NotificationResponse(BaseModel):
    notification_id: int
    title: str
    message: str
    notification_type: str
    is_read: bool
    created_at: Optional[datetime] = None


# ==================== ERROR SCHEMAS ====================

class ErrorResponse(BaseModel):
    status: str = "error"
    message: str
    detail: Optional[str] = None


class SuccessResponse(BaseModel):
    status: str = "success"
    message: str
    data: Optional[dict] = None


# Update forward references
TokenResponse.model_rebuild()
