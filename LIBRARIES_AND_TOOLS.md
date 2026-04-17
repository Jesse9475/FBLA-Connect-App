# FBLA Connect - Libraries and Tools Reference

Complete inventory of all dependencies, tools, and services used in FBLA Connect.

## Flutter/Dart Dependencies

### Direct Dependencies (pubspec.yaml)

#### UI & Display

| Package | Version | Purpose | License | URL |
|---------|---------|---------|---------|-----|
| flutter | 3.x | Core Flutter framework for mobile development | BSD | https://flutter.dev |
| material_design_icons_flutter | Latest | Material Design icons for UI | Apache 2.0 | https://pub.dev/packages/material_design_icons_flutter |
| google_fonts | 6.2.1 | Integration of Google Fonts (Josefin Sans, Mulish, JetBrains Mono) | Apache 2.0 | https://pub.dev/packages/google_fonts |
| flutter_animate | 4.5.0 | Animation library for Flutter widgets | MIT | https://pub.dev/packages/flutter_animate |

#### Networking & API

| Package | Version | Purpose | License | URL |
|---------|---------|---------|---------|-----|
| dio | Latest | HTTP client with interceptors and advanced features | MIT | https://pub.dev/packages/dio |
| supabase_flutter | 2.8.4 | Official Supabase SDK for Flutter | Apache 2.0 | https://pub.dev/packages/supabase_flutter |
| http | Latest | HTTP library for making requests | BSD | https://pub.dev/packages/http |

#### Authentication & Storage

| Package | Version | Purpose | License | URL |
|---------|---------|---------|---------|-----|
| flutter_secure_storage | 9.2.2 | Secure storage for tokens and credentials | BSD | https://pub.dev/packages/flutter_secure_storage |
| jwt_decoder | Latest | Decode JWT tokens | MIT | https://pub.dev/packages/jwt_decoder |

#### Media & Image Handling

| Package | Version | Purpose | License | URL |
|---------|---------|---------|---------|-----|
| image_picker | 1.0.7 | Camera and gallery access for image selection | BSD | https://pub.dev/packages/image_picker |
| flutter_image_compress | 2.1.0 | Image compression before upload | MIT | https://pub.dev/packages/flutter_image_compress |
| qr_flutter | 4.1.0 | QR code generation and display | BSD | https://pub.dev/packages/qr_flutter |
| cached_network_image | Latest | Cached image loading from network | Apache 2.0 | https://pub.dev/packages/cached_network_image |

#### Sharing & External Links

| Package | Version | Purpose | License | URL |
|---------|---------|---------|---------|-----|
| share_plus | 9.0.0 | Native sharing functionality | BSD | https://pub.dev/packages/share_plus |
| url_launcher | 6.2.5 | Launch URLs, emails, and phone calls | BSD | https://pub.dev/packages/url_launcher |

#### Internationalization & Formatting

| Package | Version | Purpose | License | URL |
|---------|---------|---------|---------|-----|
| intl | 0.20.2 | Date formatting, number formatting, localization | BSD | https://pub.dev/packages/intl |
| timeago | 3.7.0 | Relative time formatting (e.g., "2 hours ago") | MIT | https://pub.dev/packages/timeago |

#### State Management & Architecture

| Package | Version | Purpose | License | URL |
|---------|---------|---------|---------|-----|
| provider | Latest | State management and dependency injection | MIT | https://pub.dev/packages/provider |
| get_it | Latest | Service locator for dependency injection | MIT | https://pub.dev/packages/get_it |

#### JSON & Serialization

| Package | Version | Purpose | License | URL |
|---------|---------|---------|---------|-----|
| json_serializable | Latest | Code generation for JSON serialization | BSD | https://pub.dev/packages/json_serializable |
| json_annotation | Latest | Annotations for JSON serialization | BSD | https://pub.dev/packages/json_annotation |

### Development Dependencies

| Package | Version | Purpose | License | URL |
|---------|---------|---------|---------|-----|
| flutter_test | 3.x | Testing framework for Flutter | BSD | https://flutter.dev |
| build_runner | Latest | Code generation runner | BSD | https://pub.dev/packages/build_runner |
| mockito | Latest | Mocking library for tests | Apache 2.0 | https://pub.dev/packages/mockito |

## Python/Backend Dependencies

### Core Framework

| Package | Version | Purpose | License | URL |
|---------|---------|---------|---------|-----|
| Flask | 3.1.1 | Lightweight Python web framework | BSD | https://flask.palletsprojects.com |
| Werkzeug | Latest | WSGI utilities and request/response handling | BSD | https://werkzeug.palletsprojects.com |

### Database & ORM

| Package | Version | Purpose | License | URL |
|---------|---------|---------|---------|-----|
| psycopg2-binary | Latest | PostgreSQL database adapter | LGPL | https://www.psycopg.org |
| SQLAlchemy | Latest | SQL toolkit and ORM | MIT | https://www.sqlalchemy.org |
| alembic | Latest | Database migration tool | MIT | https://alembic.sqlalchemy.org |

### Authentication & Security

| Package | Version | Purpose | License | URL |
|---------|---------|---------|---------|-----|
| PyJWT | 2.10.1 | JSON Web Token encoding/decoding | MIT | https://pyjwt.readthedocs.io |
| cryptography | Latest | Cryptographic recipes and primitives | Apache 2.0 | https://cryptography.io |
| python-dotenv | 1.1.0 | Load environment variables from .env | BSD | https://python-dotenv.readthedocs.io |

### API Management

| Package | Version | Purpose | License | URL |
|---------|---------|---------|---------|-----|
| Flask-Limiter | 3.12 | Rate limiting for Flask | MIT | https://flask-limiter.readthedocs.io |
| Flask-CORS | 5.0.1 | CORS handling for Flask | MIT | https://flask-cors.readthedocs.io |

