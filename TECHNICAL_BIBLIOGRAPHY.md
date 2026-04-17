# FBLA Connect - Technical Bibliography

Comprehensive reference of all technologies, frameworks, tools, and standards used in the FBLA Connect application.

## Languages & Frameworks

### Flutter
**Version:** 3.x
**Description:** Open-source UI framework for building natively compiled applications for mobile, web, and desktop from a single codebase.
**Used For:** Cross-platform mobile development (iOS and Android), responsive UI components, state management, widget system.
**Official Documentation:** https://flutter.dev
**API Reference:** https://api.flutter.dev

### Dart
**Version:** 3.x
**Description:** Object-oriented, strongly typed programming language optimized for fast apps on any platform.
**Used For:** Frontend logic, business logic implementation, app architecture, Flutter widget development.
**Official Documentation:** https://dart.dev
**Language Specification:** https://dart.dev/guides/language/spec

### Python
**Version:** 3.13
**Description:** High-level, interpreted programming language known for clean syntax and rapid development.
**Used For:** Backend API development, data processing, server-side logic, automation.
**Official Documentation:** https://python.org/doc
**Standard Library:** https://docs.python.org/3/library

### Flask
**Version:** 3.1.1
**Description:** Lightweight Python web framework for building RESTful APIs and web applications.
**Used For:** Backend REST API, request routing, response handling, middleware configuration.
**Official Documentation:** https://flask.palletsprojects.com
**Extension Ecosystem:** https://flask.palletsprojects.com/extensions

## Backend & Services

### Supabase
**Description:** Open-source Firebase alternative providing PostgreSQL database, real-time capabilities, authentication, and file storage.
**Components Used:**
- **PostgreSQL Database** - Relational data storage
- **Authentication (Auth)** - User registration, login, JWT tokens
- **Storage** - File upload and retrieval for user profiles and media
- **Real-time Subscriptions** - Live data updates
**Official Documentation:** https://supabase.com/docs
**API Reference:** https://supabase.com/docs/reference

### Gunicorn
**Version:** Production WSGI server
**Description:** Python WSGI HTTP Server for running Flask applications in production.
**Used For:** Production application server, process management, request handling, worker management.
**Official Documentation:** https://gunicorn.org
**Configuration Guide:** https://docs.gunicorn.org

### Flask-Limiter
**Version:** 3.12
**Description:** Flask extension for rate limiting and request throttling.
**Used For:** DDoS protection, API rate limiting, endpoint throttling.
**Documentation:** https://flask-limiter.readthedocs.io
**GitHub:** https://github.com/alisaifee/flask-limiter

### Flask-CORS
**Version:** 5.0.1
**Description:** Flask extension for handling Cross-Origin Resource Sharing (CORS).
**Used For:** Allowing frontend requests from different domains, CORS configuration.
**Documentation:** https://flask-cors.readthedocs.io
**GitHub:** https://github.com/corydolphin/flask-cors

### PyJWT
**Version:** 2.10.1
**Description:** Python library for encoding and decoding JSON Web Tokens.
**Used For:** JWT token generation, token validation, authentication verification.
**Documentation:** https://pyjwt.readthedocs.io
**GitHub:** https://github.com/jpadilla/pyjwt

### python-dotenv
**Version:** 1.1.0
**Description:** Python library for loading environment variables from .env files.
**Used For:** Configuration management, environment-specific settings, secrets management.
**Documentation:** https://python-dotenv.readthedocs.io
**GitHub:** https://github.com/theskumar/python-dotenv

## Frontend Dependencies

### Dio
**Description:** Powerful HTTP client for Dart/Flutter with interceptors, global configuration, and request/response transformation.
**Used For:** API communication, HTTP requests, request/response interceptors, error handling.
**Pub.dev:** https://pub.dev/packages/dio

### flutter_secure_storage
**Version:** 9.2.2
**Description:** Flutter plugin for secure token and credential storage on iOS and Android.
**Used For:** Storing JWT tokens, storing user credentials, secure local storage.
**Pub.dev:** https://pub.dev/packages/flutter_secure_storage
**GitHub:** https://github.com/mogol/flutter_secure_storage

