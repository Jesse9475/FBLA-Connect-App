# FBLA Connect — UI/UX Audit & Improvement Plan
**Date:** March 25, 2026
**Scope:** Flutter/Dart frontend (`lib/screens/`, `lib/widgets/`, `lib/theme/`)
**Standards Applied:** WCAG 2.1 AA · Material Design 3 · Flutter best practices

---

## Executive Summary

FBLA Connect has a **strong foundation**: a dedicated `app_theme.dart` with well-named design tokens (`FblaColors`, `FblaSpacing`, `FblaRadius`, `FblaShadow`, `FblaMotion`), Material 3 enabled, consistent use of `GoogleFonts.inter`, and good error-handling patterns. However, the app has several layers of issues that make it feel **flat, static, and AI-generated** rather than polished and interactive. This report covers three areas — Accessibility (WCAG 2.1 AA), Design System inconsistencies, and User Journey gaps — then provides a prioritized action plan.

---

## Part 1 — Accessibility Audit (WCAG 2.1 AA)

### Summary
| Severity | Count |
|---|---|
| 🔴 Critical | 3 |
| 🟡 Major | 7 |
| 🟢 Minor | 4 |

---

### Perceivable

| # | Screen / Widget | Issue | Criterion | Severity | Fix |
|---|---|---|---|---|---|
| 1 | All screens | `FblaColors.textSecondary` (#6B7280) on `FblaColors.background` (#F5F7FF) achieves only ~3.9:1 contrast ratio — below the 4.5:1 required for normal text. Affects body copy, dates, subtitles, filter chip labels, hub card descriptions. | 1.4.3 Contrast | 🔴 Critical | Darken `textSecondary` to #4B5563 (≈5.9:1 on white). |
| 2 | `_AnnouncementHeroCard` | White body text rendered at `withAlpha(200)` (~78% opacity) over gradient; the district scope gradient (amber `#B45309 → #92400E`) with white text at 78% achieves approx 3.1:1 — fails 4.5:1. | 1.4.3 Contrast | 🔴 Critical | Use full-opacity white text or darken gradient. Consider a semi-transparent dark overlay behind text. |
| 3 | `_AnnouncementHeroCard`, `PostCard` author row, all `CircleAvatar` uses | Decorative and informational icons (person, forum) have no alt text or semantic labels. `_AnnouncementHeroCard` has zero `Semantics` wrapper — invisible to VoiceOver/TalkBack. Thread list shows UUID substrings as titles. | 1.1.1 Non-text Content | 🔴 Critical | Wrap `_AnnouncementHeroCard` in `Semantics(label: '$_scopeLabel announcement: $_title')`. Replace UUID thread titles with meaningful names. |
| 4 | `_MessageBubble` | Message body has no sender label, no timestamp, no semantic role — screen reader users get raw text with no context. | 1.3.1 Info & Structure | 🟡 Major | Add `Semantics(label: 'From [sender], [time]: $_body')` wrapping each bubble. |
| 5 | `_SplashScreen` | The "FC" logo container is not wrapped in Semantics — it will be announced as an unlabeled image. | 1.1.1 Non-text Content | 🟢 Minor | Add `Semantics(label: 'FBLA Connect logo', excludeSemantics: true)`. |

---

### Operable

| # | Screen / Widget | Issue | Criterion | Severity | Fix |
|---|---|---|---|---|---|
| 6 | `_ActionButton` (`PostCard`) | Touch target is icon 18px + padding 8+6px = ~30px height. Fails the 44×44 CSS-px (logical pixel) minimum. | 2.5.5 Touch Target | 🟡 Major | Increase vertical padding to `EdgeInsets.symmetric(horizontal: 8, vertical: 13)` to reach 44px. |
| 7 | `_FilterBar` (EventsScreen), category chips (HubScreen) | `FilterChip` default height is ~32px with no custom padding. Fails 44px touch target. | 2.5.5 Touch Target | 🟡 Major | Set `materialTapTargetSize: MaterialTapTargetSize.padded` on all chips, or wrap in a 44px minimum container. |
| 8 | `_DateTimeTile` (EventsScreen create sheet) | `InkWell` border radius is `FblaRadius.sm (6)` but outer container uses same — visually aligned, but the entire tile including borders can fall below 44px on compact screens if label is short. | 2.5.5 Touch Target | 🟢 Minor | Enforce `minHeight: 44` on the tile container. |
| 9 | `_ThreadTile` | `ListTile` with `vertical: FblaSpacing.xs (4px)` content padding — tile total height may drop to ~36px for short messages. | 2.5.5 Touch Target | 🟡 Major | Remove custom vertical padding; Material ListTile defaults to 48px and complies. |

---

### Understandable

| # | Screen / Widget | Issue | Criterion | Severity | Fix |
|---|---|---|---|---|---|
| 10 | `_showNewPostSheet` (FeedScreen) | The post text area uses `hintText` only (`"What's on your mind?"`), not `labelText`. This means once the user starts typing, there's no accessible label — the field becomes unlabeled. | 3.3.2 Labels | 🟡 Major | Change to `labelText: 'Post content'` and keep hintText as supplementary, OR use a `Semantics(label: 'Post content')` wrapper. |
| 11 | `_CreateEventSheet` | Required fields marked `*` (asterisk in label text like `'Title *'`). Asterisks are not announced by screen readers as "required." | 3.3.2 Labels | 🟢 Minor | Add `semanticsLabel: 'Title, required'` to the `InputDecoration`, or use `Semantics` with explicit required-field callout. |
| 12 | Error views in EventsScreen, MessagesScreen, HubScreen | Raw error text without `Semantics(liveRegion: true)` — screen reader users won't be alerted when an error appears. (LoginScreen's `_ErrorBanner` does this correctly.) | 4.1.3 Status Messages | 🟢 Minor | Add `Semantics(liveRegion: true)` to all error and empty-state containers, consistent with `_ErrorBanner`. |

