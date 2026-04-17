# FBLA Connect — Complete UI/UX Redesign Plan
**Date:** March 25, 2026
**Scope:** Flutter/Dart frontend — all screens, widgets, and theme
**Research basis:** Direct codebase audit + Apple HIG / iOS 26, Instagram 2025, LinkedIn mobile, Flutter animation research

---

## What This Document Is

This is a complete, implementation-ready UI/UX plan built from two sources:
1. A line-by-line audit of every Dart file in `lib/screens/`, `lib/widgets/`, and `lib/theme/`
2. Research into how Apple, Instagram, and LinkedIn build apps that *feel* premium

The core finding: **FBLA Connect has excellent infrastructure — clean design tokens, Material 3, good error handling — but zero expressiveness.** Nothing moves, nothing responds, nothing feels alive. The gap between a student project and an App Store–ready app is not features; it's the 20 small moments between features.

---

## The Six Principles From the Best Apps in the World

Before any fixes, understand what you're building toward. Apple, Instagram, and LinkedIn share these six design commitments:

**1. Depth** — UI lives in layers. Navigation floats above content. Modals sit above navigation. Users always know where they are in the stack from visual weight alone, not just screen title.

**2. Motion That Guides** — Every animation has a spatial logic. Things slide in from where they conceptually live. Cards that come from a list slide back to the list. Sheets rise from below because sheets live below. Apple's principle: *"Motion should reinforce the spatial model."*

**3. Emotional Feedback** — Every tap gets a response. Instagram's like heart pops with spring physics. LinkedIn's connect button morphs and emits a particle burst. The app acknowledges your presence. FBLA Connect is currently silent on almost every interaction.

**4. Skeleton Loading** — Spinners say "I don't know how long." Skeletons say "here's the exact shape of what's coming." Studies show 20–30% better perceived performance at identical actual load times.

**5. Hierarchy in Every Card** — Instagram's feed has exactly one "loudest" element per card. Username > content > actions, each a distinct visual tier. Never two elements competing at the same weight.

**6. Invisible Affordances** — If it looks tappable, it IS tappable. If it's interactive, it signals that with shape, elevation, or a caret. No silent buttons.

---

## Part 1 — Accessibility Audit (WCAG 2.1 AA)

> These are not optional polish items. WCAG compliance is a competition differentiator and an ethical baseline.

### Severity Overview
| Severity | Count |
|---|---|
| 🔴 Critical | 3 |
| 🟡 Major | 7 |
| 🟢 Minor | 4 |

---

### Critical Issues (Fix These First)