### supabase_flutter
**Version:** 2.8.4
**Description:** Official Flutter SDK for Supabase providing authentication, database, and storage integration.
**Used For:** Supabase integration, user authentication, database queries, file storage.
**Pub.dev:** https://pub.dev/packages/supabase_flutter
**Documentation:** https://supabase.com/docs/reference/flutter

### image_picker
**Version:** 1.0.7
**Description:** Flutter plugin for selecting images from camera or gallery.
**Used For:** Profile picture uploads, event photos, gallery access, camera integration.
**Pub.dev:** https://pub.dev/packages/image_picker
**GitHub:** https://github.com/flutter/plugins

### flutter_image_compress
**Version:** 2.1.0
**Description:** Flutter plugin for image compression before upload.
**Used For:** Reducing image file sizes, optimizing storage, improving upload performance.
**Pub.dev:** https://pub.dev/packages/flutter_image_compress

### qr_flutter
**Version:** 4.1.0
**Description:** Flutter widget for generating and displaying QR codes.
**Used For:** QR code profile sharing, event check-in, quick networking.
**Pub.dev:** https://pub.dev/packages/qr_flutter
**GitHub:** https://github.com/david-legrand/qr_flutter

### flutter_animate
**Version:** 4.5.0
**Description:** Flutter package providing simple yet powerful animation capabilities.
**Used For:** UI animations, transitions, micro-interactions, smooth visual effects.
**Pub.dev:** https://pub.dev/packages/flutter_animate

### google_fonts
**Version:** 6.2.1
**Description:** Flutter package for easy integration of Google Fonts.
**Used For:** Custom typography (Josefin Sans, Mulish, JetBrains Mono), consistent font styling.
**Pub.dev:** https://pub.dev/packages/google_fonts
**Fonts Used:**
- Josefin Sans - Headlines and branding
- Mulish - Body text and interface
- JetBrains Mono - Code and technical display

### share_plus
**Version:** 9.0.0
**Description:** Flutter plugin for sharing content via native sharing UI.
**Used For:** Share profiles, share posts, share events, native sharing dialogs.
**Pub.dev:** https://pub.dev/packages/share_plus
**GitHub:** https://github.com/fluttercommunity/plus_plugins

### url_launcher
**Version:** 6.2.5
**Description:** Flutter plugin for launching URLs in browser, sending emails, and making calls.
**Used For:** Opening links, deep linking, email integration, event links.
**Pub.dev:** https://pub.dev/packages/url_launcher

### intl
**Version:** 0.20.2
**Description:** Dart package for internationalization and localization including date formatting.
**Used For:** Date formatting, number formatting, localization support.
**Pub.dev:** https://pub.dev/packages/intl
**Documentation:** https://pub.dev/documentation/intl

### timeago
**Version:** 3.7.0
**Description:** Dart package for formatting dates relative to now (e.g., "2 hours ago").
**Used For:** Relative timestamps on posts and messages, human-readable time display.
**Pub.dev:** https://pub.dev/packages/timeago

## Design & UI Systems

### Material Design
**Version:** Material Design 3
**Description:** Design system developed by Google for consistent, accessible, and visually appealing interfaces.
**Used For:** Component design, color schemes, typography, spacing, motion guidelines.
**Official Documentation:** https://material.io
**Guidelines:** https://material.io/design
**Components:** https://material.io/components

### Google Fonts
**Description:** Free, open-source font library by Google with modern typography options.
**Used For:** Custom app typography with Josefin Sans, Mulish, and JetBrains Mono.
**Website:** https://fonts.google.com
**License:** Open Font License

### Material Icons
**Description:** Comprehensive set of open-source icons by Google.
**Used For:** UI icons throughout the app.
**Library:** https://fonts.google.com/icons

## Development Tools

### Visual Studio Code
**Description:** Lightweight, powerful source code editor with extensive extension support.
**Used For:** Code editing, Flutter development, Python development, Git integration.
**Download:** https://code.visualstudio.com
**Extensions:** Flutter, Dart, Python, GitLens

