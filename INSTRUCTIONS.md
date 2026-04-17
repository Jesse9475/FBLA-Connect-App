# FBLA Connect - Setup and Deployment Instructions

Complete step-by-step guide for setting up the FBLA Connect application for development and production deployment.

## Prerequisites

Before beginning setup, ensure you have the following installed:

- **Flutter SDK 3.x** - Download from flutter.dev
- **Python 3.13** - Download from python.org
- **Git** - For version control
- **Xcode 14+** (macOS/iOS development) - Install from App Store
- **Android SDK 21+** (Android development) - Included with Android Studio
- **Node.js and npm** (optional, for some build tools)

Verify installations:
```bash
flutter --version
python --version
xcode-select --version
```

## Backend Setup (Flask + Python)

### Step 1: Navigate to Backend Directory

```bash
cd backend
```

### Step 2: Create Python Virtual Environment

```bash
python3.13 -m venv venv
```

### Step 3: Activate Virtual Environment

On macOS/Linux:
```bash
source venv/bin/activate
```

On Windows:
```bash
venv\Scripts\activate
```

### Step 4: Install Python Dependencies

```bash
pip install --upgrade pip
pip install -r requirements.txt
```

### Step 5: Configure Environment Variables

Copy the example environment file and configure it:

```bash
cp .env.example .env
```

Edit `.env` and configure the following variables:

```
# Supabase Configuration
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_API_KEY=your_supabase_anon_key
SUPABASE_SERVICE_KEY=your_supabase_service_role_key

# JWT Configuration
JWT_SECRET=your_jwt_secret_key
JWT_ALGORITHM=HS256

# Flask Configuration
FLASK_ENV=development
FLASK_APP=app.py
FLASK_DEBUG=True

# CORS Configuration
CORS_ALLOWED_ORIGINS=http://localhost:8080,http://127.0.0.1:8080

# Rate Limiting
RATELIMIT_ENABLED=True
RATELIMIT_DEFAULT=100/hour

# Database
DATABASE_URL=postgresql://user:password@localhost:5432/fbla_connect
```

### Step 6: Run Flask Development Server

```bash
flask run
```

The server will start on `http://localhost:5000` by default.

To specify a custom port:
```bash
flask run --port 8000
```

## Flutter App Setup

### Step 1: Navigate to Mobile Directory

```bash
cd mobile
```

### Step 2: Get Flutter Dependencies

```bash
flutter pub get
```

### Step 3: Configure Backend URL

Edit the configuration file to point to your backend API:

In `lib/config/api_config.dart` or your main configuration:

```dart
const String API_BASE_URL = 'http://localhost:5000';  // Development
// const String API_BASE_URL = 'https://api.fbla-connect.com';  // Production
```

Or use environment variables:
```bash
flutter run --dart-define=API_BASE_URL=http://localhost:5000
```

### Step 4: Configure Supabase

Update Supabase configuration in your app initialization:

```dart
// In main.dart or app initialization
await Supabase.initialize(
  url: 'https://your-project.supabase.co',
  anonKey: 'your_supabase_anon_key',
);
```

### Step 5: Run on Device or Emulator

**iOS (requires Xcode):**
```bash
flutter run -d iPhone
```

**Android (requires Android emulator or physical device):**
```bash
flutter run -d android
```

**Web (for testing):**
```bash
flutter run -d chrome
```

## iOS Development & Build

For complete iOS-specific setup and troubleshooting, see IOS_BUILD_GUIDE.md.

### Quick iOS Setup:

1. Install iOS dependencies:
```bash
cd mobile/ios
pod install
cd ../..
```

2. Open in Xcode for signing and provisioning:
```bash
open mobile/ios/Runner.xcworkspace
```

3. Configure your Apple Developer signing credentials in Xcode

4. Run on physical device:
```bash
flutter run -d <device_id>
```

## Android Development & Build

### Quick Android Setup:

1. Ensure Android SDK is properly configured:
```bash
flutter doctor
```

2. Create or start an Android emulator:
```bash
emulator -avd <avd_name>
```

3. Run the app:
```bash
flutter run
```

## Building Release Versions

### iOS Release Build:

```bash
flutter build ios --release
```

Then upload to App Store via Xcode or Transporter.

### Android Release Build:

```bash
flutter build apk --release
```

Or for Google Play (AAB format):
```bash
flutter build appbundle --release
```

## Production Deployment

### Backend Deployment to Render

This project includes a `render.yaml` configuration file for easy deployment to Render.

#### Prerequisites:
- Render.com account
- GitHub repository with your code

#### Deployment Steps:

1. Connect your GitHub repository to Render

2. In Render dashboard, create a new Web Service

3. Configure the service:
   - **Name**: fbla-connect-api
   - **Environment**: Python 3.13
   - **Build Command**: `pip install -r requirements.txt`
   - **Start Command**: `gunicorn app:app`

