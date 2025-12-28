# 🔐 LockSpot - Smart Locker Booking System

<p align="center">
  <img src="Logo.png" alt="LockSpot Logo" width="200">
</p>

<p align="center">
  <strong>Book Smart Lockers Anywhere in Egypt</strong>
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#demo">Demo</a> •
  <a href="#installation">Installation</a> •
  <a href="#tech-stack">Tech Stack</a> •
  <a href="#project-structure">Structure</a> •
  <a href="#api-documentation">API</a>
</p>

---

## 📖 Overview

LockSpot is a comprehensive smart locker booking system that allows users to find, book, and manage secure storage lockers across Egypt. The platform features a Flutter mobile app with GPS-based location finding and a Django REST backend with admin dashboard.

### 🎯 Key Highlights

- **6 Real Egypt Locations** - Sheikh Zayed, Cairo Festival City, Alexandria, Citystars, Mall of Egypt, Maadi
- **GPS Integration** - Find nearest lockers with real-time distance calculation
- **Complete Booking Flow** - From browsing to payment to active rental tracking
- **Real-time Countdown** - Track remaining rental time with live timer
- **User Isolation** - Each user has their own booking history

---

## ✨ Features

### 📱 Mobile App (Flutter)

| Feature | Description |
|---------|-------------|
| 🔍 **Location Discovery** | Browse locker stations with availability info |
| 📍 **GPS Integration** | "Find lockers near you" with distance display |
| 🔒 **Secure Booking** | Select size (S/M/L), duration, and pay |
| 💳 **Payment System** | Card payment with 5 test templates |
| ⏱️ **Active Rentals** | Real-time countdown timer for active bookings |
| 📜 **Booking History** | View completed rentals |
| 👤 **User Profiles** | Manage account settings |
| 🔐 **Authentication** | Login, signup, demo mode |

### 🖥️ Admin Dashboard (Django)

| Feature | Description |
|---------|-------------|
| 📊 **Dashboard** | Modern UI with Jazzmin theme |
| 👥 **User Management** | Full user administration |
| 🏢 **Location Management** | Add/edit locker locations |
| 📦 **Locker Management** | Manage individual units |
| 📅 **Booking Management** | View and manage all bookings |
| 💰 **Payment Tracking** | Monitor transactions |

---

## 🎮 Demo

### Quick Start Demo

