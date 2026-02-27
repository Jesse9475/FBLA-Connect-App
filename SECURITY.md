# Security Overview

This document summarizes the security hardening applied to the FBLA Connect
backend and how to operate it safely.

## Authentication and Authorization
- Supabase Auth access tokens are required for all protected routes.
- Tokens are verified server-side; user mapping is created on first request.
- Admin-only access is enforced for `/api/admin/*` routes.
- Supabase RLS policies enforce ownership and visibility rules in the database.

## Rate Limiting
- All routes are rate limited using a combined key of IP + user id (when
  available) with sensible defaults.
- Exceeded limits return a JSON `429` response:
  `{"error": "rate_limit_exceeded"}`.

## Input Validation and Sanitization
- All write endpoints use schema-based validation with type checks and
  length limits.
- Unexpected fields are rejected to prevent mass assignment.
- Text inputs are trimmed and null bytes are removed.

## Secrets and API Keys
- Secrets are **never** hard-coded; they are loaded from environment
  variables in `.env` (local) or the hosting provider (production).
- Supabase supports key rotation via `SUPABASE_SERVICE_KEYS`
  (comma-delimited). The first key is used by default.
- Do not expose service keys client-side. Only the server should read
  `SUPABASE_SERVICE_KEY(S)`.

## Secure Defaults (OWASP-Inspired)
- Response headers applied globally:
  - `X-Content-Type-Options: nosniff`
  - `X-Frame-Options: DENY`
  - `Referrer-Policy: no-referrer`
- Upload size is capped by `MAX_CONTENT_LENGTH` (default 10 MB).

## Operational Guidance
- Set a strong `SECRET_KEY` in production.
- Keep `.env` out of version control (already ignored by `.gitignore`).
- Rotate credentials regularly and immediately after any exposure.
- Prefer HTTPS in all environments beyond local development.

## Configuration Reference
- `SECRET_KEY`: required for Flask session security in production
- `SUPABASE_URL`: Supabase project URL
- `SUPABASE_SERVICE_KEY`: current server key
- `SUPABASE_SERVICE_KEYS`: optional comma-delimited rotation list
- `SUPABASE_JWT_SECRET`: used to verify Supabase access tokens
- `SUPABASE_ANON_KEY`: client-side key (not secret) for Supabase Auth
- `RATELIMIT_STORAGE_URI`: rate limit storage backend (e.g., Redis)
- `MAX_CONTENT_LENGTH`: max request size in bytes
