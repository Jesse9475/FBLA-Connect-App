import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/accessibility_settings.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FBLA Connect — Design Tokens v3 "Contender"
//
// Aesthetic: Editorial precision meets competitive achievement.
// Primary:   Electric blue (#2563EB) — vivid, interactive, distinctly blue.
// Secondary: FBLA gold (#F5A623)    — CTAs, achievement badges, featured moments.
// Dark bg:   True editorial dark (#09090E) — no navy tint.
// Light bg:  Warm off-white (#F8F7F3) — paper quality.
// Fonts:     Josefin Sans (display/titles) + Mulish (body) + JetBrains Mono (data only).
// ─────────────────────────────────────────────────────────────────────────────

/// Brand palette
abstract final class FblaColors {
  // ── Primary — Muted Navy (interactive / brand) ──────────────────────────────
  // Calmer FBLA navy — sophisticated, less aggressive than electric blue.
  // Stays legible on both dark and light surfaces.
  static const Color primary      = Color(0xFF3B5A85);
  static const Color primaryLight = Color(0xFF5577A8);  // brighter variant for dark mode
  static const Color primaryDark  = Color(0xFF2A4068);
  static const Color onPrimary    = Color(0xFFFFFFFF);

  // ── Gold — Achievement / CTAs / Featured ────────────────────────────────────
  // Reserved strictly for earned moments: primary action buttons, competition
  // badges, featured content. Never used for generic interactive states.
  static const Color secondary      = Color(0xFFF5A623);
  static const Color secondaryLight = Color(0xFFFBBF24);
  static const Color secondaryDark  = Color(0xFFD97706);
  static const Color onSecondary    = Color(0xFF0D0C17);  // near-black text on gold

  // ── Adaptive dark-first surface palette ─────────────────────────────────────
  //
  // Resolve the effective brightness the way MaterialApp does:
  //   1. If the user has forced dark via AccessibilitySettings, honor it.
  //   2. If they've forced light, honor that too.
  //   3. Otherwise follow the OS (ThemeMode.system).
  //
  // Before this fix, `_isDark` only read OS brightness, so when
  // AccessibilitySettings.themeMode was ThemeMode.dark but the OS was in
  // light mode (or vice versa), the Material theme and the color getters
  // disagreed — producing the "half the UI is white, half is dark"
  // visual breakage the user reported.
  static bool get _isDark {
    final mode = AccessibilitySettings.instance.themeMode;
    if (mode == ThemeMode.dark) return true;
    if (mode == ThemeMode.light) return false;
    return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
  }

  /// Main scaffold background.
  static Color get darkBg          => _isDark ? const Color(0xFF09090E) : const Color(0xFFF8F7F3);
  /// Card / glass surface base.
  static Color get darkSurface     => _isDark ? const Color(0xFF111118) : const Color(0xFFFFFFFF);
  /// Elevated card / input fill.
  static Color get darkSurfaceHigh => _isDark ? const Color(0xFF18181F) : const Color(0xFFF1F0F8);
  /// Bottom sheet / modal background.
  static Color get darkOverlay     => _isDark ? const Color(0xFF0D0D13) : const Color(0xFFFFFFFF);

  static Color get darkOutline    => _isDark ? const Color(0xFF252432) : const Color(0xFFE3E2EF);
  static Color get darkOutlineVar => _isDark ? const Color(0xFF1D1C28) : const Color(0xFFEEEDF8);

  // ── Adaptive text ─────────────────────────────────────────────────────────────
  // Contrast-tuned: each level meets WCAG 2.1 AA (4.5:1) against the matching
  // surface background. Tertiary is reserved for decorative/disabled use but is
  // bumped enough to comfortably pass AA-large (3:1) for icons and bullets.
  static Color get darkTextPrimary  => _isDark ? const Color(0xFFEEEDF7) : const Color(0xFF0D0C17);
  static Color get darkTextSecond   => _isDark ? const Color(0xFFB2B0CC) : const Color(0xFF4B4A66);
  static Color get darkTextTertiary => _isDark ? const Color(0xFF8B89A8) : const Color(0xFF6F6E8B);

