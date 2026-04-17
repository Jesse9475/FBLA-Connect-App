import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// Detail screen for a chapter / district / national event surfaced from
/// the EventsScreen calendar list.
///
/// Shows a hero header (date column, title, scope badge, location), the body
/// description, and a primary register / unregister button wired to the
/// backend `/events/<id>/register` endpoint. A bookmark toggle in the AppBar
/// mirrors the bookmarking the list view uses (same SecureStorage key) so
/// the two stay in sync.
class ChapterEventDetailScreen extends StatefulWidget {
  const ChapterEventDetailScreen({
    super.key,
    required this.event,
  });

  final Map<String, dynamic> event;

  @override
  State<ChapterEventDetailScreen> createState() =>
      _ChapterEventDetailScreenState();
}

class _ChapterEventDetailScreenState extends State<ChapterEventDetailScreen> {
  static const _storage = FlutterSecureStorage();
  static const _bookmarkKey = 'bookmarked_event_ids';

  final _api = ApiService.instance;
  late Map<String, dynamic> _event;

  bool _isBookmarked = false;
  bool _busy = false;

  String get _id => _event['id'] as String? ?? '';
  String get _title => _event['title'] as String? ?? 'Untitled Event';
  String get _body => _event['body'] as String? ?? '';
  String get _location => _event['location'] as String? ?? '';
  String get _scope => (_event['visibility'] as String? ??
          _event['scope'] as String? ??
          'national')
      .toLowerCase();

  DateTime? get _startAt =>
      DateTime.tryParse(_event['start_at'] as String? ?? '');
  DateTime? get _endAt =>
      DateTime.tryParse(_event['end_at'] as String? ?? '');

  bool get _isRegistered => _event['is_registered'] == true;

  @override
  void initState() {
    super.initState();
    _event = Map<String, dynamic>.from(widget.event);
    _loadBookmark();
  }

  Future<void> _loadBookmark() async {
    try {
      final raw = await _storage.read(key: _bookmarkKey);
      if (raw != null && mounted) {
        final list = (jsonDecode(raw) as List).cast<String>();
        setState(() => _isBookmarked = list.contains(_id));
      }
    } catch (_) {}
  }

  Future<void> _toggleBookmark() async {
    HapticFeedback.lightImpact();
    final next = !_isBookmarked;
    setState(() => _isBookmarked = next);
    try {
      final raw = await _storage.read(key: _bookmarkKey);
      final list =
          raw == null ? <String>[] : (jsonDecode(raw) as List).cast<String>();
      if (next) {
        if (!list.contains(_id)) list.add(_id);
      } else {
        list.remove(_id);
      }
      await _storage.write(key: _bookmarkKey, value: jsonEncode(list));
    } catch (_) {}
  }