### Xcode
**Version:** 14+
**Description:** Integrated development environment for iOS, macOS, watchOS, and tvOS development.
**Used For:** iOS app development, code signing, app deployment, device management.
**Download:** App Store (macOS)
**Documentation:** https://developer.apple.com/xcode

### Android Studio
**Description:** Official IDE for Android development based on IntelliJ IDEA.
**Used For:** Android emulation, Android SDK management, Google Play integration.
**Download:** https://developer.android.com/studio
**Documentation:** https://developer.android.com/docs

### Git & GitHub
**Description:** Version control system and repository hosting platform.
**Used For:** Source code management, collaboration, version history, CI/CD integration.
**GitHub:** https://github.com
**Git Documentation:** https://git-scm.com/doc

### Render
**Description:** Cloud platform for deploying and managing web applications.
**Used For:** Production backend hosting, environment management, automated deployment.
**Website:** https://render.com
**Documentation:** https://render.com/docs

## Standards & Guidelines

### WCAG 2.1 AA Accessibility
**Description:** Web Content Accessibility Guidelines ensuring digital content is accessible to all users.
**Used For:** Accessible color contrast, keyboard navigation, screen reader support, semantic structure.
**Official Documentation:** https://www.w3.org/WAI/WCAG21/quickref
**Checklist:** https://www.w3.org/WAI/WCAG21/quickref

### Flutter State Management
**Description:** Best practices for managing application state in Flutter.
**Used For:** State architecture, provider patterns, bloc patterns, state preservation.
**Documentation:** https://flutter.dev/docs/development/data-and-backend/state-mgmt/intro
**Best Practices:** https://flutter.dev/docs/development/data-and-backend/state-mgmt/options

### OWASP Security Headers
**Description:** Open Web Application Security Project guidelines for HTTP security headers.
**Used For:** Security header configuration, API security, protection against common attacks.
**Documentation:** https://owasp.org/www-project-secure-headers
**HTTP Security Headers:** https://securityheaders.com

### REST API Best Practices
**Description:** Architectural style and guidelines for designing RESTful web services.
**Used For:** API endpoint design, HTTP method usage, status codes, request/response format.
**Documentation:** https://restfulapi.net
**RFC 7231:** https://tools.ietf.org/html/rfc7231

### JSON Web Tokens (JWT)
**Description:** Stateless authentication method using cryptographically signed JSON tokens.
**Used For:** User authentication, secure API requests, stateless session management.
**Specification:** https://tools.ietf.org/html/rfc7519
**JWT.io:** https://jwt.io

## Deployment & Infrastructure

### PostgreSQL
**Version:** Latest (via Supabase)
**Description:** Advanced open-source relational database.
**Used For:** Primary data storage via Supabase.
**Official Site:** https://www.postgresql.org
**Documentation:** https://www.postgresql.org/docs

### SSL/TLS
**Description:** Cryptographic protocols for secure internet communication.
**Used For:** HTTPS encryption, secure API communication, certificate-based security.
**Standards:** RFC 5246 (TLS 1.2), RFC 8446 (TLS 1.3)

### Rate Limiting
**Description:** Technique to control the rate of requests to an API.
**Used For:** DDoS protection, API quota management, resource protection.
**Implementation:** Flask-Limiter
**Documentation:** https://tools.ietf.org/html/draft-ietf-httpbis-ratelimit

## Performance & Optimization

### Image Compression
**Tool:** flutter_image_compress
**Used For:** Reducing image payload, improving upload speed, optimizing storage.

### Caching Strategies
**Used For:** Reducing API calls, improving app responsiveness, offline capability.

### Code Splitting
**Used For:** Reducing initial app bundle size, lazy loading features.

### Database Indexing
**Used For:** Query optimization, improving database performance.

---

For detailed implementation information, refer to:
- README.md - Project overview
- INSTRUCTIONS.md - Setup and deployment guide
- LIBRARIES_AND_TOOLS.md - Complete dependency list with versions
- CITATIONS.md - Formal citations for all resources
