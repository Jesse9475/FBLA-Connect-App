import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../services/api_service.dart';
import '../services/user_state.dart';
import '../theme/app_theme.dart';
import '../widgets/fbla_empty_view.dart';
import '../widgets/fbla_error_view.dart';
import '../widgets/announcement_card.dart';
import 'announcements_screen.dart';
import 'create_post_screen.dart';

/// Home feed — editorial design with staggered posts, announcements carousel,
/// and smooth interactions. Advisors/admins see a gold FAB to compose posts.
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _api = ApiService.instance;

  List<Map<String, dynamic>> _announcements = [];
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  String? _error;
  String? _backendDisplayName;

  // Announcement carousel state
  late final PageController _carouselCtrl;
  Timer? _carouselTimer;
  int _carouselPage = 0;

  @override
  void initState() {
    super.initState();
    _carouselCtrl = PageController();
    _load();
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _carouselCtrl.dispose();
    super.dispose();
  }

  /// Auto-scroll intentionally removed.
  /// Emil Kowalski principle: carousels auto-advancing every 4s interrupt users.
  /// Manual swipe with dot indicators gives affordance without hijacking attention.
  void _startCarousel() {
    // No-op — kept so _load() call sites don't need updating.
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      final futures = <Future<dynamic>>[
        _api.get<List<Map<String, dynamic>>>(
          '/announcements',
          parser: (data) =>
              (data['announcements'] as List).cast<Map<String, dynamic>>(),
        ),
        _api.get<List<Map<String, dynamic>>>(
          '/posts',
          parser: (data) =>
              (data['posts'] as List).cast<Map<String, dynamic>>(),
        ),
        if (userId != null)
          _api.get<Map<String, dynamic>>(
            '/users/$userId',
            parser: (data) =>
                (data['user'] as Map<String, dynamic>?) ?? {},
          ).catchError((_) => <String, dynamic>{}),
      ];

      final results = await Future.wait(futures);
      if (mounted) {
        if (userId != null && results.length > 2) {
          final userData = results[2] as Map<String, dynamic>;
          final dn = userData['display_name'] as String?;
          if (dn != null && dn.isNotEmpty) {
            // Greet with the full "First Last" display name rather than
            // truncating to the first token — students go by their full
            // name in chapter rosters and the greeting feels less
            // anonymous when both names show.
            _backendDisplayName = dn.trim();
          }
        }
        setState(() {
          _announcements = results[0] as List<Map<String, dynamic>>;
          _posts = results[1] as List<Map<String, dynamic>>;
          _loading = false;
        });
        _startCarousel();
      }
    } on Exception catch (e) {
      // Catch API exceptions and display user-facing error with retry affordance.
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    } catch (e) {
      // Unexpected error (not an Exception) — still show to user.
      if (mounted) {
        setState(() {
          _error =
              'An unexpected error occurred. Please try again.';
          _loading = false;
        });
        debugPrint('Feed load error: $e');
      }
    }
  }

  Future<void> _likePost(String postId) async {
    try {
      await _api.post<void>('/posts/$postId/like', body: {});
    } catch (_) {}
  }

  // ── Chapter-scoped filtering ─────────────────────────────────────────────────
  //
  // Rules:
  //   scope == 'national' (or null)  → visible to everyone
  //   scope == 'district'            → only members of the same district
  //   scope == 'chapter'             → only members of the same chapter
  //
  // Items with no scope field default to 'national'.

  bool _isVisible(Map<String, dynamic> item) {
    final scope = (item['scope'] as String?)?.toLowerCase() ?? 'national';
    if (scope == 'national') return true;

    final us = UserState.instance;
    if (scope == 'district') {
      final itemDistrict = item['district_id'] as String?;
      if (itemDistrict == null) return true; // no restriction
      return us.districtId == null || us.districtId == itemDistrict;
    }
    if (scope == 'chapter') {
      final itemChapter = item['chapter_id'] as String?;
      if (itemChapter == null) return true;
      return us.chapterId == null || us.chapterId == itemChapter;
    }
    return true; // unknown scope → show
  }

  List<Map<String, dynamic>> get _filteredAnnouncements =>
      _announcements.where(_isVisible).toList();

  List<Map<String, dynamic>> get _filteredPosts =>
      _posts.where(_isVisible).toList();

  String get _displayName {
    if (_backendDisplayName != null && _backendDisplayName!.isNotEmpty) {
      return _backendDisplayName!;
    }
    // Fall back to the auth metadata. Combine first + last when both are
    // present so the greeting reads "Surya Dusi" instead of just "Surya".
    final user = Supabase.instance.client.auth.currentUser;
    final meta = user?.userMetadata ?? {};
    final first = (meta['first_name'] as String?)?.trim() ??
        (meta['given_name'] as String?)?.trim();
    final last = (meta['last_name'] as String?)?.trim() ??
        (meta['family_name'] as String?)?.trim();
    if (first != null && first.isNotEmpty) {
      if (last != null && last.isNotEmpty) return '$first $last';
      return first;
    }
    final fullName = (meta['name'] as String?)?.trim();
    if (fullName != null && fullName.isNotEmpty) return fullName;
    return user?.email?.split('@').first ?? 'Leader';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Live snapshot used by sliver padding so the bottom gutter accounts
    // for the FAB.  The FAB itself is wrapped in a ListenableBuilder so it
    // appears immediately when the role flips after advisor verification.
    final canPost = UserState.instance.isAdvisorOrAdmin;

    return Scaffold(
      backgroundColor: FblaColors.darkBg,
      floatingActionButton: ListenableBuilder(
        listenable: UserState.instance,
        builder: (context, _) {
          if (!UserState.instance.isAdvisorOrAdmin) return const SizedBox.shrink();
          return _GoldFab(onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreatePostScreen()),
            ).then((_) => _load());
          });
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: _loading
          ? const _FeedSkeleton()
          : _error != null
              ? FblaErrorView(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  color: FblaColors.secondary,
                  backgroundColor: FblaColors.darkSurface,
                  child: CustomScrollView(
                    slivers: [
                      // ── Hero header with greeting ──────────────────────────
                      SliverToBoxAdapter(
                        child: _HeroHeader(
                          name: _displayName,
                          onNotificationTap: () =>
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      const AnnouncementsScreen(standalone: true),
                                ),
                              ),
                        ),
                      ),

                      // ── Announcements carousel (if any) ───────────────────
                      if (_filteredAnnouncements.isNotEmpty) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 8, 12, 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 3,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: FblaColors.secondary,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Announcements',
                                  style: FblaFonts.heading(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: FblaColors.darkTextPrimary,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const Spacer(),
                              ],
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: _AnnouncementCarousel(
                            announcements: _filteredAnnouncements,
                            controller: _carouselCtrl,
                            currentPage: _carouselPage,
                            onPageChanged: (i) =>
                                setState(() => _carouselPage = i),
                            onChanged: _load,
                          ),
                        ),
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 8),
                        ),
                      ],

                      // ── "Chapter Posts" section label ──────────────────────
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
                          child: Row(
                            children: [
                              Container(
                                width: 3,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: FblaColors.secondary,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Chapter Posts',
                                style: FblaFonts.heading(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: FblaColors.darkTextPrimary,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ── Posts list with stagger animation ──────────────────
                      if (_filteredPosts.isEmpty)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: FblaEmptyView(
                            icon: Icons.article_outlined,
                            title: 'No posts yet',
                            subtitle: 'Be the first to share something.',
                          ),
                        )
                      else
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            FblaSpacing.md,
                            0,
                            FblaSpacing.md,
                            canPost ? 72 : FblaSpacing.md,
                          ),
                          sliver: SliverList.separated(
                            itemCount: _filteredPosts.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: FblaSpacing.sm),
                            itemBuilder: (ctx, i) => _EditorialPostCard(
                              post: _filteredPosts[i],
                              onLike: () {
                                // Defensive null-check: the old force-cast
                                // `as String` would crash the app if a row
                                // came back from the API without an `id`.
                                final id = _filteredPosts[i]['id'];
                                if (id is String && id.isNotEmpty) {
                                  _likePost(id);
                                }
                              },
                              onDeleted: _load,
                            )
                                .animate(
                                  delay: Duration(milliseconds: i * 50),
                                )
                                .fadeIn(duration: FblaMotion.standard)
                                .slideY(
                                  begin: 0.08,
                                  end: 0,
                                  duration: FblaMotion.standard,
                                  curve: FblaMotion.easeOut,
                                ),
                          ),
                        ),
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 100),
                      ),
                    ],
                  ),
                ),
    );
  }
}