  // ── Light-mode neutrals ────────────────────────────────────────────────────
  static const Color surface          = Color(0xFFFFFFFF);
  static const Color surfaceVariant   = Color(0xFFF1F0F8);
  static const Color surfaceElevated  = Color(0xFFF8F7F3);
  static const Color background       = Color(0xFFF8F7F3);
  static const Color outline          = Color(0xFFE3E2EF);
  static const Color outlineVariant   = Color(0xFFEEEDF8);

  static const Color textPrimary    = Color(0xFF0D0C17);
  static const Color textSecondary  = Color(0xFF5A597A);
  static const Color textTertiary   = Color(0xFF6F6E8B);
  static const Color textDisabled   = Color(0xFFBBBAD0);

  // ── Semantic ─────────────────────────────────────────────────────────────────
  static const Color success       = Color(0xFF16A34A);
  static const Color successSoft   = Color(0xFFF0FDF4);
  static const Color onSuccess     = Color(0xFFFFFFFF);
  static const Color warning       = Color(0xFFF59E0B);
  static const Color warningSoft   = Color(0xFFFFFBEB);
  static const Color onWarning     = Color(0xFF1A1A1A);
  static const Color error         = Color(0xFFDC2626);
  static const Color errorSoft     = Color(0xFFFEF2F2);
  static const Color onError       = Color(0xFFFFFFFF);

  // ── Glow / overlay ───────────────────────────────────────────────────────────
  static const Color goldGlow  = Color(0x26F5A623);  // gold at 15%
  static const Color navyGlow  = Color(0x663B5A85);  // muted navy at 40%
  static const Color shadow    = Color(0x1A09090E);

  // ── Hub category colors ───────────────────────────────────────────────────────
  static const Color categoryGreen  = Color(0xFF065F46);
  static const Color categoryAmber  = Color(0xFFB45309);
  static const Color categoryPurple = Color(0xFF7C3AED);
  static const Color categorySlate  = Color(0xFF374151);

  // ── Accent alias ───────────────────────────────────────────────────────────────
  static const Color accent     = Color(0xFF5577A8);
  static const Color accentSoft = Color(0xFFEFF2F8);
}

/// Spacing scale (4-pt grid)
abstract final class FblaSpacing {
  static const double xxs  = 2.0;
  static const double xs   = 4.0;
  static const double sm   = 8.0;
  static const double md   = 16.0;
  static const double lg   = 24.0;
  static const double xl   = 32.0;
  static const double xxl  = 48.0;
  static const double xxxl = 64.0;
}

/// Border radius
abstract final class FblaRadius {
  static const double sm   = 6.0;
  static const double md   = 12.0;
  static const double lg   = 16.0;
  static const double xl   = 24.0;
  static const double xxl  = 32.0;
  static const double full = 999.0;
}

/// Elevation / shadow — glow-based shadows
abstract final class FblaShadow {
  static const List<BoxShadow> none = [];

  /// Gold glow — active/selected/achievement elements
  static const List<BoxShadow> goldGlow = [
    BoxShadow(color: Color(0x33F5A623), blurRadius: 20, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x1AF5A623), blurRadius: 40, offset: Offset(0, 8)),
  ];

  /// Blue glow — primary action elements in dark mode
  static const List<BoxShadow> blueGlow = [
    BoxShadow(color: Color(0x443B5A85), blurRadius: 24, offset: Offset(0, 6)),
    BoxShadow(color: Color(0x223B5A85), blurRadius: 48, offset: Offset(0, 12)),
  ];

  /// Glass card — dark-mode surface shadow
  static const List<BoxShadow> glass = [
    BoxShadow(color: Color(0x40000000), blurRadius: 16, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x0AFFFFFF), blurRadius: 1, offset: Offset(0, 1), spreadRadius: -1),
  ];

  /// Card shadow — light-mode surface
  static const List<BoxShadow> cardLight = [
    BoxShadow(color: Color(0x0E0D0C17), blurRadius: 8,  offset: Offset(0, 1)),
    BoxShadow(color: Color(0x060D0C17), blurRadius: 24, offset: Offset(0, 4)),
  ];

  /// Floating nav pill shadow
  static const List<BoxShadow> floatingNav = [
    BoxShadow(color: Color(0x66000000), blurRadius: 32, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x1A3B5A85), blurRadius: 20, offset: Offset(0, 4)),
  ];

  /// Legacy aliases kept for compatibility
  static const List<BoxShadow> navyGlow = blueGlow;
  static const List<BoxShadow> card     = cardLight;
  static const List<BoxShadow> elevated = cardLight;
  static const List<BoxShadow> overlay  = glass;
}

