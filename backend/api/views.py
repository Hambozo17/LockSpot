"""
API Views for LockSpot
REST API Endpoints
"""

from rest_framework import viewsets, status, generics
from rest_framework.decorators import api_view, permission_classes, action
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView
from django.utils import timezone
from django.db import transaction
from django.db.models import Q
from datetime import datetime, timedelta
import uuid
import hashlib

from lockers.models import (
    User, LockerLocation, LockerUnit, PricingTier, Discount,
    Booking, PaymentMethod, Payment, Review, QRAccessCode, Notification
)
from .serializers import (
    UserRegistrationSerializer, UserLoginSerializer, UserSerializer, TokenResponseSerializer,
    LockerLocationListSerializer, LockerLocationDetailSerializer,
    LockerUnitSerializer, AvailableLockerSerializer, PricingTierSerializer,
    DiscountSerializer, ValidateDiscountSerializer,
    CreateBookingSerializer, BookingSerializer, BookingListSerializer, CancelBookingSerializer,
    PaymentMethodSerializer, PaymentSerializer,
    CreateReviewSerializer, ReviewSerializer,
    QRCodeSerializer, GenerateQRSerializer,
    NotificationSerializer
)

# Import raw SQL functions
from db_utils import DatabaseConnection
from .authentication import create_access_token, get_token_expiration_seconds


# ==================== AUTH VIEWS ====================

