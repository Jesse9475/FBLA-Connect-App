import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shared gradient AppBar used across every top-level screen.
///
/// Features the FBLA brand gradient, a refined gold "FC" badge, and M3-correct
/// scroll behaviour. Drop-in replacement for all five inline copies.
///
/// ```dart
/// appBar: const FblaAppBar()                        // home — shows badge + wordmark
/// appBar: const FblaAppBar(title: Text('Events'))   // section screen
/// appBar: FblaAppBar(
///   title: const Text('Profile'),
///   actions: [IconButton(...)],
/// )
/// ```
class FblaAppBar extends StatelessWidget implements PreferredSizeWidget {
  const FblaAppBar({
    super.key,
    this.title,
    this.actions,
    this.bottom,
    this.centerTitle = false,
    this.showBrandBadge = true,
  });

  /// Override the default branded Row title with any widget.
  final Widget? title;

  /// Optional trailing action icons.
  final List<Widget>? actions;

  /// Optional [PreferredSizeWidget] shown below the bar (e.g. [TabBar]).
  final PreferredSizeWidget? bottom;

  /// Centre the title. Defaults to false (left-aligned, M3 style).
  final bool centerTitle;

  /// Show the gold FC badge before the title text.
  final bool showBrandBadge;

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    final effectiveTitle = title ??
        Row(
          children: [
            // ── Logo icon ─────────────────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Image.asset(
                'assets/images/logo_48.png',
                width: 30,
                height: 30,
                filterQuality: FilterQuality.high,
              ),
            ),
            const SizedBox(width: FblaSpacing.sm),
            Text(
              'FBLA',
              style: FblaFonts.heading(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 3),
            Text(
              'Connect',
              style: FblaFonts.heading(
                fontSize: 19,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.75),
                letterSpacing: -0.1,
              ),
            ),
          ],
        );

    return AppBar(
      title: effectiveTitle,
      centerTitle: centerTitle,
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      bottom: bottom,
      actions: [
        if (actions != null) ...actions!,
        const SizedBox(width: FblaSpacing.xs),
      ],
      // Gradient fills behind the status bar + toolbar
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: FblaGradient.brand,
        ),
      ),
    );
  }
}

/// Public logo badge for use on Splash, Login, and any screen that needs
/// the FBLA Connect icon mark.
class FblaFcBadge extends StatelessWidget {
  const FblaFcBadge({super.key, this.size = 32});
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
        child: Image.asset(
          'assets/images/logo_64.png',
          width: size,
          height: size,
          filterQuality: FilterQuality.high,
        ),
      );
}
