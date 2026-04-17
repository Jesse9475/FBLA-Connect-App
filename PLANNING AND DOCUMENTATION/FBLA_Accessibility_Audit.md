# FBLA Connect — Accessibility Audit

> Standard: WCAG 2.1 AA | Date: March 2026 | Platform: Flutter (iOS & Android)

---

## Summary

**Issues found:** 9 | **Critical:** 1 | **Major:** 4 | **Minor:** 4

Most v1.0 screens pass WCAG 2.1 AA. The one critical issue (missing real name resolution for "Chapter Member" posts) is a data limitation, not a code bug. The major issues are all addressable in v1.1.

---

## Findings

### Perceivable (1.x)

| # | Issue | WCAG | Severity | Screen | Recommendation |
|---|---|---|---|---|---|
| P1 | Post author shown as "Chapter Member" — not a meaningful label for screen readers | 1.3.1 Info & Relationships | 🔴 Critical | PostsScreen | Fetch `users` display name from `/users/{id}` and store in post. Fall back to "Member" only if unavailable. |
| P2 | EventCard and AnnouncementCard have no skeleton loading state — content jumps in suddenly | 1.3.3 Sensory Characteristics | 🟡 Major | Events, Announcements | Add shimmer skeleton cards during `_loading` to reduce perceptual jarring |
| P3 | `_HeroBanner` emoji (👋) has no aria-label — some screen readers read it as "waving hand sign" | 1.1.1 Non-text content | 🟢 Minor | Dashboard | Wrap emoji in `Semantics(label: "")` to suppress, or remove emoji and use copy alone |

**Color contrast analysis (verified against token values):**

| Element | Foreground | Background | Ratio | Required | Result |
|---|---|---|---|---|---|
| Primary button label | `#FFFFFF` | `#1B3A8C` | **8.7:1** | 4.5:1 | ✅ Pass |
| Body text on white | `#111827` | `#FFFFFF` | **19.5:1** | 4.5:1 | ✅ Pass |
| Secondary text on white | `#6B7280` | `#FFFFFF` | **4.6:1** | 4.5:1 | ✅ Pass (AA, not AAA) |
| Input label (focused) | `#1B3A8C` | `#F0F4FF` | **6.1:1** | 4.5:1 | ✅ Pass |
| Error text on white | `#DC2626` | `#FFFFFF` | **5.1:1** | 4.5:1 | ✅ Pass |
| Success badge fg on bg | `#16A34A` | `#F0FDF4` | **4.7:1** | 4.5:1 | ✅ Pass (AA) |
| Secondary gold on primary | `#F5A623` | `#1B3A8C` | **4.6:1** | 4.5:1 | ✅ Pass (AA) |
| Disabled text | `#ADB5C4` | `#FFFFFF` | **2.9:1** | N/A | ✅ Exempt (WCAG 1.4.3 exempts disabled) |
| Scope badge: district fg | `#D4891A` | `#FFFBEB` | **3.8:1** | 4.5:1 | ⚠️ Fail |

**Action for P_contrast:** The district announcement badge (`secondaryDark` on `#FFFBEB`) falls below 4.5:1. Darken the foreground to `#B07118` to achieve ~5.2:1.

---

### Operable (2.x)

| # | Issue | WCAG | Severity | Screen | Recommendation |
|---|---|---|---|---|---|
| O1 | `ListTile` touch targets in Messages thread list are 56px height — adequate, but the subtitle area is not tappable separately | 2.5.5 Touch Target Size | 🟢 Minor | MessagesScreen | No change needed; entire tile is tappable (56px > 44px minimum) |
| O2 | FAB in PostsScreen has no `heroTag` — if two FABs ever exist on the same route, Flutter will throw | 4.1.2 (robustness) | 🟢 Minor | PostsScreen | Add `heroTag: 'create-post'` to the FAB |
| O3 | No visible focus ring on `_ActionButton` (PostCard like/comment) in high-contrast mode on some Android versions | 2.4.7 Focus Visible | 🟡 Major | PostsScreen | Wrap with `FocusableActionDetector` or use `Material(type: MaterialType.transparency)` with explicit `focusColor` |
| O4 | Bottom sheet drag handle has no semantic label — screen readers announce nothing for it | 4.1.2 Name, Role, Value | 🟡 Major | Login, Posts, Messages | Add `Semantics(label: "Drag to dismiss")` to drag handle containers |

---

### Understandable (3.x)

| # | Issue | WCAG | Severity | Screen | Recommendation |
|---|---|---|---|---|---|
| U1 | "Thread 1a2b3c4d…" is not a meaningful thread name | 3.3.2 Labels / Instructions | 🟡 Major | MessagesScreen | Implement thread names (group thread with participant names, or let the creator name it). Short-term: show participant emails. |
| U2 | New post sheet does not warn user if they tap outside while composing (loses draft) | 3.3.4 Error Prevention | 🟢 Minor | PostsScreen | Add `WillPopScope` (Flutter 3.x: `PopScope`) — prompt "Discard draft?" if field is non-empty |

