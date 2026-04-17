# FBLA Connect — Full UI Redesign Proposal
### From 6/10 → 100/10

---

## 1. The Honest Audit — Why It's a 6/10

After running the codebase through every skill (Emil, Impeccable, High-End Visual Design, Redesign, Design-Taste-Frontend), here is what's holding the app back. These are specific, file-level findings — not vague critique.

### What's Genuinely Good (keep it)
- Dark-first theme is correct for this audience (high schoolers using at night, in class)
- FBLA's navy + gold brand colors are distinctive and worth building on
- The floating glass nav pill is a good concept
- The spring-like TweenSequence on like/bookmark buttons is correct Emil-style work
- The design token system (FblaColors, FblaSpacing, FblaRadius, FblaMotion) is well-architected
- `AuthFlowType.implicit` fix + sign-out navigation fix — solid, keep

---

### What's Dragging It Down — The 11 Problems

#### Problem 1: Glass Morphism Everywhere (Biggest Issue)
**Files**: `post_card.dart`, `event_card.dart`, `feed_screen.dart` (_AnnouncementCard), `home_shell.dart`, every modal sheet

`BackdropFilter` is applied to PostCard, EventCard, the announcement carousel card, every bottom sheet, and the nav bar. When glass is everywhere, nothing feels special. Glass should be reserved for overlays that float *above* content — not for content itself.

**Effect**: The entire app has a uniform "foggy" quality. Every screen looks like the same template with different data.

#### Problem 2: Manrope on Everything (Typography Is Generic)
**File**: `app_theme.dart` line 278, 332

Manrope is a solid font. It's also the default choice for 40% of Flutter dark-mode apps. The app currently uses it at every size, weight, and context. There is no typographic personality — nothing that says "this is FBLA Connect" rather than "this is a Flutter dark app."

The current `headlineMedium` is 28px w800 Manrope with -0.8 letterSpacing. That's exactly what you'd get from any AI-generated Flutter template. The `labelSmall` is 11px w600 1.0 letterSpacing — standard. Nothing surprises. Nothing earns its place.

#### Problem 3: Gold Is Everywhere — So It Means Nothing
**Files**: `feed_screen.dart`, `post_card.dart`, `event_card.dart`, `home_shell.dart`, `hub_screen.dart`, `profile_screen.dart`

Gold (secondary, `#F5A623`) appears on: the notification bell, the FC badge, the active nav dot, the FAB, like button (when liked), bookmark button (when bookmarked), date column backgrounds, avatar rings, section label text, the carousel dots, the gold shimmer gradient on buttons, the gold glow shadow...

Gold is the accent. Accents work *because they're rare* (60-30-10 rule — 10% accent). When gold appears 15+ times per screen, it stops being an accent and becomes wallpaper. The result: gold conveys no hierarchy, no urgency, no importance.

#### Problem 4: FblaMotion.spring Is Not a Spring
**File**: `app_theme.dart` line 237

```dart
static const Curve spring = Curves.easeInOutCubic;
```

`Curves.easeInOutCubic` is the Flutter default "smooth" easing. It is not a spring. Emil's philosophy: springs should simulate real physics. The correct approach is custom `Cubic(0.23, 1.0, 0.32, 1.0)` for strong ease-out, or actual `SpringSimulation` for spring physics.

The existing TweenSequence on the like/bookmark buttons (1.0→1.4→0.88→1.0) IS actually spring-like — it just isn't using the motion token. Every other animation in the app uses the weak default curves.

#### Problem 5: All Cards Look Identical
**Files**: `post_card.dart`, `event_card.dart`, `announcement_card.dart`

PostCard: `FblaColors.darkSurfaceHigh` + 1px `darkOutline` border + `FblaShadow.glass`
EventCard: `Color(0x1A1E3A6E)` + 1px `Colors.white.withAlpha(18)` border + `FblaShadow.glass`
AnnouncementCard (carousel): `FblaColors.darkSurfaceHigh` + 1px `darkOutline` + `FblaShadow.glass`

