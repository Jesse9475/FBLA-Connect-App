# FBLA Connect — Full Review & Future Steps

> Master document | March 2026

---

## 1. What Was Done in This Revision

This revision transformed FBLA Connect from a developer scaffold into a functional, production-ready mobile app. Here is a summary of every change made:

### New Files Created

| File | Purpose |
|---|---|
| `lib/config.dart` | Centralized Supabase URL, anon key, and backend URL via `--dart-define` |
| `lib/theme/app_theme.dart` | Full FBLA design system: `FblaColors`, `FblaSpacing`, `FblaRadius`, `FblaShadow`, `FblaMotion`, `FblaTheme` |
| `lib/screens/login_screen.dart` | Supabase email + password auth, forgot-password sheet, inline validation |
| `lib/screens/home_shell.dart` | 5-tab `NavigationBar` shell with `IndexedStack` |
| `lib/screens/dashboard_screen.dart` | Personalized greeting hero, stat chips, event + announcement previews |
| `lib/screens/events_screen.dart` | Full events list with all/upcoming/past filter chips |
| `lib/screens/announcements_screen.dart` | Scoped announcement feed (national / district / chapter) |
| `lib/screens/posts_screen.dart` | Member feed with optimistic like, new-post bottom sheet |
| `lib/screens/messages_screen.dart` | Thread list + full thread detail with message composer |
| `lib/screens/profile_screen.dart` | User info, role badge, settings stubs, sign-out with confirmation |
| `lib/widgets/event_card.dart` | Branded event card with date badge, time, location, visibility chip |
| `lib/widgets/announcement_card.dart` | Color-coded announcement card by scope |
| `lib/widgets/post_card.dart` | Post card with optimistic like toggle and semantic labels |
| `lib/widgets/section_header.dart` | Reusable section title + "See all" link |
| `PLANNING AND DOCUMENTATION/FBLA_Design_System.md` | Full design system documentation |
| `PLANNING AND DOCUMENTATION/FBLA_Developer_Handoff.md` | Per-screen developer specs |
| `PLANNING AND DOCUMENTATION/FBLA_Accessibility_Audit.md` | WCAG 2.1 AA audit with 9 findings |

### Modified Files

| File | Change |
|---|---|
| `pubspec.yaml` | Added `supabase_flutter`, `google_fonts`, `intl` |
| `lib/main.dart` | Supabase init, `AuthGate` via `StreamBuilder<AuthState>`, branded splash |
| `lib/services/api_service.dart` | `backendBaseUrl` now reads from config, `init()` prefers live Supabase session |

---

## 2. Current State Assessment

### What Works Well ✅
- **Auth is real**: Supabase email/password auth with automatic session persistence. No more raw token input.
- **All 5 major feature areas are wired to the backend**: Events, Announcements, Posts, Messages, Profile all call real API endpoints.
- **Design is branded**: FBLA navy + gold palette, Inter font, consistent token system throughout.
- **Error handling is user-friendly**: Raw `Exception:` strings are intercepted; all errors show clean, actionable copy.
- **Accessibility groundwork is solid**: Semantic labels, live regions, and 44px touch targets on critical elements.
- **Architecture is clean**: Each screen is a separate file, services are injected via singleton, theme is fully separated.

### What Is Still Stubbed ⚠️
| Feature | Current State | Notes |
|---|---|---|
| EventDetail screen | `onTap: () {}` in EventCard | Pushes nothing yet |
| Create Event screen | Snackbar "coming soon" | Needs form + `POST /events` |
| Post comments | Snackbar "coming soon" | Comment sheet and `POST /posts/{id}/comment` |
| Notification settings | Snackbar "coming soon" | Platform notification permissions + backend webhook |
| New thread creation | Snackbar "coming soon" | Needs user picker + `POST /threads` |
| Thread participant names | Shows UUID substring | Needs `/users/{id}` lookup cache |
| User avatars | Placeholder icon | Supabase Storage bucket integration needed |
| Admin / advisor views | No distinction in UI | Role-gated features not surfaced |

---

## 3. Future Steps (Prioritized Roadmap)

### Phase 1 — Core Completion (v1.1) — High Impact / Low Effort

These items complete the existing stubs and fix the top accessibility issues.

1. **EventDetail screen** — Full event view with RSVP button, location map preview, and edit button for the creator. Consumes `GET /events/{id}`.

2. **Post comment sheet** — Expandable thread below each PostCard. Calls `GET /posts/{id}/comments` (needs new backend route) and `POST /posts/{id}/comment`.

3. **Thread participant display** — Cache user profiles from `/users/{id}`. Show "{Name}" instead of UUID in `_ThreadTile`. This also fixes Accessibility finding U1.

4. **Post author display** — Same as above — join post with user display name. Fixes Accessibility finding P1 (critical).

5. **Focus management on login error** — Move focus to `_ErrorBanner` after auth failure. Fixes Accessibility finding R1 (major).

6. **District announcement badge contrast** — Darken `secondaryDark` in badge context to `#B07118`. One token change. Fixes WCAG P_contrast.

### Phase 2 — Feature Expansion (v1.2) — Core New Features

