/// Reusable UI pieces for password entry:
///   • [PasswordRequirementsChecklist] — live list of rules that tick off as
///     the user types.
///   • [ShyEyesMascot] — a small padlock badge that sits beside the password
///     field. Closes with a gentle bounce while the password is hidden and
///     unlocks with a soft glow when the user taps "show password". Pure
///     delight, zero external deps.
library;

import 'package:flutter/material.dart';

import '../services/password_policy.dart';
import '../theme/app_theme.dart';

// ─── Requirements checklist ───────────────────────────────────────────────────

/// Shows each password rule with an icon that animates from an outlined
/// circle to a filled check as the rule is satisfied.
///
/// Reactive to [value] — pass the current controller text and rebuild on
/// change. Keeps its own layout compact enough to sit directly under a
/// [TextFormField].
class PasswordRequirementsChecklist extends StatelessWidget {
  const PasswordRequirementsChecklist({
    super.key,
    required this.value,
    this.confirmValue,
    this.padding = const EdgeInsets.only(top: FblaSpacing.sm, left: 4),
  });

  final String value;

  /// When provided, an additional "Passwords match" row appears at the
  /// bottom of the checklist. The row is considered satisfied when both
  /// values are non-empty AND exactly equal.
  final String? confirmValue;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final confirm = confirmValue;
    final matches =
        confirm != null && confirm.isNotEmpty && confirm == value;

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final rule in passwordRules)
            _ChecklistRow(
              label: rule.label,
              satisfied: rule.test(value),
            ),
          if (confirm != null)
            _ChecklistRow(
              label: 'Passwords match',
              satisfied: matches,
            ),
        ],
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.label, required this.satisfied});

  final String label;
  final bool satisfied;

  @override
  Widget build(BuildContext context) {
    final Color met = FblaColors.success;
    final Color unmet = FblaColors.darkTextSecond;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Animated icon: circle-outline ↔ filled check, with a tiny scale
          // bounce so ticking a rule feels rewarding.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: anim,
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: satisfied
                ? Icon(
                    Icons.check_circle_rounded,
                    key: const ValueKey('met'),
                    size: 16,
                    color: met,
                  )
                : Icon(
                    Icons.radio_button_unchecked_rounded,
                    key: const ValueKey('unmet'),
                    size: 16,
                    color: unmet.withValues(alpha: 0.6),
                  ),
          ),
          const SizedBox(width: 8),
          // Label — color + weight shift when satisfied.
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            style: FblaFonts.body(
              fontSize: 12.5,
              fontWeight: satisfied ? FontWeight.w600 : FontWeight.w500,
              color: satisfied ? met : unmet,
            ),
            child: Text(label),
          ),
        ],
      ),
    );
  }
}

// ─── Padlock mascot ───────────────────────────────────────────────────────────

/// A small padlock icon shown in the prefix slot of a password field.
/// Renders as a clean inline icon — no background box, no border — so it
/// sits flush inside the field's own frame. State is communicated purely
/// through icon swap + color tint + tiny scale bounce.
///
/// Semantic: the lock **closes** once the password meets every
/// requirement, and stays **open** until then. This makes the mascot read
/// as a live "strength gate": users see it click shut as a clear signal
/// that they've hit the bar.
///
/// Kept the original class name ([ShyEyesMascot]) for call-site stability.
class ShyEyesMascot extends StatelessWidget {
  const ShyEyesMascot({
    super.key,
    required this.locked,
    required this.focused,
    this.size = 30,
  });

  /// True when the password (or, for the confirm field, both values)
  /// satisfies every rule — the lock clicks shut.
  final bool locked;

  /// True when the field currently has focus. Drives a subtle gold tint
  /// while the user is still working on meeting the bar.
  final bool focused;

  /// Target icon size (the icon is rendered at ~85% of this value).
  final double size;

  @override
  Widget build(BuildContext context) {
    // Compose a compact state key so the TweenAnimationBuilder below
    // re-pulses on any visual change.
    final stateKey = '${locked ? 'L' : 'U'}${focused ? 'F' : 'B'}';

    final Color iconColor;
    if (locked) {
      iconColor = FblaColors.success;
    } else if (focused) {
      iconColor = FblaColors.primary;
    } else {
      iconColor = FblaColors.darkTextSecond;
    }

    final icon = locked ? Icons.lock_rounded : Icons.lock_open_rounded;

    // Emil-style easeOut — cubic-bezier(0.23, 1, 0.32, 1). Stronger than
    // Curves.easeOut, no bounce.
    const emilEaseOut = Cubic(0.23, 1, 0.32, 1);

    // A gentle scale pulse on state change: rest at 1.0, dip to 0.9 on
    // switch, back to 1.0 immediately. Uses TweenAnimationBuilder keyed
    // on state so each state change triggers one fresh pulse.
    return TweenAnimationBuilder<double>(
      key: ValueKey(stateKey),
      tween: Tween(begin: 0.88, end: 1.0),
      duration: const Duration(milliseconds: 180),
      curve: emilEaseOut,
      builder: (context, scale, child) => Transform.scale(
        scale: scale,
        child: child,
      ),
      // Icon cross-fade: swap between lock / lock_open with a quick
      // fade + tiny scale, no bounce.
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 160),
        switchInCurve: emilEaseOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.85, end: 1.0).animate(anim),
            child: child,
          ),
        ),
        child: Icon(
          icon,
          key: ValueKey(icon),
          size: size * 0.86,
          color: iconColor,
        ),
      ),
    );
  }
}
