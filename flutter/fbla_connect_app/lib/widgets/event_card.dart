import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../services/accessibility_settings.dart';
import '../theme/app_theme.dart';

/// Card displaying a single event.
///
/// Dark glass-morphism card with:
/// - Navy gradient date column (56px) on the left
/// - Gold day number, white month/weekday
/// - Pulsing gold dot for upcoming events
/// - Bookmark icon with spring animation + haptic
class EventCard extends StatefulWidget {
  const EventCard({
    super.key,
    required this.event,
    this.onTap,
    this.isBookmarked = false,
    this.onBookmark,
    this.onDelete,
    this.isOwner = false,
  });

  final Map<String, dynamic> event;
  final VoidCallback? onTap;
  final bool isBookmarked;
  final VoidCallback? onBookmark;

  /// Called when the owner taps the kebab menu's Delete action. The card
  /// shows the confirmation dialog itself; the callback just fires after the
  /// user confirms so the parent list can reload.
  final VoidCallback? onDelete;

  /// Whether the current viewer owns this event. Only owners get the kebab.
  final bool isOwner;

  @override
  State<EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<EventCard>
    with TickerProviderStateMixin {
  late bool _bookmarked;
  late final AnimationController _bookmarkCtrl;
  late final Animation<double> _bookmarkScale;

  // Press-scale feedback
  late final AnimationController _pressCtrl;
  late final Animation<double> _pressScale;

  static final _dateFmt = DateFormat('EEE, MMM d');
  static final _timeFmt = DateFormat('h:mm a');

  String get _title       => widget.event['title']   as String? ?? 'Untitled Event';
  String get _description => widget.event['body']     as String? ?? '';
  String get _location    => widget.event['location'] as String? ?? '';

  DateTime? get _startAt => DateTime.tryParse(widget.event['start_at'] as String? ?? '');
  DateTime? get _endAt   => DateTime.tryParse(widget.event['end_at']   as String? ?? '');

  bool get _isUpcoming {
    final s = _startAt;
    return s != null && s.isAfter(DateTime.now());
  }

  /// Smart status tag — priority: Past → Registered → Deadline → ≤8 Days Away.
  ({String label, Color bg, Color fg, IconData? icon})? get _urgencyTag {
    final now = DateTime.now();
    final start = _startAt;
    if (start == null) return null;

    if (start.isBefore(now)) {
      return (label: 'Past',       bg: const Color(0xFF94A3B8), fg: Colors.white, icon: Icons.history_rounded);
    }
    if (widget.event['is_registered'] == true) {
      return (label: 'Registered', bg: const Color(0xFF22C55E),  fg: Colors.white, icon: Icons.check_circle_outline_rounded);
    }
    final deadlineStr = widget.event['registration_deadline'] as String?;
    if (deadlineStr != null) {
      final deadline = DateTime.tryParse(deadlineStr);
      if (deadline != null && !deadline.isAfter(now)) {
        return (label: 'Deadline', bg: const Color(0xFFEF4444), fg: Colors.white, icon: Icons.warning_amber_rounded);
      }
    }
    final days = start.difference(now).inDays;
    if (days <= 8) {
      final label = days == 0 ? 'Today' : days == 1 ? '1 Day Away' : '$days Days Away';
      return (label: label, bg: const Color(0xFFF59E0B), fg: const Color(0xFF1A1A1A), icon: Icons.timer_outlined);
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _bookmarked = widget.isBookmarked;
    _bookmarkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _bookmarkScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 0.90), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0.90, end: 1.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _bookmarkCtrl, curve: Curves.easeOut));

    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _pressScale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _pressCtrl, curve: FblaMotion.strongEaseOut),
    );
  }

  @override
  void didUpdateWidget(EventCard old) {
    super.didUpdateWidget(old);
    if (old.isBookmarked != widget.isBookmarked) {
      _bookmarked = widget.isBookmarked;
    }
  }

  @override
  void dispose() {
    _bookmarkCtrl.dispose();
    _pressCtrl.dispose();
    super.dispose();
  }

  void _handleBookmark() {
    HapticFeedback.lightImpact();
    setState(() => _bookmarked = !_bookmarked);
    _bookmarkCtrl.forward(from: 0);
    widget.onBookmark?.call();
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FblaColors.darkSurface,
        title: Text(
          'Delete event?',
          style: FblaFonts.heading(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: FblaColors.darkTextPrimary,
          ),
        ),
        content: Text(
          'This will remove the event and all RSVPs. This can\'t be undone.',
          style: FblaFonts.body(
            fontSize: 14,
            color: FblaColors.darkTextSecond,
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: FblaColors.darkTextSecond),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: FblaColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) widget.onDelete?.call();
  }

  @override
  Widget build(BuildContext context) {
    final start = _startAt;

    return Semantics(
      label: 'Event: $_title${start != null ? ", ${_dateFmt.format(start)}" : ""}',
      child: ScaleTransition(
        scale: _pressScale,
        // ── Single-surface event card — clean palette ─────────────────────────
        child: Container(
          decoration: BoxDecoration(
            color: FblaColors.darkSurface,
            borderRadius: BorderRadius.circular(FblaRadius.xl),
            border: Border.all(
              color: FblaColors.darkOutline,
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(FblaRadius.xl),
            child: InkWell(
              onTap: widget.onTap,
              onHighlightChanged: (on) =>
                  on ? _pressCtrl.forward() : _pressCtrl.reverse(),
              borderRadius: BorderRadius.circular(FblaRadius.xl),
              child: IntrinsicHeight(
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Left date column ─────────────────────────────────
                    _DateColumn(date: start, isUpcoming: _isUpcoming),

                    // ── Card content ──────────────────────────────────────
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title + bookmark
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    _title,
                                    style: FblaFonts.heading(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: _isUpcoming
                                          ? FblaColors.darkTextPrimary
                                          : FblaColors.darkTextSecond,
                                      letterSpacing: -0.1,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Bookmark icon with spring animation
                                Builder(builder: (context) {
                                  final large = AccessibilitySettings.instance.largeTargets;
                                  return Semantics(
                                    label: _bookmarked ? 'Remove bookmark' : 'Bookmark event',
                                    button: true,
                                    child: GestureDetector(
                                      onTap: _handleBookmark,
                                      behavior: HitTestBehavior.opaque,
                                      child: SizedBox(
                                        width: large ? 48 : 32,
                                        height: large ? 48 : 32,
                                        child: Center(
                                          child: ScaleTransition(
                                            scale: _bookmarkScale,
                                            child: Icon(
                                              _bookmarked
                                                  ? Icons.bookmark_rounded
                                                  : Icons.bookmark_border_rounded,
                                              size: large ? 24 : 20,
                                              color: _bookmarked
                                                  ? FblaColors.secondary
                                                  : FblaColors.darkTextTertiary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                                // Owner-only kebab menu — sits right after the
                                // bookmark so the card header stays tight.
                                if (widget.isOwner && widget.onDelete != null)
                                  _EventOwnerMenu(
                                    onDelete: () => _confirmDelete(context),
                                  ),
                              ],
                            ),

                            if (_description.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                _description,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: FblaColors.darkTextSecond,
                                  height: 1.45,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],

                            const SizedBox(height: 10),

                            // Meta rows
                            if (start != null)
                              _MetaRow(
                                icon: Icons.access_time_rounded,
                                label: _endAt != null
                                    ? '${_timeFmt.format(start)} – ${_timeFmt.format(_endAt!)}'
                                    : _timeFmt.format(start),
                              ),
                            if (_location.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              _MetaRow(
                                icon: Icons.place_outlined,
                                label: _location,
                              ),
                            ],

                            // Status / urgency badge
                            Builder(builder: (ctx) {
                              final tag = _urgencyTag;
                              if (tag == null) return const SizedBox.shrink();
                              final showIcon = AccessibilitySettings.instance.colorBlindFriendly;
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: _EventStatusChip(
                                  label: tag.label,
                                  bg: tag.bg,
                                  fg: tag.fg,
                                  icon: showIcon ? tag.icon : null,
                                ),
                              );
                            }),

                            // Pulsing dot — only when upcoming AND no urgency tag
                            // (avoids showing both urgency indicators simultaneously)
                            if (_isUpcoming && _urgencyTag == null) ...[
                              const SizedBox(height: 8),
                              _PulsingDot(),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Left date column ─────────────────────────────────────────────────────────

class _DateColumn extends StatelessWidget {
  const _DateColumn({required this.date, required this.isUpcoming});

  final DateTime? date;
  final bool isUpcoming;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      decoration: BoxDecoration(
        gradient: isUpcoming
            ? FblaGradient.blueShimmer
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  FblaColors.darkSurfaceHigh,
                  FblaColors.darkSurface,
                ],
              ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(FblaRadius.xl),
          bottomLeft: Radius.circular(FblaRadius.xl),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            date != null
                ? DateFormat('MMM').format(date!).toUpperCase()
                : '—',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            date != null ? DateFormat('d').format(date!) : '—',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: isUpcoming ? FblaColors.secondary : FblaColors.darkTextSecond,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            date != null
                ? DateFormat('EEE').format(date!).toUpperCase()
                : '',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: FblaColors.darkTextTertiary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Meta row ─────────────────────────────────────────────────────────────────

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 12, color: FblaColors.darkTextTertiary),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: FblaColors.darkTextSecond,
              fontWeight: FontWeight.w400,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ── Pulsing gold dot ─────────────────────────────────────────────────────────

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        FadeTransition(
          opacity: _opacity,
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: FblaColors.secondary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: FblaColors.secondary.withAlpha(100),
                  blurRadius: 6,
                  offset: Offset.zero,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 5),
        const Text(
          'UPCOMING',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: FblaColors.secondary,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status chip — Registered / N Days Away / Deadline / Past
// With optional leading icon for colorblind-friendly mode.
// ─────────────────────────────────────────────────────────────────────────────

class _EventStatusChip extends StatelessWidget {
  const _EventStatusChip({
    required this.label,
    required this.bg,
    required this.fg,
    this.icon,
  });

  final String label;
  final Color bg;
  final Color fg;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg.withAlpha(230),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: fg,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Owner-only kebab menu for events ─────────────────────────────────────────
class _EventOwnerMenu extends StatelessWidget {
  const _EventOwnerMenu({required this.onDelete});

  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Event options',
      icon: Icon(
        Icons.more_vert,
        color: FblaColors.darkTextTertiary,
        size: 18,
      ),
      color: FblaColors.darkSurfaceHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FblaRadius.md),
        side: BorderSide(color: FblaColors.darkOutline, width: 1),
      ),
      padding: EdgeInsets.zero,
      splashRadius: 18,
      onSelected: (v) {
        if (v == 'delete') onDelete();
      },
      itemBuilder: (ctx) => [
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 18, color: FblaColors.error),
              const SizedBox(width: 10),
              Text(
                'Delete event',
                style: FblaFonts.body(
                  fontSize: 14,
                  color: FblaColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
