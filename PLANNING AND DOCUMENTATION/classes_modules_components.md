# Classes, Modules, and Components Standard

This document defines expert-level usage of classes, modules, and components
for the FBLA Connect app. Update it whenever we add a new domain, service, or
major endpoint group.

## Standards
- Single Responsibility: each class/module handles one purpose.
- Clear boundaries: routes, services, schemas, and storage are separated.
- Reusable services: shared auth, validation, storage, and data helpers.
- Minimal coupling: use interfaces and helper functions to avoid tight binds.
- Consistent naming: follow domain-driven naming (users, posts, messages).

## Current Application of Standards
- `fbla/routes/`: HTTP boundary and request handling.
- `fbla/services/`: auth, storage, and external systems (Supabase/Firebase).
- `fbla/schemas/`: shared validation rules and input schemas.

## Change Log
- Add dated entries describing architectural improvements.
- 2026-02-03: Added announcements/org routes and web UI modules.