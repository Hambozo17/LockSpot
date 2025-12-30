# Installation Guide

Complete setup instructions for LockSpot development environment.

---

## Prerequisites

### Required Software

| Software | Version | Download |
|----------|---------|----------|
| Flutter SDK | 3.38+ | [flutter.dev](https://flutter.dev/docs/get-started/install) |
| Python | 3.10+ | [python.org](https://www.python.org/downloads/) |
| MySQL | 8.0+ | [mysql.com](https://dev.mysql.com/downloads/) |
| Android Studio | Latest | [developer.android.com](https://developer.android.com/studio) |
| VS Code | Latest | [code.visualstudio.com](https://code.visualstudio.com/) |

### VS Code Extensions (Recommended)

- Flutter
- Dart
- Python
- MySQL (optional)

---

## Backend Setup

### Step 1: Navigate to Backend

```bash
cd backend
```

### Step 2: Create Virtual Environment

```bash
# Create venv
python -m venv venv

# Activate (Windows)
venv\Scripts\activate

# Activate (macOS/Linux)
source venv/bin/activate
```

### Step 3: Install Dependencies

```bash
pip install -r requirements.txt
```

### Step 4: Configure Database

1. Create MySQL database:

```sql
CREATE DATABASE lockspot CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

2. Update `lockspot_backend/settings.py`:

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

3. Update `db_utils.py` with the same credentials:

```python
DATABASE_CONFIG = {
    'host': 'localhost',
    'database': 'lockspot',
    'user': 'your_username',
    'password': 'your_password',
    'port': 3306,
}
```

### Step 5: Initialize Database

```bash
# Create database schema
python manage.py migrate

# Create admin user
python manage.py createsuperuser

# (Optional) Seed sample data
python scripts/seed_data.py
```

### Step 6: Start Server

```bash
python manage.py runserver
```

Server runs at: `http://localhost:8000`

---

## Flutter App Setup

### Step 1: Return to Project Root

```bash
cd ..
```

### Step 2: Install Dependencies

```bash
flutter pub get
```

### Step 3: Configure API URL

Update `lib/services/api_service.dart`:

```dart
// For local development
static const String baseUrl = 'http://localhost:8000/api';

// For device testing (use your computer's IP)
static const String baseUrl = 'http://192.168.1.100:8000/api';

// For production
static const String baseUrl = 'https://your-server.com/api';
```

### Step 4: Run the App

```bash
# List available devices
flutter devices

# Run on specific device
flutter run -d <device_id>

# Run on all devices
flutter run
```

---

## Building for Release

### Android APK

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

### Android App Bundle

```bash
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`

### iOS (requires macOS)

```bash
flutter build ios --release
```

---

## Testing with ngrok

For testing the app on a physical device while backend runs locally:

### Step 1: Install ngrok

Download from [ngrok.com](https://ngrok.com/download)

### Step 2: Start Tunnel

```bash
ngrok http 8000
```

### Step 3: Update Flutter App

Copy the ngrok URL and update `api_service.dart`:

```dart
static const String baseUrl = 'https://your-subdomain.ngrok-free.app/api';
```

### Step 4: Update Django Settings

Add ngrok URL to `settings.py`:

```python
CSRF_TRUSTED_ORIGINS = [
    'https://*.ngrok-free.app',
]
```

---

## Troubleshooting

### Flutter Issues

| Issue | Solution |
|-------|----------|
| Packages not found | Run `flutter pub get` |
| Build errors | Run `flutter clean` then rebuild |
| Device not detected | Check USB debugging is enabled |

### Backend Issues

| Issue | Solution |
|-------|----------|
| MySQL connection error | Check credentials in settings.py |
| Migration errors | Delete migrations and recreate |
| Port in use | Kill process or use different port |

### Database Reset

```bash
# Drop and recreate database
mysql -u root -p -e "DROP DATABASE lockspot; CREATE DATABASE lockspot CHARACTER SET utf8mb4;"

# Recreate schema
python manage.py migrate

# Re-seed data
python scripts/seed_data.py
```

---

## Development Workflow

1. Start MySQL server
2. Start Django backend: `python manage.py runserver`
3. Start ngrok (if testing on device): `ngrok http 8000`
4. Run Flutter app: `flutter run`

---

## Next Steps

- [API Documentation](API.md)
- [Backend README](../backend/README.md)
- [Contributing Guidelines](../CONTRIBUTING.md)