---

### Robust

| # | Screen / Widget | Issue | Criterion | Severity | Fix |
|---|---|---|---|---|---|
| 13 | `home_shell.dart` | Uses `NavigationBar` (M3) but `ThemeData` in `app_theme.dart` configures `bottomNavigationBarTheme` (M2 widget). The two don't share a theme — `NavigationBarTheme` should be added to `FblaTheme.light` instead. | 4.1.2 Name, Role, Value | 🟡 Major | Add `navigationBarTheme: NavigationBarThemeData(...)` to `FblaTheme.light`, remove inline `backgroundColor`/`indicatorColor` from `HomeShell`. |
| 14 | `_ThreadDetailScreen` | AppBar title is hardcoded `'Thread'` — doesn't identify the actual conversation context. | 2.4.2 Page Titled | 🟡 Major | Pass the thread subject/participant name down and display it in the AppBar. |

---

### Color Contrast Check

| Element | Foreground | Background | Estimated Ratio | Required | Pass? |
|---|---|---|---|---|---|
| Body text (bodyLarge) | #111827 | #FFFFFF | ~18:1 | 4.5:1 | ✅ |
| bodyMedium (secondary text) | #6B7280 | #F5F7FF | ~3.9:1 | 4.5:1 | ❌ |
| Announcement card body text | #FFFFFF @ 78% | #B45309 gradient | ~3.1:1 | 4.5:1 | ❌ |
| Input hint text | #ADB5C4 | #F0F4FF | ~2.5:1 | 4.5:1 | ❌ (decorative OK if not alone) |
| Button label on primary | #FFFFFF | #1B3A8C | ~9.2:1 | 4.5:1 | ✅ |
| Secondary label on secondary | #1A1A1A | #F5A623 | ~6.9:1 | 4.5:1 | ✅ |
| Role badge (member) text | #1B3A8C | #1B3A8C @ 6% alpha | ~4.6:1 | 4.5:1 | ✅ (barely) |
| Scope label on chapter card | #FFFFFF @ 30% tint | #1B3A8C | ~6:1 | 4.5:1 | ✅ |
| Category icon color on tinted bg | #065F46 | #065F46 @ 8% alpha | ~4.2:1 | 3:1 (UI component) | ✅ |

---

## Part 2 — Design System Audit

### Token Compliance — Hardcoded Values Found

The following files contain **magic numbers or raw hex colors** that bypass the design token system. These create inconsistency risk if tokens ever change.

