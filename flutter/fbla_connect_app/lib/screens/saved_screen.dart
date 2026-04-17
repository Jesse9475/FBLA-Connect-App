import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/event_card.dart';
import '../widgets/fbla_empty_view.dart';
import '../widgets/fbla_error_view.dart';
import 'chapter_event_detail_screen.dart';

/// Aggregates everything the user has saved/bookmarked across the app —
/// chapter events, posts, and competitive events — into one navigable hub.
///
/// Each tab loads the source list from the API and filters it by the IDs
/// persisted in [FlutterSecureStorage]. Bookmark IDs stay the source of
/// truth so toggling a bookmark anywhere in the app stays consistent here.
class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen>
    with SingleTickerProviderStateMixin {
  static const _storage = FlutterSecureStorage();
  static const _eventKey = 'bookmarked_event_ids';
  static const _postKey = 'bookmarked_post_ids';
  static const _ceKey = 'bookmarked_competitive_event_ids';
  static const _resourceKey = 'bookmarked_resource_ids';

  final _api = ApiService.instance;
  late final TabController _tabCtrl;

  // Per-tab state
  bool _loadingEvents = true;
  bool _loadingPosts = true;
  bool _loadingCEs = true;
  bool _loadingResources = true;
  String? _eventsError;
  String? _postsError;
  String? _cesError;
  String? _resourcesError;
  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _ces = [];
  List<Map<String, dynamic>> _resources = [];

  Set<String> _eventIds = {};
  Set<String> _postIds = {};
  Set<String> _ceIds = {};
  Set<String> _resourceIds = {};

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<Set<String>> _readIds(String key) async {
    try {
      final raw = await _storage.read(key: key);
      if (raw == null) return {};
      return (jsonDecode(raw) as List).cast<String>().toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadEvents(),
      _loadPosts(),
      _loadCEs(),
      _loadResources(),
    ]);
  }

  Future<void> _loadResources() async {
    setState(() {
      _loadingResources = true;
      _resourcesError = null;
    });
    try {
      _resourceIds = await _readIds(_resourceKey);
      if (_resourceIds.isEmpty) {
        if (!mounted) return;
        setState(() {
          _resources = [];
          _loadingResources = false;
        });
        return;
      }
      final all = await _api.get<List<Map<String, dynamic>>>(
        '/hub',
        parser: (data) =>
            (data['hub_items'] as List? ?? []).cast<Map<String, dynamic>>(),
      );
      if (!mounted) return;
      setState(() {
        _resources = all
            .where((r) => _resourceIds.contains(r['id'] as String? ?? ''))
            .toList();
        _loadingResources = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _resourcesError = e.toString().replaceFirst('Exception: ', '');
        _loadingResources = false;
      });
    }
  }

  Future<void> _loadEvents() async {
    setState(() {
      _loadingEvents = true;
      _eventsError = null;
    });
    try {
      _eventIds = await _readIds(_eventKey);
      if (_eventIds.isEmpty) {
        if (!mounted) return;
        setState(() {
          _events = [];
          _loadingEvents = false;
        });
        return;
      }
      final all = await _api.get<List<Map<String, dynamic>>>(
        '/events',
        parser: (data) =>
            (data['events'] as List? ?? []).cast<Map<String, dynamic>>(),
      );
      if (!mounted) return;
      setState(() {
        _events = all
            .where((e) => _eventIds.contains(e['id'] as String? ?? ''))
            .toList();
        _loadingEvents = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _eventsError = e.toString().replaceFirst('Exception: ', '');
        _loadingEvents = false;
      });
    }
  }

  Future<void> _loadPosts() async {
    setState(() {
      _loadingPosts = true;
      _postsError = null;
    });
    try {
      _postIds = await _readIds(_postKey);
      if (_postIds.isEmpty) {
        if (!mounted) return;
        setState(() {
          _posts = [];
          _loadingPosts = false;
        });
        return;
      }
      final all = await _api.get<List<Map<String, dynamic>>>(
        '/posts',
        parser: (data) =>
            (data['posts'] as List? ?? []).cast<Map<String, dynamic>>(),
      );
      if (!mounted) return;
      setState(() {
        _posts = all
            .where((p) => _postIds.contains(p['id'] as String? ?? ''))
            .toList();
        _loadingPosts = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _postsError = e.toString().replaceFirst('Exception: ', '');
        _loadingPosts = false;
      });
    }
  }

  Future<void> _loadCEs() async {
    setState(() {
      _loadingCEs = true;
      _cesError = null;
    });
    try {
      _ceIds = await _readIds(_ceKey);
      if (_ceIds.isEmpty) {
        if (!mounted) return;
        setState(() {
          _ces = [];
          _loadingCEs = false;
        });
        return;
      }
      final all = await _api.get<List<Map<String, dynamic>>>(
        '/competitive-events',
        parser: (data) =>
            (data['events'] as List? ?? data['competitive_events'] as List? ?? [])
                .cast<Map<String, dynamic>>(),
      );
      if (!mounted) return;
      setState(() {
        _ces = all
            .where((e) => _ceIds.contains(e['id'] as String? ?? ''))
            .toList();
        _loadingCEs = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cesError = e.toString().replaceFirst('Exception: ', '');
        _loadingCEs = false;
      });
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? FblaColors.darkBg : FblaColors.background;
    final textPrimary =
        isDark ? FblaColors.darkTextPrimary : FblaColors.textPrimary;
    final textSecond =
        isDark ? FblaColors.darkTextSecond : FblaColors.textSecondary;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Saved',
          style: TextStyle(
            fontFamily: 'Josefin Sans',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tabCtrl,
            indicatorColor: FblaColors.secondary,
            indicatorWeight: 3,
            labelColor: textPrimary,
            unselectedLabelColor: textSecond,
            labelStyle: const TextStyle(
              fontFamily: 'Mulish',
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
            unselectedLabelStyle: const TextStyle(
              fontFamily: 'Mulish',
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            isScrollable: true,
            tabs: [
              Tab(text: 'Events (${_events.length})'),
              Tab(text: 'Posts (${_posts.length})'),
              Tab(text: 'Comp. (${_ces.length})'),
              Tab(text: 'Resources (${_resources.length})'),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _SavedEventsTab(
            loading: _loadingEvents,
            error: _eventsError,
            events: _events,
            onRetry: _loadEvents,
          ),
          _SavedPostsTab(
            loading: _loadingPosts,
            error: _postsError,
            posts: _posts,
            onRetry: _loadPosts,
            isDark: isDark,
          ),
          _SavedCEsTab(
            loading: _loadingCEs,
            error: _cesError,
            events: _ces,
            onRetry: _loadCEs,
            isDark: isDark,
          ),
          _SavedResourcesTab(
            loading: _loadingResources,
            error: _resourcesError,
            resources: _resources,
            onRetry: _loadResources,
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

// ─── Tabs ────────────────────────────────────────────────────────────────────

class _SavedEventsTab extends StatelessWidget {
  const _SavedEventsTab({
    required this.loading,
    required this.error,
    required this.events,
    required this.onRetry,
  });

  final bool loading;
  final String? error;
  final List<Map<String, dynamic>> events;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(color: FblaColors.secondary),
      );
    }
    if (error != null) {
      return FblaErrorView(message: error!, onRetry: onRetry);
    }
    if (events.isEmpty) {
      return FblaEmptyView(
        icon: Icons.bookmark_outline,
        title: 'No saved events yet',
        subtitle:
            'Tap the bookmark icon on any event to save it here for quick access.',
      );
    }
    return RefreshIndicator(
      onRefresh: () async => onRetry(),
      color: FblaColors.secondary,
      child: ListView.builder(
        padding: const EdgeInsets.all(FblaSpacing.md),
        itemCount: events.length,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.only(bottom: FblaSpacing.sm),
          child: EventCard(
            event: events[i],
            isBookmarked: true,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    ChapterEventDetailScreen(event: events[i]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SavedPostsTab extends StatelessWidget {
  const _SavedPostsTab({
    required this.loading,
    required this.error,
    required this.posts,
    required this.onRetry,
    required this.isDark,
  });

  final bool loading;
  final String? error;
  final List<Map<String, dynamic>> posts;
  final VoidCallback onRetry;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(color: FblaColors.secondary),
      );
    }
    if (error != null) return FblaErrorView(message: error!, onRetry: onRetry);
    if (posts.isEmpty) {
      return FblaEmptyView(
        icon: Icons.push_pin_outlined,
        title: 'No saved posts yet',
        subtitle:
            'Bookmark posts from the chapter feed to revisit them later.',
      );
    }
    return RefreshIndicator(
      onRefresh: () async => onRetry(),
      color: FblaColors.secondary,
      child: ListView.builder(
        padding: const EdgeInsets.all(FblaSpacing.md),
        itemCount: posts.length,
        itemBuilder: (_, i) => _SavedPostCard(post: posts[i], isDark: isDark),
      ),
    );
  }
}

class _SavedCEsTab extends StatelessWidget {
  const _SavedCEsTab({
    required this.loading,
    required this.error,
    required this.events,
    required this.onRetry,
    required this.isDark,
  });

  final bool loading;
  final String? error;
  final List<Map<String, dynamic>> events;
  final VoidCallback onRetry;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(color: FblaColors.secondary),
      );
    }
    if (error != null) return FblaErrorView(message: error!, onRetry: onRetry);
    if (events.isEmpty) {
      return FblaEmptyView(
        icon: Icons.emoji_events_outlined,
        title: 'No saved competitive events',
        subtitle:
            'Star competitive events you\'re considering for nationals or districts.',
      );
    }
    return RefreshIndicator(
      onRefresh: () async => onRetry(),
      color: FblaColors.secondary,
      child: ListView.builder(
        padding: const EdgeInsets.all(FblaSpacing.md),
        itemCount: events.length,
        itemBuilder: (_, i) => _SavedCECard(event: events[i], isDark: isDark),
      ),
    );
  }
}

// ─── Cards ───────────────────────────────────────────────────────────────────

class _SavedPostCard extends StatelessWidget {
  const _SavedPostCard({required this.post, required this.isDark});
  final Map<String, dynamic> post;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final title = post['title'] as String? ?? 'Untitled post';
    final body = post['body'] as String? ?? '';
    final author = post['author_name'] as String? ?? 'Unknown';

    final surface = isDark ? FblaColors.darkSurfaceHigh : Colors.white;
    final outline = isDark ? FblaColors.darkOutline : FblaColors.outline;
    final textPrimary =
        isDark ? FblaColors.darkTextPrimary : FblaColors.textPrimary;
    final textSecond =
        isDark ? FblaColors.darkTextSecond : FblaColors.textSecondary;

    return Container(
      margin: const EdgeInsets.only(bottom: FblaSpacing.sm),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(FblaRadius.md),
        border: Border.all(color: outline),
      ),
      padding: const EdgeInsets.all(FblaSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Josefin Sans',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              body,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Mulish',
                fontSize: 13,
                height: 1.45,
                color: textPrimary.withAlpha(220),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            author,
            style: TextStyle(
              fontFamily: 'Mulish',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textSecond,
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedResourcesTab extends StatelessWidget {
  const _SavedResourcesTab({
    required this.loading,
    required this.error,
    required this.resources,
    required this.onRetry,
    required this.isDark,
  });

  final bool loading;
  final String? error;
  final List<Map<String, dynamic>> resources;
  final VoidCallback onRetry;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(color: FblaColors.secondary),
      );
    }
    if (error != null) return FblaErrorView(message: error!, onRetry: onRetry);
    if (resources.isEmpty) {
      return FblaEmptyView(
        icon: Icons.library_books_outlined,
        title: 'No saved resources',
        subtitle:
            'Tap the bookmark icon on any resource in the Hub to save it here.',
      );
    }
    return RefreshIndicator(
      onRefresh: () async => onRetry(),
      color: FblaColors.secondary,
      child: ListView.builder(
        padding: const EdgeInsets.all(FblaSpacing.md),
        itemCount: resources.length,
        itemBuilder: (_, i) =>
            _SavedResourceCard(resource: resources[i], isDark: isDark),
      ),
    );
  }
}

class _SavedResourceCard extends StatelessWidget {
  const _SavedResourceCard({required this.resource, required this.isDark});
  final Map<String, dynamic> resource;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final title = resource['title'] as String? ?? 'Untitled resource';
    final body = resource['body'] as String? ?? '';
    final category = resource['category'] as String? ?? '';

    final surface = isDark ? FblaColors.darkSurfaceHigh : Colors.white;
    final outline = isDark ? FblaColors.darkOutline : FblaColors.outline;
    final textPrimary =
        isDark ? FblaColors.darkTextPrimary : FblaColors.textPrimary;
    final textSecond =
        isDark ? FblaColors.darkTextSecond : FblaColors.textSecondary;

    return Container(
      margin: const EdgeInsets.only(bottom: FblaSpacing.sm),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(FblaRadius.md),
        border: Border.all(color: outline),
      ),
      padding: const EdgeInsets.all(FblaSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: FblaColors.primary.withAlpha(28),
              borderRadius: BorderRadius.circular(FblaRadius.sm),
            ),
            child: const Icon(
              Icons.library_books_outlined,
              color: FblaColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: FblaSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Josefin Sans',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (category.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    category,
                    style: TextStyle(
                      fontFamily: 'Mulish',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: FblaColors.primary,
                    ),
                  ),
                ],
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Mulish',
                      fontSize: 12,
                      height: 1.4,
                      color: textSecond,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedCECard extends StatelessWidget {
  const _SavedCECard({required this.event, required this.isDark});
  final Map<String, dynamic> event;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final name = event['name'] as String? ?? 'Untitled event';
    final category = event['category'] as String? ?? '';
    final isTeam = !(event['is_individual'] as bool? ?? true);

    final surface = isDark ? FblaColors.darkSurfaceHigh : Colors.white;
    final outline = isDark ? FblaColors.darkOutline : FblaColors.outline;
    final textPrimary =
        isDark ? FblaColors.darkTextPrimary : FblaColors.textPrimary;

    return Container(
      margin: const EdgeInsets.only(bottom: FblaSpacing.sm),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(FblaRadius.md),
        border: Border.all(color: outline),
      ),
      padding: const EdgeInsets.all(FblaSpacing.md),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: FblaColors.secondary.withAlpha(28),
              borderRadius: BorderRadius.circular(FblaRadius.sm),
            ),
            child: const Icon(Icons.emoji_events_rounded,
                color: FblaColors.secondary, size: 22),
          ),
          const SizedBox(width: FblaSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontFamily: 'Josefin Sans',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${isTeam ? 'Team' : 'Individual'}${category.isNotEmpty ? ' · $category' : ''}',
                  style: TextStyle(
                    fontFamily: 'Mulish',
                    fontSize: 12,
                    color: textPrimary.withAlpha(180),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