**C1 — textSecondary contrast failure (all screens)**
`FblaColors.textSecondary` is `#6B7280`. On `FblaColors.background` (#F5F7FF) it achieves only ~3.9:1 — below the 4.5:1 required for normal text. This affects body copy, dates, subtitles, filter chip labels, and hub card descriptions on *every screen*.

Fix: Change to `#4B5563` in `app_theme.dart`. That's one line, achieves ~5.9:1, done.

**C2 — Announcement card body text contrast failure**
White text at `withAlpha(200)` (~78% opacity) over the amber district gradient (`#B45309 → #92400E`) achieves approximately 3.1:1. Fails 4.5:1.

Fix: Use full-opacity `Colors.white` for body text, or add a `Container` with `Color(0x40000000)` (dark overlay at 25%) behind the text column.

**C3 — AnnouncementHeroCard is invisible to screen readers**
`_AnnouncementHeroCard` has zero `Semantics` wrapping. VoiceOver/TalkBack users get nothing. Also: `_ThreadTile` titles show UUID substrings ("Thread abc123…") which are meaningless when read aloud.

Fix for card: wrap in `Semantics(label: '$_scopeLabel announcement: $_title. $_body')`.
Fix for threads: replace UUID display with "Conversation" + date, or participant name.

---

### Major Issues

| # | Location | Issue | WCAG | Fix |
|---|---|---|---|---|
| M1 | `_ActionButton` (PostCard) | Touch target ~30px height. Fails 44px minimum. | 2.5.5 | Increase vertical padding to 13px each side. |
| M2 | FilterChip (HubScreen, EventsScreen) | Default 32px height. Fails 44px. | 2.5.5 | Add `materialTapTargetSize: MaterialTapTargetSize.padded`. |
| M3 | `_ThreadTile` | Custom 4px vertical padding shrinks tile to ~36px. | 2.5.5 | Remove custom vertical padding; Material default is 48px. |
| M4 | `_MessageBubble` | No sender name, no timestamp in semantics — screen reader gets raw text with no context. | 1.3.1 | Wrap in `Semantics(label: 'From [sender], [time]: $body')`. |
| M5 | New post sheet (FeedScreen) | Text area uses `hintText` only — once user starts typing, field is unlabeled. | 3.3.2 | Add `labelText: 'Post content'` to `InputDecoration`. |
| M6 | `home_shell.dart` | Uses M3 `NavigationBar` but theme configures M2 `BottomNavigationBarTheme` — properties don't transfer. | 4.1.2 | Add `navigationBarTheme: NavigationBarThemeData(...)` to `FblaTheme.light`. |
| M7 | `_ThreadDetailScreen` | AppBar title hardcoded `'Thread'`. | 2.4.2 | Pass participant/subject name from the thread object. |

---

### Minor Issues

| # | Location | Fix |
|---|---|---|
| m1 | `_SplashScreen` "FC" logo | Wrap in `Semantics(label: 'FBLA Connect logo', excludeSemantics: true)`. |
| m2 | `_CreateEventSheet` required fields | `'Title *'` asterisk not announced as required. Use `semanticsLabel: 'Title, required'`. |
| m3 | Error views in Events/Messages/Hub | Missing `Semantics(liveRegion: true)`. LoginScreen's `_ErrorBanner` does it correctly — apply the same pattern. |
| m4 | `_DateTimeTile` | Enforce `minHeight: 44` on the tile container. |

---

### Color Contrast Reference Table

| Element | Foreground | Background | Ratio | Pass? |
|---|---|---|---|---|
| Body text (bodyLarge) | #111827 | #FFFFFF | ~18:1 | ✅ |
| Secondary text (bodyMedium) | #6B7280 | #F5F7FF | ~3.9:1 | ❌ Fix → #4B5563 |
| Announcement body (amber card) | #FFF @ 78% | #B45309 | ~3.1:1 | ❌ Use full opacity |
| Input hint text | #ADB5C4 | #F0F4FF | ~2.5:1 | ❌ (decorative only) |
| Button label on primary | #FFFFFF | #1B3A8C | ~9.2:1 | ✅ |
| Gold button label | #1A1A1A | #F5A623 | ~6.9:1 | ✅ |

---

## Part 2 — Design System Audit

### Hardcoded Values That Bypass Tokens

**hub_screen.dart — `_categoryColor` getter**
Five raw hex colors that should be named tokens:
```dart
// ❌ Current (raw hex, un-maintainable):
'study guides' => const Color(0xFF1B3A8C),  // duplicates FblaColors.primary
'templates'    => const Color(0xFF065F46),  // not in token system
'events'       => const Color(0xFFB45309),  // not in token system
'leadership'   => const Color(0xFF7C3AED),  // not in token system
_              => const Color(0xFF374151),  // not in token system

// ✅ Fix — add to FblaColors:
static const Color categoryGreen  = Color(0xFF065F46);
static const Color categoryAmber  = Color(0xFFB45309);
static const Color categoryPurple = Color(0xFF7C3AED);
static const Color categorySlate  = Color(0xFF374151);
// 'study guides' then uses FblaColors.primary (already exists)
```

**Hardcoded spacing (all should use FblaSpacing tokens):**
| File | Value | Fix |
|---|---|---|
| `post_card.dart` L98–99 | `horizontal: 6, vertical: 2` | `horizontal: FblaSpacing.xs, vertical: FblaSpacing.xxs` |
| `post_card.dart` L197 | `SizedBox(width: 4)` | `SizedBox(width: FblaSpacing.xs)` |
| `event_card.dart` L101, L121, L189 | `SizedBox(height: 4)` / `height: 2` | `FblaSpacing.xs` / `FblaSpacing.xxs` |
| `hub_screen.dart` L664 | `horizontal: 7, vertical: 2` | `FblaSpacing.sm` / `FblaSpacing.xxs` |
| `messages_screen.dart` L382 | `horizontal: 14, vertical: 10` | `FblaSpacing.md` / `FblaSpacing.sm` |
| `profile_screen.dart` L617 | `SizedBox(height: 2)` | `FblaSpacing.xxs` |
| `login_screen.dart` L191, `profile_screen.dart` L524 | `vertical: 4` | `FblaSpacing.xs` |

> Add `static const double xxs = 2.0;` to `FblaSpacing` to enable this.

---

### AppBar Gradient — Copy-Pasted 5 Times
Every screen duplicates this exact block:
```dart
// In FeedScreen, MessagesScreen, ProfileScreen, HubScreen, EventsScreen:
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
This bypasses `FblaTheme.light`'s `appBarTheme` and creates 5 independent update points.

**Fix:** Create `lib/widgets/fbla_app_bar.dart`:
```dart
class FblaAppBar extends StatelessWidget implements PreferredSizeWidget {
  const FblaAppBar({super.key, required this.title, this.actions});
  final String title;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) => AppBar(
    title: Text(title),
    backgroundColor: FblaColors.primary,
    foregroundColor: Colors.white,
    actions: actions,
    flexibleSpace: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [FblaColors.primaryDark, FblaColors.primaryLight],
        ),
      ),
    ),
  );
}
```

---

### FblaMotion — Defined, Never Used

`FblaMotion` has `fast`, `standard`, `slow`, `easeOut`, and `spring` defined in `app_theme.dart`. Only one screen (`messages_screen.dart`) uses any of it. Zero page transitions. Zero entrance animations. Zero micro-interactions. The infrastructure exists — it just hasn't been wired up anywhere.

---

### Missing Theme Entries
```dart
// Add to FblaTheme.light (ThemeData block):
navigationBarTheme: NavigationBarThemeData(
  backgroundColor: FblaColors.surface,
  indicatorColor: FblaColors.primary.withAlpha(20),
  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
),
```
Also needed: `FblaTheme.dark` — currently only `get light` exists.

---

### Two Error Widget Patterns (Should Be One)

Pattern A: `_ErrorBanner` in `login_screen.dart` — correct, has `Semantics(liveRegion: true)`.

Pattern B: Anonymous `Center > Column > Icon + Text + OutlinedButton` — copied verbatim into FeedScreen, EventsScreen, MessagesScreen, and HubScreen — no live region, no shared source.

**Fix:** Create `lib/widgets/fbla_error_view.dart` and `lib/widgets/fbla_empty_view.dart`. Replace all four instances.

---

## Part 3 — User Journey Analysis

### User Segments
- **Student Members** (primary) — checking announcements, events, messaging peers, studying via Hub
- **Chapter Advisors** — posting, creating events, managing resources
- **Admins** — organization-level oversight

---

### Journey 1: New Member First Open

```
Cold start → 2s forced delay → Splash → Login or Signup
→ 9-step signup (Email → OTP → Role → Name → School → Chapter → Interests → Tour)
→ Lands on Feed
→ Greeting: "Good morning, jsmith" (email prefix, not first name)
→ Blank or sparse feed
→ Explores tabs
```

Pain points:
- 🔴 2-second hardcoded `Future.delayed` on every cold start regardless of connection speed
- 🟡 Greeting uses email prefix, not the first name collected during signup
- 🟡 Spinner during feed load gives no content-shape preview
- 🟡 Selected interests from onboarding are collected but never used (Hub not personalized)

---

### Journey 2: Checking Announcements

```
Feed tab → Announcement carousel (140px fixed, horizontal scroll)
→ No tap response (cards are not interactive)
→ "See all" → AnnouncementsScreen (no filter by scope)
```

Pain points:
- 🔴 Cards look tappable (gradient, rounded corners, elevation) but do nothing on tap
- 🟡 No pagination indicator — users don't know if there are 2 or 20 announcements
- 🟡 No scope filter (chapter/district/national) on the standalone view

---

### Journey 3: Messaging

```
Messages tab → Thread list
→ Thread titles: "Thread abc123…" (UUID substring)
→ Tap "New message" icon → Snackbar: "New thread — coming soon"
→ Open thread → Bubbles with no sender distinction, no timestamps
```

Pain points:
- 🔴 UUID thread titles are completely meaningless — the feature is effectively broken
- 🔴 "New message" button looks real but fires a snackbar — users feel deceived
- 🟡 No visual distinction between sent vs. received messages
- 🟡 No real-time updates — requires manual pull-to-refresh

---

### Journey 4: Advisor Creates Event

```
Events tab → Tap + → Sheet: Title, Start (date picker → time picker → separate steps)
→ Optional: End, Location, Description → Visibility → "Create Event"
→ Sheet closes, list reloads
```

Pain points:
- 🟡 Two forced consecutive system pickers (date then time) with no option to skip time
- 🟡 Event cards have an `onTap: () {}` no-op — no detail view despite looking tappable
- 🟢 No edit/delete after creation

---

### Journey 5: Resource Hub

```
Hub tab → Search + category chips → Tap card → DraggableScrollableSheet
→ Read content → "Download attachment" → Snackbar: "Download started"
```

Pain points:
- 🟡 Download fires a fake snackbar — no actual file action
- 🟡 Long content in a bottom sheet is cramped; full-screen detail page needed
- 🟢 Chip `selectedColor` is solid primary in Hub but tinted primary in Events — inconsistent

---

## Part 4 — What the Best Apps Do Differently (Applied to FBLA Connect)

### Depth: Add a Real Layer System

**Right now:** Flat cards, uniform shadows, gradient AppBar repeated on every screen.

**What Apple/Instagram do:** Distinct depth layers. Content layer → navigation layer → modal layer. Each has different shadow intensity and blur treatment.

**What to change:**
- Use `BackdropFilter(filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8))` behind all bottom sheets for an iOS-native depth effect
- Vary shadows: resting card = `FblaShadow.card`, pressed/elevated card = `FblaShadow.elevated`
- Reduce gradient AppBar to Feed only (the brand home). Other screens (Events, Hub, Messages, Profile) use the white `FblaColors.surface` AppBar from the theme — this creates visual hierarchy between tabs

---

### Motion: Actually Use FblaMotion

**Right now:** `FblaMotion` defines five constants. Zero page transitions use them. Zero cards animate in.

**Flutter implementation — add `flutter_animate` to pubspec.yaml:**

```yaml
dependencies:
  flutter_animate: ^4.5.0
