import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

// ─── Persistence key ─────────────────────────────────────────────────────────

const _kOnboardingKey = 'fbla_onboarding_v1';

// Onboarding slides are always dark — a confident brand statement that does not
// follow the system preference. The contrast and drama require the dark canvas.
const _kBg      = Color(0xFF09090E);
const _kSurface = Color(0xFF111118);

// ─── Slide data ───────────────────────────────────────────────────────────────

class _SlideData {
  const _SlideData({
    required this.verb,
    required this.headline,
    required this.body,
    required this.accentColor,
  });

  final String verb;
  final String headline;
  final String body;
  final Color accentColor;
}

const _slides = [
  _SlideData(
    verb: 'CONNECT.',
    headline: 'Your chapter,\nyour community.',
    body: 'Stay in sync with announcements, posts, and messages from advisors and fellow members — all in one place.',
    accentColor: Color(0xFF3B82F6),  // electric blue
  ),
  _SlideData(
    verb: 'COMPETE.',
    headline: 'Events, deadlines,\nyour schedule.',
    body: 'Track every competition date, RSVP to chapter events, and never miss a registration window again.',
    accentColor: Color(0xFFF5A623),  // gold
  ),
  _SlideData(
    verb: 'SUCCEED.',
    headline: 'Resources built\nfor winners.',
    body: 'Study guides, officer resources, chapter documents — everything you need to walk into a competition ready.',
    accentColor: Color(0xFF3B82F6),  // electric blue
  ),
];