4. Set environment variables in Render dashboard:
   - `SUPABASE_URL`
   - `SUPABASE_API_KEY`
   - `SUPABASE_SERVICE_KEY`
   - `JWT_SECRET`
   - `FLASK_ENV=production`
   - Any other required variables

5. Deploy:
   - Render will automatically deploy on GitHub push
   - Or manually trigger deployment in dashboard

#### Example Production Configuration:

```bash
# In render.yaml or environment variables
FLASK_ENV=production
GUNICORN_WORKERS=4
GUNICORN_THREADS=2
DATABASE_POOL_SIZE=10
RATELIMIT_ENABLED=True
RATELIMIT_DEFAULT=200/hour
```

### Frontend Deployment

Build the Flutter app for your target platform:

**iOS App Store:**
1. Build release: `flutter build ios --release`
2. Use Xcode or Transporter to submit to App Store
3. Wait for review and approval

**Google Play Store:**
1. Build release: `flutter build appbundle --release`
2. Create a Google Play developer account
3. Sign up for Google Play Console
4. Upload the AAB file
5. Configure store listing and submit for review

## Environment Variables Reference

### Backend (.env file)

| Variable | Description | Example |
|----------|-------------|---------|
| SUPABASE_URL | Supabase project URL | https://xyz.supabase.co |
| SUPABASE_API_KEY | Supabase anonymous key | eyJ... |
| SUPABASE_SERVICE_KEY | Supabase service role key | eyJ... |
| JWT_SECRET | Secret key for JWT signing | your-secret-key |
| JWT_ALGORITHM | JWT algorithm | HS256 |
| FLASK_ENV | Flask environment | development, production |
| FLASK_DEBUG | Enable debug mode | True, False |
| CORS_ALLOWED_ORIGINS | Allowed CORS origins | http://localhost:8080 |
| DATABASE_URL | PostgreSQL connection string | postgresql://... |
| RATELIMIT_ENABLED | Enable rate limiting | True, False |
| RATELIMIT_DEFAULT | Default rate limit | 100/hour |

### Flutter (environment variables or configuration)

| Variable | Description | Example |
|----------|-------------|---------|
| API_BASE_URL | Backend API base URL | http://localhost:5000 |
| SUPABASE_URL | Supabase project URL | https://xyz.supabase.co |
| SUPABASE_ANON_KEY | Supabase anonymous key | eyJ... |

## Troubleshooting

### Flutter Issues

**"flutter command not found"**
- Add Flutter to your PATH: `export PATH="$PATH:`flutter_sdk_path`/bin"`
- Verify: `flutter --version`

**"CocoaPods not installed"** (iOS)
- Install: `sudo gem install cocoapods`
- Run: `cd mobile/ios && pod install`

**"Build failed due to missing dependencies"**
- Clean and retry: `flutter clean && flutter pub get && flutter run`

### Backend Issues

**"ModuleNotFoundError: No module named 'flask'"**
- Ensure virtual environment is activated
- Reinstall requirements: `pip install -r requirements.txt`

**"Port 5000 already in use"**
- Use a different port: `flask run --port 8000`
- Or kill existing process: `lsof -i :5000 | grep -v PID | awk '{print $2}' | xargs kill -9`

**Supabase Connection Failed**
- Verify SUPABASE_URL and API keys in .env
- Check internet connectivity
- Confirm Supabase project is active

### Deployment Issues

**"Render deployment fails"**
- Check build logs in Render dashboard
- Verify all environment variables are set
- Ensure requirements.txt is up to date
- Test locally: `gunicorn app:app`

**"JWT authentication errors"**
- Verify JWT_SECRET matches between frontend and backend
- Check token expiration settings
- Ensure tokens are properly passed in Authorization headers

## Development Workflow

### Local Development

1. Terminal 1 - Run Flask backend:
```bash
cd backend
source venv/bin/activate
flask run
```

2. Terminal 2 - Run Flutter app:
```bash
cd mobile
flutter run
```

### Git Workflow

```bash
# Create feature branch
git checkout -b feature/your-feature

# Make changes and commit
git add .
git commit -m "Add feature description"

# Push to remote
git push origin feature/your-feature

# Create pull request on GitHub
```

### Testing

**Flutter unit tests:**
```bash
flutter test
```

**Flask tests:**
```bash
cd backend
pytest
```

## Next Steps

1. Read through the full README.md for project overview
2. Review TECHNICAL_BIBLIOGRAPHY.md for detailed technology information
3. Check LIBRARIES_AND_TOOLS.md for complete dependency list
4. Consult IOS_BUILD_GUIDE.md for iOS-specific setup
5. Review security guidelines in the main documentation

---

For additional questions or issues, refer to official documentation:
- Flutter: https://flutter.dev/docs
- Flask: https://flask.palletsprojects.com
- Supabase: https://supabase.com/docs
