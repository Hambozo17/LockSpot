# 🖥️ LockSpot Backend

Django REST API backend for the LockSpot smart locker booking system.

## 🚀 Quick Start

### 1. Setup Virtual Environment

```bash
cd backend
python -m venv venv

# Windows
venv\Scripts\activate

# macOS/Linux
source venv/bin/activate
```

### 2. Install Dependencies

```bash
pip install -r requirements.txt
```

### 3. Database Setup

```bash
python manage.py migrate
python manage.py createsuperuser
```

### 4. Seed Sample Data (Optional)

```bash
python seed_data.py
```

### 5. Run Development Server

```bash
python manage.py runserver
```

Server will be available at `http://localhost:8000`

## 📡 API Endpoints

### Authentication
- `POST /api/auth/register/` - Register new user
- `POST /api/auth/login/` - Login and get JWT token
- `GET /api/auth/me/` - Get current user profile

### Locations
- `GET /api/locations/` - List all locations
- `GET /api/locations/{id}/` - Get location details
- `GET /api/locations/{id}/pricing/` - Get pricing tiers

### Lockers
- `GET /api/lockers/available/` - Get available lockers
- `GET /api/lockers/{id}/` - Get locker details

### Bookings
- `GET /api/bookings/` - Get user's bookings
- `POST /api/bookings/` - Create new booking
- `GET /api/bookings/{id}/` - Get booking details

### Payments
- `POST /api/payments/` - Process payment
- `GET /api/payments/booking/{id}/` - Get payment by booking

## 🔐 Admin Dashboard

Access at `http://localhost:8000/admin/`

Features:
- Modern Jazzmin theme
- User management
- Location & locker management
- Booking oversight
- Payment tracking

## 📁 Structure

```
backend/
├── manage.py               # Django CLI
├── requirements.txt        # Python dependencies
├── seed_data.py           # Sample data script
├── db.sqlite3             # SQLite database
├── lockspot_backend/      # Django settings
│   ├── settings.py
│   ├── urls.py
│   └── wsgi.py
├── lockers/               # Main app
│   ├── models.py          # Database models
│   ├── admin.py           # Admin configuration
│   └── migrations/
└── api/                   # REST API
    ├── views.py           # API endpoints
    ├── serializers.py     # Data serialization
    ├── urls.py            # API routes
    └── authentication.py  # JWT auth
```

## 🔧 Configuration

### CORS (for Flutter app)

Already configured in `settings.py`:

```python
CORS_ALLOW_ALL_ORIGINS = True  # For development
```

### JWT Settings

```python
JWT_SECRET = 'your-secret-key'
JWT_ALGORITHM = 'HS256'
JWT_EXPIRATION_HOURS = 24
```

## 🌐 Deployment with ngrok

For mobile app testing:

```bash
ngrok http 8000
```

Update Flutter app's `api_service.dart` with the ngrok URL.

## 📝 Database Models

- **User** - User accounts
- **Location** - Locker stations
- **Address** - Location addresses
- **Locker** - Individual locker units
- **PricingTier** - Size-based pricing
- **Booking** - User bookings
- **Payment** - Payment records
- **Review** - User reviews
- **DiscountCode** - Promo codes