#### `hub_screen.dart` — `_HubItemCard._categoryColor`
```dart
// ❌ PROBLEM: Raw hex colors that duplicate or diverge from the token system
'study guides' => const Color(0xFF1B3A8C),  // = FblaColors.primary — use token
'templates'    => const Color(0xFF065F46),  // not in token system
'events'       => const Color(0xFFB45309),  // not in token system
'leadership'   => const Color(0xFF7C3AED),  // not in token system
_              => const Color(0xFF374151),  // not in token system

// ✅ FIX: Add these to FblaColors (or a FblaCategoryColors extension):
// FblaColors.categoryGreen  = Color(0xFF065F46)
// FblaColors.categoryAmber  = Color(0xFFB45309)
// FblaColors.categoryPurple = Color(0xFF7C3AED)
// FblaColors.categorySlate  = Color(0xFF374151)
```

#### Hardcoded Spacing Values (should use FblaSpacing tokens)
| File | Line | Value | Should Be |
|---|---|---|---|
| `feed_screen.dart` | 532 | `SizedBox(height: 4)` | `FblaSpacing.xs` (4) ✅ — just use the token |
| `post_card.dart` | 98, 99 | `horizontal: 6, vertical: 2` | `FblaSpacing.xs` / 2 — add `FblaSpacing.xxs = 2` |
| `post_card.dart` | 197 | `SizedBox(width: 4)` | `FblaSpacing.xs` |
| `event_card.dart` | 101 | `SizedBox(height: 4)` | `FblaSpacing.xs` |
| `event_card.dart` | 121 | `SizedBox(height: 2)` | Add `FblaSpacing.xxs = 2` |
| `event_card.dart` | 189 | `SizedBox(height: 2)` | `FblaSpacing.xxs` |
| `hub_screen.dart` | 664 | `horizontal: 7, vertical: 2` | `horizontal: FblaSpacing.sm, vertical: FblaSpacing.xxs` |
| `messages_screen.dart` | 382 | `horizontal: 14, vertical: 10` | `horizontal: FblaSpacing.md, vertical: FblaSpacing.sm` |
| `profile_screen.dart` | 617 | `SizedBox(height: 2)` | `FblaSpacing.xxs` |
| `login_screen.dart` | 191 | `vertical: 4` | `FblaSpacing.xs` |
| `profile_screen.dart` | 524 | `vertical: 4` | `FblaSpacing.xs` |

#### Inline AppBar Overrides (Theme Bypass)
Every screen manually overrides `AppBar` with identical gradient code:
```dart
// ❌ This pattern is copy-pasted across ALL 5 main screens:
backgroundColor: FblaColors.primary,
foregroundColor: Colors.white,
flexibleSpace: Container(
  decoration: const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [FblaColors.primaryDark, FblaColors.primaryLight],
    ),
  ),
),
```
This bypasses `FblaTheme.light`'s `appBarTheme` entirely. It creates 5 code duplication points and can't be updated from one place.

**Fix:** Create a `FblaAppBar` widget or extend `AppBarTheme` with a `flexibleSpace` background via a custom `AppBar` factory.

#### `FblaMotion` — Defined But Largely Unused
`FblaMotion` defines `fast`, `standard`, `slow`, `easeOut`, and `spring` but only `messages_screen.dart` uses `FblaMotion.fast`. No screen uses page transition animations, card entrance animations, or press micro-interactions.

#### Missing Theme Entries
- **`NavigationBarTheme`** — not in `FblaTheme.light`; `HomeShell` sets properties inline
- **Dark mode** — `FblaTheme` only has `get light`; no dark theme defined
- **`FblaSpacing.xxs`** — several places need a 2px unit; add `static const double xxs = 2.0`

#### Structural Inconsistency: Two Error Widget Patterns
The codebase has two separate error UI patterns that aren't shared:
1. `_ErrorBanner` in `login_screen.dart` — semantic live region, inline
2. Anonymous `Center > Column > Icon + Text + Button` — duplicated in EventsScreen, MessagesScreen, HubScreen, FeedScreen

These should be extracted to a shared `FblaErrorView` widget in `lib/widgets/`.

---

## Part 3 — User Research & Journey Analysis

