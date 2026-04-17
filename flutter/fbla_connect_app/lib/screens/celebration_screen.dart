import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/share_service.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Celebration Screen — shown after publishing a post, event, or announcement.
//
//   X / Twitter button → url_launcher opens X directly with text (no image).
//
//   Share button → Web Share API equivalent (iOS UIActivityViewController).
//     If the post has an image, downloads it and attaches it to the share
//     sheet so it actually appears in Messages, AirDrop, etc.
//     If no image, shares text only via the same native share sheet.
// ─────────────────────────────────────────────────────────────────────────────

class CelebrationScreen extends StatefulWidget {
  const CelebrationScreen({
    super.key,
    required this.contentType,
    required this.contentId,
    required this.content,
  });

  final String contentType;
  final String contentId;
  final Map<String, dynamic> content;

  @override
  State<CelebrationScreen> createState() => _CelebrationScreenState();
}

class _CelebrationScreenState extends State<CelebrationScreen> {
  final _share = ShareService.instance;
  final Set<String> _sharedPlatforms = {};
  bool _downloading = false;

  ShareContentType get _shareType => switch (widget.contentType) {
    'post' => ShareContentType.post,
    'event' => ShareContentType.event,
    'announcement' => ShareContentType.announcement,
    _ => ShareContentType.post,
  };

  String get _subline => switch (widget.contentType) {
        'event' => 'Your event is now live for your community.',
        'announcement' => 'Your announcement is now live.',
        _ => 'Your post is now live.',
      };

  String get _text => _share.generateShareText(
    type: _shareType,
    content: widget.content,
  );

  /// The post's uploaded image URL (if any).
  String? get _mediaUrl {
    final raw = widget.content['media_url'];
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    return null;
  }

