# Mobile App Architecture Patterns Standard

This document defines the mobile architecture standards for FBLA Connect. It
must be updated as the mobile web UI and backend evolve.

## Pattern Standards (Expert Use)
- Client-server separation with a documented API contract.
- Service layer on the server for external dependencies (auth, storage).
- Stateless REST endpoints with explicit resource boundaries.
- Centralized validation and error handling.
- Consistent data models and DTOs for client consumption.

## Current Architecture Notes
- The mobile web UI will consume `/api/*` endpoints from Flask.
- Supabase Auth provides authentication; Supabase stores data and media.

## Change Log
- Add dated entries for architecture decisions.
- 2026-02-03: Switched to Supabase Auth + RLS as the auth model.
- 2026-02-03: Added web dashboard for QA and role-based views.