### Who Are the Users?
Based on the app's architecture (roles: `member`, `advisor`, `admin`) and the signup onboarding flow, there are three user segments:

**1. Student Members** (primary) — High school students exploring competitive events, staying connected with their chapter, checking announcements.
**2. Chapter Advisors** — Teachers managing chapter activity, posting announcements, creating events, moderating content.
**3. Admins** — Organization-level oversight, access to admin panel.

---

### User Journey Map

#### Journey 1: New Member Signs Up and Explores
```
Open App
  → Splash screen (2s wait for backend)
  → Login screen
  → Tap "Create an account"
  → Multi-step signup: Email → OTP → Role → Name → School → Chapter → Interests → Tour
  → Lands on HomeShell (Feed tab)
  → Sees greeting "Good morning, [username]"
  → Sees empty feed or posts
  → Taps Messages → sees empty state
  → Taps Events → sees events list
  → Taps Hub → searches resources
  → Taps Profile → sees basic info
```

**Pain Points Identified:**
- 🔴 **2-second forced delay** on every cold start (`Future.delayed(Duration(seconds: 2))`) — even on fast connections; feels broken
- 🟡 **No post-onboarding orientation** — after the tour step, users land cold on the Feed with no contextual guidance
- 🟡 **Feed loading state is just a spinner** — no skeleton or shimmer to indicate content shape
- 🟡 **Display name in greeting** is the email username prefix (e.g., "jsmith") — impersonal, should use first name from onboarding
- 🟢 **Onboarding interests step** collects data but it's not reflected anywhere in the app (no personalized feed)

#### Journey 2: Member Checks Announcements
```
Open App (warm start)
  → Feed tab (already loaded via keepAlive)
  → Sees horizontal announcement carousel (fixed 140px height)
  → Can scroll carousel sideways
  → Taps "See all" → AnnouncementsScreen
  → Can't filter by scope (chapter/district/national) in standalone view
```

**Pain Points:**
- 🔴 **Announcement cards are not tappable** — `_AnnouncementHeroCard` has no `onTap`, no interaction. Users expect tapping to expand details.
- 🟡 **Fixed 140px carousel height** clips long announcement titles (maxLines: 2) with no way to see full content
- 🟡 **No scope filter** on the standalone announcements screen
- 🟢 **Carousel has no pagination indicator** — users don't know how many announcements exist

#### Journey 3: Member Wants to Message Someone
```
Taps Messages tab
  → Sees thread list (or empty state)
  → Thread titles show "Thread abc123…" (UUID substrings)
  → Taps "New message" icon → Gets snackbar: "New thread — coming soon"
```

**Pain Points:**
- 🔴 **Thread titles are UUID substrings** — completely unusable; users can't identify conversations
- 🔴 **Can't start new conversations** — "coming soon" is presented as a real button; creates frustration
- 🟡 **No sender name in message bubbles** — all messages look the same, no visual distinction for own vs. others
- 🟡 **No real-time updates** — messages require manual pull-to-refresh to see new content
- 🟢 **Comment button on posts** also shows "coming soon" snackbar

#### Journey 4: Advisor Creates an Event
```
Taps Events tab
  → Taps + button in AppBar
  → Bottom sheet: fill Title, tap Start (opens date picker, then time picker separately)
  → Fill optional End, Location, Description
  → Choose visibility
  → Tap "Create Event"
  → Sheet closes, list reloads
```

**Pain Points:**
- 🟡 **Two consecutive system pickers** (date then time) with no "skip time" option — forces picking a time even if you just want a date
- 🟡 **No confirmation step** before creating — easy to accidentally submit
- 🟡 **Event cards are not tappable** (EventCard has `onTap: () {}` TODO comment) — no detail view
- 🟢 **No edit/delete for events after creation** — advisor-level action but not surfaced

#### Journey 5: User Explores the Resource Hub
```
Taps Hub tab
  → Search bar + category chip filter
  → Taps a resource card → DraggableScrollableSheet opens
  → Reads content, sees download button (shows "Download started" snackbar)
```