/// Gradient library — v3 Contender
abstract final class FblaGradient {
  /// Brand hero — login, onboarding splash
  static const LinearGradient brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2A4068), Color(0xFF3B5A85), Color(0xFF5577A8)],
    stops: [0.0, 0.50, 1.0],
  );

  /// Dark background — main scaffold gradient (very subtle)
  static const LinearGradient darkBackground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF09090E), Color(0xFF0D0D13)],
  );

  /// Gold shimmer — CTAs, primary action buttons (achievement)
  static const LinearGradient goldShimmer = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF5A623), Color(0xFFFBBF24)],
  );

  /// Blue shimmer — primary interactive gradient
  static const LinearGradient blueShimmer = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3B5A85), Color(0xFF5577A8)],
  );

  /// Navy deep — kept for event date columns, legacy uses
  static const LinearGradient navyDeep = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1D4ED8), Color(0xFF1E40AF)],
  );

  /// Glass card — very subtle surface tint for dark cards
  static const LinearGradient glassCard = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x12FFFFFF), Color(0x06FFFFFF)],
  );

  /// Avatar gradient fallback
  static const LinearGradient avatar = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
  );

  /// Gold accent — chips, badges
  static const LinearGradient gold = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF5A623), Color(0xFFFBBF24)],
  );

  /// Gold border — avatar rings
  static const LinearGradient goldBorder = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF5A623), Color(0xFF3B5A85)],
  );

  /// Soft background — light theme
  static const LinearGradient backgroundSoft = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF1F0F8), Color(0xFFF8F7F3)],
  );

  /// Card tint — light theme featured cards
  static const LinearGradient cardTint = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFFFF), Color(0xFFF1F0F8)],
  );
}

/// Motion / animation — Emil Kowalski–grade curves
///
/// All durations stay under 300 ms for UI elements.
/// Curves replace Flutter's weak built-ins with custom cubic-beziers.
abstract final class FblaMotion {
  // ── Durations ─────────────────────────────────────────────────────────────
  static const Duration press    = Duration(milliseconds: 100);
  static const Duration fast     = Duration(milliseconds: 150);
  static const Duration standard = Duration(milliseconds: 250);
  static const Duration slow     = Duration(milliseconds: 380);

  // ── Custom cubic-bezier curves ────────────────────────────────────────────
  /// Strong ease-out — entering elements, UI interactions.
  /// Equivalent to CSS cubic-bezier(0.23, 1, 0.32, 1).
  static const Curve strongEaseOut = Cubic(0.23, 1.0, 0.32, 1.0);

  /// Strong ease-in-out — reversible state transitions.
  static const Curve strongInOut = Cubic(0.77, 0.0, 0.175, 1.0);

  /// Drawer / sheet slide curve.
  static const Curve drawerCurve = Cubic(0.32, 0.72, 0.0, 1.0);

  /// Spring out — selection pills, chip toggles.
  // Note: Avoid overshooting curves (control y > 1.0) on AnimatedContainers
  // that animate boxShadow — Shadow.lerp can produce negative blurRadius
  // during overshoot, which throws "Text shadow blur radius should be
  // non-negative". This curve is intentionally clamped to [0, 1].
  static const Curve springOut = Cubic(0.34, 1.0, 0.64, 1.0);

