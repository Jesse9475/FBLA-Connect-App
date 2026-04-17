import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Reusable empty-state widget shown when a list has no items.
///
/// Dark-first: uses gold-accented circle instead of surfaceContainerHighest
/// so it reads correctly on the app's deep-navy dark background.
///
/// ```dart
/// FblaEmptyView(
///   icon: Icons.event_available_outlined,
///   title: 'No events yet',
///   subtitle: 'Check back soon for upcoming chapter events.',
/// )
///
/// FblaEmptyView(
///   icon: Icons.article_outlined,
///   title: 'No posts yet',
///   subtitle: 'Be the first to share something.',
///   actionLabel: 'Create post',
///   onAction: _showNewPostSheet,
/// )
/// ```
class FblaEmptyView extends StatelessWidget {
  const FblaEmptyView({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    assert(
      (actionLabel == null) == (onAction == null),
      'actionLabel and onAction must both be provided or both omitted.',
    );

    return Semantics(
      liveRegion: true,
      label: subtitle != null ? '$title. $subtitle' : title,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(FblaSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Gold-accented icon circle — dark-first design
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: FblaColors.secondary.withAlpha(15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: FblaColors.secondary.withAlpha(45),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 36,
                  color: FblaColors.secondary,
                ),
              ),

              const SizedBox(height: FblaSpacing.md + 4),

              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: FblaColors.darkTextPrimary,
                    ),
                textAlign: TextAlign.center,
              ),

              if (subtitle != null) ...[
                const SizedBox(height: FblaSpacing.sm),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        height: 1.5,
                        color: FblaColors.darkTextSecond,
                      ),
                ),
              ],

              if (actionLabel != null) ...[
                const SizedBox(height: FblaSpacing.lg),
                SizedBox(
                  width: 200,
                  child: ElevatedButton(
                    onPressed: onAction,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      backgroundColor: FblaColors.secondary,
                      foregroundColor: FblaColors.primaryDark,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(FblaRadius.md),
                      ),
                    ),
                    child: Text(
                      actionLabel!,
                      style: FblaFonts.monoTag(
                        fontSize: 11,
                        color: FblaColors.primaryDark,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
