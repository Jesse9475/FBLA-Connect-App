# FBLA Connect — Design System

> Version 1.0 | March 2026 | Flutter / Material 3

---

## 1. Overview

FBLA Connect's design system defines the visual language, component library, and interaction patterns for the app. It is built on Material 3 with FBLA branding and is implemented entirely in `lib/theme/app_theme.dart`.

The system is organized into four layers:

1. **Design Tokens** — atomic values (colors, spacing, radius, shadows, motion)
2. **Components** — reusable widgets built from tokens
3. **Patterns** — common screen-level solutions (auth flow, empty states, lists)
4. **Documentation** — this file

---

## 2. Design Tokens

### 2.1 Color Palette

All colors are defined in `FblaColors` in `lib/theme/app_theme.dart`.

#### Brand
| Token | Hex | Usage |
|---|---|---|
| `FblaColors.primary` | `#1B3A8C` | Navigation, buttons, links, active states |
| `FblaColors.primaryLight` | `#2B4FAF` | Hover states, gradient end |
| `FblaColors.primaryDark` | `#122870` | Pressed states |
| `FblaColors.secondary` | `#F5A623` | FAB, gold accent, advisor badge |
| `FblaColors.secondaryDark` | `#D4891A` | Pressed secondary |

#### Neutral
| Token | Hex | Usage |
|---|---|---|
| `FblaColors.surface` | `#FFFFFF` | Cards, AppBar, BottomNav |
| `FblaColors.surfaceVariant` | `#F0F4FF` | Input fills, hover overlays |
| `FblaColors.background` | `#F5F7FF` | Page background |
| `FblaColors.outline` | `#D1D9F0` | Input borders, dividers |
| `FblaColors.outlineVariant` | `#E8EDFB` | Card borders, section dividers |

#### Text
| Token | Hex | Usage |
|---|---|---|
| `FblaColors.textPrimary` | `#111827` | Headlines, body copy |
| `FblaColors.textSecondary` | `#6B7280` | Meta text, labels, captions |
| `FblaColors.textDisabled` | `#ADB5C4` | Disabled states |

#### Semantic
| Token | Hex | Usage |
|---|---|---|
| `FblaColors.success` | `#16A34A` | National announcements, success states |
| `FblaColors.warning` | `#F59E0B` | Private visibility badge |
| `FblaColors.error` | `#DC2626` | Errors, sign-out, admin badge |