  Future<void> _toggleRegistration() async {
    if (_busy || _id.isEmpty) return;
    final wantRegister = !_isRegistered;
    HapticFeedback.mediumImpact();
    setState(() => _busy = true);

    try {
      if (wantRegister) {
        await _api.post<void>('/events/$_id/register', body: {});
        if (!mounted) return;
        setState(() {
          _event['is_registered'] = true;
          _busy = false;
        });
        _showToast('You\'re registered. +5 points', color: FblaColors.success);
      } else {
        await _api.delete<void>('/events/$_id/register');
        if (!mounted) return;
        setState(() {
          _event['is_registered'] = false;
          _busy = false;
        });
        _showToast('Registration cancelled');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showToast(
        e.toString().replaceFirst('Exception: ', ''),
        color: FblaColors.error,
      );
    }
  }

  void _showToast(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Formatting helpers ────────────────────────────────────────────────────

  String _dateLabel() {
    final start = _startAt;
    if (start == null) return 'Date TBA';
    final dayName = DateFormat('EEEE').format(start);
    final monthDay = DateFormat('MMMM d, y').format(start);
    return '$dayName · $monthDay';
  }

  String _timeLabel() {
    final start = _startAt;
    if (start == null) return '';
    final fmt = DateFormat('h:mm a');
    final s = fmt.format(start);
    final end = _endAt;
    if (end != null) return '$s – ${fmt.format(end)}';
    return s;
  }

  Color _scopeAccent() {
    switch (_scope) {
      case 'chapter':
      case 'members':
        return FblaColors.secondary;
      case 'district':
        return const Color(0xFF8AB4FF);
      case 'national':
      case 'public':
      default:
        return const Color(0xFFFF9F66);
    }
  }

  String _scopeLabel() {
    switch (_scope) {
      case 'chapter':
        return 'Chapter';
      case 'members':
        return 'Members';
      case 'district':
        return 'District';
      case 'national':
        return 'National';
      case 'public':
        return 'Public';
      default:
        return _scope.isEmpty ? 'Event' : _scope.toUpperCase();
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? FblaColors.darkBg : FblaColors.background;
    final surface = isDark ? FblaColors.darkSurface : Colors.white;
    final textPrimary =
        isDark ? FblaColors.darkTextPrimary : FblaColors.textPrimary;
    final textSecond =
        isDark ? FblaColors.darkTextSecond : FblaColors.textSecondary;
    final outline =
        isDark ? FblaColors.darkOutline : FblaColors.outline;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            tooltip: _isBookmarked ? 'Remove bookmark' : 'Bookmark',
            icon: Icon(
              _isBookmarked
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_outline_rounded,
              color: _isBookmarked ? FblaColors.secondary : textSecond,
            ),
            onPressed: _toggleBookmark,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              FblaSpacing.lg, 0, FblaSpacing.lg, FblaSpacing.xl),
          children: [
            // ── Hero block: scope chip + title + date row ───────────────
            _ScopePill(label: _scopeLabel(), color: _scopeAccent()),
            const SizedBox(height: FblaSpacing.md),
            Text(
              _title,
              style: TextStyle(
                fontFamily: 'Josefin Sans',
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: textPrimary,
                height: 1.15,
                letterSpacing: -0.5,
              ),
            ).animate().fadeIn(duration: 240.ms).slideY(
                  begin: 0.05,
                  end: 0,
                  duration: 280.ms,
                  curve: Curves.easeOut,
                ),
            const SizedBox(height: FblaSpacing.lg),

            // ── Meta card: date, time, location ─────────────────────────
            Container(
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(FblaRadius.lg),
                border: Border.all(color: outline),
              ),
              padding: const EdgeInsets.all(FblaSpacing.lg),
              child: Column(
                children: [
                  _MetaRow(
                    icon: Icons.calendar_today_rounded,
                    label: _dateLabel(),
                    accent: _scopeAccent(),
                    textColor: textPrimary,
                    secondColor: textSecond,
                  ),
                  if (_timeLabel().isNotEmpty) ...[
                    const SizedBox(height: FblaSpacing.md),
                    _MetaRow(
                      icon: Icons.schedule_rounded,
                      label: _timeLabel(),
                      accent: _scopeAccent(),
                      textColor: textPrimary,
                      secondColor: textSecond,
                    ),
                  ],
                  if (_location.isNotEmpty) ...[
                    const SizedBox(height: FblaSpacing.md),
                    _MetaRow(
                      icon: Icons.location_on_rounded,
                      label: _location,
                      accent: _scopeAccent(),
                      textColor: textPrimary,
                      secondColor: textSecond,
                    ),
                  ],
                ],
              ),
            )
                .animate(delay: 60.ms)
                .fadeIn(duration: 240.ms)
                .slideY(begin: 0.04, end: 0, duration: 240.ms),
            const SizedBox(height: FblaSpacing.lg),

            // ── Description ─────────────────────────────────────────────
            if (_body.trim().isNotEmpty) ...[
              Text(
                'About this event',
                style: TextStyle(
                  fontFamily: 'Mulish',
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: textSecond,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: FblaSpacing.sm),
              Text(
                _body,
                style: TextStyle(
                  fontFamily: 'Mulish',
                  fontSize: 15,
                  height: 1.55,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: FblaSpacing.xl),
            ],

            // ── Primary CTA ─────────────────────────────────────────────
            _RegisterButton(
              isRegistered: _isRegistered,
              busy: _busy,
              onTap: _toggleRegistration,
            ),
            const SizedBox(height: FblaSpacing.sm),
            Center(
              child: Text(
                _isRegistered
                    ? 'You\'re on the list. Tap to cancel.'
                    : 'Earn +5 points for registering. +10 more for attending.',
                style: TextStyle(
                  fontFamily: 'Mulish',
                  fontSize: 12,
                  color: textSecond,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Atoms
// ─────────────────────────────────────────────────────────────────────────────

class _ScopePill extends StatelessWidget {
  const _ScopePill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withAlpha(30),
          borderRadius: BorderRadius.circular(FblaRadius.full),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontFamily: 'Mulish',
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: 1.4,
          ),
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.icon,
    required this.label,
    required this.accent,
    required this.textColor,
    required this.secondColor,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final Color textColor;
  final Color secondColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: accent.withAlpha(28),
            borderRadius: BorderRadius.circular(FblaRadius.sm),
          ),
          child: Icon(icon, size: 18, color: accent),
        ),
        const SizedBox(width: FblaSpacing.md),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Mulish',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _RegisterButton extends StatelessWidget {
  const _RegisterButton({
    required this.isRegistered,
    required this.busy,
    required this.onTap,
  });

  final bool isRegistered;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: busy ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: isRegistered
              ? FblaColors.darkSurfaceHigh
              : FblaColors.secondary,
          foregroundColor: isRegistered
              ? FblaColors.darkTextPrimary
              : FblaColors.primaryDark,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FblaRadius.md),
            side: BorderSide(
              color: isRegistered
                  ? FblaColors.darkOutline
                  : Colors.transparent,
            ),
          ),
        ),
        child: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: FblaColors.primaryDark,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isRegistered
                        ? Icons.check_circle_rounded
                        : Icons.event_available_rounded,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isRegistered ? 'Registered' : 'Register for this event',
                    style: const TextStyle(
                      fontFamily: 'Mulish',
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