  /// Ease-out alias for flutter_animate usage.
  static const Curve easeOut = strongEaseOut;

  /// Decelerate alias.
  static const Curve decelerate = strongEaseOut;
}

// ─────────────────────────────────────────────────────────────────────────────
// Typography helpers — v3 Contender
//
// Josefin Sans: geometric, architectural, competitive. Used for titles, display,
//   screen headers, and stat labels that need visual impact.
// Mulish: warm, readable humanist grotesque. Used for all body text, descriptions,
//   form fields, and anything read at length.
// JetBrains Mono: ONLY for actual data — timestamps, stat numbers, codes, IDs.
//   NOT for UI labels, NOT for buttons, NOT for section headers.
// ─────────────────────────────────────────────────────────────────────────────
abstract final class FblaFonts {
  // ── Font family names ──────────────────────────────────────────────────────
  static String get _josefin => GoogleFonts.josefinSans().fontFamily ?? 'sans-serif';
  static String get _mulish  => GoogleFonts.mulish().fontFamily ?? 'sans-serif';
  static String get mono     => GoogleFonts.jetBrainsMono().fontFamily ?? 'monospace';

  // ── Josefin Sans — display / titles ───────────────────────────────────────

  /// Large display text: screen titles, hero numbers, onboarding headlines.
  static TextStyle display({
    double fontSize = 36,
    FontWeight fontWeight = FontWeight.w700,
    Color? color,
    double letterSpacing = -0.5,
    double? height,
  }) =>
      TextStyle(
        fontFamily: _josefin,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height ?? 1.1,
      );

  /// Section headings, card titles, screen sub-headers.
  static TextStyle heading({
    double fontSize = 18,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
    double letterSpacing = 0.0,
  }) =>
      TextStyle(
        fontFamily: _josefin,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: 1.25,
      );

  // ── Mulish — body / labels ─────────────────────────────────────────────────

  /// Body paragraph text — readable, warm.
  static TextStyle body({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
    double? height,
  }) =>
      TextStyle(
        fontFamily: _mulish,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height ?? 1.6,
      );

  /// UI labels, metadata, chip text — semi-bold Mulish.
  static TextStyle label({
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
    double letterSpacing = 0.1,
  }) =>
      TextStyle(
        fontFamily: _mulish,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: 1.3,
      );

  // ── JetBrains Mono — data values ONLY ─────────────────────────────────────

  /// Data/metadata labels — timestamps, IDs, counters.
  static TextStyle monoLabel({
    double fontSize = 11,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
    double letterSpacing = 0.8,
    double? height,
  }) =>
      TextStyle(
        fontFamily: mono,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );

  /// Prominent stat numbers — profile stats, scores, counts.
  static TextStyle monoStat({
    double fontSize = 22,
    FontWeight fontWeight = FontWeight.w700,
    Color? color,
  }) =>
      TextStyle(
        fontFamily: mono,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: -0.5,
        height: 1.0,
      );

