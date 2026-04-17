import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A custom [PageRoute] that combines a fade + subtle upward slide transition.
///
/// Usage:
/// ```dart
/// Navigator.of(context).push(FblaPageRoute(builder: (_) => SomeScreen()));
/// ```
class FblaPageRoute<T> extends PageRouteBuilder<T> {
  FblaPageRoute({required WidgetBuilder builder, super.settings})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionDuration: FblaMotion.standard,
          reverseTransitionDuration: FblaMotion.fast,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Fade
            final fade = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            );

            // Slide upward (begin slightly below, end at 0)
            final slide = Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: FblaMotion.easeOut,
            ));

            return FadeTransition(
              opacity: fade,
              child: SlideTransition(
                position: slide,
                child: child,
              ),
            );
          },
        );
}