class RegisterView(APIView):
    """User Registration with MySQL"""
    permission_classes = [AllowAny]
    
    def post(self, request):
        email = request.data.get('email')
        password = request.data.get('password')
        first_name = request.data.get('first_name', '')
        last_name = request.data.get('last_name', '')
        phone = request.data.get('phone_number', '') or request.data.get('phone', '')
        
        # Handle empty phone - convert to None for database
        if not phone or phone.strip() == '':
            phone = None
        
        # Validate required fields
        if not email or not password:
            return Response(
                {'detail': 'Email and password are required'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            # Check if user already exists and create new user
            with DatabaseConnection.get_connection() as conn:
                cursor = conn.cursor(dictionary=True)
                
                cursor.execute("SELECT id FROM auth_user WHERE email = %s", (email,))
                if cursor.fetchone():
                    cursor.close()
                    return Response(
                        {'detail': 'User with this email already exists'},
                        status=status.HTTP_400_BAD_REQUEST
                    )
                
                # Hash password
                hashed_password = hashlib.sha256(password.encode()).hexdigest()
                
                # Insert new user
                cursor.execute("""
                    INSERT INTO auth_user 
                    (password, email, first_name, last_name, phone, user_type, 
                     is_verified, is_staff, is_superuser, is_active, created_at, updated_at)
                    VALUES (%s, %s, %s, %s, %s, 'Customer', TRUE, FALSE, FALSE, TRUE, NOW(), NOW())
                """, (hashed_password, email, first_name, last_name, phone))
                
                user_id = cursor.lastrowid
                conn.commit()
                
                # Fetch created user
                cursor.execute("""
                    SELECT id, email, first_name, last_name, phone, user_type, created_at
                    FROM auth_user WHERE id = %s
                """, (user_id,))
                user_data = cursor.fetchone()
                cursor.close()
                
                # Create mock user object for token
                class MockUser:
                    def __init__(self, data):
                        self.id = data['id']
                        self.email = data['email']
                        self.user_type = data['user_type']
                
                user = MockUser(user_data)
                token = create_access_token(user)
                
                return Response({
                    'access_token': token,
                    'token_type': 'bearer',
                    'expires_in': get_token_expiration_seconds(),
                    'user': {
                        'id': user_data['id'],
                        'email': user_data['email'],
                        'first_name': user_data['first_name'],
                        'last_name': user_data['last_name'],
                        'phone': user_data['phone']
                    }
                }, status=status.HTTP_201_CREATED)
        except Exception as e:
            return Response(
                {'detail': f'Registration failed: {str(e)}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class LoginView(APIView):
    """User Login with MySQL"""
    permission_classes = [AllowAny]
    
    def post(self, request):
        email = request.data.get('email')
        password = request.data.get('password')
        
        if not email or not password:
            return Response(
                {'detail': 'Email and password are required'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        with DatabaseConnection.get_connection() as conn:
            cursor = conn.cursor(dictionary=True)
            
            # Get user by email
            cursor.execute("""
                SELECT id, email, password, first_name, last_name, phone, user_type, is_active
                FROM auth_user WHERE email = %s
            """, (email,))
            
            user_data = cursor.fetchone()
            
            if not user_data:
                cursor.close()
                return Response(
                    {'detail': 'Invalid email or password'},
                    status=status.HTTP_401_UNAUTHORIZED
                )
            
            # Verify password
            hashed_password = hashlib.sha256(password.encode()).hexdigest()
            if user_data['password'] != hashed_password:
                cursor.close()
                return Response(
                    {'detail': 'Invalid email or password'},
                    status=status.HTTP_401_UNAUTHORIZED
                )
            
            # Update last login
            cursor.execute("""
                UPDATE auth_user SET last_login = NOW() WHERE id = %s
            """, (user_data['id'],))
            conn.commit()
            
            cursor.close()
            
            # Create mock user object for token
            class MockUser:
                def __init__(self, data):
                    self.id = data['id']
                    self.email = data['email']
                    self.user_type = data['user_type']
            
            user = MockUser(user_data)
            token = create_access_token(user)
            
            return Response({
                'access_token': token,
                'token_type': 'bearer',
                'expires_in': get_token_expiration_seconds(),
                'user': {
                    'id': user_data['id'],
                    'email': user_data['email'],
                    'first_name': user_data['first_name'],
                    'last_name': user_data['last_name'],
                    'phone': user_data['phone']
                }
            })


class ProfileView(APIView):
    """User Profile"""
    permission_classes = [IsAuthenticated]
    
    def get(self, request):
        return Response(UserSerializer(request.user).data)
    
    def patch(self, request):
        serializer = UserSerializer(request.user, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


# ==================== LOCATION VIEWS ====================

class LocationViewSet(viewsets.ReadOnlyModelViewSet):
    """Locker Locations"""
    permission_classes = [AllowAny]
    queryset = LockerLocation.objects.filter(is_active=True).select_related('address')
    
    def get_serializer_class(self):
        if self.action == 'retrieve':
            return LockerLocationDetailSerializer
        return LockerLocationListSerializer
    
    @action(detail=True, methods=['get'])
    def pricing(self, request, pk=None):
        """Get pricing tiers for a location"""
        location = self.get_object()
        tiers = PricingTier.objects.filter(
            lockers__location=location, is_active=True
        ).distinct()
        return Response(PricingTierSerializer(tiers, many=True).data)
    
    @action(detail=True, methods=['get'])
    def lockers(self, request, pk=None):
        """Get available lockers at a location"""
        location = self.get_object()
        size = request.query_params.get('size')
        
        lockers = location.lockers.filter(status='Available')
        if size:
            lockers = lockers.filter(size=size)
        
        return Response(AvailableLockerSerializer(lockers, many=True).data)


# ==================== LOCKER VIEWS ====================

class LockerViewSet(viewsets.ReadOnlyModelViewSet):
    """Locker Units"""
    permission_classes = [AllowAny]
    serializer_class = LockerUnitSerializer
    
    def get_queryset(self):
        queryset = LockerUnit.objects.select_related('location', 'tier')
        
        # Filter by location
        location_id = self.request.query_params.get('location_id')
        if location_id:
            queryset = queryset.filter(location_id=location_id)
        
        # Filter by size
        size = self.request.query_params.get('size')
        if size:
            queryset = queryset.filter(size=size)
        
        # Filter by status
        status_param = self.request.query_params.get('status')
        if status_param:
            queryset = queryset.filter(status=status_param)
        else:
            # Default to available only
            queryset = queryset.filter(status='Available')
        
        return queryset
    
    @action(detail=False, methods=['get'])
    def available(self, request):
        """Get all available lockers with optional filters"""
        queryset = LockerUnit.objects.filter(status='Available').select_related('location', 'tier')
        
        location_id = request.query_params.get('location_id')
        if location_id:
            queryset = queryset.filter(location_id=location_id)
        
        size = request.query_params.get('size')
        if size:
            queryset = queryset.filter(size=size)
        
        return Response(AvailableLockerSerializer(queryset, many=True).data)
    
    @action(detail=True, methods=['post'])
    def check_availability(self, request, pk=None):
        """Check if locker is available for a time period"""
        locker = self.get_object()
        start_time = request.data.get('start_time')
        end_time = request.data.get('end_time')
        
        if not start_time or not end_time:
            return Response(
                {'detail': 'start_time and end_time are required'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Check for conflicts
        conflicts = Booking.objects.filter(
            locker=locker,
            status__in=['Pending', 'Confirmed', 'Active']
        ).filter(
            Q(start_time__lt=end_time, end_time__gt=start_time)
        ).exists()
        
        return Response({
            'available': not conflicts,
            'locker': LockerUnitSerializer(locker).data
        })


# ==================== BOOKING VIEWS ====================

class BookingViewSet(viewsets.ModelViewSet):
    """User Bookings"""
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        return Booking.objects.filter(
            user=self.request.user
        ).select_related('locker', 'locker__location').order_by('-created_at')
    
    def get_serializer_class(self):
        if self.action == 'list':
            return BookingListSerializer
        if self.action == 'create':
            return CreateBookingSerializer
        return BookingSerializer
    
    @transaction.atomic
    def create(self, request):
        """Create a new booking"""
        serializer = CreateBookingSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        
        data = serializer.validated_data
        
        # Get locker
        try:
            locker = LockerUnit.objects.select_for_update().get(
                id=data['locker_id'], status='Available'
            )
        except LockerUnit.DoesNotExist:
            return Response(
                {'detail': 'Locker not available'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Check for time conflicts
        conflicts = Booking.objects.filter(
            locker=locker,
            status__in=['Pending', 'Confirmed', 'Active']
        ).filter(
            Q(start_time__lt=data['end_time'], end_time__gt=data['start_time'])
        ).exists()
        
        if conflicts:
            return Response(
                {'detail': 'Time slot not available'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Calculate pricing
        duration = data['end_time'] - data['start_time']
        hours = duration.total_seconds() / 3600
        
        if hours <= 24:
            subtotal = float(locker.tier.hourly_rate) * hours
        else:
            days = hours / 24
            subtotal = float(locker.tier.daily_rate) * days
        
        # Apply discount
        discount_amount = 0
        discount = None
        discount_code = data.get('discount_code')
        
        if discount_code:
            try:
                discount = Discount.objects.get(code=discount_code, is_active=True)
                if discount.is_valid:
                    if discount.discount_type == 'Percentage':
                        discount_amount = subtotal * (float(discount.discount_value) / 100)
                    else:
                        discount_amount = float(discount.discount_value)
                    
                    if discount.max_discount_amount:
                        discount_amount = min(discount_amount, float(discount.max_discount_amount))
                    
                    discount.current_uses += 1
                    discount.save()
            except Discount.DoesNotExist:
                pass
        
        total = subtotal - discount_amount
        
        # Create booking
        booking = Booking.objects.create(
            user=request.user,
            locker=locker,
            discount=discount,
            start_time=data['start_time'],
            end_time=data['end_time'],
            booking_type=data.get('booking_type', 'Storage'),
            subtotal_amount=subtotal,
            discount_amount=discount_amount,
            total_amount=max(0, total),
            status='Confirmed'
        )
        
        # Update locker status
        locker.status = 'Booked'
        locker.save()
        
        return Response(BookingSerializer(booking).data, status=status.HTTP_201_CREATED)
    
    @action(detail=True, methods=['post'])
    def cancel(self, request, pk=None):
        """Cancel a booking"""
        booking = self.get_object()
        
        if booking.status in ['Completed', 'Cancelled']:
            return Response(
                {'detail': 'Cannot cancel this booking'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        serializer = CancelBookingSerializer(data=request.data)
        if serializer.is_valid():
            booking.status = 'Cancelled'
            booking.cancellation_reason = serializer.validated_data.get('reason', '')
            booking.save()
            
            # Free up the locker
            booking.locker.status = 'Available'
            booking.locker.save()
            
            return Response({'status': 'cancelled'})
        
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
    
    @action(detail=True, methods=['get'])
    def qr_code(self, request, pk=None):
        """Get or generate QR code for booking"""
        booking = self.get_object()
        
        if booking.status not in ['Confirmed', 'Active']:
            return Response(
                {'detail': 'Cannot generate QR for this booking'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Get or create QR code
        qr_code, created = QRAccessCode.objects.get_or_create(
            booking=booking,
            code_type='Unlock',
            is_used=False,
            defaults={
                'code': f'LOCK-{booking.id}-{uuid.uuid4().hex[:8].upper()}',
                'expires_at': booking.end_time
            }
        )
        
        return Response(QRCodeSerializer(qr_code).data)


# ==================== DISCOUNT VIEWS ====================

class DiscountView(APIView):
    """Validate discount codes"""
    permission_classes = [AllowAny]
    
    def post(self, request):
        serializer = ValidateDiscountSerializer(data=request.data)
        if serializer.is_valid():
            code = serializer.validated_data['code']
            
            try:
                discount = Discount.objects.get(code=code, is_active=True)
                if discount.is_valid:
                    return Response(DiscountSerializer(discount).data)
                return Response(
                    {'detail': 'Discount code is expired or invalid'},
                    status=status.HTTP_400_BAD_REQUEST
                )
            except Discount.DoesNotExist:
                return Response(
                    {'detail': 'Discount code not found'},
                    status=status.HTTP_404_NOT_FOUND
                )
        
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


# ==================== REVIEW VIEWS ====================

class ReviewViewSet(viewsets.ModelViewSet):
    """Reviews"""
    permission_classes = [IsAuthenticated]
    serializer_class = ReviewSerializer
    
    def get_queryset(self):
        location_id = self.request.query_params.get('location_id')
        if location_id:
            return Review.objects.filter(
                booking__locker__location_id=location_id
            ).order_by('-created_at')
        return Review.objects.filter(
            booking__user=self.request.user
        ).order_by('-created_at')
    
    def create(self, request):
        serializer = CreateReviewSerializer(data=request.data)
        if serializer.is_valid():
            data = serializer.validated_data
            
            try:
                booking = Booking.objects.get(
                    id=data['booking_id'],
                    user=request.user,
                    status='Completed'
                )
            except Booking.DoesNotExist:
                return Response(
                    {'detail': 'Booking not found or not completed'},
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            if hasattr(booking, 'review'):
                return Response(
                    {'detail': 'Review already exists for this booking'},
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            review = Review.objects.create(
                booking=booking,
                rating=data['rating'],
                title=data.get('title', ''),
                comment=data.get('comment', '')
            )
            
            return Response(ReviewSerializer(review).data, status=status.HTTP_201_CREATED)
        
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


# ==================== NOTIFICATION VIEWS ====================

class NotificationViewSet(viewsets.ReadOnlyModelViewSet):
    """User Notifications"""
    permission_classes = [IsAuthenticated]
    serializer_class = NotificationSerializer
    
    def get_queryset(self):
        return Notification.objects.filter(
            user=self.request.user
        ).order_by('-created_at')
    
    @action(detail=True, methods=['post'])
    def mark_read(self, request, pk=None):
        notification = self.get_object()
        notification.is_read = True
        notification.read_at = timezone.now()
        notification.save()
        return Response({'status': 'read'})
    
    @action(detail=False, methods=['post'])
    def mark_all_read(self, request):
        Notification.objects.filter(
            user=request.user, is_read=False
        ).update(is_read=True, read_at=timezone.now())
        return Response({'status': 'all read'})


# ==================== HEALTH CHECK ====================

@api_view(['GET'])
@permission_classes([AllowAny])
def health_check(request):
    """API Health Check"""
    return Response({
        'status': 'online',
        'service': 'LockSpot API',
        'version': '2.0.0',
        'framework': 'Django REST Framework',
        'documentation': '/api/docs/'
    })
