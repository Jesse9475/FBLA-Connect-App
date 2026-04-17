# FBLA Connect — Developer Handoff Spec

> Version 1.0 | March 2026 | Flutter 3.x / Dart 3.x / Material 3

---

## Tech Stack Quick Reference

| Layer | Technology |
|---|---|
| Frontend | Flutter 3.x (Dart 3.x) |
| Auth | Supabase Auth (email + password) |
| Backend | Flask REST API (Python) |
| Database | Supabase (PostgreSQL + RLS) |
| HTTP client | Dio 5.x |
| Fonts | Google Fonts — Inter |
| Theme | Material 3 + `FblaTheme` |
| State | `setState` + `StreamBuilder` (no external state management) |
| Storage | `flutter_secure_storage` (legacy token), Supabase native session |

---

## Screen 1: Splash Screen (`_SplashScreen`)

### Overview
Branded loading screen shown while `AuthGate` waits for the first Supabase `AuthState` event.

### Layout
Full-screen `Scaffold` with `FblaColors.primary` background, centered `Column`.

### Design Tokens Used
| Token | Value | Usage |
|---|---|---|
| `FblaColors.primary` | `#1B3A8C` | Scaffold background |
| `FblaColors.secondary` | `#F5A623` | Logo circle background |
| `FblaSpacing.lg` | 24px | Gap between logo and title |
| `FblaSpacing.xxl` | 48px | Gap before spinner |

### Components
| Element | Spec | Notes |
|---|---|---|
| Logo circle | 80×80, `BoxShape.circle`, `FblaColors.secondary` | Contains "FC" in `FblaColors.primary` W800 28sp |
| Box shadow | `secondary` at 31% alpha, blur 24, y 8 | Glow effect |
| App name | 24sp W700 white `letterSpacing: 0.5` | "FBLA Connect" |
| Tagline | 13sp white at 70% alpha | "Future Business Leaders of America" |
| Spinner | `CircularProgressIndicator` 28×28, 2.5 stroke, `FblaColors.secondary` | |

### Transitions
Auto-replaced by `LoginScreen` or `HomeShell` when `AuthState` emits. No manual navigation needed.

---

## Screen 2: Login Screen (`LoginScreen`)

### Overview
Supabase email + password sign-in. Two-part layout: branded hero (primary bg) + form card (background color, rounded top corners).

### Layout
```
Scaffold (primary bg)
└── SafeArea
    ├── Expanded(flex:2) → Hero / branding
    └── Expanded(flex:3) → Form card
        ├── Round top corners (xl: 24px)
        └── SingleChildScrollView
            └── Form
                ├── Title + subtitle
                ├── Email TextFormField
                ├── Password TextFormField
                ├── Forgot password TextButton (right-aligned)
                ├── _ErrorBanner (conditional)
                └── ElevatedButton "Sign in"
```

### Design Tokens Used
| Token | Value | Usage |
|---|---|---|
| `FblaColors.primary` | `#1B3A8C` | Hero background |
| `FblaColors.background` | `#F5F7FF` | Form card bg |
| `FblaRadius.xl` | 24px | Form card top corners |
| `FblaSpacing.xl` | 32px | Form card padding |
| `FblaSpacing.md` | 16px | Between fields |

### States and Interactions
| Element | State | Behavior |
|---|---|---|
| Email field | Empty submit | Inline error: "Please enter your email address." |
| Email field | Invalid format | Inline error: "Please enter a valid email address." |
| Password field | Empty submit | Inline error: "Please enter your password." |
| Password field | < 6 chars | Inline error: "Password must be at least 6 characters." |
| Sign-in button | Loading | Spinner replaces label, button disabled |
| Sign-in button | Auth error | `_ErrorBanner` appears above button |
| Visibility toggle | Tap | Toggles `obscureText`, icon swaps (150ms `AnimatedSwitcher`) |
| Forgot password | Tap | Opens `ModalBottomSheet` |

### Error Messages (Friendly Copy)
| Supabase Error | User-facing Copy |
|---|---|
| `invalid login credentials` | "Incorrect email or password. Please try again." |
| `email not confirmed` | "Please verify your email address before signing in." |
| `too many requests` | "Too many attempts. Please wait a moment and try again." |
| Network error | "Unable to reach the server. Please check your connection." |
| Any other | "Sign in failed. Please try again." |

### Forgot Password Sheet
Bottom sheet with email field + "Send reset link" button. Calls `Supabase.auth.resetPasswordForEmail()`. Shows success banner on completion.

### Accessibility
- Form wrapped in `Form` with `GlobalKey` for proper validation
- Error banner uses `Semantics(liveRegion: true)` — screen readers announce changes
- Password visibility toggle has `tooltip`
- All fields have `autofillHints`

---

## Screen 3: Home Shell (`HomeShell`)

### Overview
Root scaffold with Material 3 `NavigationBar`. Uses `IndexedStack` to preserve scroll state per tab.

