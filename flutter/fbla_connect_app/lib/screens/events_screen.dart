import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/accessibility_settings.dart';
import '../services/api_service.dart';
import '../services/user_state.dart';
import '../theme/app_theme.dart';
import '../widgets/event_card.dart';
import '../widgets/fbla_app_bar.dart';
import '../widgets/fbla_empty_view.dart';
import '../widgets/fbla_error_view.dart';
import 'chapter_event_detail_screen.dart';
import 'create_event_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Events Screen — Premium editorial calendar + filtered event list
// ─────────────────────────────────────────────────────────────────────────────

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _api = ApiService.instance;
  static const _storage = FlutterSecureStorage();
  static const _bookmarkKey = 'bookmarked_event_ids';

  // Data
  List<Map<String, dynamic>> _events = [];
  bool _loading = true;
  String? _error;

  // Calendar
  late DateTime _calendarMonth;
  DateTime? _selectedDay;

  // Filters
  String _scope = 'all';
  bool _sortAsc = true;

  // Bookmarks
  Set<String> _bookmarkedIds = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _calendarMonth = DateTime(now.year, now.month);
    _load();
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    try {
      final raw = await _storage.read(key: _bookmarkKey);
      if (raw != null && mounted) {
        final list = (jsonDecode(raw) as List).cast<String>();
        setState(() => _bookmarkedIds = list.toSet());
      }
    } catch (_) {}
  }

  Future<void> _saveBookmarks() async {
    try {
      await _storage.write(
        key: _bookmarkKey,
        value: jsonEncode(_bookmarkedIds.toList()),
      );
    } catch (_) {}
  }

  void _toggleBookmark(String eventId) {
    setState(() {
      if (_bookmarkedIds.contains(eventId)) {
        _bookmarkedIds.remove(eventId);
      } else {
        _bookmarkedIds.add(eventId);
      }
    });
    _saveBookmarks();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _bookmarkedIds.contains(eventId) ? 'Event bookmarked' : 'Bookmark removed',
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.get<List<Map<String, dynamic>>>(
        '/events',
        parser: (data) =>
            (data['events'] as List? ?? []).cast<Map<String, dynamic>>(),
      );
      if (mounted) {
        setState(() {
          _events = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  /// DELETE /events/<id>. Optimistically drops the event from the local list
  /// so the UI feels instant; re-runs [_load] on failure to resync from the
  /// server. Confirmation dialog is owned by [EventCard].
  Future<void> _deleteEvent(Map<String, dynamic> event) async {
    final id = event['id'];
    if (id is! String || id.isEmpty) return;
    final snapshot = List<Map<String, dynamic>>.from(_events);
    setState(() {
      _events = _events.where((e) => e['id'] != id).toList();
    });
    try {
      await _api.delete('/events/$id');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Event deleted'),
          backgroundColor: FblaColors.darkSurface,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FblaRadius.md),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _events = snapshot);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Couldn\'t delete: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
          backgroundColor: FblaColors.error,
        ),
      );
    }
  }

  void _showEventDetail(BuildContext ctx, Map<String, dynamic> event) async {
    await Navigator.of(ctx).push(
      MaterialPageRoute<void>(
        builder: (_) => ChapterEventDetailScreen(event: event),
      ),
    );
    // Reload after the user returns so registration / bookmark state
    // stays in sync with what they did inside the detail screen.
    if (mounted) await _load();
  }

  bool _isVisible(Map<String, dynamic> event) {
    final scope = (event['scope'] as String?)?.toLowerCase() ?? 'national';
    if (scope == 'national') return true;
    final us = UserState.instance;
    if (scope == 'district') {
      final eventDistrict = event['district_id'] as String?;
      if (eventDistrict == null) return true;
      return us.districtId == null || us.districtId == eventDistrict;
    }
    if (scope == 'chapter') {
      final eventChapter = event['chapter_id'] as String?;
      if (eventChapter == null) return true;
      return us.chapterId == null || us.chapterId == eventChapter;
    }
    return true;
  }

  /// Pulls a normalized scope string from an event, falling back through the
  /// fields the backend has used over time (`scope`, `visibility`).
  String _eventScope(Map<String, dynamic> event) =>
      ((event['scope'] as String?) ??
              (event['visibility'] as String?) ??
              'national')
          .toLowerCase();

  List<Map<String, dynamic>> get _filtered {
    return _events.where((event) {
      if (!_isVisible(event)) return false;

      // Chip filter — All shows everything visible. The other chips narrow
      // to events whose own scope matches.
      final s = _eventScope(event);
      if (_scope == 'national' && s != 'national' && s != 'public') {
        return false;
      }
      if (_scope == 'district' && s != 'district') return false;
      if (_scope == 'chapter' &&
          s != 'chapter' &&
          s != 'members') {
        return false;
      }

      // Calendar filter — when the user taps a specific day in the calendar
      // we only want events that start on that day in the bottom list.
      // Tapping the same day again clears the selection (handled by the
      // calendar widget) so the full month is shown.
      final selected = _selectedDay;
      if (selected != null) {
        final start =
            DateTime.tryParse(event['start_at'] as String? ?? '');
        if (start == null) return false;
        if (start.year != selected.year ||
            start.month != selected.month ||
            start.day != selected.day) {
          return false;
        }
      }
      return true;
    }).toList()
      ..sort((a, b) {
        final aStart = DateTime.tryParse(a['start_at'] as String? ?? '');
        final bStart = DateTime.tryParse(b['start_at'] as String? ?? '');
        if (aStart == null || bStart == null) return 0;
        return _sortAsc ? aStart.compareTo(bStart) : bStart.compareTo(aStart);
      });
  }

  Map<int, List<Map<String, dynamic>>> _eventsInMonth() {
    final result = <int, List<Map<String, dynamic>>>{};
    for (final event in _filtered) {
      final start = DateTime.tryParse(event['start_at'] as String? ?? '');
      if (start != null && start.year == _calendarMonth.year && start.month == _calendarMonth.month) {
        result.putIfAbsent(start.day, () => []).add(event);
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: FblaColors.darkBg,
      appBar: FblaAppBar(
        title: const Text('Events'),
        actions: [
          ListenableBuilder(
            listenable: UserState.instance,
            builder: (context, _) {
              if (!UserState.instance.isAdvisorOrAdmin) {
                return const SizedBox.shrink();
              }
              return IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Create event',
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CreateEventScreen(),
                    ),
                  );
                  // Reload after user returns from the create flow so a
                  // newly-published event appears immediately in the list
                  // and calendar. Without this, _events is stale because
                  // EventsScreen is kept alive via AutomaticKeepAliveClientMixin.
                  if (mounted) await _load();
                },
              );
            },
          ),
        ],
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(FblaColors.primary),
              ),
            )
          : _error != null
              ? FblaErrorView(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  color: FblaColors.primary,
                  child: ListView(
                  padding: EdgeInsets.zero,
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    // ── Premium month calendar ─────────────────────────────────
                    _PremiumMonthCalendar(
                      month: _calendarMonth,
                      selectedDay: _selectedDay,
                      eventsInMonth: _eventsInMonth(),
                      onDaySelected: (day) => setState(() {
                        // Tap the already-selected day again to clear the
                        // filter — a less surprising gesture than hunting
                        // for a separate "Clear" button.
                        if (_selectedDay != null &&
                            _selectedDay!.year == day.year &&
                            _selectedDay!.month == day.month &&
                            _selectedDay!.day == day.day) {
                          _selectedDay = null;
                        } else {
                          _selectedDay = day;
                        }
                      }),
                      onMonthChanged: (month) => setState(() => _calendarMonth = month),
                    ),
                    const SizedBox(height: FblaSpacing.lg),
                    // ── Filters row ────────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: FblaSpacing.md),
                      child: Row(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _FilterChip(
                                    label: 'All',
                                    isActive: _scope == 'all',
                                    onTap: () => setState(() => _scope = 'all'),
                                  ),
                                  const SizedBox(width: FblaSpacing.sm),
                                  _FilterChip(
                                    label: 'Nationals',
                                    isActive: _scope == 'national',
                                    onTap: () => setState(() => _scope = 'national'),
                                  ),
                                  const SizedBox(width: FblaSpacing.sm),
                                  _FilterChip(
                                    label: 'District',
                                    isActive: _scope == 'district',
                                    onTap: () => setState(() => _scope = 'district'),
                                  ),
                                  const SizedBox(width: FblaSpacing.sm),
                                  _FilterChip(
                                    label: 'Chapter',
                                    isActive: _scope == 'chapter',
                                    onTap: () => setState(() => _scope = 'chapter'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: FblaSpacing.sm),
                          _SortButton(
                            isAscending: _sortAsc,
                            onTap: () => setState(() => _sortAsc = !_sortAsc),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: FblaSpacing.md),
                    // ── Event list ────────────────────────────────────────────
                    if (_filtered.isEmpty)
                      FblaEmptyView(
                        icon: Icons.event_outlined,
                        title: 'No events found',
                        subtitle: 'Events matching your filters will appear here.',
                      )
                    else
                      ..._buildEventList(),
                    const SizedBox(height: 88),
                  ],
                  ),
                ),
      floatingActionButton: ListenableBuilder(
        listenable: UserState.instance,
        builder: (context, _) {
          if (!UserState.instance.isAdvisorOrAdmin) return const SizedBox.shrink();
          return _FloatingActionButton(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CreateEventScreen(),
                ),
              );
              // Reload after user returns so a newly-published event
              // shows up immediately in the list and calendar.
              if (mounted) await _load();
            },
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  List<Widget> _buildEventList() {
    final events = _filtered;
    if (events.isEmpty) return [];

    final items = <_ListItem>[];
    String? lastLabel;
    int eventIndex = 0;

    for (final event in events) {
      final start = DateTime.tryParse(event['start_at'] as String? ?? '');
      final label = start != null ? _dateGroupLabel(start) : 'Upcoming';
      if (label != lastLabel) {
        items.add(_HeaderItem(label));
        lastLabel = label;
      }
      items.add(_EventItem(event, eventIndex++));
    }

    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: FblaSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(items.length, (i) {
            final item = items[i];
            if (item is _HeaderItem) {
              return Padding(
                padding: const EdgeInsets.only(bottom: FblaSpacing.md, top: FblaSpacing.md),
                child: _DateGroupHeader(label: item.label)
                    .animate(delay: Duration(milliseconds: i * 30))
                    .fadeIn(duration: FblaMotion.standard)
                    .slideX(begin: -0.05, end: 0, duration: FblaMotion.standard, curve: FblaMotion.easeOut),
              );
            }
            final ei = item as _EventItem;
            final event = ei.event;
            final id = event['id'] as String? ?? 'event_${ei.originalIndex}';
            // Owner check for delete affordance — admins can also delete,
            // but we rely on the backend's 403 to enforce that rather than
            // widening this check here (keeps the UI uncluttered for non-
            // owners). The kebab only shows for the user's own events.
            final me = Supabase.instance.client.auth.currentUser?.id;
            final isOwner = me != null && event['created_by'] == me;
            return Padding(
              padding: const EdgeInsets.only(bottom: FblaSpacing.sm),
              child: EventCard(
                event: event,
                isBookmarked: _bookmarkedIds.contains(id),
                onBookmark: () => _toggleBookmark(id),
                onTap: () => _showEventDetail(context, event),
                isOwner: isOwner,
                onDelete: isOwner ? () => _deleteEvent(event) : null,
              )
                  .animate(delay: Duration(milliseconds: ei.originalIndex * 60))
                  .fadeIn(duration: FblaMotion.standard)
                  .slideY(begin: 0.07, end: 0, duration: FblaMotion.standard, curve: FblaMotion.easeOut),
            );
          }),
        ),
      ),
    ];
  }

  static String _dateGroupLabel(DateTime date) {
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    final weekFromNow = now.add(const Duration(days: 7));

    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'Today';
    } else if (date.year == tomorrow.year && date.month == tomorrow.month && date.day == tomorrow.day) {
      return 'Tomorrow';
    } else if (date.isAfter(now) && date.isBefore(weekFromNow)) {
      return 'This week';
    } else if (date.year == now.year && date.month == now.month) {
      return 'This month';
    } else if (date.year == now.year) {
      return DateFormat('MMMM').format(date);
    } else {
      return DateFormat('MMMM yyyy').format(date);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Premium Month Calendar — Editorial grid with electric blue today, gold selected
// ─────────────────────────────────────────────────────────────────────────────

class _PremiumMonthCalendar extends StatelessWidget {
  const _PremiumMonthCalendar({
    required this.month,
    required this.selectedDay,
    required this.eventsInMonth,
    required this.onDaySelected,
    required this.onMonthChanged,
  });

  final DateTime month;
  final DateTime? selectedDay;
  final Map<int, List<Map<String, dynamic>>> eventsInMonth;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<DateTime> onMonthChanged;

  static final _monthFmt = DateFormat('MMMM yyyy');
  static final _dayFmt = DateFormat('E');
  static const _weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final startWeek = firstDay.subtract(Duration(days: firstDay.weekday - 1));

    // Generate all days for the grid (6 weeks)
    final days = List.generate(42, (i) => startWeek.add(Duration(days: i)));

    return Container(
      color: FblaColors.darkBg,
      padding: const EdgeInsets.fromLTRB(FblaSpacing.md, FblaSpacing.lg, FblaSpacing.md, FblaSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Month navigation ──────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _monthFmt.format(month),
                      style: FblaFonts.display(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: FblaColors.darkTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${lastDay.day} days • ${eventsInMonth.values.fold<int>(0, (sum, list) => sum + list.length)} events',
                      style: FblaFonts.label(
                        fontSize: 12,
                        color: FblaColors.darkTextSecond,
                      ),
                    ),
                  ],
                ),
              ),
              _CalendarNavButton(
                icon: Icons.chevron_left_rounded,
                onTap: () => onMonthChanged(DateTime(month.year, month.month - 1)),
              ),
              const SizedBox(width: FblaSpacing.sm),
              _CalendarNavButton(
                icon: Icons.chevron_right_rounded,
                onTap: () => onMonthChanged(DateTime(month.year, month.month + 1)),
              ),
            ],
          ),
          const SizedBox(height: FblaSpacing.lg),

          // ── Weekday headers ───────────────────────────────────────────────
          Row(
            children: List.generate(
              7,
              (i) => Expanded(
                child: Text(
                  _weekDays[i],
                  textAlign: TextAlign.center,
                  style: FblaFonts.monoTag(
                    fontSize: 11,
                    color: FblaColors.darkTextSecond,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: FblaSpacing.sm),

          // ── Calendar grid ─────────────────────────────────────────────────
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: FblaSpacing.xs,
              crossAxisSpacing: FblaSpacing.xs,
              childAspectRatio: 1.0,
            ),
            itemCount: days.length,
            itemBuilder: (ctx, i) {
              final date = days[i];
              final isCurrentMonth = date.month == month.month;
              final isToday = date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day;
              final isSelected = selectedDay != null &&
                  selectedDay!.year == date.year &&
                  selectedDay!.month == date.month &&
                  selectedDay!.day == date.day;
              final hasEvent = eventsInMonth[date.day] != null &&
                  eventsInMonth[date.day]!.isNotEmpty;

              return _CalendarDay(
                date: date,
                isCurrentMonth: isCurrentMonth,
                isToday: isToday,
                isSelected: isSelected,
                hasEvent: hasEvent,
                onTap: () => onDaySelected(date),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CalendarDay extends StatefulWidget {
  const _CalendarDay({
    required this.date,
    required this.isCurrentMonth,
    required this.isToday,
    required this.isSelected,
    required this.hasEvent,
    required this.onTap,
  });

  final DateTime date;
  final bool isCurrentMonth;
  final bool isToday;
  final bool isSelected;
  final bool hasEvent;
  final VoidCallback onTap;

  @override
  State<_CalendarDay> createState() => _CalendarDayState();
}

class _CalendarDayState extends State<_CalendarDay> with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _pressScale;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _pressScale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _pressCtrl, curve: FblaMotion.strongEaseOut),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.isCurrentMonth ? widget.onTap : null,
      onTapDown: widget.isCurrentMonth ? (_) {
        HapticFeedback.selectionClick();
        _pressCtrl.forward();
      } : null,
      onTapUp: widget.isCurrentMonth ? (_) => _pressCtrl.reverse() : null,
      onTapCancel: widget.isCurrentMonth ? () => _pressCtrl.reverse() : null,
      child: ScaleTransition(
        scale: _pressScale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: FblaMotion.strongEaseOut,
          decoration: BoxDecoration(
            color: widget.isSelected
                ? FblaColors.secondary
                : widget.isToday
                    ? FblaColors.primary.withAlpha(12)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(FblaRadius.md),
            border: widget.isToday && !widget.isSelected
                ? Border.all(color: FblaColors.primary, width: 1.5)
                : null,
            boxShadow: widget.isSelected ? FblaShadow.goldGlow : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Day number
              Text(
                '${widget.date.day}',
                style: FblaFonts.monoStat(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: !widget.isCurrentMonth
                      ? FblaColors.darkTextTertiary
                      : widget.isSelected
                          ? FblaColors.primaryDark
                          : FblaColors.darkTextPrimary,
                ),
              ),
              // Event indicator — small gold dot
              if (widget.hasEvent && widget.isCurrentMonth)
                Positioned(
                  bottom: 3,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 3,
                    height: 3,
                    decoration: BoxDecoration(
                      color: widget.isSelected ? FblaColors.primaryDark : FblaColors.secondary,
                      shape: BoxShape.circle,
                      boxShadow: widget.isSelected
                          ? null
                          : [BoxShadow(color: FblaColors.secondary.withAlpha(80), blurRadius: 3)],
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

class _CalendarNavButton extends StatelessWidget {
  const _CalendarNavButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: FblaColors.darkSurface,
          borderRadius: BorderRadius.circular(FblaRadius.md),
          border: Border.all(color: FblaColors.darkOutline, width: 1),
        ),
        child: Icon(icon, size: 18, color: FblaColors.darkTextPrimary),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter chip and sort button
// ─────────────────────────────────────────────────────────────────────────────

class _FilterChip extends StatefulWidget {
  const _FilterChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip> with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _pressScale;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _pressScale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _pressCtrl, curve: FblaMotion.strongEaseOut),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _pressCtrl.forward(),
      onTapUp: (_) => _pressCtrl.reverse(),
      onTapCancel: () => _pressCtrl.reverse(),
      child: ScaleTransition(
        scale: _pressScale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: FblaMotion.strongEaseOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isActive ? FblaColors.primary : FblaColors.darkSurface,
            borderRadius: BorderRadius.circular(FblaRadius.full),
            border: widget.isActive
                ? null
                : Border.all(color: FblaColors.darkOutline, width: 1),
            boxShadow: widget.isActive ? FblaShadow.blueGlow : null,
          ),
          child: Text(
            widget.label,
            style: FblaFonts.label(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: widget.isActive ? Colors.white : FblaColors.darkTextPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _SortButton extends StatefulWidget {
  const _SortButton({required this.isAscending, required this.onTap});
  final bool isAscending;
  final VoidCallback onTap;

  @override
  State<_SortButton> createState() => _SortButtonState();
}

class _SortButtonState extends State<_SortButton> with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _pressScale;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _pressScale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _pressCtrl, curve: FblaMotion.strongEaseOut),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _pressCtrl.forward(),
      onTapUp: (_) => _pressCtrl.reverse(),
      onTapCancel: () => _pressCtrl.reverse(),
      child: ScaleTransition(
        scale: _pressScale,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: FblaColors.darkSurface,
            borderRadius: BorderRadius.circular(FblaRadius.md),
            border: Border.all(color: FblaColors.darkOutline, width: 1),
          ),
          child: Icon(
            widget.isAscending ? Icons.arrow_upward : Icons.arrow_downward,
            size: 18,
            color: FblaColors.darkTextPrimary,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Date group header — "Today", "Tomorrow", "This week", etc.
// ─────────────────────────────────────────────────────────────────────────────

class _DateGroupHeader extends StatelessWidget {
  const _DateGroupHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: FblaSpacing.md),
      child: Row(
        children: [
          Container(
            width: 2,
            height: 14,
            decoration: BoxDecoration(
              color: FblaColors.secondary,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: FblaFonts.display(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: FblaColors.darkTextPrimary,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Floating action button — Gold FAB for advisors
// ─────────────────────────────────────────────────────────────────────────────

class _FloatingActionButton extends StatefulWidget {
  const _FloatingActionButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  State<_FloatingActionButton> createState() => _FloatingActionButtonState();
}

class _FloatingActionButtonState extends State<_FloatingActionButton> with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _pressScale;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _pressScale = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _pressCtrl, curve: FblaMotion.strongEaseOut),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onPressed,
      onTapDown: (_) => _pressCtrl.forward(),
      onTapUp: (_) => _pressCtrl.reverse(),
      onTapCancel: () => _pressCtrl.reverse(),
      child: ScaleTransition(
        scale: _pressScale,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: FblaGradient.goldShimmer,
            borderRadius: BorderRadius.circular(FblaRadius.lg),
            boxShadow: FblaShadow.goldGlow,
          ),
          child: const Icon(Icons.add, color: FblaColors.onSecondary, size: 28),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal data model
// ─────────────────────────────────────────────────────────────────────────────

abstract class _ListItem {}

class _HeaderItem extends _ListItem {
  final String label;
  _HeaderItem(this.label);
}

class _EventItem extends _ListItem {
  final Map<String, dynamic> event;
  final int originalIndex;
  _EventItem(this.event, this.originalIndex);
}