```

**Staggered list entrance (replaces snap-in appearance):**
```dart
// In SliverList itemBuilder, FeedScreen / EventsScreen / HubScreen:
itemBuilder: (ctx, i) => PostCard(post: _posts[i])
  .animate(delay: Duration(milliseconds: i * 50))
  .fadeIn(duration: FblaMotion.standard)
  .slideY(begin: 0.08, end: 0, curve: FblaMotion.spring),
```

**Custom page transition (replaces flat MaterialPageRoute):**
```dart
// Use this instead of MaterialPageRoute everywhere:
Navigator.of(context).push(
  PageRouteBuilder(
    transitionDuration: FblaMotion.standard,
    pageBuilder: (_, __, ___) => DestinationScreen(),
    transitionsBuilder: (_, anim, __, child) => FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: FblaMotion.spring)),
        child: child,
      ),
    ),
  ),
);
```

---

### Emotional Feedback: Haptics + Micro-Interactions

**Right now:** Like button changes icon and color — silently. No haptic, no animation.

**What Instagram does:** Scale pop + haptic on like. Heart appears at tap coordinates on double-tap.

**Flutter implementation:**

```dart
// In PostCard — animated like button:
class _LikeButton extends StatefulWidget { ... }

class _LikeButtonState extends State<_LikeButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: FblaMotion.fast,
    );
  }

  void _onTap() {
    HapticFeedback.lightImpact();      // ← the key line
    _ctrl.forward().then((_) => _ctrl.reverse());
    widget.onLike();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
    scale: Tween<double>(begin: 1.0, end: 1.35).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
    ),
    child: IconButton(
      icon: Icon(
        _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        color: _liked ? FblaColors.error : FblaColors.textSecondary,
      ),
      onPressed: _onTap,
    ),
  );
}
```

**Haptic map (add these calls throughout the app):**
```dart
HapticFeedback.lightImpact();    // Like, chip select, toggle
HapticFeedback.mediumImpact();   // Post published, event created, form saved
HapticFeedback.heavyImpact();    // Error, destructive action (sign out confirm)
```

---

### Skeleton Loading: Replace Every Spinner

**Right now:** `CircularProgressIndicator(color: FblaColors.primary)` on every screen.

**What LinkedIn does:** Skeleton that exactly matches the content card shape, so the transition from loading → loaded is seamless.

**Self-contained shimmer widget (no package needed):**

```dart
class _Shimmer extends StatefulWidget {
  const _Shimmer({required this.width, required this.height, this.radius = 8});
  final double width, height, radius;
  @override State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  @override void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200),
    )..repeat();
    _anim = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Container(
      width: widget.width, height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.radius),
        gradient: LinearGradient(
          begin: Alignment(_anim.value - 1, 0),
          end: Alignment(_anim.value + 1, 0),
          colors: const [
            Color(0xFFE8EDFB), Color(0xFFF5F7FF), Color(0xFFE8EDFB),
          ],
        ),
      ),
    ),
  );
}

