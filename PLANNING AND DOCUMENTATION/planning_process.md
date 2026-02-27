# Planning Process Standard

This document defines the planning process standard for the FBLA Connect app.
It must be updated for every major feature, system change, or architectural
decision.

## Planning Artifacts (Required)
- Product vision and target users.
- Scope and feature backlog (prioritized).
- Architecture diagram(s) and data flow.
- Data model and schema decisions.
- API contract notes and endpoint list.
- Risk register (security, privacy, performance).
- Testing strategy and acceptance criteria.

## Process (Industry Terminology)
- Requirements analysis and stakeholder alignment.
- Technical design review and architecture selection.
- Iterative development with milestones and sprint goals.
- Change control with decision logs and tradeoff analysis.
- Verification and validation (V&V) for critical flows.

## Current Planning Documents
- Backend plan: stored in `.cursor/plans/` and referenced in commit notes.
- Security overview: `SECURITY.md`.

## Change Log
- Add dated entries describing each planning update.
- 2026-02-03: Planned Supabase-only auth, RLS, and invite-code advisor flow.
- 2026-02-03: Added org-aware announcements and basic web dashboard for QA.