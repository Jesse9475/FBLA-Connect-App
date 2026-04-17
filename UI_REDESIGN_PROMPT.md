# FBLA Connect — Complete UI Overhaul Prompt
# Paste this entire prompt into a new Cowork session to execute the redesign.

---

You are redesigning the frontend of **FBLA Connect** — a Flutter mobile app for FBLA (Future Business Leaders of America) members, advisors, and admins. The app has 5 main screens: Feed, Messages, Events, Hub, and Profile, accessed via a bottom nav bar.

**Use the `taste-skill`, `emil-design-eng`, `frontend-design`, `audit`, `polish`, `animate`, `typeset`, and `colorize` skills to guide every decision throughout this task.**

The current UI is a 2/10 — generic light mode Material 3 defaults: white cards, `#F4F6FE` background, navy blue headers, no personality. I want a 10/10.

---

## The Vision

FBLA Connect should feel like **what would happen if Linear and Notion had a child that was built specifically for ambitious high school business students.** It needs to feel premium, fast, intentional, and proud of the FBLA brand — not like a school admin portal.

**Aesthetic target:** Dark-first. Deep navy/obsidian background with bold FBLA gold accents. Glass-morphism surfaces. Purposeful motion. Every tap should feel responsive. Every screen should have a clear visual hierarchy where the eye knows exactly where to go.

---

## Design System Changes (start here — `app_theme.dart`)

### 1. New Color Palette — update `FblaColors`

The app already has the right brand colors (`#012B83` navy, `#F5A623` gold). The problem is they're used too conservatively. Make the dark theme the primary focus:

```
Dark background:    #070D1F  (near-black with blue undertone)
Surface (cards):    #0D1829  (slightly lighter — glass effect base)
Surface elevated:   #111F35
Primary navy:       #012B83  (keep — use as gradient base)
Gold accent:        #F5A623  (keep — use more boldly)
Gold glow:          rgba(245, 166, 35, 0.15) (for glow effects)
Navy glow:          rgba(1, 43, 131, 0.4)
Text primary:       #F0F4FF  (warm white)
Text secondary:     #8B9EC4  (muted blue-white)
Text tertiary:      #4A5E84
```

Add these gradient tokens to `FblaGradient`:
- `darkBackground`: vertical from `#070D1F` to `#0A1526`
- `goldShimmer`: diagonal from `#F5A623` to `#FFD166` (button CTAs)
- `navyDeep`: diagonal from `#012B83` to `#001456` (hero sections)
- `glassCard`: `Colors.white.withAlpha(13)` to `Colors.white.withAlpha(6)` (glass surfaces)

### 2. Typography — keep Manrope but be bolder

- Screen titles (`headlineMedium`): bump to 28px, weight 800, letter-spacing -0.8
- Card titles: weight 700, not 600
- Timestamps/labels: add letter-spacing 0.8 for that premium "spaced caps" feel
- Add a new `FblaTextStyle.heroDisplay` token: 36px, weight 900, letter-spacing -1.2, used on the feed greeting

### 3. Shadows → Glows

Replace `FblaShadow.card` (the current blue-grey box shadows) with glow-based shadows:

```dart
// Gold glow — for active/selected cards
static const List<BoxShadow> goldGlow = [
  BoxShadow(color: Color(0x33F5A623), blurRadius: 20, offset: Offset(0, 4)),
  BoxShadow(color: Color(0x1AF5A623), blurRadius: 40, offset: Offset(0, 8)),
];

// Navy glow — for primary action elements
static const List<BoxShadow> navyGlow = [
  BoxShadow(color: Color(0x66012B83), blurRadius: 24, offset: Offset(0, 6)),
];

// Glass card — subtle for dark-mode cards
static const List<BoxShadow> glass = [
  BoxShadow(color: Color(0x40000000), blurRadius: 16, offset: Offset(0, 2)),
  BoxShadow(color: Color(0x0AFFFFFF), blurRadius: 1, offset: Offset(0, 1), spreadRadius: -1),
];
```

