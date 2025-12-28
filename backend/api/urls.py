"""
API URL Configuration
"""

from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    RegisterView, LoginView, ProfileView,
    LocationViewSet, LockerViewSet, BookingViewSet,
    DiscountView, ReviewViewSet, NotificationViewSet,
    health_check
)

router = DefaultRouter()
router.register(r'locations', LocationViewSet, basename='location')
router.register(r'lockers', LockerViewSet, basename='locker')
router.register(r'bookings', BookingViewSet, basename='booking')
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
    
    # Discount validation
    path('discounts/validate/', DiscountView.as_view(), name='validate_discount'),
    
    # Router URLs
    path('', include(router.urls)),
]