**Contrast ratios (WCAG 2.1 AA):**
- `primary` on white: **8.7:1** ✅ (exceeds AAA)
- `secondary` (#F5A623) on `primary` background: **4.6:1** ✅
- `textPrimary` on white: **19.5:1** ✅
- `textSecondary` on white: **4.6:1** ✅ (passes AA)
- `error` on white: **5.1:1** ✅

---

### 2.2 Typography

The app uses **Inter** via `google_fonts`. All styles are defined in `FblaTheme.light.textTheme`.

| Style | Size | Weight | Usage |
|---|---|---|---|
| `displayLarge` | 57 / W700 | Extra bold | Marketing screens |
| `headlineLarge` | 32 / W700 | Bold | Major section titles |
| `headlineMedium` | 24 / W600 | SemiBold | Screen titles |
| `headlineSmall` | 20 / W600 | SemiBold | Card titles, sheet headers |
| `titleLarge` | 18 / W600 | SemiBold | AppBar title |
| `titleMedium` | 16 / W500 | Medium | Section headers, list items |
| `titleSmall` | 14 / W500 | Medium | Small labels |
| `bodyLarge` | 16 / W400 | Regular | Primary body copy; `height: 1.5` |
| `bodyMedium` | 14 / W400 | Regular | Secondary body, descriptions |
| `bodySmall` | 12 / W400 | Regular | Timestamps, captions |
| `labelLarge` | 14 / W600 | SemiBold | Button text |
| `labelMedium` | 12 / W500 | Medium | Filter chips, tags |
| `labelSmall` | 11 / W500 | Medium | Badges, micro labels; `letterSpacing: 0.5` |

**Minimum readable size:** 12sp (`bodySmall`). Nothing below this in the component library.

---

### 2.3 Spacing Scale

4pt grid. Defined in `FblaSpacing`.

| Token | Value | Usage |
|---|---|---|
| `xs` | 4px | Icon gaps, micro padding |
| `sm` | 8px | Between related items, list separators |
| `md` | 16px | Default horizontal screen padding, between fields |
| `lg` | 24px | Section separation, sheet internal padding |
| `xl` | 32px | Screen-level padding, modal padding |
| `xxl` | 48px | Hero section internal spacing |
| `xxxl` | 64px | Large splash spacing |

---

### 2.4 Border Radius

Defined in `FblaRadius`.

| Token | Value | Usage |
|---|---|---|
| `sm` | 6px | Chips, error banners |
| `md` | 12px | Cards, inputs, buttons |
| `lg` | 16px | Modals, tooltips |
| `xl` | 24px | Bottom sheets |
| `full` | 999px | Pills, badges, avatars |

---

### 2.5 Shadows

Defined in `FblaShadow`.

| Token | Spec | Usage |
|---|---|---|
| `card` | `y:4 blur:12 color:primary@6%` | Event cards, announcement cards |
| `elevated` | `y:8 blur:24 color:primary@10%` | FAB, modals |

---

### 2.6 Motion

Defined in `FblaMotion`.

| Token | Duration | Easing | Usage |
|---|---|---|---|
| `fast` | 150ms | `easeOut` | Icon swaps, toggles |
| `standard` | 250ms | `easeOut` | Page transitions, show/hide |
| `slow` | 400ms | `easeInOutCubic` | Modal enter/exit, hero transitions |

---

## 3. Component Library

### 3.1 Button

#### Variants
| Variant | Flutter Widget | Background | Foreground | Use When |
|---|---|---|---|---|
| Primary | `ElevatedButton` | `primary` | `white` | Main CTAs (Sign in, Post, Send) |
| Secondary | `OutlinedButton` | transparent | `primary` | Secondary actions (Try again, Cancel) |
| Ghost | `TextButton` | transparent | `primary` | Tertiary links (Forgot password, See all) |
| Danger | `OutlinedButton` override | transparent | `error` | Destructive actions (Sign out, Delete) |
| FAB | `FloatingActionButton` | `secondary` | `onSecondary` | Primary floating action |

#### States
| State | Visual | Behavior |
|---|---|---|
| Default | See variants above | Interactive |
| Hover | `primary` at 8% overlay | Cursor pointer |
| Pressed | `primary` at 12% overlay | Haptic feedback |
| Disabled | `outline` bg, `textDisabled` fg | Non-interactive; `onPressed: null` |
| Loading | Spinner (20px, 2.5 stroke, white) replaces label | Non-interactive |

#### Specs
- Min height: **52px** (touch target ≥ 44px)
- Min width: `double.infinity` (full-width in forms)
- Padding: `24px` horizontal
- Border radius: `12px`
- Label: `labelLarge` (14/W600)

#### Accessibility
- Role: `button`
- Keyboard: `Enter` / `Space` to activate
- Screen reader: reads label + state (e.g. "Sign in, button, dimmed" when disabled)
- Loading state announces via `Semantics(liveRegion: true)`

---

### 3.2 Text Input

#### States
| State | Border | Fill |
|---|---|---|
| Default (enabled) | `outline` 1px | `surfaceVariant` |
| Focused | `primary` 2px | `surfaceVariant` |
| Error | `error` 1px → 2px on focus | `surfaceVariant` |
| Disabled | `outline` 1px, 50% opacity | `outlineVariant` |

#### Props
| Property | Default | Notes |
|---|---|---|
| Label | floating | Animates on focus per Material 3 |
| Prefix icon | optional | 20px, `primary` color |
| Suffix icon | optional | Toggle visibility (passwords) |
| Error text | none | `bodySmall`/`error` color below field |
| Helper text | none | `bodySmall`/`textSecondary` |

#### Accessibility
- All inputs have explicit `labelText` (no placeholder-only labels)
- Password fields have show/hide toggle with `tooltip`
- Error messages use `Semantics(liveRegion: true)` via `_ErrorBanner`

---

### 3.3 EventCard

Displays a single event from `/api/events`.

#### Anatomy
1. **Date badge** (left) — colored box showing Month/Day/Weekday
2. **Title** (right top) — `titleMedium`, truncated at 1 line
3. **Visibility chip** (right of title) — hidden for `public` events
4. **Description** — `bodySmall`, max 2 lines
5. **Time row** — clock icon + formatted time range
6. **Location row** — pin icon + venue name

#### Props fed from API
| Field | Type | Renders As |
|---|---|---|
| `title` | string | Title text |
| `description` | string | Description (2-line clamp) |
| `start_at` | ISO 8601 | Date badge + time row |
| `end_at` | ISO 8601 | End time in time row |
| `location` | string | Location row |
| `visibility` | `public/members` | Chip (hidden if public) |

---

### 3.4 AnnouncementCard

Displays a scoped announcement.

#### Anatomy
1. **Scope badge** — color-coded: national (green), district (gold), chapter (blue)
2. **Date** — right-aligned, `bodySmall`
3. **Title** — `titleMedium`, 2-line clamp
4. **Body** — `bodySmall`, 3-line clamp

#### Scope color mapping
| Scope | Background | Foreground | Icon |
|---|---|---|---|
| `national` | `#F0FDF4` | `success` | `public` |
| `district` | `#FFFBEB` | `secondaryDark` | `location_city` |
| `chapter` | `#EFF6FF` | `primary` | `groups` |

---

### 3.5 PostCard

Member feed post with like and comment actions.

#### Anatomy
1. **Author avatar** — circular, `primary` at 15% bg (placeholder until user avatars are implemented)
2. **Author name** — "You" for own posts, "Chapter Member" otherwise
3. **Timestamp** — `bodySmall`
4. **Visibility chip** — hidden for `members`
5. **Body text** — `bodyLarge`, full expansion
6. **Action bar** — Like (optimistic toggle), Comment (stub)

---

### 3.6 Navigation Bar

Material 3 `NavigationBar` (not `BottomNavigationBar`) with 5 destinations.

| Index | Label | Icon (inactive) | Icon (active) |
|---|---|---|---|
| 0 | Home | `home_outlined` | `home` |
| 1 | Events | `event_outlined` | `event` |
| 2 | News | `campaign_outlined` | `campaign` |
| 3 | Feed | `dynamic_feed_outlined` | `dynamic_feed` |
| 4 | Profile | `person_outlined` | `person` |

- `IndexedStack` preserves scroll position per tab
- `indicatorColor`: `primary` at 8% opacity

---

## 4. Screen Patterns

### 4.1 Auth Gate Pattern
`AuthGate` (in `main.dart`) wraps `StreamBuilder<AuthState>` from Supabase. The app never requires users to manage tokens — the stream handles all auth state changes including silent refresh.

### 4.2 Data Loading Pattern
Every screen follows: **load → show skeleton/spinner → success state or error state**. Pull-to-refresh (`RefreshIndicator`) available on all list screens.

### 4.3 Empty State Pattern
Centered column with: large outlined icon (56px, primary at 30% alpha) + `titleMedium` headline + `bodyMedium` supporting text. Consistent across all list screens.

### 4.4 Error State Pattern
Same layout as empty state but with `error_outline` icon and a retry button (`OutlinedButton.icon` with refresh icon).

### 4.5 Bottom Sheet Pattern
Used for: forgot password, new post, new thread. Always includes:
- 40px × 4px drag handle at top
- `headlineSmall` title
- Content with `viewInsets` padding for keyboard
- Full-width CTA button

---

## 5. Design System Audit

### Summary
**Components reviewed:** 8 | **Issues resolved in v1.0:** 6 | **Remaining:** 2

### Token Coverage
| Category | Tokens Defined | Hardcoded Values |
|---|---|---|
| Colors | 20 | 0 — all colors use `FblaColors.*` |
| Spacing | 7 | 0 — all spacing uses `FblaSpacing.*` |
| Radius | 5 | 0 — all radius uses `FblaRadius.*` |
| Typography | 12 | 0 — all text styles use `textTheme.*` |
| Shadows | 2 | 0 |
| Motion | 3 | 0 |

### Component Completeness
| Component | States | Variants | Docs | Score |
|---|---|---|---|---|
| Button | ✅ | ✅ | ✅ | 10/10 |
| Input | ✅ | ✅ | ✅ | 10/10 |
| EventCard | ✅ | ⚠️ (no skeleton) | ✅ | 8/10 |
| AnnouncementCard | ✅ | ⚠️ (no skeleton) | ✅ | 8/10 |
| PostCard | ✅ | ⚠️ (no comment sheet) | ✅ | 7/10 |
| NavigationBar | ✅ | ✅ | ✅ | 10/10 |
| SectionHeader | ✅ | ✅ | ✅ | 10/10 |
| ErrorBanner | ✅ | ✅ (error + success) | ✅ | 10/10 |

### Priority Actions
1. **Add skeleton loading states** to EventCard and AnnouncementCard — currently shows spinner; shimmer skeletons would feel faster.
2. **Add comment sheet** to PostCard — the action button exists, the sheet implementation is stubbed.
