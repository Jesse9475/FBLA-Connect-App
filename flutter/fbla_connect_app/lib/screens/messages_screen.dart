import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/api_service.dart';
import '../services/user_state.dart';
import '../theme/app_theme.dart';
import '../utils/profanity_filter.dart';
import '../widgets/fbla_app_bar.dart';
import '../widgets/fbla_empty_view.dart';
import '../widgets/fbla_error_view.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Messages Screen — tabs: Direct | Groups (| Reports for advisors)
// Redesigned with Josefin Sans names, JetBrains timestamps, and smooth animations
// ─────────────────────────────────────────────────────────────────────────────

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  @override
  bool get wantKeepAlive => true;

  late TabController _tabs;
  final _us = UserState.instance;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: _us.isAdvisorOrAdmin ? 3 : 2,
      vsync: this,
    );
    _us.addListener(_onRoleChanged);
  }

  void _onRoleChanged() {
    if (!mounted) return;
    final needed = _us.isAdvisorOrAdmin ? 3 : 2;
    if (_tabs.length == needed) return;

    final old = _tabs;
    final prev = old.index.clamp(0, needed - 1);
    _tabs = TabController(length: needed, vsync: this, initialIndex: prev);

    setState(() {});

    WidgetsBinding.instance.addPostFrameCallback((_) {
      old.dispose();
    });
  }

  @override
  void dispose() {
    _us.removeListener(_onRoleChanged);
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _showNewOptions(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: FblaColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(FblaRadius.xl)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: FblaSpacing.sm),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: FblaColors.darkOutline,
                borderRadius: BorderRadius.circular(FblaRadius.full),
              ),
            ),
            const SizedBox(height: FblaSpacing.md),
            _NewMessageOption(
              icon: Icons.person_outline,
              iconColor: FblaColors.secondary,
              title: 'New Direct Message',
              subtitle: 'Message a specific member',
              onTap: () => Navigator.pop(context, 'dm'),
            ),
            _NewMessageOption(
              icon: Icons.group_add_outlined,
              iconColor: FblaColors.accent,
              title: 'New Group Chat',
              subtitle: 'Create a chat with multiple members',
              onTap: () => Navigator.pop(context, 'group'),
            ),
            const SizedBox(height: FblaSpacing.md),
          ],
        ),
      ),
    );

    if (choice == null || !mounted) return;
    if (choice == 'dm') {
      _tabs.animateTo(0);
      _directsKey.currentState?.startNewConversation();
    } else {
      _tabs.animateTo(1);
      _groupsKey.currentState?.showCreateSheet();
    }
  }

  final _directsKey = GlobalKey<_DirectsTabState>();
  final _groupsKey = GlobalKey<_GroupsTabState>();

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // Touching Theme.of registers this widget as a Theme dependent so it
    // rebuilds when MaterialApp.themeMode flips. Without it, the screen
    // stays painted with the old brightness's `FblaColors.darkBg` value.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelOn  = isDark ? Colors.white : FblaColors.textPrimary;
    final labelOff = isDark ? Colors.white60 : FblaColors.textSecondary;
    final divider  = isDark ? Colors.white24 : FblaColors.outlineVariant;

    final tabs = [
      const Tab(text: 'Direct'),
      const Tab(text: 'Groups'),
      if (_us.isAdvisorOrAdmin) const Tab(text: 'Reports'),
    ];

    return Scaffold(
      backgroundColor: FblaColors.darkBg,
      appBar: FblaAppBar(
        title: const Text('Messages'),
        bottom: TabBar(
          controller: _tabs,
          tabs: tabs,
          labelStyle: FblaFonts.label(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: labelOn,
          ),
          unselectedLabelStyle: FblaFonts.label(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: labelOff,
          ),
          indicator: const UnderlineTabIndicator(
            borderSide: BorderSide(color: FblaColors.secondary, width: 3),
          ),
          indicatorColor: FblaColors.secondary,
          labelColor: labelOn,
          unselectedLabelColor: labelOff,
          dividerColor: divider,
        ),
      ),
      floatingActionButton: _NewMessageFAB(
        onPressed: () => _showNewOptions(context),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: TabBarView(
        controller: _tabs,
        children: [
          _DirectsTab(key: _directsKey),
          _GroupsTab(key: _groupsKey),
          if (_us.isAdvisorOrAdmin) const _ReportsTab(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Direct messages tab
// ─────────────────────────────────────────────────────────────────────────────

class _DirectsTab extends StatefulWidget {
  const _DirectsTab({super.key});

  @override
  State<_DirectsTab> createState() => _DirectsTabState();
}

class _DirectsTabState extends State<_DirectsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _api = ApiService.instance;
  List<Map<String, dynamic>> _threads = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final all = await _api.get<List<Map<String, dynamic>>>(
        '/threads',
        parser: (d) => (d['threads'] as List).cast<Map<String, dynamic>>(),
      );
      if (mounted) {
        setState(() {
          _threads = all.where((t) => (t['type'] as String?) == 'direct').toList();
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

  Future<void> startNewConversation() async {
    List<Map<String, dynamic>> users = [];
    try {
      users = await _api.get<List<Map<String, dynamic>>>(
        '/users',
        parser: (d) => (d['users'] as List).cast<Map<String, dynamic>>(),
      );
    } catch (_) {}
    if (!mounted) return;

    final myId = Supabase.instance.client.auth.currentUser?.id ?? '';
    users = users.where((u) => (u['id'] as String?) != myId).toList();

    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: FblaColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(FblaRadius.xl)),
      ),
      builder: (_) => _UserPickerSheet(title: 'New Direct Message', users: users),
    );
    if (picked == null || !mounted) return;

    try {
      final thread = await _api.post<Map<String, dynamic>>(
        '/threads',
        body: {'type': 'direct', 'recipient_id': picked['id']},
        parser: (d) => (d['thread'] as Map<String, dynamic>?) ?? {},
      );
      if (!mounted) return;
      final tid = thread['id'] as String?;
      if (tid != null) {
        await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => ChatScreen(
            threadId: tid,
            title: picked['display_name'] as String? ?? 'Chat',
            isGroup: false,
          ),
        ));
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not start conversation: $e'),
          backgroundColor: FblaColors.error,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return _buildLoading();
    if (_error != null) return FblaErrorView(message: _error!, onRetry: _load);
    if (_threads.isEmpty) {
      return FblaEmptyView(
        icon: Icons.mail_outlined,
        title: 'No messages yet',
        subtitle: 'Start a conversation to begin messaging.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: FblaColors.secondary,
      backgroundColor: FblaColors.darkSurface,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          FblaSpacing.md,
          FblaSpacing.sm,
          FblaSpacing.md,
          FblaSpacing.md,
        ),
        itemCount: _threads.length,
        separatorBuilder: (_, __) => const SizedBox(height: FblaSpacing.xs),
        itemBuilder: (_, i) => _ConversationTile(
          thread: _threads[i],
          onTap: () async {
            final tid = _threads[i]['id'] as String?;
            if (tid == null) return;
            await Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => ChatScreen(
                threadId: tid,
                title: _threads[i]['display_name'] as String? ?? 'Chat',
                isGroup: false,
              ),
            ));
            _load();
          },
        )
            .animate(delay: Duration(milliseconds: i * 50))
            .fadeIn(duration: FblaMotion.standard)
            .slideX(begin: -0.05, end: 0, duration: FblaMotion.standard, curve: FblaMotion.easeOut),
      ),
    );
  }

  Widget _buildLoading() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: FblaSpacing.md,
        vertical: FblaSpacing.sm,
      ),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: FblaSpacing.xs),
      itemBuilder: (_, __) => _ConversationTileSkeleton(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Groups tab (stub — existing implementation)
// ─────────────────────────────────────────────────────────────────────────────

class _GroupsTab extends StatefulWidget {
  const _GroupsTab({super.key});

  @override
  State<_GroupsTab> createState() => _GroupsTabState();
}

class _GroupsTabState extends State<_GroupsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _api = ApiService.instance;
  List<Map<String, dynamic>> _threads = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final all = await _api.get<List<Map<String, dynamic>>>(
        '/threads',
        parser: (d) => (d['threads'] as List).cast<Map<String, dynamic>>(),
      );
      if (mounted) {
        setState(() {
          _threads = all.where((t) => (t['type'] as String?) == 'group').toList();
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

  Future<void> showCreateSheet() async {
    List<Map<String, dynamic>> users = [];
    try {
      users = await _api.get<List<Map<String, dynamic>>>(
        '/users',
        parser: (d) => (d['users'] as List).cast<Map<String, dynamic>>(),
      );
    } catch (_) {}
    if (!mounted) return;

    final myId = Supabase.instance.client.auth.currentUser?.id ?? '';
    users = users.where((u) => (u['id'] as String?) != myId).toList();

    final groupName = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: FblaColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(FblaRadius.xl)),
      ),
      builder: (_) => const _GroupNameSheet(),
    );
    if (groupName == null || !mounted) return;

    final selected = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: FblaColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(FblaRadius.xl)),
      ),
      builder: (_) => _UserPickerSheet(title: 'Select members', users: users, multiselect: true),
    );
    if (selected == null || selected.isEmpty || !mounted) return;

    try {
      final thread = await _api.post<Map<String, dynamic>>(
        '/threads',
        body: {
          'type': 'group',
          'name': groupName,
          'member_ids': selected,
        },
        parser: (d) => (d['thread'] as Map<String, dynamic>?) ?? {},
      );
      if (!mounted) return;
      final tid = thread['id'] as String?;
      if (tid != null) {
        await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => ChatScreen(
            threadId: tid,
            title: groupName,
            isGroup: true,
          ),
        ));
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not create group: $e'),
          backgroundColor: FblaColors.error,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return _buildLoading();
    if (_error != null) return FblaErrorView(message: _error!, onRetry: _load);
    if (_threads.isEmpty) {
      return FblaEmptyView(
        icon: Icons.group_outlined,
        title: 'No group chats yet',
        subtitle: 'Create a group to chat with multiple members.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: FblaColors.secondary,
      backgroundColor: FblaColors.darkSurface,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          FblaSpacing.md,
          FblaSpacing.sm,
          FblaSpacing.md,
          FblaSpacing.md,
        ),
        itemCount: _threads.length,
        separatorBuilder: (_, __) => const SizedBox(height: FblaSpacing.xs),
        itemBuilder: (_, i) => _ConversationTile(
          thread: _threads[i],
          isGroup: true,
          onTap: () async {
            final tid = _threads[i]['id'] as String?;
            if (tid == null) return;
            await Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => ChatScreen(
                threadId: tid,
                title: _threads[i]['display_name'] as String? ?? 'Chat',
                isGroup: true,
              ),
            ));
            _load();
          },
        )
            .animate(delay: Duration(milliseconds: i * 50))
            .fadeIn(duration: FblaMotion.standard)
            .slideX(begin: -0.05, end: 0, duration: FblaMotion.standard, curve: FblaMotion.easeOut),
      ),
    );
  }

  Widget _buildLoading() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: FblaSpacing.md,
        vertical: FblaSpacing.sm,
      ),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: FblaSpacing.xs),
      itemBuilder: (_, __) => _ConversationTileSkeleton(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reports tab (advisors only)
// ─────────────────────────────────────────────────────────────────────────────

class _ReportsTab extends StatefulWidget {
  const _ReportsTab();

  @override
  State<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<_ReportsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _api = ApiService.instance;
  List<Map<String, dynamic>> _reports = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.get<List<Map<String, dynamic>>>(
        '/reports',
        parser: (d) => (d['reports'] as List).cast<Map<String, dynamic>>(),
      );
      if (mounted) {
        setState(() {
          _reports = data;
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return _buildLoading();
    if (_error != null) return FblaErrorView(message: _error!, onRetry: _load);
    if (_reports.isEmpty) {
      return FblaEmptyView(
        icon: Icons.description_outlined,
        title: 'No reports',
        subtitle: 'Reports will appear here.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: FblaColors.secondary,
      backgroundColor: FblaColors.darkSurface,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          FblaSpacing.md,
          FblaSpacing.sm,
          FblaSpacing.md,
          FblaSpacing.md,
        ),
        itemCount: _reports.length,
        separatorBuilder: (_, __) => const SizedBox(height: FblaSpacing.sm),
        itemBuilder: (_, i) => _ReportCard(report: _reports[i])
            .animate(delay: Duration(milliseconds: i * 50))
            .fadeIn(duration: FblaMotion.standard)
            .slideY(begin: 0.05, end: 0, duration: FblaMotion.standard, curve: FblaMotion.easeOut),
      ),
    );
  }

  Widget _buildLoading() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: FblaSpacing.md,
        vertical: FblaSpacing.sm,
      ),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: FblaSpacing.sm),
      itemBuilder: (_, __) => _ReportCardSkeleton(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Conversation tile — Josefin Sans name, Mulish preview, JetBrains timestamp
// ─────────────────────────────────────────────────────────────────────────────

class _ConversationTile extends StatefulWidget {
  const _ConversationTile({
    required this.thread,
    this.isGroup = false,
    required this.onTap,
  });

  final Map<String, dynamic> thread;
  final bool isGroup;
  final VoidCallback onTap;

  @override
  State<_ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends State<_ConversationTile>
    with SingleTickerProviderStateMixin {
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
    _pressScale = Tween<double>(begin: 1.0, end: 0.98).animate(
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
    final name = widget.thread['display_name'] as String? ?? 'Chat';
    final rawPreview = widget.thread['last_message'] as String? ?? 'No messages yet';
    // Censor the inbox preview too, so the previous message's bad words
    // don't show through in the conversation list.
    final preview = ProfanityFilter.censor(rawPreview);
    final timestamp = widget.thread['last_message_at'] as String?;
    final hasUnread = widget.thread['unread_count'] as int? ?? 0;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _pressCtrl.forward(),
      onTapUp: (_) => _pressCtrl.reverse(),
      onTapCancel: () => _pressCtrl.reverse(),
      child: ScaleTransition(
        scale: _pressScale,
        child: Container(
          decoration: BoxDecoration(
            color: FblaColors.darkSurface,
            borderRadius: BorderRadius.circular(FblaRadius.lg),
            border: Border.all(color: FblaColors.darkOutline, width: 1),
          ),
          padding: const EdgeInsets.all(FblaSpacing.md),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: FblaGradient.avatar,
                  borderRadius: BorderRadius.circular(FblaRadius.md),
                  border: hasUnread > 0
                      ? Border.all(color: FblaColors.secondary, width: 2)
                      : null,
                ),
                child: Center(
                  child: Icon(
                    widget.isGroup ? Icons.group : Icons.person,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: FblaSpacing.md),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: FblaFonts.display(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: FblaColors.darkTextPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: FblaSpacing.sm),
                        if (timestamp != null)
                          Text(
                            _formatTime(timestamp),
                            style: FblaFonts.monoLabel(
                              fontSize: 11,
                              color: FblaColors.darkTextSecond,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FblaFonts.label(
                        fontSize: 12,
                        color: FblaColors.darkTextSecond,
                      ),
                    ),
                  ],
                ),
              ),

              // Unread indicator
              if (hasUnread > 0)
                Padding(
                  padding: const EdgeInsets.only(left: FblaSpacing.sm),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: FblaColors.secondary,
                      shape: BoxShape.circle,
                      boxShadow: FblaShadow.goldGlow,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp);
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } else {
        return '${dt.month}/${dt.day}';
      }
    } catch (_) {
      return '';
    }
  }
}

class _ConversationTileSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: FblaColors.darkSurface,
        borderRadius: BorderRadius.circular(FblaRadius.lg),
        border: Border.all(color: FblaColors.darkOutline, width: 1),
      ),
      padding: const EdgeInsets.all(FblaSpacing.md),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: FblaColors.darkSurfaceHigh,
              borderRadius: BorderRadius.circular(FblaRadius.md),
            ),
          ),
          const SizedBox(width: FblaSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 12,
                  width: 150,
                  decoration: BoxDecoration(
                    color: FblaColors.darkSurfaceHigh,
                    borderRadius: BorderRadius.circular(FblaRadius.sm),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 10,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: FblaColors.darkSurfaceHigh,
                    borderRadius: BorderRadius.circular(FblaRadius.sm),
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

// ─────────────────────────────────────────────────────────────────────────────
// Report card (advisor reports)
// ─────────────────────────────────────────────────────────────────────────────

class _ReportCard extends StatefulWidget {
  const _ReportCard({required this.report});
  final Map<String, dynamic> report;

  @override
  State<_ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends State<_ReportCard>
    with SingleTickerProviderStateMixin {
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
    _pressScale = Tween<double>(begin: 1.0, end: 0.98).animate(
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
    final title = widget.report['title'] as String? ?? '';
    final description = widget.report['description'] as String? ?? '';

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
            border: Border.all(color: FblaColors.darkOutline, width: 1),
          ),
          padding: const EdgeInsets.all(FblaSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: FblaFonts.display(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: FblaColors.darkTextPrimary,
                ),
              ),
              const SizedBox(height: FblaSpacing.xs),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: FblaFonts.label(
                  fontSize: 12,
                  color: FblaColors.darkTextSecond,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportCardSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: FblaColors.darkSurface,
        borderRadius: BorderRadius.circular(FblaRadius.lg),
        border: Border.all(color: FblaColors.darkOutline, width: 1),
      ),
      padding: const EdgeInsets.all(FblaSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 12,
            width: 200,
            decoration: BoxDecoration(
              color: FblaColors.darkSurfaceHigh,
              borderRadius: BorderRadius.circular(FblaRadius.sm),
            ),
          ),
          const SizedBox(height: FblaSpacing.xs),
          Container(
            height: 10,
            width: double.infinity,
            decoration: BoxDecoration(
              color: FblaColors.darkSurfaceHigh,
              borderRadius: BorderRadius.circular(FblaRadius.sm),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// New message option (bottom sheet option)
// ─────────────────────────────────────────────────────────────────────────────

class _NewMessageOption extends StatefulWidget {
  const _NewMessageOption({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  State<_NewMessageOption> createState() => _NewMessageOptionState();
}

class _NewMessageOptionState extends State<_NewMessageOption>
    with SingleTickerProviderStateMixin {
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
    _pressScale = Tween<double>(begin: 1.0, end: 0.98).animate(
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
        child: ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: widget.iconColor.withAlpha(15),
              borderRadius: BorderRadius.circular(FblaRadius.sm),
            ),
            child: Icon(widget.icon, color: widget.iconColor),
          ),
          title: Text(
            widget.title,
            style: FblaFonts.label(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: FblaColors.darkTextPrimary,
            ),
          ),
          subtitle: Text(
            widget.subtitle,
            style: FblaFonts.label(
              fontSize: 12,
              color: FblaColors.darkTextSecond,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// User picker sheet
// ─────────────────────────────────────────────────────────────────────────────

class _UserPickerSheet extends StatefulWidget {
  const _UserPickerSheet({
    required this.title,
    required this.users,
    this.multiselect = false,
  });

  final String title;
  final List<Map<String, dynamic>> users;
  final bool multiselect;

  @override
  State<_UserPickerSheet> createState() => _UserPickerSheetState();
}

class _UserPickerSheetState extends State<_UserPickerSheet> {
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = {};
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: FblaSpacing.sm),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: FblaColors.darkOutline,
                borderRadius: BorderRadius.circular(FblaRadius.full),
              ),
            ),
          ),
          const SizedBox(height: FblaSpacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: FblaSpacing.lg),
            child: Text(
              widget.title,
              style: FblaFonts.display(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: FblaColors.darkTextPrimary,
              ),
            ),
          ),
          const SizedBox(height: FblaSpacing.lg),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: FblaSpacing.lg),
              itemCount: widget.users.length,
              separatorBuilder: (_, __) => const SizedBox(height: FblaSpacing.sm),
              itemBuilder: (_, i) {
                final user = widget.users[i];
                final uid = user['id'] as String? ?? '';
                final name = user['display_name'] as String? ?? 'User';
                final isSelected = _selected.contains(uid);

                return _UserOption(
                  name: name,
                  isSelected: isSelected,
                  onTap: () {
                    setState(() {
                      if (widget.multiselect) {
                        if (isSelected) {
                          _selected.remove(uid);
                        } else {
                          _selected.add(uid);
                        }
                      } else {
                        Navigator.pop(context, user);
                      }
                    });
                  },
                );
              },
            ),
          ),
          if (widget.multiselect) ...[
            const SizedBox(height: FblaSpacing.lg),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: FblaSpacing.lg),
              child: ElevatedButton(
                onPressed: _selected.isEmpty
                    ? null
                    : () => Navigator.pop(context, _selected.toList()),
                child: const Text('Done'),
              ),
            ),
            const SizedBox(height: FblaSpacing.lg),
          ],
        ],
      ),
    );
  }
}