### 4. Card Design Language

ALL cards (PostCard, EventCard, hub items) should become **glass-morphism dark cards**:

```dart
// Standard glass card decoration
BoxDecoration(
  color: Color(0x1A1E3A6E),  // navy tint, very transparent
  borderRadius: BorderRadius.circular(20),
  border: Border.all(
    color: Colors.white.withAlpha(18),
    width: 1,
  ),
  boxShadow: FblaShadow.glass,
)
// + a BackdropFilter with ImageFilter.blur(sigmaX: 10, sigmaY: 10) wrapping it
```

### 5. Bottom Nav — complete redesign

Replace the default Material 3 NavigationBar with a custom floating pill nav:

- Floating bar with 24px horizontal margin, 16px from bottom
- Rounded pill shape (full radius)
- Dark glass background: `Color(0xCC070D1F)` with backdrop blur
- Gold indicator dot below active icon (not the M3 indicator chip)
- Icons-only with tiny labels, no M3 label behavior
- Subtle top border: `Colors.white.withAlpha(20)`
- `BoxShadow` with gold glow at 5% opacity beneath active icon

---

## Screen-by-Screen Redesign

### HomeShell (`home_shell.dart`)

Replace `NavigationBar` with the custom floating glass nav described above. The `Scaffold` background should use `FblaColors.darkBackground` (the new `#070D1F`). Remove the `scaffold backgroundColor` from theme — set it per-screen via `Scaffold(backgroundColor: ...)` for more control.

### Feed Screen (`feed_screen.dart`)

**Header section:**
- Replace whatever top greeting exists with a bold hero greeting:
  ```
  [Gold dot] WED, APR 8                    [notification bell icon]

  Hey Jesse, 👋
  What's happening
  at your chapter?
  ```
  Title is 36px, weight 900, `#F0F4FF`. Date is spaced caps, `#F5A623`.

**Announcement Carousel:**
- Each announcement card should be a full-bleed glass card with a gradient overlay
- Height: 160px, full width minus 32px horizontal padding
- Bold announcement title at bottom-left (18px, weight 700, white)
- Scope badge (`NATIONAL` / `DISTRICT` / `CHAPTER`) as a gold pill in top-right
- Page dots replaced with a thin gold progress bar that fills as the carousel auto-advances
- Entrance animation: slide up from 20px below + fade in, staggered 100ms from header

**Post List:**
- Section header: `CHAPTER POSTS` in spaced gold caps (11px, weight 700, letter-spacing 1.5)
- PostCard redesign: see PostCard section below
- List items stagger-animate on load: each card slides up 30px + fades in, 80ms delay per item

### PostCard (`widgets/post_card.dart`)

Complete redesign:
- Glass card background (dark navy tint + backdrop blur)
- Avatar: 40px circle with gradient border (gold-to-navy 2px border) — no flat color
- Author name: 15px weight 700 `#F0F4FF`
- Timestamp: right-aligned, 11px, `#4A5E84`
- Body text: 14px, weight 400, `#8B9EC4`, line-height 1.6
- Like button: heart icon that fills with gold on tap
  - On tap: `transform: scale(1.0 → 1.4 → 1.0)` with a 200ms spring
  - HapticFeedback.lightImpact() on like
  - Like count animates (CounterAnimation: old number slides up, new number slides in from below)
- Remove the `CHAPTER` badge from every post — it's noise. Replace with a subtle `•` separator between author and timestamp
- On long-press: show share/report bottom sheet with a smooth `DraggableScrollableSheet` entrance

### Events Screen (`events_screen.dart`)

**Calendar strip (replace the half-page calendar):**
- Horizontal scrolling 7-day strip showing Mon–Sun of current week
- Each day: pill shape, 44px wide, shows abbreviated day name + date number
- Selected day: gold pill with dark text
- Days with events: small gold dot below the number
- Swipe left/right to move week — spring animation

**Filter chips:**
- `CHAPTER` / `DISTRICT` / `ALL` as pill chips
- Active: solid gold background, dark text
- Inactive: ghost with `Colors.white.withAlpha(20)` background, muted text