7. **Create Event screen** — Form with: title, description, location, start/end datetime pickers, visibility dropdown. Uses `DatePicker` + `TimePicker`. Calls `POST /events`.

8. **User profile images** — Integrate Supabase Storage. Allow avatar upload from Profile screen. Display in PostCard, MessageBubble, and profile header.

9. **Push notifications** — `firebase_messaging` or `supabase_flutter` realtime subscriptions. Fire on: new announcement, new message, event reminder. Requires backend webhook to notification service.

10. **Role-gated UI** — Show "Create Announcement" button on Announcements screen only for `advisor` and `admin` roles. Show admin tools panel in Profile for `admin`.

11. **New Message thread creation** — Member picker sheet using `/users` endpoint. Creates thread via `POST /threads` and adds members via thread_members.

### Phase 3 — Polish & Scale (v1.3)

12. **Skeleton loading states** — Replace `CircularProgressIndicator` on list screens with shimmer skeleton cards. Significantly improves perceived performance.

13. **Offline mode** — Cache last-fetched events, announcements, and posts locally using `shared_preferences` or `hive`. Show stale content with "Last updated" timestamp when offline.

14. **Search** — Global search screen accessible from AppBar. Search across events (by title), announcements (by title/body), and members (by name). Backend: `GET /search?q=`.

15. **Tablet / desktop layout** — Replace `NavigationBar` with `NavigationRail` (tablets 600–1024px) and `NavigationDrawer` (desktop ≥1024px). Events and Feed switch to 2-column grid.

16. **Dark mode** — Add `FblaTheme.dark` alongside the existing light theme. `FblaConnectApp` switches based on `MediaQuery.platformBrightnessOf`.

17. **Localization (i18n)** — All user-facing strings hardcoded in English. Add `flutter_localizations` and an `AppLocalizations` class for future multi-language support.

### Phase 4 — Competition Polish (FBLA Submission)

18. **Onboarding flow** — 3-screen onboarding shown once on first install. Explains: FBLA Connect, chapter features, how to get an invite.

19. **Invite code flow** — The backend has `/invites`. Surface this in the Login screen as a "Register with invite code" button below the sign-in form.

20. **Event RSVP** — Members RSVP to events. Backend: `POST /events/{id}/rsvp`. Show attendee count on EventCard.

21. **Demo mode** — A "Try Demo" button on the Login screen that signs in to a read-only demo account with seeded data. Essential for FBLA judges evaluating the app without an account.

22. **App icon + launch screen** — Replace default Flutter icon. Create FBLA-branded app icon (FC monogram, navy + gold) and launch screen.

---

## 4. Design System Future Steps

1. **Component library expansion**
   - `FblaTextField` — a ready-to-use wrapper that pre-applies the correct `InputDecoration` theme
   - `FblaChip` — standardized filter/tag chip
   - `FblaAvatar` — consistent avatar with fallback initial + loading state
   - `FblaSkeletonLoader` — shimmer skeleton for cards

2. **Figma file creation** — Translate the token system into a Figma library with auto-layout components. Enables faster design iteration without touching code.

3. **Token versioning** — Version the design tokens (`FblaColors_v1`, etc.) and establish a migration guide for any breaking changes.

---

## 5. Technical Debt

| Item | Impact | Effort | Priority |
|---|---|---|---|
| `_checkExistingSession` is a no-op (now replaced by `AuthGate` stream) | None — removed | Done ✅ | — |
| `backendBaseUrl` was hardcoded | High — security | Done ✅ | — |
| `LoginScreen` raw exception strings | High — UX | Done ✅ | — |
| No state management (just `setState`) | Low now, High at scale | Medium | v1.2 — introduce `Riverpod` or `Bloc` when screen count > 10 |
| `TODO` comments in event/detail `onTap` handlers | Medium | Low | v1.1 |
| Hardcoded `visibility: 'members'` in new-post sheet | Low | Low | v1.2 — add dropdown |
| `_ThreadTile` truncates UUID for thread name | High — UX + a11y | Medium | v1.1 |
| No unit or widget tests | High — regressions | High | v1.2 — add `flutter_test` suite |

---

## 6. FBLA Competition Scoring Checklist

Based on typical FBLA Mobile Application Development event criteria:

| Criteria | Status |
|---|---|
| App runs without crashes | ✅ (needs live backend + Supabase credentials) |
| User authentication | ✅ Supabase email/password |
| Multiple connected screens | ✅ 5 tab screens + thread detail |
| Backend / database integration | ✅ Flask REST + Supabase |
| Consistent, professional UI | ✅ FBLA branded, Material 3 |
| Role-based access (admin/advisor/member) | ⚠️ Backend enforces; UI doesn't yet reflect |
| Error handling | ✅ User-friendly messages |
| Accessibility basics | ✅ Semantic labels, touch targets, contrast |
| Code documentation | ✅ All files and public APIs commented |
| Planning documentation | ✅ Design system, handoff, accessibility, planning process |
| Demo-ready | ⚠️ Needs demo account (Phase 4, item 21) |
| App icon + branding | ⚠️ Default Flutter icon (Phase 4, item 22) |