// Post card skeleton — mirrors exact PostCard layout:
class PostCardSkeleton extends StatelessWidget {
  const PostCardSkeleton();
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(FblaSpacing.md),
    decoration: BoxDecoration(
      color: FblaColors.surface,
      borderRadius: BorderRadius.circular(FblaRadius.md),
      border: Border.all(color: FblaColors.outlineVariant),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const _Shimmer(width: 36, height: 36, radius: 18),
        const SizedBox(width: FblaSpacing.sm),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _Shimmer(width: 120, height: 12),
          const SizedBox(height: 4),
          const _Shimmer(width: 80, height: 10),
        ]),
      ]),
      const SizedBox(height: FblaSpacing.md),
      const _Shimmer(width: double.infinity, height: 14),
      const SizedBox(height: 6),
      const _Shimmer(width: 240, height: 14),
      const SizedBox(height: 6),
      const _Shimmer(width: 180, height: 14),
    ]),
  );
}
```

Use `ListView.builder(itemCount: 4, itemBuilder: (_, __) => const PostCardSkeleton())` while `_loading` is true.

---

### Visual Hierarchy: Make PostCard Feel Real

**Right now:** Author row shows "Chapter Member" for everyone. Generic icon. No name. No personality.

**What LinkedIn does:** Every list item has a distinct colored avatar (initials-based), real name in bold, role in secondary weight, timestamp in tertiary. Three tiers, one focal point.

**Colored initials avatar (deterministic, no backend change needed):**
```dart
Widget _buildAvatar(String userId, String displayName) {
  // Generate consistent hue from userId hash
  final hue = (userId.hashCode.abs() % 360).toDouble();
  final color = HSLColor.fromAHSL(1.0, hue, 0.5, 0.4).toColor();
  final initials = displayName.isNotEmpty
      ? displayName.split(' ').take(2).map((w) => w[0]).join().toUpperCase()
      : '?';
  return CircleAvatar(
    radius: 18,
    backgroundColor: color.withAlpha(40),
    child: Text(
      initials,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    ),
  );
}
```

---

### Affordances: Make Tappable Things Tap

The single most visible UX failure: items look interactive but aren't.

| Element | Current | Fix |
|---|---|---|
| `_AnnouncementHeroCard` | No onTap | Wrap in `InkWell`, push detail sheet |
| `EventCard` | `onTap: () {}` no-op | Push `EventDetailScreen` |
| Thread "New message" button | "Coming soon" snackbar | Hide button or show truly disabled state |
| Post "Comment" button | "Coming soon" snackbar | Hide or disabled with tooltip |
| Hub download button | Fake snackbar | Implement or hide |

---

## Part 5 — Complete Prioritized Implementation Plan

### 🔴 Do These Today (under 30 min each)

| # | What | Where | Time |
|---|---|---|---|
| 1 | Fix `textSecondary`: `#6B7280` → `#4B5563` | `app_theme.dart` L32 | 2 min |
| 2 | Wrap `_AnnouncementHeroCard` in `Semantics` | `feed_screen.dart` L487 | 5 min |
| 3 | Remove `Future.delayed(Duration(seconds: 2))` | `main.dart` L82 | 2 min |
| 4 | Replace "coming soon" snackbars with hidden/disabled | `messages_screen.dart`, `post_card.dart` | 15 min |
| 5 | Fix announcement card body text to full `Colors.white` opacity | `feed_screen.dart` L535 | 2 min |
| 6 | Add `HapticFeedback.lightImpact()` to like button | `post_card.dart` L41 | 3 min |

