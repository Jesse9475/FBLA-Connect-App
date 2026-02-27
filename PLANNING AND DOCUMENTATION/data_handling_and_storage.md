# Data Handling and Storage Standard

This document defines comprehensive data handling and storage practices for
FBLA Connect. Update it when data models, storage methods, or retention rules
change.

## Standards
- Collect only necessary data; document the purpose of each field.
- Enforce validation on all inputs before persistence.
- Use least-privilege access for database and storage credentials.
- Maintain data integrity with consistent schema updates.
- Protect PII with controlled access and secure transport (HTTPS).
- Limit file uploads by size and validate file metadata.

## Current Practices
- Supabase Auth tokens are verified server-side and mapped to users.
- Supabase service keys are server-only and loaded via environment variables.
- Upload size limit enforced by `MAX_CONTENT_LENGTH`.
- Global rate limiting and security headers enabled.
- Announcements are scoped by national/district/chapter with RLS.

## Change Log
- Add dated entries to track data governance updates.
- 2026-02-03: Moved to Supabase Auth tokens and RLS-based access.
- 2026-02-03: Added org hierarchy for district/chapter visibility.