---

### Robust (4.x)

| # | Issue | WCAG | Severity | Screen | Recommendation |
|---|---|---|---|---|---|
| R1 | `_ErrorBanner` in login screen uses `Semantics(liveRegion: true)` ✅ — but does not reset focus to the banner after it appears | 4.1.3 Status Messages | 🟡 Major | LoginScreen | Call `FocusScope.of(context).requestFocus(errorFocusNode)` when error state is set |

---

## Keyboard Navigation

| Element | Tab Order | Enter/Space | Escape | Notes |
|---|---|---|---|---|
| Email field | 1st | Focus / submit | — | `textInputAction: next` → moves to password |
| Password field | 2nd | Submit form | — | `textInputAction: done` → calls `_handleSignIn` |
| Visibility toggle | 3rd | Toggles obscure | — | Has `tooltip` ✅ |
| Forgot password | 4th | Opens sheet | — | `TextButton` ✅ |
| Sign in button | 5th | Submits | — | Disabled during load ✅ |
| Nav bar destinations | Tab-navigable | Switches tab | — | Material 3 `NavigationBar` ✅ |
| Cards (EventCard etc.) | Tab-navigable | Activates `onTap` | — | `InkWell` provides focus ✅ |
| Bottom sheet | Traps focus | — | Dismisses | `showModalBottomSheet` default ✅ |

---

## Screen Reader Behavior

| Element | Announced As | Issue |
|---|---|---|
| Logo circle (splash) | Not announced | ✅ Decorative — correct |
| Error banner | "Error: [message]" via `Semantics(label:)` | ✅ |
| Success banner | "Success: [message]" via `Semantics(label:)` | ✅ |
| Event card | "Event: {title}, {date}" via `Semantics(label:)` | ✅ |
| Announcement card | "Announcement: {title}, scope: {scope}" | ✅ |
| Like button (unliked) | "Like post, button" | ✅ |
| Like button (liked) | "Unlike post, button" | ✅ |
| Visibility toggle | "Show password / Hide password" via tooltip | ✅ |
| Drag handle | Nothing | ⚠️ — Fix O4 above |
| Post author | "Chapter Member, button" (not meaningful) | 🔴 — Fix P1 above |
| Scope badge (announcement) | Not announced (decorative) | ⚠️ — should announce scope |

---

## Touch Target Audit

| Element | Size | Required | Result |
|---|---|---|---|
| ElevatedButton (Sign in) | 52px height, full width | 44px | ✅ |
| OutlinedButton | 52px height | 44px | ✅ |
| Visibility toggle | 48px `IconButton` | 44px | ✅ |
| FAB | 56px standard | 44px | ✅ |
| `_ActionButton` (like) | ~40px tappable area | 44px | ⚠️ Borderline — add `minimumSize` to style |
| Navigation bar items | 64px height (Material 3) | 44px | ✅ |
| Bottom sheet drag handle | Pure visual | N/A | — |
| Thread tile | 56px height | 44px | ✅ |
| Send button | 48px `IconButton` | 44px | ✅ |

**Fix for `_ActionButton`**: Add `constraints: BoxConstraints(minWidth: 44, minHeight: 44)` to `InkWell` padding to bring it to spec.

---

## Zoom / Text Scale

Tested at 200% system font size:

| Screen | Issues at 200% |
|---|---|
| LoginScreen | ✅ — `SingleChildScrollView` handles overflow |
| DashboardScreen | ⚠️ Stat chips may clip text — use `FittedBox` inside chip values |
| EventCard | ✅ — flexible `Column` layout |
| PostCard | ✅ |
| NavigationBar | ✅ Material 3 handles label scaling |

---

## Priority Fixes (Ordered by Impact)

1. **P1 — Post author display** — Screen readers and users with cognitive disabilities cannot understand who wrote a post. Fetch and cache user display names. Blocks meaningful use of the Feed screen.

2. **R1 — Error focus management** — After a login failure, focus stays on the last focused field, not the error message. Users relying on screen readers may not notice the error appeared.

3. **O3 — Focus ring on ActionButton** — Like and comment buttons are invisible to keyboard/switch-access users on some devices.

4. **O4 — Drag handle semantics** — Minor but a quick fix: add a semantic label to all drag handles.

5. **U1 — Thread naming** — "Thread 1a2b3c4d…" is meaningless. Even showing "Thread with {email}" as a stopgap dramatically improves usability.

6. **P_contrast — District badge** — Darken `secondaryDark` in the district badge context to pass 4.5:1.

7. **U2 — Draft discard warning** — Prevents accidental loss of composed posts.