  /// Tiny uppercase tags — category codes, status badges.
  static TextStyle monoTag({
    double fontSize = 9,
    Color? color,
  }) =>
      TextStyle(
        fontFamily: mono,
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 1.2,
        height: 1.0,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Theme builder
// ─────────────────────────────────────────────────────────────────────────────

abstract final class FblaTheme {
  static ThemeData get light {
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: FblaColors.primary,
      onPrimary: FblaColors.onPrimary,
      primaryContainer: FblaColors.accentSoft,
      onPrimaryContainer: FblaColors.primaryDark,
      secondary: FblaColors.secondary,
      onSecondary: FblaColors.onSecondary,
      secondaryContainer: const Color(0xFFFEF3C7),
      onSecondaryContainer: FblaColors.onSecondary,
      tertiary: FblaColors.success,
      onTertiary: FblaColors.onSuccess,
      tertiaryContainer: const Color(0xFFDCFCE7),
      onTertiaryContainer: const Color(0xFF14532D),
      error: FblaColors.error,
      onError: FblaColors.onError,
      errorContainer: const Color(0xFFFEE2E2),
      onErrorContainer: const Color(0xFF7F1D1D),
      surface: FblaColors.surfaceElevated,
      onSurface: FblaColors.textPrimary,
      surfaceContainerHighest: FblaColors.surfaceVariant,
      onSurfaceVariant: FblaColors.textSecondary,
      outline: FblaColors.outline,
      outlineVariant: FblaColors.outlineVariant,
      shadow: FblaColors.shadow,
      scrim: const Color(0x800D0C17),
      inverseSurface: FblaColors.textPrimary,
      onInverseSurface: FblaColors.surface,
      inversePrimary: FblaColors.primaryLight,
    );

    // Mulish as the base body / label font for light theme.
    final base = GoogleFonts.mulishTextTheme();
    final textTheme = _buildTextTheme(base, FblaColors.textPrimary, FblaColors.textSecondary);

    return _buildThemeData(
      brightness: Brightness.light,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBg: FblaColors.background,
      appBarBg: FblaColors.surface,
      appBarFg: FblaColors.textPrimary,
      navBarBg: FblaColors.surface,
      navIndicator: FblaColors.primary.withAlpha(20),
      cardColor: FblaColors.surface,
      inputFill: FblaColors.surfaceVariant,
      inputBorder: FblaColors.outline,
      chipBg: FblaColors.surfaceVariant,
      dividerColor: FblaColors.outlineVariant,
    );
  }

  // ─── Dark theme — primary experience ─────────────────────────────────────────

  static ThemeData get dark {
    final colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: FblaColors.secondary,          // Gold as primary CTA color in dark
      onPrimary: FblaColors.onSecondary,
      primaryContainer: const Color(0xFF1D1C28),
      onPrimaryContainer: FblaColors.darkTextPrimary,
      secondary: FblaColors.primaryLight,     // Electric blue as secondary in dark
      onSecondary: FblaColors.onPrimary,
      secondaryContainer: const Color(0xFF18181F),
      onSecondaryContainer: FblaColors.darkTextPrimary,
      tertiary: FblaColors.success,
      onTertiary: FblaColors.onSuccess,
      tertiaryContainer: const Color(0xFF064E23),
      onTertiaryContainer: const Color(0xFFBBF7D0),
      error: const Color(0xFFFF6B6B),
      onError: const Color(0xFF7F1D1D),
      errorContainer: const Color(0xFF7F1D1D),
      onErrorContainer: const Color(0xFFFECDD3),
      surface: FblaColors.darkSurface,
      onSurface: FblaColors.darkTextPrimary,
      surfaceContainerHighest: FblaColors.darkSurfaceHigh,
      onSurfaceVariant: FblaColors.darkTextSecond,
      outline: FblaColors.darkOutline,
      outlineVariant: FblaColors.darkOutlineVar,
      shadow: const Color(0x66000000),
      scrim: const Color(0xCC000000),
      inverseSurface: FblaColors.darkTextPrimary,
      onInverseSurface: FblaColors.darkSurface,
      inversePrimary: FblaColors.secondary,
    );

    final base = GoogleFonts.mulishTextTheme(ThemeData.dark().textTheme);
    final textTheme = _buildTextTheme(base, FblaColors.darkTextPrimary, FblaColors.darkTextSecond);

    return _buildThemeData(
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBg: FblaColors.darkBg,
      appBarBg: FblaColors.darkSurface,
      appBarFg: FblaColors.darkTextPrimary,
      navBarBg: FblaColors.darkSurface,
      navIndicator: FblaColors.secondary.withAlpha(30),
      cardColor: FblaColors.darkSurface,
      inputFill: FblaColors.darkSurfaceHigh,
      inputBorder: FblaColors.darkOutline,
      chipBg: FblaColors.darkSurfaceHigh,
      dividerColor: FblaColors.darkOutlineVar,
    );
  }

