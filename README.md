# LockSpot

<div align="center">
  <img src="assets/images/Logo.png" alt="LockSpot Logo" width="120">
  
  **Smart Locker Booking System**
  
  [![Flutter](https://img.shields.io/badge/Flutter-3.38-02569B?logo=flutter)](https://flutter.dev)
  [![Django](https://img.shields.io/badge/Django-5.2-092E20?logo=django)](https://djangoproject.com)
  [![MySQL](https://img.shields.io/badge/MySQL-8.0-4479A1?logo=mysql&logoColor=white)](https://mysql.com)
  [![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
</div>

---

## Overview

LockSpot is a mobile application for booking smart storage lockers across Egypt. Users can find nearby locker stations, reserve lockers of various sizes, and manage their rentals through an intuitive interface.

### Features

- **Location Discovery** — Browse locker stations with real-time availability
- **GPS Integration** — Find nearest lockers with distance calculation
- **Size Options** — Small, Medium, and Large lockers with dynamic pricing
- **Secure Booking** — Complete booking flow with payment processing
- **Active Rentals** — Real-time countdown timer for ongoing rentals
- **Booking History** — View past and completed rentals
- **User Authentication** — Secure login and registration

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| **Mobile App** | Flutter 3.38, Dart |
| **Backend API** | Django 5.2, Django REST Framework |
| **Database** | MySQL 8.0 |
| **Authentication** | JWT Tokens |

---

## Project Structure

```
lockspot/
├── lib/                    # Flutter application source
│   ├── features/           # Feature modules
│   │   ├── auth/           # Authentication screens
│   │   ├── home/           # Home and location browsing
│   │   ├── lockers/        # Locker selection and booking
│   │   ├── history/        # Booking history
│   │   └── profile/        # User profile
│   ├── services/           # API and business logic
│   ├── shared/             # Shared components
│   │   ├── models/         # Data models
│   │   ├── theme/          # App theming
│   │   └── utils/          # Utilities
│   └── main.dart           # App entry point
├── backend/                # Django REST API
│   ├── api/                # API endpoints
│   ├── lockers/            # Database models
│   ├── scripts/            # Utility scripts
│   └── sql/                # Database schema
├── assets/                 # Static assets
│   └── images/             # App images and logos
├── docs/                   # Documentation
├── android/                # Android configuration
├── ios/                    # iOS configuration
└── test/                   # Unit tests
```

---

## Getting Started

### Prerequisites

- Flutter SDK 3.38+
- Python 3.10+
- MySQL 8.0+

### Installation

#### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/lockspot.git
cd lockspot
```

#### 2. Setup Backend

```bash
cd backend

# Create virtual environment
python -m venv venv
source venv/bin/activate  # Linux/macOS
venv\Scripts\activate     # Windows

# Install dependencies
pip install -r requirements.txt

# Configure database (update settings.py with your MySQL credentials)

# Run migrations
python manage.py migrate

# Seed sample data
python scripts/seed_data.py

# Start server
python manage.py runserver
```

#### 3. Setup Flutter App

```bash
cd ..  # Return to project root

# Install dependencies
flutter pub get

# Run on device/emulator
flutter run
```

#### 4. Build Release APK

```bash
flutter build apk --release
```

The APK will be at `build/app/outputs/flutter-apk/app-release.apk`

---

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/api/auth/register/` | Register new user |
| `POST` | `/api/auth/login/` | User login |
| `GET` | `/api/auth/me/` | Get current user profile |
| `GET` | `/api/locations/` | List all locations |
| `GET` | `/api/locations/{id}/` | Get location details |
| `GET` | `/api/lockers/available/` | List available lockers |
| `POST` | `/api/bookings/` | Create booking |
| `GET` | `/api/bookings/` | Get user bookings |

See [Backend Documentation](backend/README.md) for complete API reference.

---

## Demo Access

For testing purposes:

| Field | Value |
|-------|-------|
| Email | `demo@lockspot.com` |
| Password | `demo123` |

---

## Configuration

### Backend Database

Update `backend/lockspot_backend/settings.py`:

```python
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.mysql',
        'NAME': 'lockspot',
        'USER': 'your_username',
        'PASSWORD': 'your_password',
        'HOST': 'localhost',
        'PORT': '3306',
    }
}
```

### Flutter API URL

Update `lib/services/api_service.dart`:

```dart
static const String baseUrl = 'https://your-server.com/api';
```

---

## Screenshots

<div align="center">
  <table>
    <tr>
      <td align="center"><b>Home</b></td>
      <td align="center"><b>Locations</b></td>
      <td align="center"><b>Booking</b></td>
      <td align="center"><b>Active Rental</b></td>
    </tr>
  </table>
</div>

---

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/new-feature`)
3. Commit changes (`git commit -m 'Add new feature'`)
4. Push to branch (`git push origin feature/new-feature`)
5. Open a Pull Request

---

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

---

## Contact

For questions or support, please open an issue on GitHub.