// ── Gold gradient FAB ────────────────────────────────────────────────────────

class _GoldFab extends StatefulWidget {
  const _GoldFab({required this.onPressed});
  final VoidCallback onPressed;

  @override
  State<_GoldFab> createState() => _GoldFabState();
}

class _GoldFabState extends State<_GoldFab> with SingleTickerProviderStateMixin {
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
    return ScaleTransition(
      scale: _pressScale,
      child: GestureDetector(
        onTapDown: (_) => _pressCtrl.forward(),
        onTapUp: (_) {
          _pressCtrl.reverse();
          widget.onPressed();
        },
        onTapCancel: () => _pressCtrl.reverse(),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: FblaGradient.goldShimmer,
            borderRadius: BorderRadius.circular(FblaRadius.full),
            boxShadow: FblaShadow.goldGlow,
          ),
          child: Material(
            color: Colors.transparent,
            child: Center(
              child: Icon(
                Icons.add,
                color: FblaColors.primaryDark,
                size: 26,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Hero header ──────────────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.name,
    required this.onNotificationTap,
  });

  final String name;
  final VoidCallback onNotificationTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 18
            ? 'Good afternoon'
            : 'Good evening';

    final dateLabel =
        '${_dayAbbr(now.weekday)} · ${_monthAbbr(now.month)} ${now.day}';

    return Container(
      decoration: const BoxDecoration(
        gradient: FblaGradient.brand,
      ),
      child: Stack(
        children: [
          // ── Ambient white highlight — top-right radial ────────────────────────
          Positioned(
            top: -20,
            right: -30,
            child: Container(
              width: 200,
              height: 200,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0x18FFFFFF),
                    Color(0x00FFFFFF),
                  ],
                ),
              ),
            ),
          ),
          // ── Second smaller white dot — bottom-left ───────────────────────────
          Positioned(
            bottom: 20,
            left: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0x10FFFFFF),
                    Color(0x00FFFFFF),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            bottom: false,
            child: Padding(
              // Compact hero — vertical insets dropped so the banner takes
              // up roughly 60% of its previous height, leaving more of the
              // first scroll devoted to actual chapter content.
              padding: const EdgeInsets.fromLTRB(
                FblaSpacing.lg,
                FblaSpacing.sm,
                FblaSpacing.md,
                FblaSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Top row: banner image + notification bell
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Banner: icon + FBLA CONNECT text
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/images/logo_64.png',
                          width: 34,
                          height: 34,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'FBLA',
                        style: FblaFonts.heading(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: FblaColors.onPrimary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'CONNECT',
                        style: FblaFonts.heading(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: FblaColors.secondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                      Semantics(
                        label: 'View announcements',
                        button: true,
                        child: GestureDetector(
                          onTap: onNotificationTap,
                          behavior: HitTestBehavior.opaque,
                          child: const SizedBox(
                            width: 44,
                            height: 44,
                            child: Center(
                              child: Icon(
                                Icons.notifications_outlined,
                                size: 22,
                                color: FblaColors.secondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: FblaSpacing.sm),

                  // ── Gold date caps ─────────────────────────────────────────
                  Text(
                    dateLabel,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: FblaColors.secondary,
                      letterSpacing: 2.0,
                    ),
                  ).animate(delay: 40.ms).fadeIn(duration: 250.ms),

                  const SizedBox(height: 4),

                  // ── Greeting — confident but compact ─────────────────────
                  Text(
                    '$greeting,',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: FblaColors.onPrimary,
                      height: 1.1,
                      letterSpacing: -0.4,
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 300.ms, curve: Curves.easeOut)
                      .slideY(
                        begin: 0.06,
                        end: 0,
                        duration: 300.ms,
                        curve: Curves.easeOut,
                      ),

                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: FblaColors.secondary,
                      height: 1.1,
                      letterSpacing: -0.4,
                    ),
                  )
                      .animate(delay: 40.ms)
                      .fadeIn(duration: 300.ms, curve: Curves.easeOut)
                      .slideY(
                        begin: 0.06,
                        end: 0,
                        duration: 300.ms,
                        curve: Curves.easeOut,
                      ),

                  const SizedBox(height: 4),

                  Text(
                    "What's happening in FBLA today?",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: FblaColors.onPrimary.withAlpha(180),
                      letterSpacing: 0.1,
                      height: 1.35,
                    ),
                  ).animate(delay: 80.ms).fadeIn(duration: 280.ms),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _dayAbbr(int weekday) => const [
        'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'
      ][weekday - 1];

  static String _monthAbbr(int month) => const [
        'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
        'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
      ][month - 1];
}

// ── Announcement carousel ────────────────────────────────────────────────────

class _AnnouncementCarousel extends StatelessWidget {
  const _AnnouncementCarousel({
    required this.announcements,
    required this.controller,
    required this.currentPage,
    required this.onPageChanged,
    this.onChanged,
  });

  final List<Map<String, dynamic>> announcements;
  final PageController controller;
  final int currentPage;
  final ValueChanged<int> onPageChanged;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 80,
          child: PageView.builder(
            controller: controller,
            physics: const BouncingScrollPhysics(),
            itemCount: announcements.length,
            onPageChanged: onPageChanged,
            itemBuilder: (ctx, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: FblaSpacing.lg),
              child: _AnnouncementCard(data: announcements[i], onChanged: onChanged),
            ),
          ),
        ),
        if (announcements.length > 1) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: FblaSpacing.lg),
            child: _CarouselDots(
              total: announcements.length,
              current: currentPage,
            ),
          ),
        ],
      ],
    );
  }
}

