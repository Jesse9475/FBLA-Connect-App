# Testing Notes (Magic Link + Visibility)

## Magic Link Auth
1. Open `/` and request a magic link with a valid email.
2. Click the link; you should land back in the app with a session.
3. Open `/dashboard` and click Refresh Session to confirm role.

## Role-Based Visibility
- Member: can read public + members content; cannot create announcements.
- Advisor: can create announcements; cannot manage districts/chapters.
- Admin: can manage all, including announcements and org data.

## Org-Aware Announcements
1. Assign `district_id` and `chapter_id` on your user.
2. Create announcements for national, district, and chapter scopes.
3. Verify a user outside the district/chapter cannot see those items.