**Pain Points:**
- 🟡 **Download is fake** — `SnackBar('Download started')` with no actual file action
- 🟡 **Hub item detail opens as bottom sheet** — long content is cramped; a full-screen page would improve readability
- 🟢 **Category chip `selectedColor`** in HubScreen is `FblaColors.primary` (solid fill) but in EventsScreen it's `FblaColors.primary.withAlpha(20)` (tint) — visually inconsistent across the same app

---

## Part 4 — UI/UX Improvement Plan

This plan is organized into three tiers: **Quick Wins** (< 1 day each), **Major Improvements** (1–3 days each), and **Experience Upgrades** (3–5 days each).

---

### Tier 1 — Quick Wins (Fix First)

**1. Remove the 2-second hardcoded delay**
In `main.dart`, remove `await Future.delayed(const Duration(seconds: 2))`. The app should show a loading spinner while probing the backend port, then proceed immediately. The current delay punishes users on fast connections.

**2. Fix thread titles**
In `messages_screen.dart`, replace the UUID-based title with a meaningful fallback (participant list, or a "Direct Message" label). Until real names are wired up, show "Conversation" with the creation date — anything better than "Thread abc1234…".

**3. Make announcement cards tappable**
Wrap `_AnnouncementHeroCard` in an `InkWell` / `GestureDetector` and push a full-screen or bottom-sheet detail view. Users absolutely expect horizontal scroll cards to be tappable.

**4. Make event cards tappable**
Replace the `onTap: () {}` TODO in `EventCard` with navigation to an `EventDetailScreen`.