class _CarouselDots extends StatelessWidget {
  const _CarouselDots({
    required this.total,
    required this.current,
  });

  final int total;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final isActive = i == current;
        return Padding(
          padding: EdgeInsets.only(right: i < total - 1 ? 8 : 0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: FblaMotion.strongEaseOut,
            width: isActive ? 16 : 5,
            height: 5,
            decoration: BoxDecoration(
              color: isActive
                  ? FblaColors.secondary
                  : FblaColors.darkOutline,
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
        );
      }),
    );
  }
}

/// Editorial announcement card with type-specific styling.
class _AnnouncementCard extends StatefulWidget {
  const _AnnouncementCard({required this.data, this.onChanged});
  final Map<String, dynamic> data;
  final VoidCallback? onChanged;

  @override
  State<_AnnouncementCard> createState() => _AnnouncementCardState();
}

class _AnnouncementCardState extends State<_AnnouncementCard>
    with SingleTickerProviderStateMixin {
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
    _pressScale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _pressCtrl, curve: FblaMotion.strongEaseOut),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  String get _title => widget.data['title'] as String? ?? 'Announcement';
  String get _body => widget.data['body'] as String? ?? '';
  String get _scope => widget.data['scope'] as String? ?? 'national';
  String get _createdAt => widget.data['created_at'] as String? ?? '';

  String get _scopeLabel => switch (_scope) {
        'chapter' => 'CHAPTER',
        'district' => 'DISTRICT',
        _ => 'NATIONAL',
      };

  Color get _scopeColor => switch (_scope) {
        'chapter' => const Color(0xFF4A90E2),
        'district' => const Color(0xFFF5A623),
        _ => const Color(0xFF7ED321),
      };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF0E1B2E) : FblaColors.surface;
    final textPrimary =
        isDark ? FblaColors.darkTextPrimary : FblaColors.textPrimary;
    final textTertiary =
        isDark ? FblaColors.darkTextTertiary : FblaColors.textTertiary;
    final outline = isDark ? _scopeColor.withAlpha(60) : _scopeColor.withAlpha(90);

    return Semantics(
      label: '$_scopeLabel announcement: $_title',
      button: true,
      child: ScaleTransition(
        scale: _pressScale,
        child: GestureDetector(
          onTapDown: (_) => _pressCtrl.forward(),
          onTapUp: (_) {
            _pressCtrl.reverse();
            showAnnouncementDetail(context, widget.data, onChanged: widget.onChanged);
          },
          onTapCancel: () => _pressCtrl.reverse(),
          child: Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(FblaRadius.lg),
              border: Border.all(
                color: outline,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: _scopeColor.withAlpha(isDark ? 20 : 14),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(FblaRadius.lg),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    color: _scopeColor,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: _scopeColor.withAlpha(40),
                                  borderRadius: BorderRadius.circular(FblaRadius.full),
                                  border: Border.all(
                                    color: _scopeColor.withAlpha(100),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  _scopeLabel,
                                  style: FblaFonts.monoTag(
                                    fontSize: 9,
                                    color: _scopeColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _createdAt.isNotEmpty
                                    ? _createdAt.split('T').first
                                    : 'Recent',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: textTertiary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _title,
                            style: FblaFonts.heading(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                              letterSpacing: -0.1,
                            ).copyWith(height: 1.2),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: _scopeColor,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Editorial post card ──────────────────────────────────────────────────────

/// Clean editorial post card with author metadata, body, and interaction row.
/// Animations: like/bookmark scale + color, card press scale(0.98).
class _EditorialPostCard extends StatefulWidget {
  const _EditorialPostCard({
    required this.post,
    required this.onLike,
    this.onDeleted,
  });

  final Map<String, dynamic> post;
  final VoidCallback onLike;

  /// Invoked after the user successfully deletes their own post so the
  /// parent list can refresh. Null-safe: cards without a handler (e.g.
  /// on a profile preview) simply won't render a delete affordance.
  final VoidCallback? onDeleted;

  @override
  State<_EditorialPostCard> createState() => _EditorialPostCardState();
}

class _EditorialPostCardState extends State<_EditorialPostCard>
    with TickerProviderStateMixin {
  bool _liked = false;
  bool _bookmarked = false;

  late final AnimationController _likeCtrl;
  late final Animation<double> _likeScale;

  late final AnimationController _bookmarkCtrl;
  late final Animation<double> _bookmarkScale;

  late final AnimationController _pressCtrl;
  late final Animation<double> _pressScale;

  String get _body => _post['caption'] as String? ?? '';
  int get _likeCount => (_post['like_count'] as int?) ?? 0;
  String get _userId => _post['user_id'] as String? ?? '';
  String? get _mediaUrl {
    final raw = _post['media_url'];
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    return null;
  }

  String get _authorName {
    final first = _post['first_name'] as String?;
    if (first != null && first.isNotEmpty) return first;
    final display = _post['display_name'] as String?;
    if (display != null && display.isNotEmpty) return display;
    final author = _post['author_name'] as String?;
    if (author != null && author.isNotEmpty) return author;
    return 'Chapter Member';
  }

  DateTime? get _createdAt =>
      DateTime.tryParse(_post['created_at'] as String? ?? '');

  bool get _isOwn {
    final me = Supabase.instance.client.auth.currentUser?.id;
    return _post['user_id'] == me;
  }

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

  String get _displayLabel => _isOwn ? 'You' : _authorName;

  Map<String, dynamic> get _post => widget.post;

  @override
  void initState() {
    super.initState();
    _likeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _likeScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 45),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 0.88), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.88, end: 1.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _likeCtrl, curve: Curves.easeOut));

    _bookmarkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _bookmarkScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 45),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 0.9), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _bookmarkCtrl, curve: Curves.easeOut));

    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _pressScale = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _pressCtrl, curve: FblaMotion.strongEaseOut),
    );
  }

  @override
  void dispose() {
    _likeCtrl.dispose();
    _bookmarkCtrl.dispose();
    _pressCtrl.dispose();
    super.dispose();
  }

  void _handleLike() {
    if (_liked) return;
    setState(() => _liked = true);
    _likeCtrl.forward(from: 0);
    widget.onLike();
  }

  void _handleBookmark() {
    setState(() => _bookmarked = !_bookmarked);
    _bookmarkCtrl.forward(from: 0);
  }

  /// Show a destructive confirmation sheet, then DELETE /posts/<id>.
  /// Parent list is responsible for the actual refresh via [widget.onDeleted].
  Future<void> _confirmAndDelete() async {
    final postId = _post['id'];
    if (postId is! String || postId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FblaColors.darkSurface,
        title: Text(
          'Delete post?',
          style: FblaFonts.heading(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: FblaColors.darkTextPrimary,
          ),
        ),
        content: Text(
          'This will permanently remove the post for everyone. This can\'t be undone.',
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

    if (confirmed != true || !mounted) return;

    try {
      await ApiService.instance.delete('/posts/$postId');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Post deleted'),
          backgroundColor: FblaColors.darkSurface,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FblaRadius.md),
          ),
        ),
      );
      widget.onDeleted?.call();
    } catch (e) {
      if (!mounted) return;
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _pressCtrl.forward(),
      onTapUp: (_) => _pressCtrl.reverse(),
      onTapCancel: () => _pressCtrl.reverse(),
      child: ScaleTransition(
        scale: _pressScale,
        child: Container(
          decoration: BoxDecoration(
            color: FblaColors.darkSurface,
            borderRadius: BorderRadius.circular(FblaRadius.lg),
            border: Border.all(
              color: FblaColors.darkOutline,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Author header: avatar, name, timestamp ───────────────────
              Padding(
                padding: const EdgeInsets.all(FblaSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AuthorAvatar(
                      initial: _avatarInitial,
                      baseColor: _avatarColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _displayLabel,
                            style: FblaFonts.heading(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: FblaColors.darkTextPrimary,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_createdAt != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                timeago.format(_createdAt!, allowFromNow: true),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: FblaColors.darkTextTertiary,
                                  fontWeight: FontWeight.w400,
                                  fontFamily: 'JetBrains Mono',
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Trailing kebab menu — only rendered when the viewer
                    // owns this post AND a delete handler was wired in.
                    // Keeps the header clean for others and avoids tempting
                    // users with a button that doesn't do anything.
                    if (_isOwn && widget.onDeleted != null)
                      _OwnerPostMenu(
                        onDelete: _confirmAndDelete,
                      ),
                  ],
                ),
              ),

              // ── Photo (if attached) — rendered Instagram-style edge-to-edge ──
              if (_mediaUrl != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    FblaSpacing.md,
                    0,
                    FblaSpacing.md,
                    FblaSpacing.sm,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(FblaRadius.md),
                    child: AspectRatio(
                      aspectRatio: 4 / 5, // Instagram portrait default
                      child: ColoredBox(
                        color: FblaColors.darkSurfaceHigh,
                        child: Image.network(
                          _mediaUrl!,
                          fit: BoxFit.cover,
                          semanticLabel: 'Image attached to post',
                          gaplessPlayback: true,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: FblaColors.darkTextTertiary,
                                  value: progress.expectedTotalBytes != null
                                      ? progress.cumulativeBytesLoaded /
                                          progress.expectedTotalBytes!
                                      : null,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) => Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.broken_image_outlined,
                                  size: 28,
                                  color: FblaColors.darkTextTertiary,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Image unavailable',
                                  style: FblaFonts.label(
                                    fontSize: 11,
                                    color: FblaColors.darkTextTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // ── Post body text ─────────────────────────────────────────────
              if (_body.trim().isNotEmpty)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    FblaSpacing.md,
                    _mediaUrl != null ? FblaSpacing.sm : FblaSpacing.sm,
                    FblaSpacing.md,
                    FblaSpacing.md,
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
              if (_body.trim().isEmpty && _mediaUrl == null)
                const SizedBox(height: FblaSpacing.md),

              // ── Hairline separator ─────────────────────────────────────────
              Container(
                height: 1,
                color: FblaColors.darkOutline,
              ),

              // ── Interaction row: like, comment, bookmark ────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: FblaSpacing.sm,
                  vertical: FblaSpacing.sm,
                ),
                child: Row(
                  children: [
                    // Like button
                    Semantics(
                      label: _liked ? 'Unlike post' : 'Like post',
                      button: true,
                      child: InkWell(
                        onTap: _handleLike,
                        borderRadius: BorderRadius.circular(FblaRadius.md),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: FblaSpacing.sm,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              ScaleTransition(
                                scale: _likeScale,
                                child: Icon(
                                  _liked
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  size: 18,
                                  color: _liked
                                      ? FblaColors.secondary
                                      : FblaColors.darkTextTertiary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 200),
                                style: FblaFonts.label(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _liked
                                      ? FblaColors.secondary
                                      : FblaColors.darkTextSecond,
                                ),
                                child: Text(
                                  '${_likeCount + (_liked ? 1 : 0)}',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: FblaSpacing.sm),

                    // Comment button (coming soon)
                    Semantics(
                      label: 'Comment on post',
                      button: true,
                      child: InkWell(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Comments — coming soon'),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(FblaRadius.md),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: FblaSpacing.sm,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.mode_comment_outlined,
                                size: 18,
                                color: FblaColors.darkTextTertiary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Comment',
                                style: FblaFonts.label(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: FblaColors.darkTextSecond,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Bookmark button
                    Semantics(
                      label: _bookmarked ? 'Remove bookmark' : 'Bookmark post',
                      button: true,
                      child: InkWell(
                        onTap: _handleBookmark,
                        borderRadius: BorderRadius.circular(FblaRadius.md),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: FblaSpacing.sm,
                            vertical: 8,
                          ),
                          child: ScaleTransition(
                            scale: _bookmarkScale,
                            child: Icon(
                              _bookmarked
                                  ? Icons.bookmark_rounded
                                  : Icons.bookmark_outline_rounded,
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

// ── Author avatar ────────────────────────────────────────────────────────────

class _AuthorAvatar extends StatelessWidget {
  const _AuthorAvatar({
    required this.initial,
    required this.baseColor,
  });

  final String initial;
  final Color baseColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: baseColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: FblaColors.onPrimary.withAlpha(20),
          width: 1,
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: FblaColors.onPrimary,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }
}

// ── Loading skeleton ─────────────────────────────────────────────────────────

class _FeedSkeleton extends StatefulWidget {
  const _FeedSkeleton();

  @override
  State<_FeedSkeleton> createState() => _FeedSkeletonState();
}

class _FeedSkeletonState extends State<_FeedSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _sweep;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    _sweep = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;
    return AnimatedBuilder(
      animation: _sweep,
      builder: (_, __) {
        final shimmer = Color.lerp(
          FblaColors.darkSurface,
          FblaColors.darkSurfaceHigh,
          _sweep.value,
        )!;
        return SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
              FblaSpacing.md, safeTop + FblaSpacing.md, FblaSpacing.md, FblaSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ShimmerBox(color: shimmer, width: 200, height: 42),
              const SizedBox(height: 8),
              _ShimmerBox(color: shimmer, width: 280, height: 28),
              const SizedBox(height: FblaSpacing.lg),
              _ShimmerBox(color: shimmer, width: double.infinity, height: 160),
              const SizedBox(height: FblaSpacing.lg),
              for (int i = 0; i < 4; i++) ...[
                _PostCardSkeleton(shimmer: shimmer),
                const SizedBox(height: FblaSpacing.sm),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  const _ShimmerBox({
    required this.color,
    required this.width,
    required this.height,
    this.radius = FblaRadius.md,
  });

  final Color color;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _PostCardSkeleton extends StatelessWidget {
  const _PostCardSkeleton({required this.shimmer});
  final Color shimmer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(FblaSpacing.md),
      decoration: BoxDecoration(
        color: FblaColors.darkSurfaceHigh,
        borderRadius: BorderRadius.circular(FblaRadius.lg),
        border: Border.all(color: FblaColors.darkOutline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ShimmerBox(color: shimmer, width: 44, height: 44, radius: 22),
              const SizedBox(width: FblaSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ShimmerBox(color: shimmer, width: 120, height: 14),
                  const SizedBox(height: 6),
                  _ShimmerBox(color: shimmer, width: 80, height: 11),
                ],
              ),
            ],
          ),
          const SizedBox(height: FblaSpacing.md),
          _ShimmerBox(color: shimmer, width: double.infinity, height: 13),
          const SizedBox(height: 8),
          _ShimmerBox(color: shimmer, width: double.infinity, height: 13),
          const SizedBox(height: 8),
          _ShimmerBox(color: shimmer, width: 200, height: 13),
        ],
      ),
    );
  }
}

// ── Owner-only kebab menu ────────────────────────────────────────────────────
// Rendered in the post header when the viewer owns the post. One action
// today (Delete), but structured as a PopupMenuButton so Edit/Archive can
// slot in without rewriting the call sites.
class _OwnerPostMenu extends StatelessWidget {
  const _OwnerPostMenu({required this.onDelete});

  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Post options',
      icon: Icon(
        Icons.more_vert,
        color: FblaColors.darkTextSecond,
        size: 20,
      ),
      color: FblaColors.darkSurfaceHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FblaRadius.md),
        side: BorderSide(color: FblaColors.darkOutline, width: 1),
      ),
      padding: EdgeInsets.zero,
      splashRadius: 20,
      onSelected: (value) {
        if (value == 'delete') onDelete();
      },
      itemBuilder: (ctx) => [
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 18, color: FblaColors.error),
              const SizedBox(width: 10),
              Text(
                'Delete post',
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
