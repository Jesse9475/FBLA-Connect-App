# FBLA Connect

A social networking and chapter management application built for FBLA (Future Business Leaders of America) members to connect, collaborate, and access competitive event information.

## Overview

FBLA Connect enables FBLA chapter members to build meaningful connections, stay informed about chapter activities and competitive events, and access a centralized hub for event management and announcements. The app combines social networking features with practical tools designed specifically for FBLA's competitive event ecosystem.

## Key Features

- **Social Feed** - Share updates, photos, and experiences with your FBLA chapter
- **Event Management** - View and participate in chapter events and competitive events
- **Messaging** - Direct messaging between chapter members
- **Competitive Events Hub** - Access detailed information about FBLA competitive events
- **Announcements** - Receive important chapter announcements and updates
- **Friend Connections** - Build your network within your FBLA chapter
- **QR Profiles** - Share your profile via QR code for quick networking
- **Chapter Directory** - Find and connect with other chapter members

## Technology Stack

### Frontend
- **Flutter 3.x** - Cross-platform mobile framework (iOS and Android)
- **Dart 3.x** - Programming language
- **Dio** - HTTP client for API communication
- **flutter_secure_storage** - Secure token storage
- **image_picker** - Camera and gallery access
- **flutter_animate** - Smooth animations
- **google_fonts** - Custom typography (Josefin Sans, Mulish, JetBrains Mono)

### Backend
- **Flask 3.1.1** - Python web framework
- **Python 3.13** - Backend runtime
- **Gunicorn** - WSGI application server for production
- **Flask-Limiter** - Rate limiting and DDoS protection
- **Flask-Cors** - Cross-origin resource sharing
- **PyJWT** - JSON Web Token handling

### Database & Services
- **Supabase** - PostgreSQL database, authentication, and file storage
- **Render** - Cloud platform for backend deployment

## Quick Start

### Prerequisites
- Flutter SDK 3.x
- Python 3.13
- iOS: Xcode 14+
- Android: Android SDK 21+

### Setup

1. **Backend Setup** (see INSTRUCTIONS.md for detailed steps)
   ```bash
   cd backend
   python -m venv venv
   source venv/bin/activate
   pip install -r requirements.txt
   cp .env.example .env
   flask run
   ```

2. **Flutter App Setup**
   ```bash
   flutter pub get
   flutter run
   ```

For complete setup instructions, environment configuration, and deployment guides, see INSTRUCTIONS.md.

## Project Structure

```
FBLA_APP_SURYA/
├── mobile/                 # Flutter mobile app
│   ├── lib/               # Dart source code
│   ├── pubspec.yaml       # Flutter dependencies
│   └── ios/               # iOS-specific configuration
├── backend/               # Flask API server
│   ├── app.py            # Main Flask application
│   ├── requirements.txt   # Python dependencies
│   ├── .env              # Environment variables
│   └── render.yaml       # Deployment configuration
├── README.md             # This file
├── INSTRUCTIONS.md       # Setup and deployment guide
└── docs/                 # Additional documentation
```

## Documentation

- **INSTRUCTIONS.md** - Complete setup and deployment guide
- **TECHNICAL_BIBLIOGRAPHY.md** - Technologies and frameworks used
- **LIBRARIES_AND_TOOLS.md** - Complete dependency list
- **CITATIONS.md** - Formal citations for all resources
- **COPYRIGHT.md** - License and copyright information
- **IOS_BUILD_GUIDE.md** - iOS-specific build instructions (if applicable)

## Architecture

The app uses a client-server architecture with clear separation of concerns:

- **Mobile Client** (Flutter) - Handles UI, user interactions, and local data caching
- **Backend API** (Flask) - Manages business logic, data validation, and database operations
- **Database** (Supabase PostgreSQL) - Stores all application data
- **Authentication** (Supabase Auth) - Handles user registration and JWT token management
- **File Storage** (Supabase Storage) - Manages user-uploaded images and media

## Security

- JWT token-based authentication
- Secure token storage on device
- HTTPS for all API communication
- Rate limiting on backend endpoints
- CORS configuration for controlled access
- Input validation and sanitization
- OWASP security best practices

## Support

For issues, questions, or contributions, please refer to the development team or project documentation in the docs/ directory.

## License

See COPYRIGHT.md for licensing information.

---

Built for the FBLA Mobile Application Development competitive event.