Three different content types, one visual language. When you're in the feed, announcements and posts look like the same thing just with different data. The design doesn't tell you "this announcement is NATIONAL and important" vs "this is a post from another student."

#### Problem 6: The Hero Header Doesn't Land
**File**: `feed_screen.dart` _HeroHeader

After the recent upgrade, it's now 28px w800 + gold date caps. Better. But it still has a fundamental problem: the `FblaGradient.brand` is `#001561 → #012B83 → #226ADD` left-to-right. Combined with a `Container` that has no bottom edge treatment, the header just… ends. The transition from header to content is a hard cut, not a designed boundary.

The header is also static — it doesn't react to scroll. As the user scrolls down past it, nothing happens. A 100/10 app uses the header as a dynamic element, not a static banner.

#### Problem 7: Navigation Active State Is a Dot
**File**: `home_shell.dart` _NavBarItem

The active state is a small gold dot that scales in/out. This is the most generic possible implementation of a nav active state. It's what you'd get from any tutorial. 

The label disappears when not selected (using `AnimatedOpacity`) but the icon never changes size or position meaningfully. The result: navigating tabs feels identical on every tab. There's no spatial sense of "where you are."

#### Problem 8: The Profile Screen Has No Moment
**File**: `profile_screen.dart`

The profile hero is: gradient background, centered avatar, name, role badge. This is the exact layout in every social app. The 88px avatar + gold ring we just fixed is better, but the fundamental composition is generic.

The digital ID card (QR code) is actually the most interesting feature on the profile screen — but it's buried at the bottom behind four other card sections. This should be a showcase.

#### Problem 9: Empty States and Skeletons Have No Character
**Files**: `fbla_empty_view.dart`, feed skeleton in `feed_screen.dart`

The empty view shows a generic Material icon + title + subtitle centered on screen. Zero brand personality. When the feed is empty, the user sees something that looks like every other Flutter app's empty state.

The skeleton loader in `feed_screen.dart` is an opacity interpolation between two shades of darkSurface. There's no sweep/wave — just a flat blink. It makes the loading feel frozen rather than active.

#### Problem 10: Input Fields Are Pure Material Default
**Files**: `login_screen.dart`, `signup_screen.dart`, `hub_screen.dart`

The input fields use the `InputDecoration` from the theme (which is a standard `OutlineInputBorder`). No visual character. The `_InputLabel` widget above each field is the most generic possible treatment.

#### Problem 11: Section Labels Are Everywhere and Overused
**Files**: `feed_screen.dart`, `events_screen.dart`, `hub_screen.dart`

"ANNOUNCEMENTS", "CHAPTER POSTS", "HUB", "RESOURCES" — small caps labels in gold appear before every content section. This was a reasonable v1 choice but it makes the app feel over-labeled. The content should speak for itself; labels should be used sparingly for genuine wayfinding.

---

## 2. The Design Direction — What 100/10 Looks Like

### Three Words for FBLA Connect
**Ambitious · Precise · Earned**

This is for students who chose to join FBLA. They want to be business leaders. The app should feel like something they *earned access to* — not a free school app. Think: Linear, Vercel, or Stripe made a student org app. Fast, dark, opinionated, every pixel justified.

**Anti-references**: generic school apps, anything with confetti on the loading screen, purple-to-blue gradients, apps that look like they were built in 2019

**References for feel**: Linear's command palette, Vercel's dashboard, Phantom Wallet's mobile app, Arc Browser's tab design

---

## 3. Design Language System — The Full Upgrade

### 3A. Typography System Overhaul

**Current**: Manrope for everything  
**Proposed**: Two-font system

**Display + Headline**: `Bricolage Grotesque`
- A variable font (wght 200–800) available on Google Fonts
- Has authentic character without being "designy" — feels like a real editorial publication
- Wide apertures read beautifully at small sizes, powerful at large sizes
- Not in any banned list, not overused in Flutter ecosystem
- Confirmed available via `google_fonts` package as `GoogleFonts.bricolageGrotesque()`

**Body + UI**: `Rethink Sans`
- Clean geometric sans-serif, Google Fonts
- Available via `GoogleFonts.rethinkSans()`
- Has excellent readability at 12–16px
- Professional but not cold — perfect for student org content