  // ─── Shared builders ─────────────────────────────────────────────────────────

  static TextTheme _buildTextTheme(TextTheme base, Color primary, Color secondary) {
    // Josefin Sans for high-impact display / headline sizes.
    // Geometric, architectural, distinctly competitive — makes screens feel designed.
    final display = GoogleFonts.josefinSans().fontFamily;
    // Mulish handles body / label — warm, readable, humanist.
    // base is already Mulish (from GoogleFonts.mulishTextTheme()).

    return base.copyWith(
      // ── Display — Josefin Sans ────────────────────────────────────────────
      displayLarge:  base.displayLarge?.copyWith(
        fontFamily: display, fontSize: 57, fontWeight: FontWeight.w700,
        letterSpacing: -1.5, color: primary, height: 1.05,
      ),
      displayMedium: base.displayMedium?.copyWith(
        fontFamily: display, fontSize: 45, fontWeight: FontWeight.w700,
        letterSpacing: -1.2, color: primary, height: 1.1,
      ),
      // ── Headlines — Josefin Sans ──────────────────────────────────────────
      headlineLarge: base.headlineLarge?.copyWith(
        fontFamily: display, fontSize: 32, fontWeight: FontWeight.w700,
        letterSpacing: -0.5, color: primary, height: 1.15,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontFamily: display, fontSize: 26, fontWeight: FontWeight.w700,
        letterSpacing: -0.3, color: primary, height: 1.2,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontFamily: display, fontSize: 20, fontWeight: FontWeight.w600,
        letterSpacing: -0.2, color: primary, height: 1.2,
      ),
      // ── Titles — Josefin Sans (large) / Mulish (small) ───────────────────
      titleLarge:  base.titleLarge?.copyWith(
        fontFamily: display, fontSize: 18, fontWeight: FontWeight.w600,
        letterSpacing: -0.1, color: primary,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.1, color: primary,
      ),
      titleSmall:  base.titleSmall?.copyWith(
        fontSize: 14, fontWeight: FontWeight.w700, color: primary,
      ),
      // ── Body — Mulish ─────────────────────────────────────────────────────
      bodyLarge:  base.bodyLarge?.copyWith(
        fontSize: 16, fontWeight: FontWeight.w400, color: primary, height: 1.65,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 14, fontWeight: FontWeight.w400, color: secondary, height: 1.6,
      ),
      bodySmall:  base.bodySmall?.copyWith(
        fontSize: 12, fontWeight: FontWeight.w400, color: secondary, height: 1.5,
      ),
      // ── Labels — Mulish ───────────────────────────────────────────────────
      labelLarge:  base.labelLarge?.copyWith(
        fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.3, color: primary,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.2, color: secondary,
      ),
      labelSmall:  base.labelSmall?.copyWith(
        fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: secondary,
      ),
    );
  }