class _UserOption extends StatefulWidget {
  const _UserOption({
    required this.name,
    required this.isSelected,
    required this.onTap,
  });

  final String name;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_UserOption> createState() => _UserOptionState();
}

class _UserOptionState extends State<_UserOption>
    with SingleTickerProviderStateMixin {
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
    _pressScale = Tween<double>(begin: 1.0, end: 0.98).animate(
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
          decoration: BoxDecoration(
            color: widget.isSelected ? FblaColors.primary.withAlpha(12) : Colors.transparent,
            borderRadius: BorderRadius.circular(FblaRadius.md),
            border: Border.all(
              color: widget.isSelected ? FblaColors.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.all(FblaSpacing.sm),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: FblaGradient.avatar,
                  borderRadius: BorderRadius.circular(FblaRadius.sm),
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 20),
              ),
              const SizedBox(width: FblaSpacing.md),
              Expanded(
                child: Text(
                  widget.name,
                  style: FblaFonts.display(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: FblaColors.darkTextPrimary,
                  ),
                ),
              ),
              if (widget.isSelected)
                Icon(
                  Icons.check_circle,
                  color: FblaColors.primary,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Group name sheet
// ─────────────────────────────────────────────────────────────────────────────

class _GroupNameSheet extends StatefulWidget {
  const _GroupNameSheet();

  @override
  State<_GroupNameSheet> createState() => _GroupNameSheetState();
}

class _GroupNameSheetState extends State<_GroupNameSheet> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: FblaSpacing.sm),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: FblaColors.darkOutline,
                borderRadius: BorderRadius.circular(FblaRadius.full),
              ),
            ),
          ),
          const SizedBox(height: FblaSpacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: FblaSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Group name',
                  style: FblaFonts.display(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: FblaColors.darkTextPrimary,
                  ),
                ),
                const SizedBox(height: FblaSpacing.lg),
                TextField(
                  controller: _ctrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(color: FblaColors.darkTextPrimary),
                  decoration: InputDecoration(
                    hintText: 'Enter group name',
                    hintStyle: TextStyle(color: FblaColors.darkTextSecond),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(FblaRadius.md),
                      borderSide: BorderSide(color: FblaColors.darkOutline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(FblaRadius.md),
                      borderSide: const BorderSide(color: FblaColors.secondary, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: FblaSpacing.lg),
                ElevatedButton(
                  onPressed: _ctrl.text.isEmpty
                      ? null
                      : () => Navigator.pop(context, _ctrl.text),
                  child: const Text('Continue'),
                ),
                const SizedBox(height: FblaSpacing.lg),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chat screen (placeholder - existing implementation)
// ─────────────────────────────────────────────────────────────────────────────

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    required this.threadId,
    required this.title,
    required this.isGroup,
  });

  final String threadId;
  final String title;
  final bool isGroup;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _api = ApiService.instance;
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focus = FocusNode();

  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;
  Timer? _poll;
  String? _myId;

  @override
  void initState() {
    super.initState();
    _myId = Supabase.instance.client.auth.currentUser?.id;
    _load();
    // Lightweight polling for new messages every 4 seconds.
    _poll = Timer.periodic(const Duration(seconds: 4), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final data = await _api.get<Map<String, dynamic>>(
        '/threads/${widget.threadId}/messages',
        queryParameters: {'limit': 100},
      );
      final list = (data['messages'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      if (!mounted) return;
      final wasAtBottom = _scrollCtrl.hasClients
          ? (_scrollCtrl.position.pixels >=
              _scrollCtrl.position.maxScrollExtent - 80)
          : true;
      setState(() {
        _messages = list;
        _loading = false;
      });
      if (wasAtBottom) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    } catch (e) {
      if (!mounted) return;
      if (silent) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _scrollToBottom() {
    if (!_scrollCtrl.hasClients) return;
    _scrollCtrl.animateTo(
      _scrollCtrl.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Future<void> _send() async {
    final rawText = _inputCtrl.text.trim();
    if (rawText.isEmpty || _sending) return;

    // ── Profanity guard ────────────────────────────────────────────────────
    // School-club product: censor obvious bad words before the message ever
    // leaves the device. We replace them with asterisks (rather than hard-
    // blocking) so the user isn't left staring at a disabled Send button —
    // they get one subtle heads-up toast the first time, and the censored
    // version is what everyone in the thread sees.
    final scan = ProfanityFilter.check(rawText);
    final text = scan.censored;
    if (scan.hasProfanity) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Heads up: some words were censored before sending.',
          ),
          backgroundColor: FblaColors.darkSurface,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FblaRadius.md),
          ),
        ),
      );
    }

    setState(() => _sending = true);

    // Optimistic insert
    final optimistic = <String, dynamic>{
      'id': 'tmp-${DateTime.now().microsecondsSinceEpoch}',
      'body': text,
      'thread_id': widget.threadId,
      'user_id': _myId,
      'sender_name': UserState.instance.displayName ?? 'You',
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'pending': true,
    };
    setState(() {
      _messages = [..._messages, optimistic];
      _inputCtrl.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    try {
      final data = await _api.post<Map<String, dynamic>>(
        '/threads/${widget.threadId}/messages',
        body: {'body': text},
      );
      final saved = (data['message'] as Map<String, dynamic>?) ?? optimistic;
      if (!mounted) return;
      setState(() {
        _messages = [
          for (final m in _messages)
            if (m['id'] == optimistic['id']) saved else m,
        ];
        _sending = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages = _messages.where((m) => m['id'] != optimistic['id']).toList();
        _sending = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send: ${e.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: FblaColors.error,
        ),
      );
    }
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final m = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '$h:$m $ampm';
    } catch (_) {
      return '';
    }
  }

  bool _shouldShowDateDivider(int index) {
    if (index == 0) return true;
    try {
      // Null-safe extraction: the old `as String` cast could crash when
      // `created_at` was missing from a locally-appended optimistic row.
      final prevRaw = _messages[index - 1]['created_at'];
      final currRaw = _messages[index]['created_at'];
      if (prevRaw is! String || currRaw is! String) return false;
      final prev = DateTime.parse(prevRaw).toLocal();
      final curr = DateTime.parse(currRaw).toLocal();
      return prev.year != curr.year || prev.month != curr.month || prev.day != curr.day;
    } catch (_) {
      return false;
    }
  }

  String _dateLabel(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      if (dt.year == today.year && dt.month == today.month && dt.day == today.day) {
        return 'Today';
      }
      if (dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day) {
        return 'Yesterday';
      }
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Scaffold(
      backgroundColor: FblaColors.darkBg,
      appBar: AppBar(
        backgroundColor: FblaColors.darkSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: 'Back to messages',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: FblaColors.primary.withAlpha(40),
                borderRadius: BorderRadius.circular(FblaRadius.full),
                border: Border.all(color: FblaColors.primary.withAlpha(60), width: 1),
              ),
              child: Center(
                child: Icon(
                  widget.isGroup ? Icons.groups_outlined : Icons.person_outline,
                  color: FblaColors.primaryLight,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: FblaSpacing.sm),
            Expanded(
              child: Text(
                widget.title,
                style: FblaFonts.display(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: FblaColors.darkTextPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: FblaColors.darkOutline),
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody()),
          _buildComposer(mq),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: FblaColors.secondary),
      );
    }
    if (_error != null) {
      return FblaErrorView(message: _error!, onRetry: _load);
    }
    if (_messages.isEmpty) {
      return const FblaEmptyView(
        icon: Icons.chat_bubble_outline,
        title: 'No messages yet',
        subtitle: 'Send the first message to start the conversation.',
      );
    }
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(
        horizontal: FblaSpacing.md,
        vertical: FblaSpacing.sm,
      ),
      itemCount: _messages.length,
      itemBuilder: (_, i) {
        final m = _messages[i];
        final isMe = m['user_id'] == _myId;
        final showDate = _shouldShowDateDivider(i);
        final prevSameSender = !showDate &&
            i > 0 &&
            _messages[i - 1]['user_id'] == m['user_id'];

        return Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (showDate) _DateDivider(label: _dateLabel(m['created_at'] as String? ?? '')),
            Padding(
              padding: EdgeInsets.only(top: prevSameSender ? 2 : 8, bottom: 2),
              child: _MessageBubble(
                // Render-time safety net: censor anything that somehow
                // landed in the DB without being cleaned (older messages,
                // other clients, etc.). Cheap — runs per-bubble on already-
                // loaded strings and short-circuits when there's no match.
                body: ProfanityFilter.censor(m['body'] as String? ?? ''),
                isMe: isMe,
                senderName: m['sender_name'] as String?,
                time: _formatTime(m['created_at'] as String? ?? ''),
                pending: m['pending'] == true,
                showSender: widget.isGroup && !isMe && !prevSameSender,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildComposer(MediaQueryData mq) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        FblaSpacing.md,
        FblaSpacing.sm,
        FblaSpacing.md,
        FblaSpacing.sm + mq.padding.bottom,
      ),
      decoration: BoxDecoration(
        color: FblaColors.darkSurface,
        border: Border(
          top: BorderSide(color: FblaColors.darkOutline, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: FblaColors.darkBg,
                  borderRadius: BorderRadius.circular(FblaRadius.lg),
                  border: Border.all(color: FblaColors.darkOutline, width: 1),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: FblaSpacing.md,
                  vertical: FblaSpacing.sm,
                ),
                child: TextField(
                  controller: _inputCtrl,
                  focusNode: _focus,
                  maxLines: null,
                  minLines: 1,
                  textInputAction: TextInputAction.newline,
                  style: FblaFonts.body(
                    fontSize: 14,
                    color: FblaColors.darkTextPrimary,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'Type a message...',
                    hintStyle: FblaFonts.body(
                      fontSize: 14,
                      color: FblaColors.darkTextSecond,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ),
            const SizedBox(width: FblaSpacing.sm),
            _SendButton(
              enabled: _inputCtrl.text.trim().isNotEmpty && !_sending,
              sending: _sending,
              onTap: _send,
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.body,
    required this.isMe,
    required this.time,
    required this.pending,
    required this.showSender,
    this.senderName,
  });

  final String body;
  final bool isMe;
  final String? senderName;
  final String time;
  final bool pending;
  final bool showSender;

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width * 0.75;
    return Column(
      crossAxisAlignment:
          isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (showSender && senderName != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 2),
            child: Text(
              senderName!,
              style: FblaFonts.label(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: FblaColors.darkTextSecond,
              ),
            ),
          ),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: FblaSpacing.md,
              vertical: FblaSpacing.sm + 2,
            ),
            decoration: BoxDecoration(
              color: isMe ? FblaColors.primary : FblaColors.darkSurface,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(FblaRadius.lg),
                topRight: const Radius.circular(FblaRadius.lg),
                bottomLeft: Radius.circular(isMe ? FblaRadius.lg : 4),
                bottomRight: Radius.circular(isMe ? 4 : FblaRadius.lg),
              ),
              border: isMe
                  ? null
                  : Border.all(color: FblaColors.darkOutline, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  body,
                  style: FblaFonts.body(
                    fontSize: 14,
                    color: isMe ? Colors.white : FblaColors.darkTextPrimary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      time,
                      style: FblaFonts.label(
                        fontSize: 11,
                        color: isMe
                            ? Colors.white.withAlpha(200)
                            : FblaColors.darkTextSecond,
                      ),
                    ),
                    if (pending) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.schedule,
                        size: 11,
                        color: isMe
                            ? Colors.white.withAlpha(180)
                            : FblaColors.darkTextSecond,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DateDivider extends StatelessWidget {
  const _DateDivider({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: FblaSpacing.md),
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: FblaColors.darkOutline)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: FblaSpacing.sm),
            child: Text(
              label,
              style: FblaFonts.label(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: FblaColors.darkTextSecond,
              ),
            ),
          ),
          Expanded(child: Container(height: 1, color: FblaColors.darkOutline)),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.enabled,
    required this.sending,
    required this.onTap,
  });

  final bool enabled;
  final bool sending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: enabled
              ? FblaColors.primary
              : FblaColors.darkOutline.withAlpha(120),
          borderRadius: BorderRadius.circular(FblaRadius.full),
        ),
        child: sending
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(
                Icons.arrow_upward_rounded,
                color: enabled ? Colors.white : FblaColors.darkTextSecond,
                size: 22,
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// New message FAB
// ─────────────────────────────────────────────────────────────────────────────

class _NewMessageFAB extends StatefulWidget {
  const _NewMessageFAB({required this.onPressed});
  final VoidCallback onPressed;

  @override
  State<_NewMessageFAB> createState() => _NewMessageFABState();
}

class _NewMessageFABState extends State<_NewMessageFAB>
    with SingleTickerProviderStateMixin {
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
            color: FblaColors.primary,
            borderRadius: BorderRadius.circular(FblaRadius.lg),
            boxShadow: FblaShadow.blueGlow,
          ),
          child: const Icon(Icons.edit_outlined, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}