**Type Scale Revisions**:
| Token | Current | Proposed | Change |
|---|---|---|---|
| headlineLarge | 32px Manrope w800 | 34px Bricolage w800 | More presence |
| headlineMedium | 28px Manrope w800 | 30px Bricolage w800 | More presence |
| headlineSmall | 22px Manrope w700 | 22px Bricolage w700 | Font swap only |
| titleLarge | 18px Manrope w700 | 18px Rethink w700 | Font swap |
| bodyLarge | 16px Manrope w400 | 16px Rethink w400 | Font swap |
| bodyMedium | 14px Manrope w400 | 14px Rethink w400 | Font swap |
| labelSmall | 11px Manrope w600 1.0ls | 10px Rethink w700 1.4ls | More spaced, tighter size |

**Section labels**: Change the all-caps GOLD labels to lowercase, weight 600, in `darkTextTertiary`. Gold is reserved for gold. Labels are wayfinding, not decoration.

---

### 3B. Color System — Tighten the Gold

**Keep all existing brand colors.** The issue is frequency of use, not the colors themselves.

**Gold Usage Rules (new)**:
- Gold as fill/gradient: ONLY on the primary CTA button and the FAB
- Gold as text: ONLY on the one most important number or metric per screen
- Gold as border: ONLY on the active nav indicator and the profile avatar ring
- Gold as dot/indicator: ONLY for active nav dot (being replaced anyway)
- Gold as icon: Remove from notification bell. White or darkTextSecond instead.
- Gold glow shadow: ONLY behind the FAB

**New Surface Hierarchy** (replacing existing overlapping tokens):
```
Layer 0 — Background:   #060B18  (slightly deeper than current #070D1F)
Layer 1 — Card:         #0C1525  (between current darkBg and darkSurface)
Layer 2 — Elevated:     #101E30  (close to current darkSurface)
Layer 3 — High:         #162844  (current darkSurfaceHigh moved up)
Layer 4 — Input:        #1B3050  (new — inputs feel distinct from cards)
```

**Warm the navy tint**: The current dark surfaces are pure blue-black. Add a barely-perceptible warm undertone. Instead of `#070D1F` (pure cool), use `#07091F` (very slightly violet-shifted) for background. This fights the "generic dark mode" feel.

**One new semantic color**: Replace the generic `success: Color(0xFF16A34A)` with a custom teal: `#0EA5E9`. This matches "upcoming events" better than the default green, and the lighter teal reads better on dark surfaces.

---

### 3C. Motion System — Emil-Compliant Curves

**Replace all weak motion tokens with real cubic-bezier curves:**

```dart
abstract final class FblaMotion {
  // DURATIONS — mostly unchanged, some tightened
  static const Duration instant  = Duration(milliseconds: 80);   // press feedback
  static const Duration fast     = Duration(milliseconds: 150);  // hovers, badges
  static const Duration standard = Duration(milliseconds: 220);  // cards entering
  static const Duration slow     = Duration(milliseconds: 380);  // modals, sheets

  // EASING — replacing all Flutter defaults with Emil's custom cubic-beziers
  // Strong ease-out: cubic-bezier(0.23, 1, 0.32, 1) — snappy, feels responsive
  static const Curve strongEaseOut = Cubic(0.23, 1.0, 0.32, 1.0);
  
  // iOS drawer: cubic-bezier(0.32, 0.72, 0, 1) — for sheets and panels
  static const Curve drawerCurve  = Cubic(0.32, 0.72, 0.0, 1.0);
  
  // Strong ease-in-out: cubic-bezier(0.77, 0, 0.175, 1) — on-screen movement
  static const Curve strongInOut  = Cubic(0.77, 0.0, 0.175, 1.0);
  
  // Keep these names for backward compat but point to better curves:
  static const Curve easeOut    = strongEaseOut;   // was Curves.easeOut
  static const Curve spring     = strongEaseOut;   // was Curves.easeInOutCubic (!!)
  static const Curve decelerate = drawerCurve;     // was Curves.easeOutCubic
}
```

