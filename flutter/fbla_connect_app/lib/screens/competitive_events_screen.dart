import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'event_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Competitive Events Hub — "Contender" Editorial Aesthetic
//
// Category filter chips with distinct colors at top.
// Event cards in scrollable list with staggered entrance animations.
// Each card shows event name (Josefin heading), category badge, and description.
// Search functionality integrated for discovery.
//
// All API calls to /competitive-events endpoint preserved.
// ─────────────────────────────────────────────────────────────────────────────

class CompetitiveEventsScreen extends StatefulWidget {
  const CompetitiveEventsScreen({super.key});

  @override
  State<CompetitiveEventsScreen> createState() =>
      _CompetitiveEventsScreenState();
}

class _CompetitiveEventsScreenState extends State<CompetitiveEventsScreen> {
  final _api = ApiService.instance;
  final _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _events = [];
  bool _loading = true;
  String? _error;
  String _category = 'all';
  String _search = '';

  static const _categories = <String, String>{
    'all': 'All Events',
    'business_management': 'Business',
    'finance': 'Finance',
    'marketing': 'Marketing',
    'information_technology': 'Tech',
    'communication': 'Communication',
    'economics': 'Economics',
    'entrepreneurship': 'Entrepreneurship',
    'leadership': 'Leadership',
    'career_development': 'Career',
  };