// ─── Public helpers ───────────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  static Future<bool> hasBeenSeen() async {
    try {
      const s = FlutterSecureStorage();
      return await s.read(key: _kOnboardingKey) == 'true';
    } catch (_) {
      return false;
    }
  }

  static Future<void> markSeen() async {
    try {
      const s = FlutterSecureStorage();
      await s.write(key: _kOnboardingKey, value: 'true');
    } catch (_) {}
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

// ─── Controller ──────────────────────────────────────────────────────────────

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _next() {
    HapticFeedback.lightImpact();
    if (_page < _slides.length - 1) {
      _pageCtrl.nextPage(
        duration: FblaMotion.slow,
        curve: FblaMotion.strongEaseOut,
      );
    } else {
      _toSignup();
    }
  }

  void _toSignup() {
    OnboardingScreen.markSeen();
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => const SignupScreen(),
        transitionDuration: const Duration(milliseconds: 320),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: CurvedAnimation(parent: a, curve: FblaMotion.strongEaseOut), child: child),
      ),
    );
  }

  void _toLogin() {
    OnboardingScreen.markSeen();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionDuration: const Duration(milliseconds: 320),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: CurvedAnimation(parent: a, curve: FblaMotion.strongEaseOut), child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final safeTop    = MediaQuery.paddingOf(context).top;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final slide      = _slides[_page];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _kBg,
        body: Stack(
          children: [
            // ── Slides ────────────────────────────────────────────────────────
            // Swipe is disabled — users must tap Next to advance. Prevents
            // skipping past any slide and keeps the pacing deliberate.
            PageView.builder(
              controller: _pageCtrl,
              onPageChanged: (i) => setState(() => _page = i),
              itemCount: _slides.length,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (ctx, i) => _Slide(data: _slides[i], safeTop: safeTop, safeBottom: safeBottom),
            ),

            // ── Header: FBLA wordmark + sign in ───────────────────────────────
            Positioned(
              top: safeTop + 12,
              left: 24,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // FBLA logo mark
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: Image.asset(
                          'assets/images/logo_48.png',
                          width: 22,
                          height: 22,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'FBLA CONNECT',
                        style: FblaFonts.monoTag(
                          fontSize: 11,
                          color: Colors.white.withAlpha(180),
                        ),
                      ),
                    ],
                  ),
                  // Sign in text button
                  GestureDetector(
                    onTap: _toLogin,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Text(
                        'Sign in',
                        style: FblaFonts.label(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withAlpha(150),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Bottom controls ───────────────────────────────────────────────
            Positioned(
              left: 24,
              right: 24,
              bottom: safeBottom + 32,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Progress dots
                  Row(
                    children: List.generate(_slides.length, (i) {
                      final active = i == _page;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: FblaMotion.strongEaseOut,
                        margin: const EdgeInsets.only(right: 6),
                        width: active ? 22 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: active
                              ? slide.accentColor
                              : Colors.white.withAlpha(50),
                          borderRadius: BorderRadius.circular(FblaRadius.full),
                        ),
                      );
                    }),
                  ),

                  // Next / finish button
                  _NextButton(
                    isLast: _page == _slides.length - 1,
                    accentColor: slide.accentColor,
                    onTap: _next,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Individual slide ─────────────────────────────────────────────────────────

class _Slide extends StatelessWidget {
  const _Slide({
    required this.data,
    required this.safeTop,
    required this.safeBottom,
  });

  final _SlideData data;
  final double safeTop;
  final double safeBottom;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(24, safeTop + 80, 24, safeBottom + 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Accent verb — giant typographic statement ─────────────────────
          Text(
            data.verb,
            style: FblaFonts.display(
              fontSize: size.width > 380 ? 72 : 60,
              fontWeight: FontWeight.w700,
              color: data.accentColor,
              letterSpacing: -2,
            ),
          )
              .animate()
              .fadeIn(duration: 480.ms, curve: Curves.easeOut)
              .slideY(begin: 0.12, end: 0, duration: 480.ms, curve: Curves.easeOut),

          const SizedBox(height: 20),

          // ── Headline ──────────────────────────────────────────────────────
          Text(
            data.headline,
            style: FblaFonts.display(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: -0.5,
              height: 1.2,
            ),
          )
              .animate(delay: 80.ms)
              .fadeIn(duration: 420.ms, curve: Curves.easeOut)
              .slideY(begin: 0.1, end: 0, duration: 420.ms, curve: Curves.easeOut),

          const SizedBox(height: 20),

          // ── Thin accent rule ──────────────────────────────────────────────
          Container(
            width: 32,
            height: 2,
            decoration: BoxDecoration(
              color: data.accentColor.withAlpha(180),
              borderRadius: BorderRadius.circular(FblaRadius.full),
            ),
          )
              .animate(delay: 140.ms)
              .fadeIn(duration: 380.ms, curve: Curves.easeOut)
              .scaleX(begin: 0, end: 1, alignment: Alignment.centerLeft),

          const SizedBox(height: 20),

          // ── Body description ──────────────────────────────────────────────
          Text(
            data.body,
            style: FblaFonts.body(
              fontSize: 16,
              color: Colors.white.withAlpha(160),
              height: 1.65,
            ),
          )
              .animate(delay: 160.ms)
              .fadeIn(duration: 380.ms, curve: Curves.easeOut)
              .slideY(begin: 0.08, end: 0, duration: 380.ms, curve: Curves.easeOut),

          const Spacer(),

          // ── Feature pills ─────────────────────────────────────────────────
          _FeaturePills(data: data),
        ],
      ),
    );
  }
}

// ─── Feature pills — 3 small chips below the description ─────────────────────

class _FeaturePills extends StatelessWidget {
  const _FeaturePills({required this.data});

  final _SlideData data;

  static const _featuresBySlide = [
    ['Announcements', 'Chapter feed', 'Direct messages'],
    ['Event calendar', 'RSVP tracking', 'Countdowns'],
    ['Study guides', 'Officer docs', 'Chapter resources'],
  ];

  @override
  Widget build(BuildContext context) {
    final idx = _slides.indexOf(data);
    final features = idx >= 0 ? _featuresBySlide[idx] : _featuresBySlide[0];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: features.asMap().entries.map((e) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.circular(FblaRadius.full),
            border: Border.all(
              color: data.accentColor.withAlpha(60),
            ),
          ),
          child: Text(
            e.value,
            style: FblaFonts.label(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white.withAlpha(180),
            ),
          ),
        )
            .animate(delay: Duration(milliseconds: 220 + e.key * 60))
            .fadeIn(duration: 340.ms, curve: Curves.easeOut)
            .slideY(begin: 0.1, end: 0, duration: 340.ms, curve: Curves.easeOut);
      }).toList(),
    );
  }
}