  bool get _hasImage => _mediaUrl != null;

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg, style: const TextStyle(fontFamily: 'Mulish')),
          backgroundColor: FblaColors.darkSurface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FblaRadius.md),
          ),
        ),
      );
  }

  void _markShared(String platform) {
    setState(() => _sharedPlatforms.add(platform));
    _share.trackShare(
      type: _shareType,
      contentId: widget.contentId,
      platform: platform,
    );
    HapticFeedback.lightImpact();
  }

  // ── X / Twitter ───────────────────────────────────────────────────────────

  Future<void> _onXTapped() async {
    // No image on this post → just do text, no choice needed
    if (!_hasImage) {
      await _xTextOnly();
      return;
    }

    // Has image → show choice: "Text" or "Text + Image"
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? FblaColors.darkOverlay : FblaColors.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(
            top: BorderSide(
              color: isDark ? FblaColors.darkOutline : FblaColors.outline,
            ),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark
                    ? FblaColors.darkOutlineVar
                    : FblaColors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text('Post to X', style: FblaFonts.heading(fontSize: 17)),
            const SizedBox(height: 4),
            Text(
              'Choose how to share',
              style: FblaFonts.body(fontSize: 13).copyWith(
                color: isDark
                    ? FblaColors.darkTextTertiary
                    : FblaColors.textTertiary,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _ChoiceButton(
                    icon: Icons.short_text_rounded,
                    label: 'Text',
                    sublabel: 'Opens X with text',
                    onTap: () {
                      Navigator.pop(ctx);
                      _xTextOnly();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ChoiceButton(
                    icon: Icons.image_rounded,
                    label: 'Text + Image',
                    sublabel: 'Opens X',
                    onTap: () {
                      Navigator.pop(ctx);
                      _xWithImage();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Text → opens X directly with the share text pre-filled.
  Future<void> _xTextOnly() async {
    final result = await _share.shareToXText(text: _text);
    if (result.success) {
      _markShared('twitter');
      if (result.message != null) _toast(result.message!);
    } else if (!result.canceled) {
      _toast(result.message ?? 'Couldn\u2019t open X');
    }
  }

  /// Text + Image → just redirects to X, nothing else.
  Future<void> _xWithImage() async {
    final uri = Uri.parse('https://twitter.com');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    _markShared('twitter');
  }

  // ── Share (Web Share API = iOS UIActivityViewController) ──────────────────
  //
  // If the post has an image, download it and attach it to the share sheet
  // so the recipient actually sees the photo. Otherwise, text-only share.

  Future<void> _onShareTapped() async {
    if (_hasImage) {
      setState(() => _downloading = true);

      final imagePath = await _share.downloadImageToTemp(_mediaUrl!);

      if (!mounted) return;
      setState(() => _downloading = false);

      if (imagePath != null) {
        final result = await _share.shareWithImage(
          text: _text,
          imagePath: imagePath,
        );
        if (result.success) {
          _markShared('native');
          if (result.message != null) _toast(result.message!);
        } else if (!result.canceled) {
          _toast(result.message ?? 'Couldn\u2019t open share sheet');
        }
        return;
      }
      // Image download failed — fall through to text-only
    }

    final result = await _share.shareText(text: _text);
    if (result.success) {
      _markShared('native');
      if (result.message != null) _toast(result.message!);
    } else if (!result.canceled) {
      _toast(result.message ?? 'Couldn\u2019t open share sheet');
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? FblaColors.darkBg : FblaColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final topSpace = (constraints.maxHeight * 0.14).clamp(32.0, 96.0);

            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                children: [
                  SizedBox(height: topSpace),

                  // ── Gold checkmark ────────────────────────────────────────
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: FblaGradient.gold,
                      boxShadow: FblaShadow.goldGlow,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 36,
                      color: FblaColors.onSecondary,
                    ),
                  )
                      .animate()
                      .scale(
                        begin: const Offset(0.82, 0.82),
                        end: const Offset(1, 1),
                        duration: FblaMotion.standard,
                        curve: FblaMotion.strongEaseOut,
                      )
                      .fadeIn(duration: FblaMotion.standard),

                  const SizedBox(height: 28),

                  Text('Published', style: FblaFonts.display())
                      .animate(delay: 100.ms)
                      .fadeIn(duration: 200.ms, curve: FblaMotion.strongEaseOut)
                      .moveY(begin: 8, end: 0, duration: 200.ms),

                  const SizedBox(height: 10),

                  Text(
                    _subline,
                    style: FblaFonts.body().copyWith(
                      fontSize: 15,
                      height: 1.45,
                      color: isDark
                          ? FblaColors.darkTextSecond
                          : FblaColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  )
                      .animate(delay: 250.ms)
                      .fadeIn(duration: 200.ms, curve: FblaMotion.strongEaseOut)
                      .moveY(begin: 6, end: 0, duration: 200.ms),

                  const Spacer(flex: 2),

                  // ── Downloading indicator ─────────────────────────────────
                  if (_downloading) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: FblaColors.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Preparing image…',
                          style: FblaFonts.body(fontSize: 12).copyWith(
                            color: isDark
                                ? FblaColors.darkTextSecond
                                : FblaColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  Text(
                    'SHARE WITH YOUR COMMUNITY',
                    style: FblaFonts.label().copyWith(
                      color: isDark
                          ? FblaColors.darkTextTertiary
                          : FblaColors.textTertiary,
                      letterSpacing: 1.2,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                      .animate(delay: 350.ms)
                      .fadeIn(duration: 200.ms),

                  const SizedBox(height: 16),

                  // ── Share cards ───────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: _ShareCard(
                          icon: Icons.alternate_email_rounded,
                          label: 'X / Twitter',
                          sublabel: _hasImage ? 'Text or image' : 'Post',
                          isShared: _sharedPlatforms.contains('twitter'),
                          onTap: _downloading ? null : _onXTapped,
                          delay: 400,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ShareCard(
                          icon: Icons.ios_share_rounded,
                          label: 'Share',
                          sublabel: 'Share',
                          isShared: _sharedPlatforms.contains('native'),
                          onTap: _downloading ? null : _onShareTapped,
                          delay: 450,
                        ),
                      ),
                    ],
                  ),

                  const Spacer(flex: 1),

                  // ── Done button ───────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(context).pop();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark
                            ? FblaColors.darkTextPrimary
                            : FblaColors.textPrimary,
                        side: BorderSide(
                          color: (isDark
                                  ? FblaColors.darkOutline
                                  : FblaColors.outline)
                              .withOpacity(0.9),
                          width: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(FblaRadius.md),
                        ),
                        backgroundColor: isDark
                            ? FblaColors.darkSurface
                            : FblaColors.surface,
                      ),
                      child: Text(
                        'Done',
                        style: FblaFonts.label().copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  )
                      .animate(delay: 550.ms)
                      .fadeIn(
                        duration: 220.ms,
                        curve: FblaMotion.strongEaseOut,
                      )
                      .moveY(begin: 6, end: 0, duration: 220.ms),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Choice Button (X bottom sheet)
// ─────────────────────────────────────────────────────────────────────────────

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String sublabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: isDark ? FblaColors.darkSurfaceHigh : FblaColors.surfaceVariant,
          borderRadius: BorderRadius.circular(FblaRadius.lg),
          border: Border.all(
            color: isDark ? FblaColors.darkOutline : FblaColors.outline,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 26, color: isDark ? FblaColors.darkTextPrimary : FblaColors.textPrimary),
            const SizedBox(height: 8),
            Text(label, style: FblaFonts.label().copyWith(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 2),
            Text(
              sublabel,
              style: FblaFonts.label().copyWith(
                fontSize: 11,
                color: isDark ? FblaColors.darkTextTertiary : FblaColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Share Card — tappable platform option with press feedback
// ─────────────────────────────────────────────────────────────────────────────

class _ShareCard extends StatefulWidget {
  const _ShareCard({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.isShared,
    required this.onTap,
    required this.delay,
  });

  final IconData icon;
  final String label;
  final String sublabel;
  final bool isShared;
  final VoidCallback? onTap;
  final int delay;

  @override
  State<_ShareCard> createState() => _ShareCardState();
}

class _ShareCardState extends State<_ShareCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _pressScale;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 160),
    );
    _pressScale = Tween<double>(begin: 1, end: 0.97).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final disabled = widget.onTap == null;

    return AnimatedBuilder(
      animation: _pressScale,
      builder: (context, child) => Transform.scale(
        scale: _pressScale.value,
        child: child,
      ),
      child: GestureDetector(
        onTapDown: disabled ? null : (_) => _pressCtrl.forward(),
        onTapUp: disabled
            ? null
            : (_) {
                _pressCtrl.reverse();
                widget.onTap!();
              },
        onTapCancel: () => _pressCtrl.reverse(),
        child: Opacity(
          opacity: disabled ? 0.5 : 1.0,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
            decoration: BoxDecoration(
              color: isDark ? FblaColors.darkSurface : FblaColors.surface,
              borderRadius: BorderRadius.circular(FblaRadius.lg),
              border: Border.all(
                color: isDark ? FblaColors.darkOutline : FblaColors.outline,
              ),
            ),
            child: Stack(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.icon,
                      size: 28,
                      color: isDark
                          ? FblaColors.darkTextPrimary
                          : FblaColors.textPrimary,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.label,
                      style: FblaFonts.label().copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.sublabel,
                      style: FblaFonts.label().copyWith(
                        fontSize: 11,
                        color: isDark
                            ? FblaColors.darkTextTertiary
                            : FblaColors.textTertiary,
                      ),
                    ),
                  ],
                ),
                if (widget.isShared)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: FblaColors.secondary,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 10,
                        color: FblaColors.onSecondary,
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 200.ms)
                        .scale(
                          begin: const Offset(0.8, 0.8),
                          end: const Offset(1, 1),
                          duration: 200.ms,
                          curve: FblaMotion.strongEaseOut,
                        ),
                  ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: widget.delay))
        .fadeIn(duration: 250.ms, curve: FblaMotion.strongEaseOut)
        .moveY(begin: 10, end: 0, duration: 250.ms);
  }
}