  static const _categoryColors = <String, Color>{
    'business_management': Color(0xFF3B82F6),  // blue
    'finance': Color(0xFF10B981),               // emerald
    'marketing': Color(0xFFF43F5E),             // rose
    'information_technology': Color(0xFF8B5CF6), // violet
    'communication': Color(0xFFFB923C),         // orange
    'economics': Color(0xFF6366F1),             // indigo
    'entrepreneurship': Color(0xFFEC4899),      // pink
    'leadership': Color(0xFF0EA5E9),            // sky
    'career_development': Color(0xFF14B8A6),   // teal
  };

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(() {
      // Guard against `setState` after `dispose` — the listener can fire
      // during teardown if a parent rebuild disposes us mid-text-change.
      if (!mounted) return;
      setState(() => _search = _searchCtrl.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.get<List<Map<String, dynamic>>>(
        '/competitive-events',
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

  List<Map<String, dynamic>> get _filtered {
    var list = _events;
    if (_category != 'all') {
      list = list.where((e) => e['category'] == _category).toList();
    }
    if (_search.isNotEmpty) {
      list = list
          .where((e) =>
              (e['name'] as String? ?? '').toLowerCase().contains(_search) ||
              (e['description'] as String? ?? '')
                  .toLowerCase()
                  .contains(_search))
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: isDark ? FblaColors.darkBg : FblaColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header with back button ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Back',
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: isDark
                          ? FblaColors.darkTextPrimary
                          : FblaColors.textPrimary,
                      size: 24,
                    ),
                  ),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        'Competitive Events',
                        style: FblaFonts.display(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Search field ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchCtrl,
                style: FblaFonts.body(
                  color: isDark
                      ? FblaColors.darkTextPrimary
                      : FblaColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Search events...',
                  hintStyle: FblaFonts.body().copyWith(
                    color: isDark
                        ? FblaColors.darkTextTertiary
                        : FblaColors.textTertiary,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: isDark
                        ? FblaColors.darkTextTertiary
                        : FblaColors.textTertiary,
                    size: 20,
                  ),
                  filled: true,
                  fillColor:
                      isDark ? FblaColors.darkSurface : FblaColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(FblaRadius.md),
                    borderSide: BorderSide(
                      color: isDark ? FblaColors.darkOutline : FblaColors.outline,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(FblaRadius.md),
                    borderSide: BorderSide(
                      color: isDark ? FblaColors.darkOutline : FblaColors.outline,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(FblaRadius.md),
                    borderSide: const BorderSide(
                      color: FblaColors.primary,
                      width: 1.5,
                    ),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),

            const SizedBox(height: 18),

            // ── Category chips ──────────────────────────────────────────────
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: _categories.entries.map((entry) {
                  final active = _category == entry.key;
                  final color = _categoryColors[entry.key] ?? FblaColors.primary;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _category = entry.key);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(FblaRadius.full),
                          color: active
                              ? color.withOpacity(0.15)
                              : (isDark
                                  ? FblaColors.darkSurface
                                  : FblaColors.surface),
                          border: Border.all(
                            color: active
                                ? color.withOpacity(0.4)
                                : (isDark
                                    ? FblaColors.darkOutline
                                    : FblaColors.outline),
                            width: active ? 1.5 : 1.0,
                          ),
                        ),
                        child: Text(
                          entry.value,
                          style: FblaFonts.label(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: active
                                ? color
                                : (isDark
                                    ? FblaColors.darkTextSecond
                                    : FblaColors.textSecondary),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 16),

            // ── Event count subtitle ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                '${filtered.length} event${filtered.length == 1 ? '' : 's'} found',
                style: FblaFonts.body(fontSize: 12).copyWith(
                  color: isDark
                      ? FblaColors.darkTextTertiary
                      : FblaColors.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Event cards list ────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: FblaColors.primary,
                      ),
                    )
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                size: 48,
                                color: isDark
                                    ? FblaColors.darkTextTertiary
                                    : FblaColors.textTertiary,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Failed to load events',
                                style: FblaFonts.heading(fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: FblaFonts.body(fontSize: 12).copyWith(
                                  color: isDark
                                      ? FblaColors.darkTextSecond
                                      : FblaColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextButton(
                                onPressed: _load,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : filtered.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.search_off_rounded,
                                      size: 48,
                                      color: isDark
                                          ? FblaColors.darkTextTertiary
                                          : FblaColors.textTertiary,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No events found',
                                      style: FblaFonts.heading(fontSize: 16),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Try adjusting your search or category filter',
                                      textAlign: TextAlign.center,
                                      style: FblaFonts.body(fontSize: 12).copyWith(
                                        color: isDark
                                            ? FblaColors.darkTextSecond
                                            : FblaColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                  20, 0, 20, 100),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final event = filtered[index];
                                return _CompetitiveEventCard(
                                  event: event,
                                  delay: index * 50,
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            CompetitiveEventDetailScreen(
                                              event: event,
                                            ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Competitive Event Card ──────────────────────────────────────────────────

class _CompetitiveEventCard extends StatefulWidget {
  const _CompetitiveEventCard({
    required this.event,
    required this.delay,
    required this.onTap,
  });

  final Map<String, dynamic> event;
  final int delay;
  final VoidCallback onTap;

  @override
  State<_CompetitiveEventCard> createState() => _CompetitiveEventCardState();
}

class _CompetitiveEventCardState extends State<_CompetitiveEventCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = widget.event['name'] as String? ?? '';
    final category = widget.event['category'] as String? ?? '';
    final eventType = widget.event['event_type'] as String? ?? '';
    final isIndividual = widget.event['is_individual'] as bool? ?? true;
    final description = widget.event['description'] as String? ?? '';
    final color = _CompetitiveEventsScreenState._categoryColors[category] ??
        FblaColors.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: Transform.scale(
          scale: _isPressed ? 0.97 : 1.0,
          child: Material(
            color: isDark ? FblaColors.darkSurface : FblaColors.surface,
            borderRadius: BorderRadius.circular(FblaRadius.md),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(FblaRadius.md),
                border: Border.all(
                  color: isDark ? FblaColors.darkOutline : FblaColors.outline,
                  width: 1.0,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category color indicator dot
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Main content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Event name (Josefin heading)
                        Text(
                          name,
                          style: FblaFonts.heading(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),

                        // Description preview
                        Text(
                          description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: FblaFonts.body(fontSize: 12).copyWith(
                            color: isDark
                                ? FblaColors.darkTextSecond
                                : FblaColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Type and participation badges
                        Row(
                          children: [
                            _TypeBadge(
                              type: eventType,
                              color: color,
                            ),
                            const SizedBox(width: 6),
                            _TypeBadge(
                              type: isIndividual ? 'individual' : 'team',
                              color: color,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Chevron indicator
                  Padding(
                    padding: const EdgeInsets.only(left: 8, top: 2),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: isDark
                          ? FblaColors.darkTextTertiary
                          : FblaColors.textTertiary,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: widget.delay.clamp(0, 300)))
        .fadeIn(duration: 200.ms, curve: FblaMotion.strongEaseOut)
        .moveY(begin: 8, end: 0, duration: 200.ms, curve: FblaMotion.strongEaseOut);
  }
}

// ── Type Badge Component ────────────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({
    required this.type,
    required this.color,
  });

  final String type;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final (label, icon) = switch (type) {
      'test' => ('Test', Icons.quiz_outlined),
      'presentation' => ('Presentation', Icons.present_to_all_outlined),
      'performance' => ('Performance', Icons.mic_outlined),
      'project' => ('Project', Icons.build_outlined),
      'individual' => ('Individual', Icons.person_outline_rounded),
      'team' => ('Team', Icons.group_outlined),
      _ => (type, Icons.circle_outlined),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(FblaRadius.sm),
        color: color.withOpacity(0.12),
        border: Border.all(
          color: color.withOpacity(0.25),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 11,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: FblaFonts.label(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