**EventCard redesign:**
- Remove the 3px left accent strip
- Instead: full dark glass card with a **colored left-side date column** (56px wide):
  - Background: navy-to-primary gradient
  - Large day number: 28px weight 800 gold
  - Month abbreviation: 11px weight 600 white, spaced caps
  - Weekday: 10px muted
- Event title: 16px weight 700 in `#F0F4FF`
- Location: icon + text in `#8B9EC4`
- Upcoming badge: replaced with a subtle pulsing dot (3px, gold, `AnimationController` with `Curves.easeInOut` repeat)
- Bookmark icon: top-right, fills gold on bookmark with spring scale animation + haptic

### Hub Screen (`hub_screen.dart`)

- Make category cards full-bleed with dark gradient overlays
- Category icon should be large (48px) and centered
- Title at bottom of card, white, weight 700
- Subtle animated shimmer on loading skeleton (not just grey boxes)

### Profile Screen (`profile_screen.dart`)

- Hero section: full-width dark gradient banner with avatar centered + large
- Avatar: 88px, gold ring border (3px), subtle glow shadow
- Display name: 24px weight 800 centered
- Role badge: gold pill for advisors, navy pill for members
- Stats row: Posts / Events / Awards — each with large number (28px weight 800 gold) and small label
- Edit profile button: glass ghost style (not filled)

---

## Animation Rules (follow `emil-design-eng` philosophy)

Every animation must pass the "frequency test": does the user see this 100x/day or 1x/day?

- **Button press feedback** (100x/day): `scale(0.97)` on `:active`, 80ms ease-out. **No opacity change.** Just the scale.
- **Card tap feedback** (10x/day): `scale(0.985)` + very subtle brightness decrease, 120ms
- **Screen entrance** (1x per navigation): stagger child items 60ms apart, each slides up 24px + fades in. Total animation window: 400ms max.
- **Modal/sheet open** (rare): slide up from bottom + backdrop fade in, 280ms `Curves.easeOutCubic`
- **Like animation** (moderate): scale pop 1.0→1.35→1.0, 200ms spring
- **Tab switch**: NO animation. Instant. It's used 50x/day.
- **Carousel auto-advance**: `animateToPage` with `Curves.easeInOutCubic`, 500ms — smooth not snappy

Use `flutter_animate` (already imported) for all entrance animations. Use raw `AnimationController` only for interactive/repeating animations (like the pulsing dot or like button).

---

## Implementation Order

Do these in order. Test each before moving on.

1. `app_theme.dart` — all new colors, gradients, shadows, typography
2. `home_shell.dart` — custom floating glass bottom nav
3. `widgets/post_card.dart` — glass card, new like animation, author layout
4. `widgets/event_card.dart` — date column redesign, glass card
5. `screens/feed_screen.dart` — hero header, announcement carousel, stagger list
6. `screens/events_screen.dart` — week strip calendar, filter chips
7. `screens/profile_screen.dart` — hero banner, stats row
8. `screens/hub_screen.dart` — full-bleed category cards

After each file: verify it compiles, check that no hardcoded colors were introduced (use only `FblaColors.*` tokens), and check that all animations pass the frequency test.

---

## Hard Rules

- **No white backgrounds anywhere.** Every surface is dark glass or deep navy.
- **No default Material 3 blue.** Zero. If anything defaulted to `Colors.blue`, replace it.
- **Gold is the hero accent color.** Use it on the ONE most important element per screen. Not everywhere.
- **Every interactive element needs press feedback.** No dead-feeling taps.
- **No animation on tab switches.** Ever.
- **Maintain all existing functionality.** This is purely a visual overhaul. No API calls, no business logic changes, no route changes.
- **Accessibility: preserve all `Semantics()` wrappers.** The existing ones are good — keep them. Dark contrast must stay WCAG AA compliant (adjust text colors to maintain ≥4.5:1 on dark backgrounds).

Go.