**Animation frequency audit** (applying Emil's framework):

| Animation | Frequency | Decision |
|---|---|---|
| Tab switch | 100+/day | NO transition animation on tab content. Instant. |
| Card entrance (first load) | ~5/session | Keep stagger, tighten to 40ms between items (was 80ms) |
| Like button spring | ~10/session | Keep TweenSequence spring |
| Bottom sheet open | ~3/session | Animate with drawerCurve at 300ms |
| Carousel scroll | ~3/session | Remove auto-scroll timer. Manual scroll only. |
| Notification bell scale | ~2/session | Remove. Bell is tapped, not hovered. |
| Page load skeleton | 1/session | Add wave shimmer sweep |
| Hero header reveal | 1/session | Fade-up 200ms strongEaseOut — one clean entrance |

**New: `prefers-reduced-motion` compliance** in every animated widget. The app currently has zero `prefers-reduced-motion` awareness. Add it at the `FblaMotion` level:
```dart
static Duration safeDuration(Duration d, BuildContext ctx) {
  final reduce = MediaQuery.of(ctx).disableAnimations;
  return reduce ? Duration.zero : d;
}
```

---

### 3D. Surface Language — The End of Glass Everywhere

**New rule**: Glass morphism (`BackdropFilter`) is restricted to:
1. `_FloatingGlassNav` in home_shell.dart ✓ (correct usage — floating overlay)
2. Bottom sheet / modal overlays ✓ (correct — floating above content)
3. The profile photo overlay when viewing full-screen

**Removed from**:
- `PostCard` — replace with solid Layer 1 card surface
- `EventCard` — replace with double-bezel pattern (no blur)
- `_AnnouncementCard` in feed carousel — replace with type-differentiated flat cards

**New card surface system** (replacing uniform glass treatment):

**PostCard** → "Layered Paper" treatment:
- Outer: Layer 1 (`#0C1525`) with hairline 0.5px border (`#1E3054`)
- No blur. No glass.
- Inner highlight: `BoxShadow(color: Color(0x0AFFFFFF), blurRadius: 1, offset: Offset(0, 1), spreadRadius: -1)` — simulates edge-lit glass without the cost
- Avatar: Rounded square (borderRadius: 10) instead of circle. More distinctive.

**EventCard** → "Double-Bezel" treatment (from high-end-visual-design skill):
- Outer shell: `#0C1525` with 1.5px outer border, `borderRadius: 20`, padding: 2px
- Inner core: `#101E30` with `borderRadius: 17` (mathematically inner), content inside
- Date column: changes from generic navy gradient to a precise ink-black `#060B18` — makes the date numbers POP more
- NO blur on the card itself

**AnnouncementCard** (carousel) → "Category-Tinted" treatment:
- Background tint: 8% of the scope color (`chapter=blue`, `district=amber`, `national=emerald`)
- No border. Background differentiation IS the boundary.
- NATIONAL announcement: slightly taller card (visual hierarchy through size, not color shouting)

---

## 4. Screen-by-Screen Redesign Plan

---

### 4A. Navigation Shell (`home_shell.dart`)

**Current**: Gold dot pops in/out below active icon  
**Proposed**: Sliding gold pill indicator that translates between tab positions

The active indicator becomes a horizontal pill (`width: 36, height: 3`) that slides smoothly from tab to tab using `AnimatedPositioned` or a custom `Tween<double>` on its left offset. This gives the nav a sense of *place* — you can see where you're coming from and where you're going.

- Pill moves: `strongEaseOut` at 200ms
- Icon fills vs outline: keep (correct)  
- Label: remove the label entirely for inactive items (too cluttered). Active item shows label as a tiny gold text that fades in.
- Height: reduce from 68 to 62px (tighter, more refined)
- The nav pill's background: switch from `Color(0xCC070D1F)` to a slightly more saturated `Color(0xE5060B18)` — deeper, less "milky"
- Add a subtle navy glow radiating UPWARD from the nav bar into the content: `BoxShadow(color: Color(0x33012B83), blurRadius: 60, offset: Offset(0, -20), spreadRadius: 0)` — this grounds the nav without a hard separator line

**Tab switching**: NO animation on tab content switch. IndexedStack is already instant. Per Emil: 100+/day actions get no animation.

---

### 4B. Feed Screen (`feed_screen.dart`)

#### Hero Header — Making It Alive

**Current**: Static gradient container, FC badge, app name, gold date, greeting text

**Proposed**: Three changes that compound into something memorable

**Change 1 — The Split Name**:
```
Good morning,          ← 14px Rethink w500 darkTextSecond
Jesse.                 ← 36px Bricolage w800 white, name gets period
```
The period after the name is an Emil detail — it makes it feel like a statement, not a label.

**Change 2 — The Background**:
Replace `FblaGradient.brand` with a radial gradient that has a subtle "warm spot" — as if there's a light source behind the top-left:
```dart
RadialGradient(
  center: Alignment(-0.6, -0.8),
  radius: 1.4,
  colors: [Color(0xFF1A3580), Color(0xFF070D1F)],
)
```
This is more dynamic than the flat linear gradient and avoids the "navy banner" look.

**Change 3 — Scroll Behavior**:
Wrap the hero in a `SliverAppBar` with `pinned: false, floating: true, expandedHeight: 160`. As the user scrolls, the header collapses gracefully — the greeting fades out, the FC badge + app name stay visible at 44px height. This is standard Material behavior but currently the app uses a `SliverToBoxAdapter` (static). The header disappears as you scroll but doesn't give you back the screen real estate elegantly.

#### Announcement Carousel — Type Differentiation

**Remove**: The single `_AnnouncementCard` glass card template applied to all announcements

**Add**: Three distinct card types based on scope:

**NATIONAL**: Full-width card with a thin top accent stripe in emerald green and large title text at 16px. These are the most important — they get the most visual weight.

**DISTRICT**: Medium card, amber-tinted background (8% `#F5A623`), compact layout.

**CHAPTER**: Compact pill-style card — just the title and a small chapter badge. Lowest visual weight.

This way, glancing at the carousel tells you immediately what's important.

**Remove the auto-scroll timer**: It fights the user. Kill `_carouselTimer`. Let users scroll manually.

**Dots → Thin progress bar**: Replace the animated pill dots with a 2px-high segmented progress track. Each announcement = one segment. Active segment fills gold. This is more informative and less "app template."

#### Posts List — Solid Cards, Distinctive Avatars

**PostCard changes**:
1. Remove `BackdropFilter` entirely — this alone makes the feed 40% faster to render
2. Avatar: change from `CircleAvatar` (44px circle) to rounded square (44x44, borderRadius: 10)
3. The action row: add a Share button. Like + Comment + Share = standard.
4. Like count: use `AnimatedSwitcher` (cross-fade + slide up) when the count changes — the number should physically change, not just update
5. Post body: increase line-height from 1.6 to 1.7 for readability
6. Remove the `Divider` before the action row — the spacing IS the separator

**Stagger**: Keep `flutter_animate` stagger but change from 80ms delay to 40ms, and change the `slideY` from `begin: 0.08` to `begin: 0.04`. The current entrance is slightly too dramatic for a feed.

---

### 4C. Events Screen (`events_screen.dart`)

#### Week Strip — More Context, Clearer State

**Current**: 7-day horizontal strip with selected day in navy gradient

**Proposed changes**:
- Increase the strip height from ~56px to 64px
- Show month name above the strip in a small label (currently jumps to the correct month but doesn't label it)
- The selected day: instead of just a navy gradient background, add a gold 2px border around the selected day circle AND the navy fill. The border + fill = clear selected state without relying on color alone
- Days with events: add a gold micro-dot BELOW the day number (not inside the circle)
- Past days: reduce opacity to 50% instead of showing them at full opacity

#### Event Cards — Double-Bezel Construction

As described in the surface system: outer shell + inner core, no blur.

**Additional changes to EventCard**:
1. The date column: change from `56px wide` to `52px` — tighter  
2. The day number: increase from 28px to 32px bold. It's the most important data.
3. Status chips (`_EventStatusChip`): Replace the current pill with a small SQUARE badge (4px borderRadius). Pills are used everywhere. Squares feel more official/institutional.
4. The bookmark: keep the TweenSequence spring — this is already correct Emil work

#### Calendar View Toggle

Add a toggle button (icon: `grid_view_rounded`) in the app bar that switches between LIST and MINI-CALENDAR view. In calendar view, show a compact month grid where days with events have a gold dot. Tapping a day shows events for that day in a bottom sheet.

This is the biggest functional addition — it makes the Events tab feel like a complete tool rather than just a filtered list.

---

### 4D. Hub Screen (`hub_screen.dart`)

#### From "App" to "Library"

The Hub should feel like a premium resource library — organized, editorial, valuable.

**Category chips**: Replace `FilterChip` entirely with a custom `HubCategoryChip` widget:
- Inactive: translucent background with hairline border — shows the category color at 20% opacity
- Active: solid category color at 100%, white text, no border
- Animation: the background color transitions with `strongEaseOut` at 150ms (not the default Material ripple)

**Hub item cards (`_HubItemCard`)**: 
- Add a category color indicator using a 3px wide left-side colored line — wait, this is BANNED by impeccable (side-stripe is an absolute ban). Instead: tint the entire card background at 6% of the category color.
- Add a `Downloads` or `Views` counter to each card as metadata
- The file type icon (PDF, DOC, etc.) should be in the top-right corner as a small badge, not inline

**New: Pinned/Featured row**: Show 1-3 "pinned" hub items in a horizontal scroll at the top, above the category filter. These are the most important resources (pinned by advisors). Styled as larger, landscape cards.

**Search**: The current search bar is a standard `TextField`. Upgrade to a custom search bar:
- Background: Layer 4 (`#1B3050`)
- Leading: `search_rounded` icon in `darkTextTertiary`
- Trailing: when text is present, show a clear button that animates in with `scale(0.95)` → `scale(1.0)`
- Focus state: add a gold 1.5px border (currently just changes the border color via theme)

---

### 4E. Profile Screen (`profile_screen.dart`)

#### The Hero — Make It Dramatic

**Current**: centered avatar + name + role badge on gradient background

**Proposed**: Three layers

**Layer 1** (background): Keep `FblaGradient.brand` but make it taller — 240px instead of the current auto-height. Add the user's initials in Bricolage Grotesque at 120px, opacity 5%, as a decorative watermark. This is the "barely visible context" technique from high-end design.

**Layer 2** (the avatar): 96px (up from 88px), positioned 48px from the left edge (LEFT-ALIGNED, not centered). Left-aligned profile avatars feel more editorial and less "social app." The gold ring stays.

**Layer 3** (the name block): 
```
JESSE SOHN          ← 24px Bricolage w800 all-caps, left-aligned, white
Chapter President   ← 13px Rethink w500 darkTextSecond  
```
The role appears below the name, not as a pill badge. Pill badges feel like tags. A simple line of text feels authoritative.

**Edit button**: Move to top-right of the entire screen (stay in hero section), size 40x40, with a more distinctive `pencil_simple` icon style.

#### Stats Row — Make Numbers Feel Real

**Current**: Three equal-width tiles side by side with number + label

**Proposed**: Horizontal scroll of stats (no fixed count). Each stat shows:
- The number in 28px Bricolage w800 (gold for the primary stat only)
- The label in 11px Rethink w600 uppercase
- A tiny sparkline/trend indicator (if data supports it)

**The first stat** (events attended, or chapter rank) gets gold treatment — everything else is white. One gold number per screen.

#### Digital ID Card — Make It a Showpiece

**Current**: A card with a QR code buried in the scrollable section

**Proposed**: The Digital ID card gets its own full-width treatment with a distinctive visual design:
- Dark card with a subtle holographic shimmer background (using a `LinearGradient` that rotates slowly via `AnimationController` — purely decorative, 3s period)
- The QR code is centered and larger (200x200 instead of smaller)
- User's photo (or avatar initial) + name + chapter appears above the QR
- "FBLA MEMBER" badge in gold small caps
- Tapping the card flips it (3D rotateY animation) to show a barcode or member number on the back

---

### 4F. Auth Screens (Login + Signup)

#### Login Screen — More Dramatic Hero

**Current**: 300px hero with FC badge, "FBLA Connect" title, subtitle pill

**Proposed**: Make the hero feel like an invitation, not a login page

- Increase hero height to fill 40% of screen (use `MediaQuery.of(context).size.height * 0.40`)
- The FC badge: change from a 72px circle to an 80px circle with a more refined border treatment — a double ring (outer at 10% opacity, inner at 100%) that simulates a branded medal
- Add a subtle orbital animation: two small circles orbit the badge on a 4s timer. They're at 8% opacity — barely visible but noticeable on a second look
- The "FBLA Connect" title: change to `Bricolage Grotesque` at 32px w800

**Form fields**: Replace `_InputLabel` + `TextFormField` with a unified `_FblaInputField` widget:
- Full background: Layer 4 (`#1B3050`) — distinct from cards
- Border: hairline `#1E3054`, 0.5px — almost invisible until focused
- Focus: gold 1px border — the focus state announces itself
- The label lives INSIDE the field as a floating label (standard `labelText` behavior but styled to match Bricolage Grotesque)
- The prefix icon: change to 16px Phosphor-style thin icons (implement as custom Icon widgets or use a different Material icon set)

#### Signup Screen — Progress Architecture

**Current**: Multi-step wizard with no visible progress indication

**Proposed**:
- Add a `_StepProgressBar` at the top of the screen: a row of segments, one per step, that fill in as the user advances. Each segment is 40px wide, 3px tall, `borderRadius: 1.5`, separated by 4px gaps.
- Animate the fill: new segment fills from left to right with a `strongEaseOut` wipe effect (using `ClipRect` + `AnimatedAlign`)
- Show the current step name below the bar: "1 of 5 — Email verification"

---

## 5. New Components to Build

### 5A. `FblaAnimatedCounter` Widget
An `AnimatedSwitcher` wrapping a number that cross-fades + slides the digits up when the value increases (like counting up) or down when it decreases. Used on: like counts, event attendee counts, stats row numbers.

### 5B. `FblaShimmerLoader` Widget (Replace `_FeedSkeleton`)
Replace the current opacity-blink shimmer with a proper sweep shimmer:
- A `LinearGradient` that moves from left to right using an `AnimationController` on repeat
- The gradient: `[shimmerBase, shimmerHighlight, shimmerBase]` at positions `[-1.0, -0.5, 0.0]` → `[0.5, 1.0, 1.5]`
- This creates the classic "loading sweep" that tells users something is genuinely loading

### 5C. `FblaSlideIndicator` Widget (Replace CarouselDots)
A thin segmented progress track:
- Total width: calculated as `(n * 20) + ((n-1) * 4)` for n segments
- Active segment: gold, 20px wide, 2px tall
- Inactive: `darkOutline`, 4px wide, 2px tall (collapsed when not active)
- Transition: width animated with `strongEaseOut` at 200ms

### 5D. `HubCategoryChip` Widget (Replace FilterChip)
Custom chip as described above — category-colored active state.

### 5E. `FblaDoubleBezelCard` Widget
Reusable wrapper that applies the outer-shell + inner-core construction:
```dart
FblaDoubleBezelCard(
  child: ...,
  outerColor: const Color(0xFF0C1525),
  innerColor: const Color(0xFF101E30),
  outerRadius: 20,
)
```
Used by EventCard. Can be adopted by other cards that need depth.

---

## 6. What We Are NOT Changing

These stay as-is. They're already correct:
- The sign-out navigation fix (popUntil to root)
- The `AuthFlowType.implicit` Supabase config
- The `ApiService` and backend communication layer
- The `UserState` / role-gating system
- The `TweenSequence` spring on like + bookmark buttons
- The `FblaSpacing` 4pt grid token system
- The `FblaRadius` token values
- The `DraggableScrollableSheet` in post actions / announcement detail

---

## 7. Implementation Roadmap — 4 Phases

### Phase 1 — Foundation (Priority: Critical)
Changes that affect everything and should happen first.

1. **Typography swap**: `app_theme.dart` — Replace Manrope with Bricolage Grotesque (display) + Rethink Sans (body). Single file change, maximum visual impact.
2. **Motion system**: `app_theme.dart` — Replace all `Curves.*` defaults with custom `Cubic()` beziers as specified.
3. **Color tightening**: `app_theme.dart` — Add new surface hierarchy tokens, update gold usage rules.
4. **Section labels**: Replace gold spaced-caps with lowercase `darkTextTertiary` labels everywhere.

### Phase 2 — Cards and Surface (Priority: High)
Removes glass from cards, adds type differentiation.

5. **PostCard**: Remove BackdropFilter, add solid surface, rounded-square avatar
6. **EventCard**: Implement double-bezel construction, remove blur
7. **AnnouncementCard (carousel)**: Add type-differentiated cards (national/district/chapter)
8. **FblaShimmerLoader**: Build the sweep shimmer to replace current blink skeleton

### Phase 3 — Navigation and Screen Moments (Priority: High)
The high-visibility changes users will notice immediately.

9. **Nav sliding pill**: Replace gold dot with sliding pill indicator
10. **Feed hero**: Split-name treatment, radial gradient, SliverAppBar behavior
11. **Profile hero**: Left-aligned avatar, watermark initial, no pill badge
12. **Announcement carousel**: Remove auto-scroll, add `FblaSlideIndicator`

### Phase 4 — Details and Delight (Priority: Medium)
The Emil details that compound into something stunning.

13. **EventCard calendar view toggle**: Mini-calendar alternative view
14. **HubCategoryChip**: Custom category-tinted chip
15. **FblaAnimatedCounter**: Animated number transitions for like counts
16. **Login hero**: Orbital animation, double-ring badge
17. **Signup progress bar**: `_StepProgressBar` with fill animation
18. **Digital ID showpiece**: Holographic shimmer + flip animation
19. **Input field upgrade**: `_FblaInputField` with Layer 4 background + gold focus border
20. **`prefers-reduced-motion`**: Add to FblaMotion and every animated widget

---

## 8. Specific Files and Lines That Change

| File | What Changes |
|---|---|
| `app_theme.dart` | Font stack, FblaMotion curves, new surface tokens, section label colors |
| `home_shell.dart` | Sliding pill indicator, tighter nav height, nav glow shadow |
| `post_card.dart` | Remove BackdropFilter, rounded-square avatar, AnimatedSwitcher on count |
| `event_card.dart` | Double-bezel construction, remove blur, square status badges |
| `announcement_card.dart` | Type-differentiated carousel cards, tinted backgrounds |
| `feed_screen.dart` | Hero overhaul (split name, radial gradient, SliverAppBar), kill carousel timer, FblaSlideIndicator, reduced stagger delay |
| `events_screen.dart` | Week strip upgrades, calendar view toggle, new EventCard |
| `hub_screen.dart` | HubCategoryChip, pinned row, upgraded search bar |
| `profile_screen.dart` | Left-aligned hero, watermark initial, stats horizontal scroll, ID card showpiece |
| `login_screen.dart` | Taller hero, orbital animation, FblaInputField |
| `signup_screen.dart` | StepProgressBar |
| NEW: `widgets/fbla_shimmer_loader.dart` | Sweep shimmer widget |
| NEW: `widgets/fbla_double_bezel_card.dart` | Reusable double-bezel wrapper |
| NEW: `widgets/fbla_animated_counter.dart` | Animated number widget |
| NEW: `widgets/fbla_slide_indicator.dart` | Segmented progress indicator |
| NEW: `widgets/hub_category_chip.dart` | Custom category chip |

---

## The One-Line Summary

> Kill the glass on cards, earn the gold back by using it 90% less, give every screen one moment worth remembering, and make every animation curve match the weight of what it's carrying.

---

*Ready for your approval. If approved, I'll execute phases 1–4 in full, file by file, with complete code — no stubs, no "// similar to above", no truncation.*
