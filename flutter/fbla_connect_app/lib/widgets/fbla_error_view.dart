import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Reusable error state widget shown when an API call fails.
///
/// Dark-first: uses error-tinted icon container with dark-mode text colors.
/// Pairs with [FblaEmptyView] in visual style.
///
/// ```dart
/// FblaErrorView(message: _error!, onRetry: _load)
///
/// FblaErrorView(
///   icon: Icons.wifi_off_outlined,
///   message: 'No internet connection.',
///   retryLabel: 'Reconnect',
///   onRetry: _load,
/// )
/// ```
class FblaErrorView extends StatelessWidget {
  const FblaErrorView({
    super.key,
    required this.message,
    required this.onRetry,
    this.icon = Icons.cloud_off_outlined,
    this.retryLabel = 'Try again',
  });

  final String message;
  final VoidCallback onRetry;
  final IconData icon;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Error: $message',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(FblaSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Error-tinted icon container — dark-first
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: FblaColors.error.withAlpha(18),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: FblaColors.error.withAlpha(40),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 36,
                  color: FblaColors.error,
                ),
              ),

              const SizedBox(height: FblaSpacing.md + 4),

              Text(
                'Something went wrong',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: FblaColors.darkTextPrimary,
                      letterSpacing: -0.2,
                    ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: FblaSpacing.sm),

              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: FblaColors.darkTextSecond,
                      height: 1.5,
                    ),
              ),

              const SizedBox(height: FblaSpacing.lg),

              SizedBox(
                width: 160,
                child: OutlinedButton.icon(
                  onPressed: onRetry,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    foregroundColor: FblaColors.secondary,
                    side: BorderSide(
                      color: FblaColors.secondary.withAlpha(120),
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(FblaRadius.md),
                    ),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: Text(
                    retryLabel,
                    style: FblaFonts.monoTag(
                      fontSize: 10,
                      color: FblaColors.secondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
