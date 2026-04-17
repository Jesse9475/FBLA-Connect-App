import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Section title with an optional "See all" link.
///
/// Typography carries hierarchy — no left accent strip.
/// Title uses Josefin Sans (heading weight); "See all" uses Mulish label
/// in electric blue (interactive state, not gold).
///
/// ```dart
/// SectionHeader(title: 'Announcements')
/// SectionHeader(title: 'Upcoming Events', onSeeAll: () { ... })
/// SectionHeader(title: 'Recent', subtitle: '12 posts this week')
/// ```
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.onSeeAll,
    this.subtitle,
  });

  final String title;
  final VoidCallback? onSeeAll;

  /// Optional descriptive line below the title.
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FblaSpacing.md,
        FblaSpacing.lg,
        FblaSpacing.sm,
        FblaSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Title (+ optional subtitle)
          Expanded(
            child: subtitle != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: FblaFonts.heading(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: FblaColors.darkTextPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: FblaFonts.label(
                          fontSize: 11,
                          color: FblaColors.darkTextSecond,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  )
                : Text(
                    title,
                    style: FblaFonts.heading(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: FblaColors.darkTextPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
          ),

          // "See all" link — electric blue (interactive state)
          if (onSeeAll != null)
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onSeeAll!();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: FblaSpacing.sm,
                  vertical: 4,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'See all',
                      style: FblaFonts.label(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: FblaColors.primaryLight,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 13,
                      color: FblaColors.primaryLight,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
