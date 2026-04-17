import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/fbla_app_bar.dart';
import '../widgets/fbla_empty_view.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Friends Screen
//
// Three tabs:
//   • Friends      — accepted friendships
//   • Requests     — incoming pending requests (you can accept / reject)
//   • Find People  — search box; tap a user to send a friend request
//
// All data flows through the /api/friends.* endpoints. Each row knows its
// `relationship` so the action button switches between Add / Sent / Accept /
// Friends without an extra round-trip.
// ─────────────────────────────────────────────────────────────────────────────

enum _Relationship {
  none,
  pendingOutgoing,
  pendingIncoming,
  accepted,
  self,
}

_Relationship _parseRelationship(String? raw) => switch (raw) {
      'pending_outgoing' => _Relationship.pendingOutgoing,
      'pending_incoming' => _Relationship.pendingIncoming,
      'accepted' => _Relationship.accepted,
      'self' => _Relationship.self,
      _ => _Relationship.none,
    };

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _api = ApiService.instance;

  // Friends list state
  bool _friendsLoading = true;
  String? _friendsError;
  List<Map<String, dynamic>> _friends = const [];

  // Pending requests state
  bool _pendingLoading = true;
  String? _pendingError;
  List<Map<String, dynamic>> _pending = const [];

  // Search state
  final _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _searchDebounce;
  bool _searchLoading = false;
  String? _searchError;
  List<Map<String, dynamic>> _searchResults = const [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _loadFriends();
    _loadPending();
    // Pre-load an initial page of users so the Find tab isn't empty.
    _runSearch('');
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _loadFriends() async {
    setState(() {
      _friendsLoading = true;
      _friendsError = null;
    });
    try {
      final list = await _api.get<List<Map<String, dynamic>>>(
        '/friends',
        parser: (data) => List<Map<String, dynamic>>.from(
          (data as Map<String, dynamic>)['friends'] as List? ?? const [],
        ),
      );
      if (!mounted) return;
      setState(() {
        _friends = list;
        _friendsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _friendsError = e.toString().replaceFirst('Exception: ', '');
        _friendsLoading = false;
      });
    }
  }

  Future<void> _loadPending() async {
    setState(() {
      _pendingLoading = true;
      _pendingError = null;
    });
    try {
      final list = await _api.get<List<Map<String, dynamic>>>(
        '/friends/pending',
        parser: (data) => List<Map<String, dynamic>>.from(
          (data as Map<String, dynamic>)['requests'] as List? ?? const [],
        ),
      );
      if (!mounted) return;
      setState(() {
        _pending = list;
        _pendingLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pendingError = e.toString().replaceFirst('Exception: ', '');
        _pendingLoading = false;
      });
    }
  }

  void _onSearchChanged(String q) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 240), () {
      _runSearch(q);
    });
  }

  Future<void> _runSearch(String q) async {
    setState(() {
      _searchLoading = true;
      _searchError = null;
    });
    try {
      final list = await _api.get<List<Map<String, dynamic>>>(
        '/friends/search',
        queryParameters: {if (q.isNotEmpty) 'q': q, 'limit': 25},
        parser: (data) => List<Map<String, dynamic>>.from(
          (data as Map<String, dynamic>)['users'] as List? ?? const [],
        ),
      );
      if (!mounted) return;
      setState(() {
        _searchResults = list;
        _searchLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searchError = e.toString().replaceFirst('Exception: ', '');
        _searchLoading = false;
      });
    }
  }

  // ── Mutations ─────────────────────────────────────────────────────────────

  Future<void> _sendRequest(Map<String, dynamic> user) async {
    final id = user['id'] as String?;
    if (id == null) return;
    HapticFeedback.lightImpact();
    try {
      await _api.post<Map<String, dynamic>>(
        '/friends/request/$id',
        body: const {},
        parser: (data) => Map<String, dynamic>.from(data as Map),
      );
      _toast('Request sent to ${_displayName(user)}');
    } catch (e) {
      _toast(e.toString().replaceFirst('Exception: ', ''));
    }
    _runSearch(_searchCtrl.text);
    _loadPending();
  }

  Future<void> _accept(Map<String, dynamic> user) async {
    final id = user['id'] as String?;
    if (id == null) return;
    HapticFeedback.mediumImpact();
    try {
      await _api.post<Map<String, dynamic>>(
        '/friends/$id/accept',
        body: const {},
        parser: (data) => Map<String, dynamic>.from(data as Map),
      );
      _toast('You\u2019re now friends with ${_displayName(user)}');
    } catch (e) {
      _toast(e.toString().replaceFirst('Exception: ', ''));
    }
    _loadPending();
    _loadFriends();
  }

  Future<void> _reject(Map<String, dynamic> user) async {
    final id = user['id'] as String?;
    if (id == null) return;
    try {
      await _api.post<Map<String, dynamic>>(
        '/friends/$id/reject',
        body: const {},
        parser: (data) => Map<String, dynamic>.from(data as Map),
      );
    } catch (_) {/* swallow — UI refresh handles state */}
    _loadPending();
    _runSearch(_searchCtrl.text);
  }

  Future<void> _unfriend(Map<String, dynamic> user) async {
    final id = user['id'] as String?;
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: FblaColors.darkSurface,
        title: Text(
          'Remove ${_displayName(user)}?',
          style: FblaFonts.heading(fontSize: 17),
        ),
        content: Text(
          'You\u2019ll need to send a new request if you want to reconnect.',
          style: FblaFonts.body(fontSize: 14)
              .copyWith(color: FblaColors.darkTextSecond),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _api.delete<void>('/friends/$id');
    } catch (_) {/* refresh handles errors */}
    _loadFriends();
    _runSearch(_searchCtrl.text);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _displayName(Map<String, dynamic> user) {
    final n = (user['display_name'] as String?)?.trim();
    if (n != null && n.isNotEmpty) return n;
    final u = (user['username'] as String?)?.trim();
    if (u != null && u.isNotEmpty) return '@$u';
    return 'FBLA member';
  }

  String _initials(Map<String, dynamic> user) {
    final name = _displayName(user);
    if (name.startsWith('@')) {
      return name.substring(1, name.length >= 3 ? 3 : name.length).toUpperCase();
    }
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: TextStyle(color: FblaColors.darkTextPrimary),
          ),
          backgroundColor: FblaColors.darkSurface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FblaRadius.md),
          ),
        ),
      );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final pendingCount = _pending.length;

    return Scaffold(
      backgroundColor: FblaColors.darkBg,
      appBar: FblaAppBar(
        title: const Text(
          'Friends',
          style: TextStyle(
            fontFamily: 'Josefin Sans',
            fontWeight: FontWeight.w700,
            color: Colors.white,
            fontSize: 19,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: FblaColors.darkBg,
            child: TabBar(
              controller: _tabs,
              indicatorColor: FblaColors.secondary,
              indicatorWeight: 2.5,
              labelColor: FblaColors.darkTextPrimary,
              unselectedLabelColor: FblaColors.darkTextTertiary,
              labelStyle: FblaFonts.label(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              tabs: [
                const Tab(text: 'Friends'),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Requests'),
                      if (pendingCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: FblaColors.secondary,
                            borderRadius:
                                BorderRadius.circular(FblaRadius.full),
                          ),
                          child: Text(
                            '$pendingCount',
                            style: const TextStyle(
                              fontFamily: 'Mulish',
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              color: FblaColors.primaryDark,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Tab(text: 'Find People'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildFriendsTab(),
          _buildPendingTab(),
          _buildFindTab(),
        ],
      ),
    );
  }

  Widget _buildFriendsTab() {
    if (_friendsLoading) return const _ListSkeleton();
    if (_friendsError != null) {
      return _ErrorView(message: _friendsError!, onRetry: _loadFriends);
    }
    if (_friends.isEmpty) {
      return const FblaEmptyView(
        icon: Icons.group_outlined,
        title: 'No friends yet',
        subtitle: 'Find FBLA members in the Find People tab.',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadFriends,
      color: FblaColors.secondary,
      backgroundColor: FblaColors.darkSurface,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        itemCount: _friends.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final entry = _friends[i];
          final user = (entry['user'] as Map?)?.cast<String, dynamic>() ?? const {};
          return _FriendRow(
            initials: _initials(user),
            displayName: _displayName(user),
            sublabel: (user['role'] as String?)?.toUpperCase() ?? 'MEMBER',
            trailing: _GhostButton(
              label: 'Remove',
              tone: _GhostTone.danger,
              onTap: () => _unfriend(user),
            ),
          )
              .animate(delay: Duration(milliseconds: i * 28))
              .fadeIn(duration: FblaMotion.standard)
              .slideY(
                begin: 0.06,
                end: 0,
                duration: FblaMotion.standard,
                curve: FblaMotion.easeOut,
              );
        },
      ),
    );
  }

  Widget _buildPendingTab() {
    if (_pendingLoading) return const _ListSkeleton();
    if (_pendingError != null) {
      return _ErrorView(message: _pendingError!, onRetry: _loadPending);
    }
    if (_pending.isEmpty) {
      return const FblaEmptyView(
        icon: Icons.mark_email_unread_outlined,
        title: 'No pending requests',
        subtitle: 'New friend requests will appear here.',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadPending,
      color: FblaColors.secondary,
      backgroundColor: FblaColors.darkSurface,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        itemCount: _pending.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final entry = _pending[i];
          final user = (entry['user'] as Map?)?.cast<String, dynamic>() ?? const {};
          return _FriendRow(
            initials: _initials(user),
            displayName: _displayName(user),
            sublabel: 'wants to be your friend',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _GhostButton(
                  label: 'Decline',
                  tone: _GhostTone.muted,
                  onTap: () => _reject(user),
                ),
                const SizedBox(width: 8),
                _GhostButton(
                  label: 'Accept',
                  tone: _GhostTone.primary,
                  onTap: () => _accept(user),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFindTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            focusNode: _searchFocus,
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            onSubmitted: _runSearch,
            style: FblaFonts.body(fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Search by name or username',
              hintStyle: FblaFonts.body(fontSize: 14)
                  .copyWith(color: FblaColors.darkTextTertiary),
              prefixIcon: Icon(Icons.search,
                  color: FblaColors.darkTextTertiary, size: 20),
              filled: true,
              fillColor: FblaColors.darkSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(FblaRadius.md),
                borderSide: BorderSide(color: FblaColors.darkOutline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(FblaRadius.md),
                borderSide: BorderSide(color: FblaColors.darkOutline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(FblaRadius.md),
                borderSide: const BorderSide(
                    color: FblaColors.secondary, width: 1.4),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 14),
            ),
          ),
        ),
        if (_searchLoading)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: FblaColors.secondary,
              ),
            ),
          )
        else if (_searchError != null)
          Expanded(
            child: _ErrorView(
                message: _searchError!,
                onRetry: () => _runSearch(_searchCtrl.text)),
          )
        else if (_searchResults.isEmpty)
          const Expanded(
            child: FblaEmptyView(
              icon: Icons.person_search_outlined,
              title: 'No matches',
              subtitle: 'Try another name or username.',
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              itemCount: _searchResults.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final user = _searchResults[i];
                final rel = _parseRelationship(user['relationship'] as String?);
                final trailing = switch (rel) {
                  _Relationship.self => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        'You',
                        style: FblaFonts.label(fontSize: 11)
                            .copyWith(color: FblaColors.darkTextTertiary),
                      ),
                    ),
                  _Relationship.accepted => _Pill(
                      label: 'Friends',
                      icon: Icons.check_rounded,
                      color: FblaColors.secondary,
                    ),
                  _Relationship.pendingOutgoing => _Pill(
                      label: 'Sent',
                      icon: Icons.schedule_rounded,
                      color: FblaColors.darkTextTertiary,
                    ),
                  _Relationship.pendingIncoming => _GhostButton(
                      label: 'Accept',
                      tone: _GhostTone.primary,
                      onTap: () => _accept(user),
                    ),
                  _Relationship.none => _GhostButton(
                      label: 'Add',
                      tone: _GhostTone.primary,
                      icon: Icons.add_rounded,
                      onTap: () => _sendRequest(user),
                    ),
                };
                return _FriendRow(
                  initials: _initials(user),
                  displayName: _displayName(user),
                  sublabel: (user['role'] as String?)?.toUpperCase() ?? 'MEMBER',
                  trailing: trailing,
                );
              },
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Row / atoms
// ─────────────────────────────────────────────────────────────────────────────

class _FriendRow extends StatelessWidget {
  const _FriendRow({
    required this.initials,
    required this.displayName,
    required this.sublabel,
    required this.trailing,
  });

  final String initials;
  final String displayName;
  final String sublabel;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: FblaColors.darkSurface,
        border: Border.all(color: FblaColors.darkOutline),
        borderRadius: BorderRadius.circular(FblaRadius.md),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: FblaGradient.gold,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: const TextStyle(
                fontFamily: 'Mulish',
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: FblaColors.primaryDark,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayName,
                  style: FblaFonts.heading(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: FblaColors.darkTextPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  sublabel,
                  style: FblaFonts.label(fontSize: 11).copyWith(
                    color: FblaColors.darkTextTertiary,
                    letterSpacing: 0.4,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}

enum _GhostTone { primary, muted, danger }

class _GhostButton extends StatelessWidget {
  const _GhostButton({
    required this.label,
    required this.onTap,
    this.tone = _GhostTone.primary,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final _GhostTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (Color fg, Color bg, Color border) = switch (tone) {
      _GhostTone.primary => (
          FblaColors.primaryDark,
          FblaColors.secondary,
          FblaColors.secondary,
        ),
      _GhostTone.muted => (
          FblaColors.darkTextSecond,
          Colors.transparent,
          FblaColors.darkOutline,
        ),
      _GhostTone.danger => (
          const Color(0xFFEF4444),
          Colors.transparent,
          FblaColors.darkOutline,
        ),
    };

    return InkWell(
      borderRadius: BorderRadius.circular(FblaRadius.full),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(FblaRadius.full),
          border: Border.all(color: border, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: FblaFonts.label(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.icon, required this.color});
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(FblaRadius.full),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: FblaFonts.label(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Skeletons / errors
// ─────────────────────────────────────────────────────────────────────────────

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, __) => Container(
        height: 64,
        decoration: BoxDecoration(
          color: FblaColors.darkSurface,
          borderRadius: BorderRadius.circular(FblaRadius.md),
          border: Border.all(color: FblaColors.darkOutline),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined,
                color: FblaColors.darkTextTertiary, size: 36),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: FblaFonts.body(fontSize: 13)
                  .copyWith(color: FblaColors.darkTextSecond),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: FblaColors.darkTextPrimary,
                side: BorderSide(color: FblaColors.darkOutline),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(FblaRadius.md),
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
