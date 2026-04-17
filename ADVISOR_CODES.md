# FBLA Connect — Advisor Code Bank

> **How to use:** When a new advisor signs up, they choose the **Chapter Advisor** role and enter the code for their chapter.  Each code is one-time use.  Run `python seed_advisor_codes.py` to load all codes into the database.

---

## Eastbrook District

| Code | Advisor Name | Chapter |
|------|-------------|---------|
| `ADV-EB-LINCOLN` | Mrs. Sandra Reyes | Lincoln High FBLA |
| `ADV-EB-GARFIELD` | Mr. David Kim | Garfield Academy FBLA |
| `ADV-EB-WESTVIEW` | Ms. Patricia O'Brien | Westview Preparatory FBLA |

---

## Northshore District

| Code | Advisor Name | Chapter |
|------|-------------|---------|
| `ADV-NS-RIVERSIDE` | Mr. Thomas Wheeler | Riverside Charter FBLA |
| `ADV-NS-OAKRIDGE` | Dr. Lisa Nguyen | Oakridge High FBLA |
| `ADV-NS-SUMMIT` | Ms. Rachel Torres | Summit STEM Academy FBLA |

---

## Crescent Valley District

| Code | Advisor Name | Chapter |
|------|-------------|---------|
| `ADV-CV-MADISON` | Mr. James Patel | Madison High FBLA |
| `ADV-CV-HORIZON` | Mrs. Angela Brooks | Horizon International FBLA |
| `ADV-CV-CRESTVALE` | Mr. Marcus Alvarez | Crestvale High FBLA |

---

## Testing / Demo Codes  *(for development only)*

| Code | Label | Notes |
|------|-------|-------|
| `ADV-TEST-001` | Test Advisor Alpha — Demo Chapter A | Safe to use in local dev |
| `ADV-TEST-002` | Test Advisor Beta — Demo Chapter B | Safe to use in local dev |

---

## Admin Code (DEBUG builds only)

| Code | Notes |
|------|-------|
| `FBLAADMIN2026` | Upgrades the signed-in user to `admin`.  Only works when `FLASK_DEBUG=True`. Set via `ADMIN_TEST_CODE` env var. |

---

## Notes

- Codes are **hashed with SHA-256** before storage — plain-text is never saved to the database.
- Each code is **single-use**.  After a code is consumed the advisor cannot re-use it.
- To add more codes, edit `ADVISOR_BANK` in `seed_advisor_codes.py` and re-run.
- To revoke a code before it is used, delete the matching row in the `advisor_invites` table in Supabase.
- To link codes to real chapter/district rows, fill in `chapter_id` and `district_id` UUIDs in `seed_advisor_codes.py`.