---

### 🟡 Do These This Week (30 min – 3 hrs each)

| # | What | Time |
|---|---|---|
| 7 | Extract `FblaAppBar` widget, replace all 5 inline AppBar blocks | 1 hr |
| 8 | Add `FblaSpacing.xxs = 2.0`, `FblaCategoryColors`, replace all hardcoded values | 2 hr |
| 9 | Add `NavigationBarTheme` to `FblaTheme.light`, remove inline HomeShell overrides | 30 min |
| 10 | Make announcement cards tappable (InkWell + detail sheet) | 1 hr |
| 11 | Make event cards tappable (push `EventDetailScreen`) | 1 hr |
| 12 | Fix thread titles (replace UUID with "Conversation · [date]") | 30 min |
| 13 | Fix greeting to use `first_name` from profile | 20 min |
| 14 | Add `labelText: 'Post content'` to new post sheet text area | 5 min |
| 15 | Create shared `FblaErrorView` + `FblaEmptyView` widgets with `Semantics(liveRegion: true)` | 1 hr |

---

### 🟢 Do These Next Sprint (1–3 days total)

| # | What | Impact | Time |
|---|---|---|---|
| 16 | Add `flutter_animate` — staggered list entrance on first load | Visual delight | 2 hr |
| 17 | Custom page transitions (`PageRouteBuilder` with fade+slideY) | Feel premium | 2 hr |
| 18 | Animated like button with `ScaleTransition` + spring curve | Memorable interaction | 1 hr |
| 19 | Shimmer skeleton loading for Feed, Events, Hub, Messages | Perceived performance | 3 hr |
| 20 | Hub detail → full-screen `HubDetailScreen` (not bottom sheet) | Readability | 2 hr |
| 21 | Personalized Hub "Recommended for you" section using onboarding interests | Personalization | 1 hr |
| 22 | Colored initials avatars on posts and message bubbles | Visual identity | 1 hr |
| 23 | Announcement carousel: page indicator + auto-scroll + `BouncingScrollPhysics` | Polish | 2 hr |
| 24 | Relative timestamps everywhere (`timeago` package or manual) | Feels alive | 1 hr |
| 25 | `FblaTheme.dark` + `themeMode: ThemeMode.system` | Modern standard | 1 day |

