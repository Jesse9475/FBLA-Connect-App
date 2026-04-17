import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'quiz_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Competitive Event Detail Screen — "Contender" Editorial Aesthetic
//
// Hero section with event name (Josefin display), category badge, description.
// Resources tab: clean list with icons, titles, and type badges.
// Practice tab: quiz cards with difficulty indicators and gold animations.
//
// All API calls preserved: /competitive-events/{id}/resources and /quizzes.
// All URL launching and quiz navigation maintained.
// ─────────────────────────────────────────────────────────────────────────────

class CompetitiveEventDetailScreen extends StatefulWidget {
  const CompetitiveEventDetailScreen({
    super.key,
    required this.event,
  });

  final Map<String, dynamic> event;

  @override
  State<CompetitiveEventDetailScreen> createState() =>
      _CompetitiveEventDetailScreenState();
}

class _CompetitiveEventDetailScreenState
    extends State<CompetitiveEventDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _api = ApiService.instance;
  static const _storage = FlutterSecureStorage();
  static const _bookmarkKey = 'bookmarked_competitive_event_ids';

  List<Map<String, dynamic>> _resources = [];
  List<Map<String, dynamic>> _quizzes = [];
  bool _loadingResources = true;
  bool _loadingQuizzes = true;
  bool _bookmarked = false;

  String get _eventId => widget.event['id'] as String? ?? '';
  String get _eventName => widget.event['name'] as String? ?? '';
  String get _eventCategory => widget.event['category'] as String? ?? '';
  String get _eventType => widget.event['event_type'] as String? ?? '';
  String get _description => widget.event['description'] as String? ?? '';
  bool get _isTeam => !(widget.event['is_individual'] as bool? ?? true);

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadResources();
    _loadQuizzes();
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
    if (_eventId.isEmpty) return;
    final ids = await _readBookmarks();
    if (mounted) setState(() => _bookmarked = ids.contains(_eventId));
  }

  Future<void> _toggleBookmark() async {
    if (_eventId.isEmpty) return;
    HapticFeedback.lightImpact();
    final ids = await _readBookmarks();
    final wasBookmarked = ids.contains(_eventId);
    if (wasBookmarked) {
      ids.remove(_eventId);
    } else {
      ids.add(_eventId);
    }
    await _storage.write(key: _bookmarkKey, value: jsonEncode(ids));
    if (mounted) {
      setState(() => _bookmarked = !wasBookmarked);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasBookmarked ? 'Removed from saved' : 'Saved for later',
            style: FblaFonts.body(fontSize: 13),
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadResources() async {
    try {
      final data = await _api.get<List<Map<String, dynamic>>>(
        '/competitive-events/$_eventId/resources',
        parser: (data) =>
            (data['resources'] as List? ?? []).cast<Map<String, dynamic>>(),
      );
      if (mounted) setState(() { _resources = data; _loadingResources = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingResources = false);
    }
  }

  Future<void> _loadQuizzes() async {
    try {
      final data = await _api.get<List<Map<String, dynamic>>>(
        '/competitive-events/$_eventId/quizzes',
        parser: (data) =>
            (data['quizzes'] as List? ?? []).cast<Map<String, dynamic>>(),
      );
      if (mounted) setState(() { _quizzes = data; _loadingQuizzes = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingQuizzes = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? FblaColors.darkBg : FblaColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header with back button ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 20, 0),
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
                        _eventName,
                        style: FblaFonts.heading(fontSize: 18),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _toggleBookmark,
                    tooltip: _bookmarked ? 'Remove bookmark' : 'Bookmark event',
                    icon: Icon(
                      _bookmarked ? Icons.bookmark : Icons.bookmark_outline,
                      color: _bookmarked
                          ? FblaColors.secondary
                          : (isDark
                              ? FblaColors.darkTextTertiary
                              : FblaColors.textTertiary),
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Hero section: Description + category badge ──────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _description,
                    style: FblaFonts.body(
                      fontSize: 13,
                      height: 1.6,
                    ).copyWith(
                      color: isDark
                          ? FblaColors.darkTextSecond
                          : FblaColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Info badges row
                  Row(
                    children: [
                      _CategoryBadge(
                        category: _eventCategory,
                      ),
                      const SizedBox(width: 8),
                      _InfoBadge(
                        icon: _isTeam
                            ? Icons.group_outlined
                            : Icons.person_outline_rounded,
                        label: _isTeam ? 'Team' : 'Individual',
                      ),
                      const SizedBox(width: 8),
                      _InfoBadge(
                        icon: Icons.category_outlined,
                        label: _eventType.replaceAll('_', ' '),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),

            // ── Tab bar ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TabBar(
                controller: _tabCtrl,
                tabs: const [
                  Tab(text: 'Resources'),
                  Tab(text: 'Practice'),
                ],
                labelStyle: FblaFonts.label(fontSize: 13).copyWith(
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelColor: isDark
                    ? FblaColors.darkTextTertiary
                    : FblaColors.textTertiary,
                labelColor: FblaColors.primary,
                indicatorColor: FblaColors.primary,
                indicatorSize: TabBarIndicatorSize.label,
                dividerHeight: 1,
                dividerColor:
                    isDark ? FblaColors.darkOutline : FblaColors.outline,
              ),
            ),

            // ── Tab content ─────────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _ResourcesTab(
                    resources: _resources,
                    loading: _loadingResources,
                    eventName: _eventName,
                  ),
                  _PracticeTab(
                    quizzes: _quizzes,
                    loading: _loadingQuizzes,
                    eventId: _eventId,
                    eventName: _eventName,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Category Badge ──────────────────────────────────────────────────────────

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.category});
  final String category;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final categoryDisplay = {
      'business_management': ('Business', Color(0xFF3B82F6)),
      'finance': ('Finance', Color(0xFF10B981)),
      'marketing': ('Marketing', Color(0xFFF43F5E)),
      'information_technology': ('Tech', Color(0xFF8B5CF6)),
      'communication': ('Communication', Color(0xFFFB923C)),
      'economics': ('Economics', Color(0xFF6366F1)),
      'entrepreneurship': ('Entrepreneurship', Color(0xFFEC4899)),
      'leadership': ('Leadership', Color(0xFF0EA5E9)),
      'career_development': ('Career', Color(0xFF14B8A6)),
    };

    final (label, color) = categoryDisplay[category] ?? ('Category', FblaColors.primary);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(FblaRadius.sm),
        color: color.withOpacity(0.12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 0.75,
        ),
      ),
      child: Text(
        label,
        style: FblaFonts.label(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ── Info Badge ──────────────────────────────────────────────────────────────

class _InfoBadge extends StatelessWidget {
  const _InfoBadge({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(FblaRadius.sm),
        color: isDark ? FblaColors.darkSurface : FblaColors.surfaceVariant,
        border: Border.all(
          color: isDark ? FblaColors.darkOutline : FblaColors.outline,
          width: 0.75,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: isDark ? FblaColors.darkTextSecond : FblaColors.textSecondary,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: FblaFonts.label(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? FblaColors.darkTextSecond : FblaColors.textSecondary,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Resources Tab ───────────────────────────────────────────────────────────

class _ResourcesTab extends StatelessWidget {
  const _ResourcesTab({
    required this.resources,
    required this.loading,
    required this.eventName,
  });

  final List<Map<String, dynamic>> resources;
  final bool loading;
  final String eventName;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: FblaColors.primary,
        ),
      );
    }

    if (resources.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.menu_book_outlined,
                size: 48,
                color: isDark
                    ? FblaColors.darkTextTertiary
                    : FblaColors.textTertiary,
              ),
              const SizedBox(height: 16),
              Text(
                'No resources yet',
                style: FblaFonts.heading(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Study resources for $eventName will appear here. Check back soon or try the practice quizzes.',
                textAlign: TextAlign.center,
                style: FblaFonts.body(fontSize: 12).copyWith(
                  color: isDark
                      ? FblaColors.darkTextSecond
                      : FblaColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      itemCount: resources.length,
      itemBuilder: (context, index) {
        final res = resources[index];
        final type = res['resource_type'] as String? ?? 'link';
        final title = res['title'] as String? ?? '';
        final desc = res['description'] as String? ?? '';
        final url = res['url'] as String?;

        final (icon, typeBadge) = switch (type) {
          'pdf' => (Icons.picture_as_pdf_outlined, 'PDF'),
          'video' => (Icons.play_circle_outline_rounded, 'Video'),
          'study_guide' => (Icons.auto_stories_outlined, 'Guide'),
          'sample_test' => (Icons.quiz_outlined, 'Test'),
          _ => (Icons.link_rounded, 'Link'),
        };

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              if (url != null && url.isNotEmpty) {
                launchUrl(
                  Uri.parse(url),
                  mode: LaunchMode.externalApplication,
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'No link available for this resource.',
                      style: FblaFonts.body(fontSize: 13),
                    ),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(FblaRadius.sm),
                    ),
                  ),
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(FblaRadius.md),
                color: isDark ? FblaColors.darkSurface : FblaColors.surface,
                border: Border.all(
                  color: isDark ? FblaColors.darkOutline : FblaColors.outline,
                  width: 1.0,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon background
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(FblaRadius.sm),
                      color: FblaColors.primary.withOpacity(0.12),
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: FblaColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: FblaFonts.body().copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? FblaColors.darkTextPrimary
                                      : FblaColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                color: FblaColors.primary.withOpacity(0.15),
                              ),
                              child: Text(
                                typeBadge,
                                style: FblaFonts.monoTag(
                                  fontSize: 11,
                                  color: FblaColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (desc.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            desc,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: FblaFonts.body(fontSize: 12).copyWith(
                              color: isDark
                                  ? FblaColors.darkTextSecond
                                  : FblaColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // External link icon
                  Icon(
                    Icons.open_in_new_rounded,
                    size: 16,
                    color: isDark
                        ? FblaColors.darkTextTertiary
                        : FblaColors.textTertiary,
                  ),
                ],
              ),
            ),
          ),
        )
            .animate(delay: Duration(milliseconds: (index * 40).clamp(0, 200)))
            .fadeIn(duration: 200.ms, curve: FblaMotion.strongEaseOut)
            .moveY(begin: 8, end: 0, duration: 200.ms, curve: FblaMotion.strongEaseOut);
      },
    );
  }
}

// ── Practice Tab (Quizzes) ──────────────────────────────────────────────────

class _PracticeTab extends StatelessWidget {
  const _PracticeTab({
    required this.quizzes,
    required this.loading,
    required this.eventId,
    required this.eventName,
  });

  final List<Map<String, dynamic>> quizzes;
  final bool loading;
  final String eventId;
  final String eventName;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: FblaColors.primary,
        ),
      );
    }

    if (quizzes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.quiz_outlined,
                size: 48,
                color: isDark
                    ? FblaColors.darkTextTertiary
                    : FblaColors.textTertiary,
              ),
              const SizedBox(height: 16),
              Text(
                'No quizzes yet',
                style: FblaFonts.heading(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Practice quizzes for $eventName will be available here. Earn points for correct answers!',
                textAlign: TextAlign.center,
                style: FblaFonts.body(fontSize: 12).copyWith(
                  color: isDark
                      ? FblaColors.darkTextSecond
                      : FblaColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      itemCount: quizzes.length,
      itemBuilder: (context, index) {
        final quiz = quizzes[index];
        final title = quiz['title'] as String? ?? 'Practice Quiz';
        final questionCount = quiz['question_count'] as int? ?? 0;
        final difficulty = quiz['difficulty'] as String? ?? 'medium';
        final pointsPer = quiz['points_per_correct'] as int? ?? 5;
        final timeLimit = quiz['time_limit_seconds'] as int?;

        final (diffColor, diffLabel) = switch (difficulty.toLowerCase()) {
          'easy' => (Color(0xFF10B981), 'Easy'),
          'hard' => (Color(0xFFDC2626), 'Hard'),
          _ => (Color(0xFFF59E0B), 'Medium'),
        };

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(FblaRadius.md),
              color: isDark ? FblaColors.darkSurface : FblaColors.surface,
              border: Border.all(
                color: isDark ? FblaColors.darkOutline : FblaColors.outline,
                width: 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quiz title and difficulty badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: FblaFonts.heading(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(FblaRadius.sm),
                        color: diffColor.withOpacity(0.15),
                        border: Border.all(
                          color: diffColor.withOpacity(0.3),
                          width: 0.75,
                        ),
                      ),
                      child: Text(
                        diffLabel,
                        style: FblaFonts.label(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: diffColor,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Quiz metadata in monospace
                Text(
                  '$questionCount questions · $pointsPer pts each${timeLimit != null ? ' · ${(timeLimit / 60).ceil()} min' : ''}',
                  style: FblaFonts.monoLabel(
                    fontSize: 11,
                    color: isDark ? FblaColors.darkTextSecond : FblaColors.textSecondary,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 14),

                // Mode buttons
                Row(
                  children: [
                    // Flashcards button
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => QuizScreen(
                              quiz: quiz,
                              mode: 'practice',
                            ),
                          ));
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(FblaRadius.sm),
                            border: Border.all(
                              color: isDark
                                  ? FblaColors.darkOutline
                                  : FblaColors.outline,
                              width: 1.0,
                            ),
                            color: isDark
                                ? FblaColors.darkSurface
                                : FblaColors.surface,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.style_outlined,
                                size: 16,
                                color: isDark
                                    ? FblaColors.darkTextPrimary
                                    : FblaColors.textPrimary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Flashcards',
                                style: FblaFonts.label(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? FblaColors.darkTextPrimary
                                      : FblaColors.textPrimary,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Test Mode button (gold accent)
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => QuizScreen(
                              quiz: quiz,
                              mode: 'test',
                            ),
                          ));
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(FblaRadius.sm),
                            gradient: FblaGradient.blueShimmer,
                            boxShadow: [
                              BoxShadow(
                                color: FblaColors.primary.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.timer_outlined,
                                size: 16,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Test Mode',
                                style: FblaFonts.label(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        )
            .animate(delay: Duration(milliseconds: (index * 50).clamp(0, 250)))
            .fadeIn(duration: 200.ms, curve: FblaMotion.strongEaseOut)
            .moveY(begin: 8, end: 0, duration: 200.ms, curve: FblaMotion.strongEaseOut);
      },
    );
  }
}