**5. Replace "coming soon" snackbars with disabled / hidden states**
"New message" and "Comment" buttons that fire a "coming soon" snackbar feel broken. Either hide them (if the feature doesn't exist) or show a clearly disabled state with a tooltip explaining future availability. Never show a tappable control that does nothing real.

**6. Harden textSecondary contrast**
Change `FblaColors.textSecondary` from `#6B7280` to `#4B5563` (darkened). This fixes the WCAG 1.4.3 failure on background surfaces for all body copy, dates, and metadata across every screen.

**7. Add `Semantics` to AnnouncementHeroCard**
One-line fix: wrap in `Semantics(label: '$_scopeLabel announcement: $_title. $_body')`.

---

### Tier 2 — Major Improvements (Core UX)

**8. Replace all loading spinners with shimmer skeletons**
Currently every screen (`FeedScreen`, `EventsScreen`, `MessagesScreen`, `HubScreen`) shows a centered `CircularProgressIndicator` while fetching. Replace with skeleton cards that mimic the shape of real content. This makes the app feel alive and tells users where content will appear. Use the `shimmer` package or hand-roll it with `AnimatedContainer` + `FblaColors.outlineVariant`.

**9. Add page transition animations**
`MaterialPageRoute` gives a basic slide, but a custom `PageRouteBuilder` using `FblaMotion.standard` with a subtle fade+slide or shared-element hero would make navigation feel natural rather than mechanical. At minimum:
- Login → Home: fade out
- Tap card → Detail: slide up (bottom-sheet style)
- Settings → Back: slide right

**10. Add micro-interactions to interactive elements**
The Like button in `PostCard` changes icon/color but has no animation. Add a quick scale bounce using `AnimationController` + `ScaleTransition` on tap. Similarly, filter chip selection should animate (`AnimatedContainer` width for the selection indicator). These small moments of responsiveness make an app feel crafted, not generated.

**11. Consolidate the duplicated error/empty widget pattern**
Create `lib/widgets/fbla_error_view.dart` and `lib/widgets/fbla_empty_view.dart` that accept an icon, message, optional sub-message, and optional action button. Replace the 4 identical anonymous error blobs in EventsScreen, MessagesScreen, HubScreen, and FeedScreen. This also fixes the missing live region accessibility issue.

**12. Extract shared AppBar into a FblaAppBar widget**
Create `lib/widgets/fbla_app_bar.dart` that returns the gradient AppBar used across all screens. Screens just call `FblaAppBar(title: 'Events', actions: [...])`. This removes 40+ lines of duplicated decoration code.

**13. Hub detail as full-screen page, not bottom sheet**
For Hub resources, push a full `HubDetailScreen` rather than `showModalBottomSheet`. The DraggableScrollableSheet works for short content but fights the user for long articles. A full-screen page with a proper AppBar, scroll behavior, and a larger font size for body text dramatically improves readability.

**14. Fix the display name in the greeting**
`FeedScreen._displayName` currently returns the email prefix (e.g., `jsmith`). This should pull `first_name` from `UserState` / the profile endpoint. The signup onboarding collects the first name — use it.

---

### Tier 3 — Experience Upgrades (Make It Feel Premium)

**15. Add animated splash screen transition**
The splash screen abruptly cuts to LoginScreen on auth-state ready. Add a `FadeTransition` or `ScaleTransition` from the "FC" logo that morphs into the login screen's logo. This is a one-time impression moment — make it count.

**16. Entrance animations for list items**
When the feed, events, or hub list loads for the first time, animate cards entering from below with staggered delays using `AnimationController` + `SlideTransition`/`FadeTransition`. Stagger at 50ms per item (up to 5 items; after that, no delay). This gives the perception of the app "filling in" rather than just snapping into view.

**17. Add pull-to-refresh visual polish**
The `RefreshIndicator` uses the default `FblaColors.primary` circle. Customize it to use the FBLA gold (`secondary`) and add a small "Last updated [time]" label below the AppBar that updates on refresh.

**18. Personalized Hub recommendations**
The signup flow collects interests (Accounting, Entrepreneurship, Leadership, etc.). Use these to show a "Recommended for you" section at the top of the Hub before the full list. Filter `_items` by category matching selected interests. Zero backend changes needed — pure client-side.

**19. Announcement carousel improvements**
- Add a page indicator dots row below the carousel
- Make the carousel auto-scroll with a 4-second timer (`PageController` + `Timer.periodic`)
- Make each card tappable (see Quick Win #3)
- Add a gentle bounce/spring physics to the scroll (`BouncingScrollPhysics`)

**20. Dark mode support**
Add `FblaTheme.dark` to `app_theme.dart` that mirrors the light theme but with a dark surface palette. Wire it through `MaterialApp` with `themeMode: ThemeMode.system`. This is expected behavior for any 2026 app.

---

## Part 5 — Recommended Implementation Order

Given the FBLA competition context, here is the highest-impact sequence:

| Priority | Item | Impact | Effort |
|---|---|---|---|
| 1 | Fix textSecondary contrast (#6B7280 → #4B5563) | WCAG compliance | 5 min |
| 2 | Add Semantics to AnnouncementHeroCard | WCAG compliance | 10 min |
| 3 | Remove 2-second hardcoded delay | First impression | 15 min |
| 4 | Fix thread titles (UUID → meaningful label) | Core UX | 30 min |
| 5 | Make announcement cards and event cards tappable | Core UX | 1 hr |
| 6 | Replace "coming soon" snackbars | UX polish | 30 min |
| 7 | Extract FblaAppBar widget (eliminate copy-paste) | Code quality | 1 hr |
| 8 | Add token `FblaSpacing.xxs`, `FblaCategoryColors`, consolidate hardcoded values | Design system | 2 hr |
| 9 | Replace CircularProgressIndicator with shimmer skeletons | Visual quality | 3 hr |
| 10 | Add micro-interaction to Like button | Delight | 1 hr |
| 11 | Entrance animations for list items | Delight | 2 hr |
| 12 | Hub detail as full-screen page | Readability | 2 hr |
| 13 | Add `NavigationBarTheme` to `FblaTheme.light` | Consistency | 30 min |
| 14 | Dark mode | Modern standard | 1 day |

---

## Appendix — Design Token Additions Recommended

```dart
// Add to FblaSpacing:
static const double xxs = 2.0;

// Add to FblaColors:
static const Color categoryGreen  = Color(0xFF065F46);
static const Color categoryAmber  = Color(0xFFB45309);
static const Color categoryPurple = Color(0xFF7C3AED);
static const Color categorySlate  = Color(0xFF374151);

// textSecondary fix:
static const Color textSecondary = Color(0xFF4B5563); // was #6B7280

// Add to FblaTheme.light:
navigationBarTheme: NavigationBarThemeData(
  backgroundColor: FblaColors.surface,
  indicatorColor: FblaColors.primary.withAlpha(20),
  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
),
```

---

*Report generated by design audit of FBLA Connect Flutter codebase — March 25, 2026*