---

## Part 6 — New Packages to Add

```yaml
# pubspec.yaml additions:
dependencies:
  flutter_animate: ^4.5.0   # Composable animations, zero boilerplate
  timeago: ^3.7.0            # "2 hours ago" timestamps
  lottie: ^3.1.0             # JSON animations for success/delight moments
  # shimmer: ^3.0.0          # Optional — or use the hand-rolled version above
```

---

## Part 7 — Token Additions (app_theme.dart)

```dart
// FblaSpacing — add:
static const double xxs = 2.0;

// FblaColors — add:
static const Color categoryGreen  = Color(0xFF065F46);
static const Color categoryAmber  = Color(0xFFB45309);
static const Color categoryPurple = Color(0xFF7C3AED);
static const Color categorySlate  = Color(0xFF374151);

// textSecondary — CHANGE:
static const Color textSecondary = Color(0xFF4B5563);  // was #6B7280

// FblaTheme.light — add inside ThemeData():
navigationBarTheme: NavigationBarThemeData(
  backgroundColor: FblaColors.surface,
  indicatorColor: FblaColors.primary.withAlpha(20),
  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
),
```

---

## One-Sentence Summary for Each Screen

| Screen | Biggest Single Fix |
|---|---|
| `login_screen.dart` | Already solid — add `HapticFeedback.mediumImpact()` on successful sign-in |
| `feed_screen.dart` | Make announcement cards tappable + use first_name in greeting |
| `events_screen.dart` | Wire `EventCard.onTap` to a real `EventDetailScreen` |
| `messages_screen.dart` | Replace UUID thread titles and remove the fake "New thread" button |
| `hub_screen.dart` | Open details in full-screen page, fix category color tokens |
| `profile_screen.dart` | Minor — show chapter name instead of UUID for `chapter_id` |
| `home_shell.dart` | Move `NavigationBar` style into `FblaTheme.light` |
| `app_theme.dart` | Fix `textSecondary`, add `xxs` spacing, add category colors, add `NavigationBarTheme` |

---

*Complete plan — ready to implement. Built from direct audit of all Dart source files + research into Apple iOS 26 HIG, Instagram 2025, LinkedIn mobile UI patterns, and Flutter animation best practices — March 25, 2026*
