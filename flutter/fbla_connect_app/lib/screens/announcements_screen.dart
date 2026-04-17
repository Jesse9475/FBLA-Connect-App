import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/api_service.dart';
import '../services/user_state.dart';
import '../theme/app_theme.dart';
import '../widgets/announcement_card.dart';
import '../widgets/fbla_app_bar.dart';

/// Announcements feed filtered by scope: national, district, chapter.
/// Advisors and admins see a FAB to create new announcements.
/// Set [standalone] = true when pushing as a detail screen from the feed.
class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key, this.standalone = false});

  /// When true, show a back arrow in the AppBar instead of a tab title.
  final bool standalone;

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _api = ApiService.instance;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  String _scope = 'all';

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
        '/announcements',
        parser: (data) =>
            (data['announcements'] as List).cast<Map<String, dynamic>>(),
      );
      if (mounted) setState(() {
        _items = data;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  /// Chapter/district visibility gate — hides content the user isn't entitled to.
  bool _isVisible(Map<String, dynamic> item) {
    final scope = (item['scope'] as String?)?.toLowerCase() ?? 'national';
    if (scope == 'national') return true;
    final us = UserState.instance;
    if (scope == 'district') {
      final itemDistrict = item['district_id'] as String?;
      if (itemDistrict == null) return true;
      return us.districtId == null || us.districtId == itemDistrict;
    }
    if (scope == 'chapter') {
      final itemChapter = item['chapter_id'] as String?;
      if (itemChapter == null) return true;
      return us.chapterId == null || us.chapterId == itemChapter;
    }
    return true;
  }

  List<Map<String, dynamic>> get _filtered {
    final list = _scope == 'all'
        ? _items
        : _items.where((a) => a['scope'] == _scope).toList();
    return list.where(_isVisible).toList();
  }

  void _showCreateAnnouncementSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(FblaRadius.xl)),
      ),
      builder: (_) => _CreateAnnouncementSheet(
        api: _api,
        onCreated: _load,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // Only show the FAB for advisors and admins (backend enforces this too).
    // Read live so role flips after /advisor/verify update the FAB without
    // a full app restart.
    final canPost = UserState.instance.isAdvisorOrAdmin;

    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: FblaColors.darkBg,
      appBar: FblaAppBar(
        title: const Text('Announcements'),
      ),
      floatingActionButton: ListenableBuilder(
        listenable: UserState.instance,
        builder: (context, _) {
          if (!UserState.instance.isAdvisorOrAdmin) return const SizedBox.shrink();
          return _PostFab(onTap: _showCreateAnnouncementSheet);
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Column(
        children: [
          // ── Industrial scope filter bar ────────────────────────────────────
          _AnnounceScopeBar(
            scope: _scope,
            onChanged: (s) {
              HapticFeedback.selectionClick();
              setState(() => _scope = s);
            },
          ),
          Divider(height: 1, color: Colors.white.withAlpha(12)),

          // ── Content ────────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const _AnnounceSkeletonList()
                : _error != null
                    ? _ErrorView(message: _error!, onRetry: _load)
                    : _filtered.isEmpty
                        ? _EmptyView(scope: _scope)
                        : RefreshIndicator(
                            onRefresh: _load,
                            color: FblaColors.secondary,
                            backgroundColor: FblaColors.darkSurface,
                            child: ListView.separated(
                              padding: EdgeInsets.only(
                                left: FblaSpacing.md,
                                right: FblaSpacing.md,
                                top: FblaSpacing.md,
                                bottom: canPost ? 72 : FblaSpacing.md,
                              ),
                              itemCount: _filtered.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: FblaSpacing.sm),
                              itemBuilder: (context, i) => AnnouncementCard(
                                announcement: _filtered[i],
                                onChanged: _load,
                              )
                                  .animate(delay: Duration(milliseconds: i * 40))
                                  .fadeIn(duration: 280.ms, curve: Curves.easeOut)
                                  .slideY(
                                    begin: 0.05,
                                    end: 0,
                                    duration: 280.ms,
                                    curve: FblaMotion.easeOut,
                                  ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Gold FAB — replaces default extended FAB
// ─────────────────────────────────────────────────────────────────────────────

class _PostFab extends StatefulWidget {
  const _PostFab({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_PostFab> createState() => _PostFabState();
}

class _PostFabState extends State<_PostFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _pressScale;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 240),
    );
    _pressScale = Tween<double>(begin: 1.0, end: 0.95)
        .animate(CurvedAnimation(parent: _pressCtrl, curve: FblaMotion.strongEaseOut));
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
      onTapDown: (_) {
        HapticFeedback.mediumImpact();
        _pressCtrl.forward();
      },
      onTapUp: (_) => _pressCtrl.reverse(),
      onTapCancel: () => _pressCtrl.reverse(),
      child: ScaleTransition(
        scale: _pressScale,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            gradient: FblaGradient.goldShimmer,
            borderRadius: BorderRadius.circular(FblaRadius.lg),
            boxShadow: FblaShadow.goldGlow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_rounded, color: FblaColors.primaryDark, size: 20),
              const SizedBox(width: 8),
              Text(
                'NEW',
                style: FblaFonts.monoTag(
                  fontSize: 11,
                  color: FblaColors.primaryDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Industrial scope filter bar
// ─────────────────────────────────────────────────────────────────────────────

class _AnnounceScopeBar extends StatelessWidget {
  const _AnnounceScopeBar({required this.scope, required this.onChanged});

  final String scope;
  final ValueChanged<String> onChanged;

  static const _scopes = [
    ('all',      'ALL',      Icons.public_outlined),
    ('national', 'NATIONAL', Icons.flag_outlined),
    ('district', 'DISTRICT', Icons.location_city_outlined),
    ('chapter',  'CHAPTER',  Icons.groups_2_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: FblaColors.darkBg,
      padding: const EdgeInsets.fromLTRB(FblaSpacing.md, 10, FblaSpacing.md, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final entry in _scopes)
              Padding(
                padding: const EdgeInsets.only(right: FblaSpacing.sm),
                child: _AnnounceChip(
                  label: entry.$2,
                  icon: entry.$3,
                  selected: scope == entry.$1,
                  onTap: () => onChanged(entry.$1),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AnnounceChip extends StatefulWidget {
  const _AnnounceChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_AnnounceChip> createState() => _AnnounceChipState();
}

class _AnnounceChipState extends State<_AnnounceChip>
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
    _pressScale = Tween<double>(begin: 1.0, end: 0.95)
        .animate(CurvedAnimation(parent: _pressCtrl, curve: FblaMotion.strongEaseOut));
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
      onTapDown: (_) {
        HapticFeedback.selectionClick();
        _pressCtrl.forward();
      },
      onTapUp: (_) => _pressCtrl.reverse(),
      onTapCancel: () => _pressCtrl.reverse(),
      child: ScaleTransition(
        scale: _pressScale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: FblaMotion.strongEaseOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: widget.selected ? FblaColors.secondary : FblaColors.darkSurfaceHigh,
            borderRadius: BorderRadius.circular(FblaRadius.full),
            border: Border.all(
              color: widget.selected ? FblaColors.secondary : FblaColors.darkOutline,
            ),
            boxShadow: widget.selected ? FblaShadow.goldGlow : FblaShadow.glass,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 12,
                color: widget.selected ? FblaColors.primaryDark : FblaColors.darkTextSecond,
              ),
              const SizedBox(width: 5),
              Text(
                widget.label,
                style: FblaFonts.monoTag(
                  fontSize: 11,
                  color: widget.selected ? FblaColors.primaryDark : FblaColors.darkTextSecond,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Skeleton loading list
// ─────────────────────────────────────────────────────────────────────────────

class _AnnounceSkeletonList extends StatefulWidget {
  const _AnnounceSkeletonList();

  @override
  State<_AnnounceSkeletonList> createState() => _AnnounceSkeletonListState();
}

class _AnnounceSkeletonListState extends State<_AnnounceSkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
    _anim = Tween<double>(begin: 0.0, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        // Directional sweep 0→1→0 sawtooth
        final t = (_anim.value * 2 - 1).abs();
        final gradient = LinearGradient(
          begin: const Alignment(-2, 0),
          end: const Alignment(2, 0),
          colors: [
            FblaColors.darkSurface,
            FblaColors.darkSurfaceHigh,
            FblaColors.darkSurface,
          ],
          stops: [
            (t - 0.35).clamp(0.0, 1.0),
            t.clamp(0.0, 1.0),
            (t + 0.35).clamp(0.0, 1.0),
          ],
        );
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(FblaSpacing.md, FblaSpacing.md, FblaSpacing.md, 100),
          itemCount: 5,
          separatorBuilder: (_, __) => const SizedBox(height: FblaSpacing.sm),
          itemBuilder: (context, i) => _SkeletonCard(gradient: gradient, index: i),
        );
      },
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.gradient, required this.index});
  final LinearGradient gradient;
  final int index;

  @override
  Widget build(BuildContext context) {
    // Alternate card heights for realism
    final tallCard = index.isEven;
    return Container(
      height: tallCard ? 120 : 88,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(FblaRadius.xl),
        border: Border.all(color: Colors.white.withAlpha(10)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Scope badge placeholder
          Container(
            width: 60,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(12),
              borderRadius: BorderRadius.circular(FblaRadius.full),
            ),
          ),
          const SizedBox(height: 10),
          // Title placeholder
          Container(
            width: double.infinity,
            height: 13,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(10),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          if (tallCard) ...[
            const SizedBox(height: 8),
            Container(
              width: 200,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(7),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Create Announcement sheet ─────────────────────────────────────────────────

class _CreateAnnouncementSheet extends StatefulWidget {
  const _CreateAnnouncementSheet({required this.api, required this.onCreated});

  final ApiService api;
  final VoidCallback onCreated;

  @override
  State<_CreateAnnouncementSheet> createState() =>
      _CreateAnnouncementSheetState();
}

class _CreateAnnouncementSheetState extends State<_CreateAnnouncementSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();

  // Admin-only scope fields
  String _scope = 'national';
  final _districtCtrl = TextEditingController();
  final _chapterCtrl = TextEditingController();

  bool _submitting = false;
  String? _error;

  bool get _isAdmin => UserState.instance.isAdmin;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _districtCtrl.dispose();
    _chapterCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Admin-only scope validation
    if (_isAdmin) {
      if (_scope == 'district' && _districtCtrl.text.trim().isEmpty) {
        setState(() => _error = 'Please enter a District ID.');
        return;
      }
      if (_scope == 'chapter' && _chapterCtrl.text.trim().isEmpty) {
        setState(() => _error = 'Please enter a Chapter ID.');
        return;
      }
    }

    setState(() { _submitting = true; _error = null; });

    try {
      final body = <String, dynamic>{
        'title': _titleCtrl.text.trim(),
        'body': _bodyCtrl.text.trim(),
        // Advisors: scope/chapter_id auto-set server-side.
        // Admins: pass explicit scope.
        if (_isAdmin) 'scope': _scope,
        if (_isAdmin && _scope == 'district') 'district_id': _districtCtrl.text.trim(),
        if (_isAdmin && _scope == 'chapter') 'chapter_id': _chapterCtrl.text.trim(),
      };
      await widget.api.post<void>('/announcements', body: body);
      if (mounted) {
        Navigator.pop(context);
        widget.onCreated();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        left: FblaSpacing.xl,
        right: FblaSpacing.xl,
        top: FblaSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + FblaSpacing.xl,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(FblaRadius.full),
                  ),
                ),
              ),
              const SizedBox(height: FblaSpacing.lg),

              Text('New Announcement', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: FblaSpacing.xs),

              // Scope label for advisors (not a picker — auto-set server-side)
              if (!_isAdmin)
                Row(
                  children: [
                    const Icon(Icons.groups_outlined, size: 16, color: FblaColors.primary),
                    const SizedBox(width: FblaSpacing.xs),
                    Text(
                      'Will be sent to your chapter members',
                      style: TextStyle(fontSize: 13, color: cs.primary, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              const SizedBox(height: FblaSpacing.lg),

              // Error banner
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(FblaSpacing.sm),
                  decoration: BoxDecoration(
                    color: FblaColors.error.withAlpha(15),
                    borderRadius: BorderRadius.circular(FblaRadius.sm),
                    border: Border.all(color: FblaColors.error.withAlpha(50)),
                  ),
                  child: Text(_error!, style: const TextStyle(fontSize: 13, color: FblaColors.error)),
                ),
                const SizedBox(height: FblaSpacing.md),
              ],

              // Title
              TextFormField(
                controller: _titleCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Title *',
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required.' : null,
              ),
              const SizedBox(height: FblaSpacing.md),

              // Body
              TextFormField(
                controller: _bodyCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Message *',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Message is required.' : null,
              ),
              const SizedBox(height: FblaSpacing.md),

              // Scope picker — admins only
              if (_isAdmin) ...[
                Text(
                  'SCOPE',
                  style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    letterSpacing: 1.2, color: cs.onSurface.withAlpha(160),
                  ),
                ),
                const SizedBox(height: FblaSpacing.sm),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'national', label: Text('National')),
                    ButtonSegment(value: 'district', label: Text('District')),
                    ButtonSegment(value: 'chapter', label: Text('Chapter')),
                  ],
                  selected: {_scope},
                  onSelectionChanged: (v) => setState(() => _scope = v.first),
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: FblaColors.secondary.withAlpha(25),
                    selectedForegroundColor: FblaColors.secondaryDark,
                  ),
                ),
                if (_scope == 'district') ...[
                  const SizedBox(height: FblaSpacing.md),
                  TextFormField(
                    controller: _districtCtrl,
                    decoration: const InputDecoration(
                      labelText: 'District ID *',
                      prefixIcon: Icon(Icons.location_city_outlined),
                    ),
                  ),
                ],
                if (_scope == 'chapter') ...[
                  const SizedBox(height: FblaSpacing.md),
                  TextFormField(
                    controller: _chapterCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Chapter ID *',
                      prefixIcon: Icon(Icons.groups_outlined),
                    ),
                  ),
                ],
              ],

              const SizedBox(height: FblaSpacing.xl),

              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Post Announcement'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Error / empty views ───────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(FblaSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: FblaColors.error),
            const SizedBox(height: FblaSpacing.md),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: FblaSpacing.md),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.scope});
  final String scope;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(FblaSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.campaign_outlined,
              size: 56,
              color: FblaColors.secondary.withAlpha(140),
            ),
            const SizedBox(height: FblaSpacing.md),
            Text(
              scope == 'all'
                  ? 'No announcements yet'
                  : 'No $scope announcements',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: FblaSpacing.sm),
            Text(
              'Your advisor will post chapter updates here.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