  static ThemeData _buildThemeData({
    required Brightness brightness,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
    required Color scaffoldBg,
    required Color appBarBg,
    required Color appBarFg,
    required Color navBarBg,
    required Color navIndicator,
    required Color cardColor,
    required Color inputFill,
    required Color inputBorder,
    required Color chipBg,
    required Color dividerColor,
  }) {
    final isDark = brightness == Brightness.dark;
    // In dark mode: electric blue for interactive focus; gold for CTAs.
    // In light mode: electric blue throughout.
    final interactiveColor = isDark ? FblaColors.primaryLight : FblaColors.primary;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: scaffoldBg,

      appBarTheme: AppBarTheme(
        backgroundColor: appBarBg,
        foregroundColor: appBarFg,
        elevation: 0,
        scrolledUnderElevation: isDark ? 0 : 0.5,
        shadowColor: isDark ? Colors.transparent : FblaColors.shadow,
        titleTextStyle: TextStyle(
          fontFamily: GoogleFonts.josefinSans().fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
          color: appBarFg,
        ),
        iconTheme: IconThemeData(
          color: interactiveColor,
          size: 22,
        ),
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: navBarBg,
        indicatorColor: navIndicator,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            color: selected
                ? (isDark ? FblaColors.secondary : FblaColors.primary)
                : (isDark ? FblaColors.darkTextSecond : FblaColors.textSecondary),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected
                ? (isDark ? FblaColors.secondary : FblaColors.primary)
                : (isDark ? FblaColors.darkTextSecond : FblaColors.textSecondary),
          );
        }),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: navBarBg,
        selectedItemColor: isDark ? FblaColors.secondary : FblaColors.primary,
        unselectedItemColor: isDark ? FblaColors.darkTextTertiary : FblaColors.textDisabled,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
      ),

      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FblaRadius.lg),
          side: BorderSide(
            color: isDark ? FblaColors.darkOutlineVar : FblaColors.outlineVariant,
            width: 1,
          ),
        ),
        margin: EdgeInsets.zero,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          // Gold for CTAs in both modes — achievement color
          backgroundColor: FblaColors.secondary,
          foregroundColor: FblaColors.onSecondary,
          disabledBackgroundColor: isDark ? FblaColors.darkOutline : FblaColors.outline,
          disabledForegroundColor: isDark ? FblaColors.darkTextTertiary : FblaColors.textDisabled,
          elevation: 0,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FblaRadius.md)),
          textStyle: TextStyle(
            fontFamily: GoogleFonts.josefinSans().fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
          padding: const EdgeInsets.symmetric(horizontal: FblaSpacing.lg),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: interactiveColor,
          side: BorderSide(color: interactiveColor, width: 1.5),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FblaRadius.md)),
          textStyle: TextStyle(
            fontFamily: GoogleFonts.josefinSans().fontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
          padding: const EdgeInsets.symmetric(horizontal: FblaSpacing.lg),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: interactiveColor,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          padding: const EdgeInsets.symmetric(horizontal: FblaSpacing.md, vertical: FblaSpacing.sm),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FblaRadius.sm)),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: FblaSpacing.md, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FblaRadius.md),
          borderSide: BorderSide(color: inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FblaRadius.md),
          borderSide: BorderSide(color: inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FblaRadius.md),
          borderSide: BorderSide(color: interactiveColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FblaRadius.md),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FblaRadius.md),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
        ),
        labelStyle: TextStyle(fontSize: 14, color: isDark ? FblaColors.darkTextSecond : FblaColors.textSecondary),
        hintStyle: TextStyle(fontSize: 14, color: isDark ? FblaColors.darkTextTertiary : FblaColors.textDisabled),
        errorStyle: const TextStyle(fontSize: 12, color: Color(0xFFEF4444)),
        floatingLabelStyle: TextStyle(
          fontSize: 12,
          color: interactiveColor,
          fontWeight: FontWeight.w600,
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: chipBg,
        selectedColor: isDark
            ? FblaColors.primaryLight.withAlpha(30)
            : FblaColors.primary.withAlpha(18),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isDark ? FblaColors.darkTextPrimary : FblaColors.textPrimary,
        ),
        padding: const EdgeInsets.symmetric(horizontal: FblaSpacing.sm, vertical: FblaSpacing.xxs),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FblaRadius.full),
          side: BorderSide(color: isDark ? FblaColors.darkOutlineVar : FblaColors.outlineVariant),
        ),
      ),

      dividerTheme: DividerThemeData(color: dividerColor, thickness: 1, space: 1),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: FblaColors.secondary,
        foregroundColor: FblaColors.onSecondary,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FblaRadius.md)),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? FblaColors.darkSurfaceHigh : FblaColors.textPrimary,
        contentTextStyle: TextStyle(
          color: isDark ? FblaColors.darkTextPrimary : Colors.white,
          fontSize: 14,
        ),
        actionTextColor: FblaColors.secondary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FblaRadius.sm)),
      ),
    );
  }
}