// ─── Next/finish button ───────────────────────────────────────────────────────

class _NextButton extends StatefulWidget {
  const _NextButton({
    required this.isLast,
    required this.accentColor,
    required this.onTap,
  });

  final bool isLast;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  State<_NextButton> createState() => _NextButtonState();
}

class _NextButtonState extends State<_NextButton>
    with SingleTickerProviderStateMixin {
  // Emil-style cubic-bezier(0.23, 1, 0.32, 1): confident ease-out, no
  // overshoot. Used for every interpolation on this button so nothing
  // fights the press-scale animation.
  static const Cubic _emilEaseOut = Cubic(0.23, 1, 0.32, 1);

  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  bool _hovering = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _ctrl, curve: _emilEaseOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Single source of truth for the "active color" — both fill and glow
    // use it, so they can never disagree mid-tween. On the last slide we
    // force the gold brand color regardless of slide accent; everywhere
    // else we track the slide's own accent.
    final Color activeColor =
        widget.isLast ? FblaColors.secondary : widget.accentColor;

    // Hover lift — desktop/web only; MouseRegion fires nothing on touch,
    // so mobile users never pay for this. 1.04 is big enough to register
    // on a hero button without feeling cartoonish.
    final double hoverScale = _hovering ? 1.04 : 1.0;

    // Dual shadow on hover — ground shadow for weight, soft diffuse for
    // glow. The alpha on the diffuse layer is intentionally low so it
    // doesn't muddy the surrounding dark canvas.
    final List<BoxShadow> shadows = _hovering
        ? [
            BoxShadow(
              color: activeColor.withAlpha(130),
              blurRadius: 28,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: activeColor.withAlpha(60),
              blurRadius: 56,
              offset: const Offset(0, 14),
            ),
          ]
        : [
            BoxShadow(
              color: activeColor.withAlpha(85),
              blurRadius: 22,
              offset: const Offset(0, 6),
            ),
          ];

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTapDown: (_) => _ctrl.forward(),
        onTapUp: (_) {
          _ctrl.reverse();
          widget.onTap();
        },
        onTapCancel: () => _ctrl.reverse(),
        child: AnimatedScale(
          // AnimatedScale tweens from current value (never from 0), so the
          // button doesn't "pop in" on first render. Hover uses a standard
          // ease per Emil's framework #3 — hover/color change → ease,
          // since motion is symmetric in both directions.
          scale: hoverScale,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: ScaleTransition(
            scale: _scale,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: _emilEaseOut,
              width: widget.isLast ? 160 : 56,
              height: 56,
              decoration: BoxDecoration(
                color: activeColor,
                borderRadius: BorderRadius.circular(FblaRadius.full),
                // Shadow derived from the button's own color — no more
                // swapping between hardcoded blue-glow and gold-glow lists
                // (which made the interpolation pass through a muddy
                // purple intermediate on slide changes). Hover amplifies
                // with a dual-layer lift.
                boxShadow: shadows,
              ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: _emilEaseOut,
            switchOutCurve: _emilEaseOut,
            transitionBuilder: (child, anim) {
              final scaled = Tween<double>(begin: 0.85, end: 1.0).animate(anim);
              return FadeTransition(
                opacity: anim,
                child: ScaleTransition(scale: scaled, child: child),
              );
            },
            child: widget.isLast
                ? Padding(
                    key: const ValueKey('last'),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'GET STARTED',
                      style: FblaFonts.label(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: FblaColors.onSecondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                  )
                : const Icon(
                    key: ValueKey('arrow'),
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