### Supabase Integration

| Package | Version | Purpose | License | URL |
|---------|---------|---------|---------|-----|
| supabase | Latest | Supabase Python client | MIT | https://github.com/supabase/supabase-py |

### Utilities

| Package | Version | Purpose | License | URL |
|---------|---------|---------|---------|-----|
| requests | Latest | HTTP library for Python | Apache 2.0 | https://requests.readthedocs.io |
| python-dateutil | Latest | Date utilities and parsing | BSD | https://dateutil.readthedocs.io |

### Testing

| Package | Version | Purpose | License | URL |
|---------|---------|---------|---------|-----|
| pytest | Latest | Testing framework | MIT | https://pytest.org |
| pytest-flask | Latest | Flask testing fixtures | MIT | https://pytest-flask.readthedocs.io |
| pytest-cov | Latest | Coverage measurement | MIT | https://pytest-cov.readthedocs.io |

### Deployment & Production

| Package | Version | Purpose | License | URL |
|---------|---------|---------|---------|-----|
| gunicorn | Latest | WSGI HTTP server for production | MIT | https://gunicorn.org |

## Development Tools

### IDE & Editors

| Tool | Version | Purpose |
|------|---------|---------|
| Visual Studio Code | Latest | Primary code editor |
| Xcode | 14+ | iOS development and deployment |
| Android Studio | Latest | Android development and emulation |

### Version Control

| Tool | Purpose | URL |
|------|---------|-----|
| Git | Version control system | https://git-scm.com |
| GitHub | Repository hosting and collaboration | https://github.com |

### Flutter SDK Components

| Component | Purpose |
|-----------|---------|
| Flutter Engine | Core runtime |
| Dart SDK | Programming language runtime |
| Android SDK | Android development tools |
| iOS SDK (via Xcode) | iOS development tools |

### Build & Compilation

| Tool | Purpose | URL |
|------|---------|-----|
| Flutter CLI | Flutter build and development commands | https://flutter.dev/cli |
| Dart Analyzer | Static analysis for Dart code | https://dart.dev/guides/language/analysis-options |
| Gradle | Android build system | https://gradle.org |
| CocoaPods | iOS dependency manager | https://cocoapods.org |

## Cloud Services

### Supabase

| Component | Purpose | URL |
|-----------|---------|-----|
| PostgreSQL Database | Primary data storage | https://supabase.com/docs/guides/database |
| Authentication | User registration and login | https://supabase.com/docs/guides/auth |
| Storage | File upload and retrieval | https://supabase.com/docs/guides/storage |
| Real-time | Live data subscriptions | https://supabase.com/docs/guides/realtime |
| Edge Functions | Serverless functions | https://supabase.com/docs/guides/functions |

### Render

| Component | Purpose | URL |
|-----------|---------|-----|
| Web Services | Application hosting | https://render.com/docs |
| Environment Variables | Secrets management | https://render.com/docs/environment-variables |
| Databases | PostgreSQL databases | https://render.com/docs/databases |
| Deployments | CI/CD and version management | https://render.com/docs/deploys |

## Required Software (Minimum Versions)

### Runtime Environments

| Software | Minimum Version | Purpose |
|----------|-----------------|---------|
| Flutter SDK | 3.0 | Mobile app development |
| Dart SDK | 3.0 | Programming language for Flutter |
| Python | 3.13 | Backend development |
| Xcode (macOS/iOS) | 14.0 | iOS development |
| Android SDK | API 21+ | Android development |
| Xcode Command Line Tools | Latest | C/C++ compilation for iOS |

### Package Managers

| Manager | Purpose | Installation |
|---------|---------|--------------|
| pub | Dart package manager | Included with Flutter SDK |
| pip | Python package manager | Included with Python 3.x |
| CocoaPods | iOS dependency manager | `sudo gem install cocoapods` |
| Gradle | Android build system | Included with Android Studio |

## Optional Tools

| Tool | Purpose | URL |
|------|---------|-----|
| GitLens (VS Code) | Git integration and history | https://www.gitlens.com |
| Flutter DevTools | Debugging and profiling Flutter apps | https://flutter.dev/docs/development/tools/devtools |
| Android Profiler | Performance monitoring for Android | https://developer.android.com/studio/profile |
| Instruments (Xcode) | Performance profiling for iOS | https://developer.apple.com/instruments |

## Licensing Summary

### Permissive Licenses (Recommended)

- **MIT License** - Allows commercial use, modification, and distribution with attribution
- **Apache 2.0** - Similar to MIT with explicit patent grants
- **BSD License** - Allows commercial use with simple attribution requirements

### Other Licenses

- **LGPL** - Requires linking, but allows proprietary use
- **Open Font License** - Allows free use and modification of fonts

## Dependency Update Strategy

### Core Dependencies (Update Cautiously)
- Flutter SDK - Major updates require testing across iOS and Android
- Python - Backend runtime, test thoroughly before updating
- Flask - Web framework, test all endpoints after updates

### Feature Dependencies (Regular Updates Recommended)
- UI libraries (google_fonts, flutter_animate)
- Utility packages (intl, timeago)
- Development tools (build_runner)

### Security Dependencies (Update Immediately)
- PyJWT - Authentication library
- cryptography - Security primitives
- Flask-Limiter - DDoS protection

---

For specific version information, see:
- `mobile/pubspec.yaml` - Exact Flutter dependencies
- `backend/requirements.txt` - Exact Python dependencies
- TECHNICAL_BIBLIOGRAPHY.md - Detailed technology information
- INSTRUCTIONS.md - Setup and installation guide
