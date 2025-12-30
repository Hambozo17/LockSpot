"""
API URL Configuration
"""

from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    RegisterView, LoginView, ProfileView,
    LocationViewSet, LockerViewSet, BookingViewSet,
    DiscountView, ReviewViewSet, NotificationViewSet,
    health_check, BookingListCreateView, BookingCompleteExpiredView,
    BookingDetailView, BookingQRView, BookingCancelView,
    LockerAvailabilityView, LocationReviewsView
)

router = DefaultRouter()
router.register(r'locations', LocationViewSet, basename='location')
router.register(r'lockers', LockerViewSet, basename='locker')
# Keep old booking routes for compatibility
router.register(r'bookings-old', BookingViewSet, basename='booking-old')
router.register(r'reviews', ReviewViewSet, basename='review')
router.register(r'notifications', NotificationViewSet, basename='notification')

urlpatterns = [
    # Health
    path('', health_check, name='health'),
    path('health/', health_check, name='health_check'),
    
    # Auth
    path('auth/register/', RegisterView.as_view(), name='register'),
    path('auth/login/', LoginView.as_view(), name='login'),
    path('auth/me/', ProfileView.as_view(), name='profile'),
    
    # Bookings - Raw SQL endpoints
    path('bookings/', BookingListCreateView.as_view(), name='bookings'),
    path('bookings/complete-expired/', BookingCompleteExpiredView.as_view(), name='complete-expired'),
    path('bookings/<int:booking_id>/', BookingDetailView.as_view(), name='booking-detail'),
    path('bookings/<int:booking_id>/qr/', BookingQRView.as_view(), name='booking-qr'),
    path('bookings/<int:booking_id>/cancel/', BookingCancelView.as_view(), name='booking-cancel'),
    
    # Locker availability check
    path('lockers/<int:locker_id>/availability/', LockerAvailabilityView.as_view(), name='locker-availability'),
    
    # Location reviews
    path('locations/<int:location_id>/reviews/', LocationReviewsView.as_view(), name='location-reviews'),
    
    # Discount validation
    path('discounts/validate/', DiscountView.as_view(), name='validate_discount'),
    
    # Router URLs
    path('', include(router.urls)),
]