### Navigation Destinations
| Index | Label | Icons | Screen |
|---|---|---|---|
| 0 | Home | `home_outlined` / `home` | `DashboardScreen` |
| 1 | Events | `event_outlined` / `event` | `EventsScreen` |
| 2 | News | `campaign_outlined` / `campaign` | `AnnouncementsScreen` |
| 3 | Feed | `dynamic_feed_outlined` / `dynamic_feed` | `PostsScreen` |
| 4 | Profile | `person_outlined` / `person` | `ProfileScreen` |

### Design Tokens Used
| Token | Value | Usage |
|---|---|---|
| `FblaColors.surface` | `#FFFFFF` | Nav bar background |
| `FblaColors.primary` at 8% | — | Indicator pill |
| `FblaColors.primary` | `#1B3A8C` | Active icon + label |
| `FblaColors.textDisabled` | `#ADB5C4` | Inactive icon + label |

### Responsive Behavior
- Mobile (< 600px): Bottom nav bar (current)
- Tablet / desktop (≥ 600px): **TODO** — replace with `NavigationRail` or `NavigationDrawer`

---

## Screen 4: Dashboard (`DashboardScreen`)

### Overview
Personalized greeting, quick stats, upcoming events (top 3), recent announcements (top 3).

### Layout
```
CustomScrollView
├── SliverAppBar (expandedHeight: 140, pinned)
│   └── FlexibleSpaceBar → _HeroBanner
│   └── PreferredSize → 20px curved cutout (background bg)
├── SliverToBoxAdapter → _StatChip row (3 chips)
├── SliverToBoxAdapter → SectionHeader "Upcoming Events"
├── SliverList → EventCard × n
├── SliverToBoxAdapter → SectionHeader "Recent Announcements"
└── SliverList → AnnouncementCard × n
```

### Hero Banner Spec
- Background: `FblaColors.primary`
- Greeting: "Good morning/afternoon/evening, {firstName} 👋"
- Font: 22sp W700 white
- Tagline: 14sp white at 78% alpha

### Stat Chips (3-column row)
| Chip | Icon | Color | Value |
|---|---|---|---|
| Events | `Icons.event` | `primary` | Count of events |
| Announcements | `Icons.campaign` | `secondary` | Count of announcements |
| Today | `Icons.calendar_today` | `success` | `MMM d` format |

Each chip: `primary`/`secondary`/`success` at 5% bg, border at 16%, rounded `md`.

### API Calls
- `GET /api/events` → top 3
- `GET /api/announcements` → top 3
- Both called in `Future.wait` (parallel)

### Edge Cases
- Empty events: `Text("No events yet")` inline
- Empty announcements: same pattern
- Load error: centered `_ErrorCard` with retry button
- Loading: `CircularProgressIndicator` centered in `SliverFillRemaining`

---

## Screen 5: Events (`EventsScreen`)

### Overview
Full events list with all/upcoming/past filter bar.

### Filter Bar
Three `FilterChip` widgets in a horizontal `Row`. `selected` state: `primary` at 8% bg + `primary` border + W600 label.

### EventCard Spec
| Element | Spec |
|---|---|
| Date badge | 52px wide, `primary` at 5% bg, border at 16% |
| Month | 10sp W700 `primary` uppercase, 0.5 tracking |
| Day | 22sp W800 `primary`, height 1.1 |
| Weekday | 9sp W600 `textSecondary` uppercase |
| Title | 15sp W600 `textPrimary`, 1-line ellipsis |
| Description | 13sp `textSecondary`, 2-line ellipsis |
| Time row | Clock icon 12px + `textSecondary` 12sp |
| Location row | Pin icon 12px + `textSecondary` 12sp |
| Card | `surface` bg, `outlineVariant` 1px border, `card` shadow, `md` radius |

### Visibility Chip
- `public`: hidden
- `members`: `primary` at 6% bg, W600 10sp
- `private`: `warning` at 6% bg, W600 10sp

### States
| State | Behavior |
|---|---|
| Loading | Centered `CircularProgressIndicator` |
| Empty (all) | "No events yet" illustration + copy |
| Empty (upcoming) | "No upcoming events" copy |
| Error | Error icon + message + "Try again" button |
| Loaded | `ListView.separated` with 8px gaps |

---

## Screen 6: Announcements (`AnnouncementsScreen`)

### Overview
Scoped announcement feed with horizontal filter chips: All / National / District / Chapter.

### Filter Chips
Uses `secondary` color family instead of `primary` (visually differentiates from Events).

### AnnouncementCard Spec
| Element | Spec |
|---|---|
| Scope badge | Pill, scope-colored bg/border/icon |
| Date | Right-aligned, 11sp `textSecondary` |
| Title | 15sp W600 `textPrimary`, 2-line clamp |
| Body | 13sp `textSecondary`, 3-line clamp, height 1.5 |

### Scope Colors
| Scope | Bg | Fg | Border |
|---|---|---|---|
| National | `#F0FDF4` | `success` | `success` at 23% |
| District | `#FFFBEB` | `secondaryDark` | `secondary` at 31% |
| Chapter | `#EFF6FF` | `primary` | `primary` at 20% |

