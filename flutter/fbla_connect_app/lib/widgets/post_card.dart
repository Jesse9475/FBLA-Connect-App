import 'dart:convert';
import 'dart:ui'; // BackdropFilter used in modal bottom sheets (valid use)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../services/share_service.dart';
import '../theme/app_theme.dart';

/// Card displaying a member post with like action.
///
/// Single-surface clean card — no double bezel, no navy tints.
/// Uses Josefin Sans for author name, Mulish for body text.
class PostCard extends StatefulWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.onLike,
  });

  final Map<String, dynamic> post;
  final VoidCallback onLike;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> with TickerProviderStateMixin {
  static const _storage = FlutterSecureStorage();
  static const _bookmarkKey = 'bookmarked_post_ids';

  bool _liked = false;
  bool _bookmarked = false;
  late final AnimationController _likeCtrl;
  late final Animation<double> _likeScale;
  late final AnimationController _bookmarkCtrl;
  late final Animation<double> _bookmarkScale;

  // Press-scale feedback (Emil Kowalski: 100ms press / 200ms release)
  late final AnimationController _pressCtrl;
  late final Animation<double> _pressScale;

  // Backend schema uses 'caption' for post text content.
  String get _body => widget.post['caption'] as String? ?? '';
  int get _likeCount => (widget.post['like_count'] as int?) ?? 0;
  String get _userId => widget.post['user_id'] as String? ?? '';
  String get _postId => widget.post['id']?.toString() ?? '';

  /// Prefer `first_name`, fall back to `display_name` or `author_name`
  String get _authorName {
    final first = widget.post['first_name'] as String?;
    if (first != null && first.isNotEmpty) return first;
    final display = widget.post['display_name'] as String?;
    if (display != null && display.isNotEmpty) return display;
    final author = widget.post['author_name'] as String?;
    if (author != null && author.isNotEmpty) return author;
    return '';
  }

  DateTime? get _createdAt =>
      DateTime.tryParse(widget.post['created_at'] as String? ?? '');

  bool get _isOwn {
    final me = Supabase.instance.client.auth.currentUser?.id;
    return widget.post['user_id'] == me;
  }

  /// Derive a deterministic avatar background color from the user id's hash.
  Color get _avatarColor {
    final hue = (_userId.hashCode.abs() % 360).toDouble();
    return HSLColor.fromAHSL(1.0, hue, 0.55, 0.38).toColor();
  }

  String get _avatarInitial {
    if (_isOwn) {
      final email = Supabase.instance.client.auth.currentUser?.email ?? '';
      return email.isNotEmpty ? email[0].toUpperCase() : 'Y';
    }
    if (_authorName.isNotEmpty) return _authorName[0].toUpperCase();
    return 'M';
  }

  String get _displayLabel {
    if (_isOwn) return 'You';
    if (_authorName.isNotEmpty) return _authorName;
    return 'Chapter Member';
  }

  @override
  void initState() {
    super.initState();
    _likeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    // Spring-like: grow, overshoot, settle — feels snappy not linear
    _likeScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 45),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 0.88), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.88, end: 1.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _likeCtrl, curve: Curves.easeOut));

    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _pressScale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _pressCtrl, curve: FblaMotion.strongEaseOut),
    );

    _bookmarkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _bookmarkScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 45),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 0.92), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.92, end: 1.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _bookmarkCtrl, curve: Curves.easeOut));

    _loadBookmark();
  }

  Future<List<String>> _readBookmarks() async {
    try {
      final raw = await _storage.read(key: _bookmarkKey);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> _loadBookmark() async {
    if (_postId.isEmpty) return;
    final ids = await _readBookmarks();
    if (mounted) setState(() => _bookmarked = ids.contains(_postId));
  }

  Future<void> _toggleBookmark() async {
    if (_postId.isEmpty) return;
    HapticFeedback.lightImpact();
    final ids = await _readBookmarks();
    final wasBookmarked = ids.contains(_postId);
    if (wasBookmarked) {
      ids.remove(_postId);
    } else {
      ids.add(_postId);
    }
    await _storage.write(key: _bookmarkKey, value: jsonEncode(ids));
    if (!mounted) return;
    setState(() => _bookmarked = !wasBookmarked);
    _bookmarkCtrl.forward(from: 0);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          wasBookmarked ? 'Removed from saved' : 'Saved post',
          style: FblaFonts.body(fontSize: 13),
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _likeCtrl.dispose();
    _pressCtrl.dispose();
    _bookmarkCtrl.dispose();
    super.dispose();
  }

  void _handleLike() {
    if (_liked) return;
    HapticFeedback.lightImpact();
    setState(() => _liked = true);
    _likeCtrl.forward(from: 0);
    widget.onLike();
  }

  void _handleLongPress() {
    HapticFeedback.mediumImpact();
    _showActionsSheet();
  }

  void _showActionsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _PostActionsSheet(post: widget.post),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: _handleLongPress,
      onTapDown: (_) => _pressCtrl.forward(),
      onTapUp: (_) => _pressCtrl.reverse(),
      onTapCancel: () => _pressCtrl.reverse(),
      child: ScaleTransition(
        scale: _pressScale,
        child: Container(
          decoration: BoxDecoration(
            color: FblaColors.darkSurface,
            borderRadius: BorderRadius.circular(FblaRadius.xl),
            border: Border.all(
              color: FblaColors.darkOutline,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Author header ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  FblaSpacing.md,
                  FblaSpacing.md,
                  FblaSpacing.md,
                  0,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _SimpleAvatar(
                      initial: _avatarInitial,
                      baseColor: _avatarColor,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _displayLabel,
                            style: FblaFonts.heading(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: FblaColors.darkTextPrimary,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_createdAt != null)
                            Text(
                              timeago.format(_createdAt!, allowFromNow: true),
                              style: FblaFonts.label(
                                fontSize: 11,
                                color: FblaColors.darkTextTertiary,
                                fontWeight: FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Post body ─────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  FblaSpacing.md,
                  10,
                  FblaSpacing.md,
                  0,
                ),
                child: Text(
                  _body,
                  style: FblaFonts.body(
                    fontSize: 14,
                    color: FblaColors.darkTextSecond,
                    height: 1.65,
                  ),
                  maxLines: 8,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // ── Divider + action row ──────────────────────────────────────
              const SizedBox(height: 12),
              Divider(
                height: 1,
                color: FblaColors.darkOutline,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: FblaSpacing.sm,
                  vertical: FblaSpacing.sm,
                ),
                child: Row(
                  children: [
                    // Like button — gold fill on active (achievement moment)
                    Semantics(
                      label: _liked ? 'Unlike post' : 'Like post',
                      button: true,
                      child: InkWell(
                        onTap: _handleLike,
                        borderRadius: BorderRadius.circular(FblaRadius.md),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: FblaSpacing.sm,
                            vertical: FblaSpacing.sm,
                          ),
                          child: Row(
                            children: [
                              ScaleTransition(
                                scale: _likeScale,
                                child: Icon(
                                  _liked
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  size: 17,
                                  color: _liked
                                      ? FblaColors.secondary
                                      : FblaColors.darkTextTertiary,
                                ),
                              ),
                              const SizedBox(width: 5),
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 200),
                                style: FblaFonts.label(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _liked
                                      ? FblaColors.secondary
                                      : FblaColors.darkTextSecond,
                                ),
                                child: Text('${_likeCount + (_liked ? 1 : 0)}'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: FblaSpacing.sm),
                    _ActionButton(
                      icon: Icons.mode_comment_outlined,
                      label: 'Comment',
                      color: FblaColors.darkTextTertiary,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Comments — coming soon'),
                          ),
                        );
                      },
                      semanticsLabel: 'Comment on post',
                    ),
                    const Spacer(),
                    // Bookmark button — pinned to the right edge of the action row
                    Semantics(
                      label: _bookmarked ? 'Remove bookmark' : 'Save post',
                      button: true,
                      child: InkWell(
                        onTap: _toggleBookmark,
                        borderRadius: BorderRadius.circular(FblaRadius.md),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: FblaSpacing.sm,
                            vertical: FblaSpacing.sm,
                          ),
                          child: ScaleTransition(
                            scale: _bookmarkScale,
                            child: Icon(
                              _bookmarked
                                  ? Icons.bookmark_rounded
                                  : Icons.bookmark_border_rounded,
                              size: 18,
                              color: _bookmarked
                                  ? FblaColors.secondary
                                  : FblaColors.darkTextTertiary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Avatar ──────────────────────────────────────────────────────────────────

class _SimpleAvatar extends StatelessWidget {
  const _SimpleAvatar({
    required this.initial,
    required this.baseColor,
  });

  final String initial;
  final Color baseColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: baseColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withAlpha(20),
          width: 1,
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }
}

// ── Action button ───────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    required this.semanticsLabel,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(FblaRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: FblaSpacing.sm,
            vertical: 13,
          ),
          child: Row(
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: FblaFonts.label(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Long-press actions sheet ────────────────────────────────────────────────

class _PostActionsSheet extends StatelessWidget {
  const _PostActionsSheet({required this.post});

  final Map<String, dynamic> post;

  Future<void> _handleShare(BuildContext context) async {
    HapticFeedback.lightImpact();

    // Hold a stable Messenger reference for the post-share toast — the
    // sheet's own context will be defunct after pop().
    final messenger = ScaffoldMessenger.maybeOf(context);
    Navigator.of(context).pop();

    final share = ShareService.instance;
    final text = share.generateShareText(
      type: ShareContentType.post,
      content: post,
    );

    final result = await share.shareText(text: text);

    if (result.success) {
      final id = (post['id'] ?? '').toString();
      if (id.isNotEmpty) {
        share.trackShare(
          type: ShareContentType.post,
          contentId: id,
          platform: 'native',
        );
      }
      if (result.message != null) {
        messenger?.showSnackBar(SnackBar(content: Text(result.message!)));
      }
    } else if (!result.canceled && result.message != null) {
      messenger?.showSnackBar(SnackBar(content: Text(result.message!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.28,
      minChildSize: 0.20,
      maxChildSize: 0.45,
      builder: (_, controller) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: FblaColors.darkSurface.withAlpha(240),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(
                  color: FblaColors.darkOutline,
                  width: 1,
                ),
              ),
              child: ListView(
                controller: controller,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: FblaColors.darkTextTertiary.withAlpha(80),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  _SheetAction(
                    icon: Icons.share_outlined,
                    label: 'Share Post',
                    onTap: () => _handleShare(context),
                  ),
                  _SheetAction(
                    icon: Icons.flag_outlined,
                    label: 'Report',
                    color: const Color(0xFFEF4444),
                    onTap: () {
                      Navigator.of(context).pop();
                      HapticFeedback.lightImpact();
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? FblaColors.darkTextPrimary;
    return ListTile(
      leading: Icon(icon, color: c, size: 22),
      title: Text(
        label,
        style: FblaFonts.label(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: c,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
    );
  }
}
