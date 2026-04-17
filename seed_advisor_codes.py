"""
seed_advisor_codes.py
─────────────────────
Generates a pre-defined bank of advisor invite codes and inserts them into
the Supabase advisor_invites table.  Each code is mapped to a specific advisor
(by name, chapter, and district) purely as a reference — the invite system
stores only the hash, so the plain-text codes below are the only copy.

Run once from the project root:
    python seed_advisor_codes.py

Requires:
    .env  with  SUPABASE_URL and SUPABASE_SERVICE_KEY set.
"""

import hashlib
import os
from datetime import datetime, timedelta, timezone

from dotenv import load_dotenv
from supabase import create_client

# ── Config ────────────────────────────────────────────────────────────────────

load_dotenv()

SUPABASE_URL = os.environ["SUPABASE_URL"]
SUPABASE_SERVICE_KEY = os.environ["SUPABASE_SERVICE_KEY"]
EXPIRES_IN_DAYS = 365   # one year — change as needed

# ── Advisor bank ──────────────────────────────────────────────────────────────
# FORMAT: {code, advisor_name, chapter_name, chapter_id*, district_name, district_id*}
# * chapter_id / district_id are optional — fill in with real UUIDs if you
#   want to link codes to actual rows in the chapters / districts tables.
# Plain-text codes are shown here so you can hand them out directly.

ADVISOR_BANK = [
    # ── Eastbrook District ────────────────────────────────────────────────────
    {
        "code":          "ADV-EB-LINCOLN",
        "advisor_name":  "Mrs. Sandra Reyes",
        "chapter_name":  "Lincoln High FBLA",
        "chapter_id":    None,
        "district_name": "Eastbrook District",
        "district_id":   None,
    },
    {
        "code":          "ADV-EB-GARFIELD",
        "advisor_name":  "Mr. David Kim",
        "chapter_name":  "Garfield Academy FBLA",
        "chapter_id":    None,
        "district_name": "Eastbrook District",
        "district_id":   None,
    },
    {
        "code":          "ADV-EB-WESTVIEW",
        "advisor_name":  "Ms. Patricia O'Brien",
        "chapter_name":  "Westview Preparatory FBLA",
        "chapter_id":    None,
        "district_name": "Eastbrook District",
        "district_id":   None,
    },
    # ── Northshore District ───────────────────────────────────────────────────
    {
        "code":          "ADV-NS-RIVERSIDE",
        "advisor_name":  "Mr. Thomas Wheeler",
        "chapter_name":  "Riverside Charter FBLA",
        "chapter_id":    None,
        "district_name": "Northshore District",
        "district_id":   None,
    },
    {
        "code":          "ADV-NS-OAKRIDGE",
        "advisor_name":  "Dr. Lisa Nguyen",
        "chapter_name":  "Oakridge High FBLA",
        "chapter_id":    None,
        "district_name": "Northshore District",
        "district_id":   None,
    },
    {
        "code":          "ADV-NS-SUMMIT",
        "advisor_name":  "Ms. Rachel Torres",
        "chapter_name":  "Summit STEM Academy FBLA",
        "chapter_id":    None,
        "district_name": "Northshore District",
        "district_id":   None,
    },
    # ── Crescent Valley District ──────────────────────────────────────────────
    {
        "code":          "ADV-CV-MADISON",
        "advisor_name":  "Mr. James Patel",
        "chapter_name":  "Madison High FBLA",
        "chapter_id":    None,
        "district_name": "Crescent Valley District",
        "district_id":   None,
    },
    {
        "code":          "ADV-CV-HORIZON",
        "advisor_name":  "Mrs. Angela Brooks",
        "chapter_name":  "Horizon International FBLA",
        "chapter_id":    None,
        "district_name": "Crescent Valley District",
        "district_id":   None,
    },
    {
        "code":          "ADV-CV-CRESTVALE",
        "advisor_name":  "Mr. Marcus Alvarez",
        "chapter_name":  "Crestvale High FBLA",
        "chapter_id":    None,
        "district_name": "Crescent Valley District",
        "district_id":   None,
    },
    # ── Testing / demo codes ──────────────────────────────────────────────────
    {
        "code":          "ADV-TEST-001",
        "advisor_name":  "Test Advisor Alpha",
        "chapter_name":  "Demo Chapter A",
        "chapter_id":    None,
        "district_name": "Demo District",
        "district_id":   None,
    },
    {
        "code":          "ADV-TEST-002",
        "advisor_name":  "Test Advisor Beta",
        "chapter_name":  "Demo Chapter B",
        "chapter_id":    None,
        "district_name": "Demo District",
        "district_id":   None,
    },
]

# ── Helpers ───────────────────────────────────────────────────────────────────

def _hash(code: str) -> str:
    return hashlib.sha256(code.encode("utf-8")).hexdigest()


def seed():
    supabase = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)
    expires_at = (datetime.now(timezone.utc) + timedelta(days=EXPIRES_IN_DAYS)).isoformat()

    inserted = 0
    skipped = 0
    for entry in ADVISOR_BANK:
        code = entry["code"]
        h = _hash(code)

        # Check for duplicate
        existing = (
            supabase.table("advisor_invites")
            .select("id")
            .eq("code_hash", h)
            .limit(1)
            .execute()
        )
        if existing.data:
            print(f"  SKIP  {code!r}  (already exists)")
            skipped += 1
            continue

        supabase.table("advisor_invites").insert(
            {"code_hash": h, "expires_at": expires_at}
        ).execute()
        print(f"  OK    {code!r}  → {entry['advisor_name']} / {entry['chapter_name']}")
        inserted += 1

    print(f"\nDone.  {inserted} inserted, {skipped} skipped.")
    print("\nPlain-text codes for distribution:")
    print("─" * 60)
    fmt = "{:<22} {:<26} {:<20} {}"
    print(fmt.format("CODE", "ADVISOR", "CHAPTER", "DISTRICT"))
    print("─" * 90)
    for e in ADVISOR_BANK:
        print(fmt.format(
            e["code"], e["advisor_name"],
            e["chapter_name"], e["district_name"],
        ))


if __name__ == "__main__":
    seed()