---

## Screen 7: Posts/Feed (`PostsScreen`)

### Overview
Member-written post feed with like (optimistic) and comment (stub) actions.

### FAB
`FloatingActionButton.extended`, `secondary` bg, label "New post", triggers `_showNewPostSheet`.

### PostCard Spec
| Element | Spec |
|---|---|
| Avatar | 36px circle, `primary` at 6% bg, person icon |
| Author | "You" (own) or "Chapter Member" (others), 13sp W600 |
| Timestamp | 11sp `textSecondary` |
| Body | 14sp `textPrimary`, height 1.55, full expansion |
| Like button | Heart icon (18px), counter, `error` when liked |
| Like state | Optimistic toggle — local `_liked` bool, fires API in background |

### New Post Sheet
- `TextFormField` (4 lines, autofocus) for body
- Visibility hardcoded to `members` in v1.0
- Calls `POST /api/posts` with `{body, visibility}`
- Refreshes list on success

---

## Screen 8: Messages (`MessagesScreen`)

### Overview
Thread list. Each thread opens `_ThreadDetailScreen`.

### Thread Tile
- Avatar: `forum_outlined` icon in `primary` bg circle
- Title: first 8 chars of UUID + "…"
- Subtitle: "Tap to view messages"
- Right: formatted date

### Thread Detail (`_ThreadDetailScreen`)
Two-part layout: scrollable message list + fixed composer.

### Message Bubble
| Element | Spec |
|---|---|
| Avatar | 32px circle, `primary` at 8% bg |
| Bubble | `surfaceVariant` bg, `md` radius (top-right + both bottom) |
| Body | 14sp `textPrimary` |

### Composer
| Element | Spec |
|---|---|
| Text field | `outlineInputBorder`, `isDense`, `viewInsets` padding |
| Send button | `send_rounded` icon, `primary` color, 48×48 tap target |
| Loading | Replaces send button with 20px `CircularProgressIndicator` |

---

## Screen 9: Profile (`ProfileScreen`)

### Overview
User info, role badge, settings list, and sign-out with confirmation dialog.

### Avatar
88×88 circle, `LinearGradient` from `primary` to `primaryLight`. Initial letter in W700 36sp white.

### Role Badge
Pill badge below name. Colors by role:
| Role | Bg | Fg |
|---|---|---|
| admin | `error` at 8% | `error` |
| advisor | `secondary` at 12% | `secondaryDark` |
| member | `primary` at 6% | `primary` |

### Section Cards
`_SectionCard` wrapper: uppercase 11sp W700 label + `surface` bg container, `md` radius, `outlineVariant` border.

**Account section**: email, role, chapter (if set), district (if set).
**App section**: Notifications (stub), About dialog.

### Sign-out Flow
`AlertDialog` confirmation → `ApiService.clearToken()` → `Supabase.auth.signOut()` → `AuthGate` auto-navigates to `LoginScreen`.

---

## Animation & Motion Spec

| Element | Trigger | Animation | Duration | Easing |
|---|---|---|---|---|
| Send button ↔ spinner | Message sending | `AnimatedSwitcher` | 150ms | default |
| Password visibility icon | Toggle tap | `AnimatedSwitcher` | 150ms | default |
| Modal bottom sheets | Open/close | Material default slide | 300ms | `decelerate` |
| Page route | Navigation | Material default | 300ms | `easeInOut` |
| `RefreshIndicator` | Pull | Material default | — | — |

---

## Responsive Breakpoints

| Breakpoint | Width | Behavior |
|---|---|---|
| Mobile (current) | < 600px | Bottom `NavigationBar`, full-width cards |
| Tablet (TODO) | 600–1024px | `NavigationRail`, 2-column card grid |
| Desktop (TODO) | > 1024px | `NavigationDrawer`, 3-column grid |

---

## API Integration Reference

All calls go through `ApiService.instance`. Token is set automatically from Supabase session.

| Endpoint | Method | Screen | Parser |
|---|---|---|---|
| `/events` | GET | Dashboard, Events | `data['events']` → `List<Map>` |
| `/events/{id}` | GET | EventDetail | `data['event']` → `Map` |
| `/events` | POST | CreateEvent | `data['event']` |
| `/announcements` | GET | Dashboard, Announcements | `data['announcements']` |
| `/posts` | GET | Posts | `data['posts']` |
| `/posts` | POST | New post sheet | `data['post']` |
| `/posts/{id}/like` | POST | PostCard | none |
| `/threads` | GET | Messages | `data['threads']` |
| `/threads/{id}/messages` | GET | ThreadDetail | `data['messages']` |
| `/threads/{id}/messages` | POST | Composer | `data['message']` |
| `/users/me` | GET | Profile | `data['user']` |

---

## Build & Run

```bash
# Install dependencies
flutter pub get

# Run with Supabase credentials
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJ... \
  --dart-define=BACKEND_URL=https://YOUR_BACKEND.com/api
```