1. **Download the APK** from [Releases](https://github.com/Hambozo17/LockSpot/releases)
2. **Install** on your Android device
3. **Login** with demo credentials:
   ```
   Email: demo@lockspot.com
   Password: demo123
   ```

### Test Card Templates

When booking, tap any card template to auto-fill:

| Name | Card Number | Expiry | CVV |
|------|-------------|--------|-----|
| Ahmed Mohamed | 4242 4242 4242 4242 | 12/27 | 123 |
| Sara Ahmed | 5555 5555 5555 4444 | 06/28 | 456 |
| Omar Hassan | 4000 0566 5566 5556 | 09/26 | 789 |
| Fatima Ali | 5200 8282 8282 8210 | 03/29 | 321 |
| Youssef Mahmoud | 4111 1111 1111 1111 | 11/27 | 654 |

### Egypt Locations

| Location | City | Available Lockers | Coordinates |
|----------|------|-------------------|-------------|
| Sheikh Zayed Mall | Sheikh Zayed | 5 | 30.0131, 30.9718 |
| Cairo Festival City | New Cairo | 7 | 30.0284, 31.4082 |
| Alexandria Bibliotheca | Alexandria | 3 | 31.2089, 29.9092 |
| Citystars Heliopolis | Cairo | 8 | 30.0724, 31.3456 |
| Mall of Egypt | 6th October | 2 | 29.9726, 30.9433 |
| Maadi Grand Mall | Maadi | 5 | 29.9602, 31.2569 |

---

## 🛠️ Tech Stack

### Frontend (Mobile)

| Technology | Purpose |
|------------|---------|
| Flutter 3.x | Cross-platform UI framework |
| Dart | Programming language |
| Provider | State management |
| http | REST API client |
| SharedPreferences | Local storage |
| geolocator | GPS location services |
| qr_flutter | QR code generation |

### Backend

| Technology | Purpose |
|------------|---------|
| Django 5.x | Web framework |
| Django REST Framework | API endpoints |
| django-jazzmin | Admin UI theme |
| PyJWT | JWT authentication |
| SQLite/MySQL | Database |
| django-cors-headers | CORS handling |

---

## 📂 Project Structure

```
lockspot/
├── 📱 lib/                          # Flutter App Source
│   ├── main.dart                    # App entry point
│   ├── features/                    # Feature modules
│   │   ├── auth/                    # Authentication
│   │   │   ├── login_screen.dart
│   │   │   └── signup_screen.dart
│   │   ├── home/                    # Home & Location browsing
│   │   │   └── home_screen.dart     # GPS integration
│   │   ├── lockers/                 # Locker booking
│   │   │   ├── locker_detail_screen.dart
│   │   │   ├── active_rental_screen.dart
│   │   │   ├── active_rental_detail_screen.dart
│   │   │   └── booking/
│   │   │       └── mock_payment_screen.dart
│   │   ├── history/                 # Booking history
│   │   │   └── history_screen.dart
│   │   ├── profile/                 # User profile
│   │   │   └── profile_screen.dart
│   │   └── main_screen.dart         # Bottom navigation
│   ├── services/                    # Business logic
│   │   ├── api_service.dart         # REST API client (1200+ lines)
│   │   └── auth_service.dart        # Authentication service
│   └── shared/                      # Shared components
│       ├── models/                  # Data models
│       └── theme/                   # App theming
│           └── colors.dart
│
├── 🖥️ backend/                      # Django Backend
│   ├── manage.py                    # Django CLI
│   ├── requirements.txt             # Python dependencies
│   ├── seed_data.py                 # Sample data seeder
│   ├── lockspot_backend/            # Django settings
│   │   ├── settings.py
│   │   └── urls.py
│   ├── lockers/                     # Main app
│   │   ├── models.py                # Database models
│   │   └── admin.py                 # Admin config
│   └── api/                         # REST API
│       ├── views.py
│       ├── serializers.py
│       ├── urls.py
│       └── authentication.py
│
├── 📦 assets/                       # Images & fonts
│   └── images/
├── 🤖 android/                      # Android config
├── 🍎 ios/                          # iOS config
└── 🌐 web/                          # Web config
```

---

## 🚀 Installation

### Prerequisites

- Python 3.10+
- Flutter 3.x
- Android Studio (for Android builds)
- Git

### 1. Clone Repository

```bash
git clone https://github.com/Hambozo17/LockSpot.git
cd LockSpot
```

### 2. Backend Setup

```bash
cd backend

# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Run migrations
python manage.py migrate

# Create admin user
python manage.py createsuperuser

# Seed sample data (optional)
python seed_data.py

# Run server
python manage.py runserver
```

### 3. Flutter App Setup

```bash
# From project root
flutter pub get

# Run on connected device
flutter run

# Build release APK
flutter build apk --release
```

### 4. Configure API URL

Update the API URL in `lib/services/api_service.dart`:

```dart
// For local development
static const String baseUrl = 'http://localhost:8000/api';

// For ngrok tunnel
static const String baseUrl = 'https://your-tunnel.ngrok-free.dev/api';

// For production
static const String baseUrl = 'https://your-server.com/api';
```

---

## 📡 API Documentation

### Base URL
```
https://your-server.com/api
```

### Authentication

All authenticated endpoints require:
```
Authorization: Bearer <token>
```

### Endpoints

#### Auth
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/auth/register/` | Register new user |
| POST | `/auth/login/` | Login user |
| GET | `/auth/me/` | Get current user |

#### Locations
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/locations/` | List all locations |
| GET | `/locations/{id}/` | Get location details |
| GET | `/locations/{id}/pricing/` | Get pricing tiers |

#### Lockers
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/lockers/available/` | Get available lockers |
| GET | `/lockers/{id}/` | Get locker details |

#### Bookings
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/bookings/` | Get user's bookings |
| POST | `/bookings/` | Create booking |
| GET | `/bookings/{id}/` | Get booking details |

#### Payments
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/payments/` | Process payment |
| GET | `/payments/booking/{id}/` | Get payment by booking |

---

## 🔧 Configuration

### Android Permissions

Location permissions in `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```

### Environment Variables

For production, set these in Django settings:

```python
SECRET_KEY = 'your-secret-key'
DEBUG = False
ALLOWED_HOSTS = ['your-domain.com']
```

---

## 📱 App Screenshots

### User Flow

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Login     │───▶│    Home     │───▶│   Detail    │───▶│   Payment   │
│             │    │  Locations  │    │  Size/Time  │    │    Card     │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                                                                │
                   ┌─────────────┐    ┌─────────────┐           │
                   │   History   │◀───│   Active    │◀──────────┘
                   │  Completed  │    │   Rentals   │
                   └─────────────┘    └─────────────┘
```

---

## 🔄 Complete Booking Flow

1. **Login** → Demo or signup account
2. **Browse Locations** → See 6 Egypt locations with availability
3. **Find Near You** → GPS sorts by distance
4. **Select Location** → View locker sizes and prices
5. **Choose Size** → Small / Medium / Large
6. **Set Duration** → 1-24 hours
7. **Payment** → Enter/select card template
8. **Confirm** → Booking created, locker reserved
9. **Active Rental** → Timer counts down
10. **Completion** → Moves to history

---

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit changes (`git commit -m 'Add AmazingFeature'`)
4. Push to branch (`git push origin feature/AmazingFeature`)
5. Open Pull Request

---

## 📄 License

This project is for educational purposes as a university database project.

---

## 👨‍💻 Author

**Hamza** - [GitHub](https://github.com/Hambozo17)

---

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Django team for the robust backend
- All contributors and testers

---

<p align="center">
  Made with ❤️ in Egypt 🇪🇬
</p>
