import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../services/api_service.dart';
import '../services/user_state.dart';
import '../theme/app_theme.dart';
import '../widgets/fbla_app_bar.dart';
import '../widgets/fbla_empty_view.dart';
import '../widgets/fbla_error_view.dart';
import 'competitive_events_screen.dart';

/// Hub / Resources tab — study guides, templates, event info, etc.
/// Redesigned with category tiles, clean grid layout, and smooth search focus.
class HubScreen extends StatefulWidget {
  const HubScreen({super.key});

  @override
  State<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends State<HubScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _api = ApiService.instance;
  final _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  String _category = 'All';
  String _search = '';
  bool _showSearch = false;

  static const _categories = [
    'All',
    'Study Materials',
    'Competition Rules',
    'Templates',
    'Leadership',
    'Chapter Documents',
    'Reference',
  ];

  static const _categoryColors = {
    'Study Materials': Color(0xFF2563EB),
    'Competition Rules': Color(0xFFFB923C),
    'Templates': Color(0xFF16A34A),
    'Leadership': Color(0xFF9333EA),
    'Chapter Documents': Color(0xFF64748B),
    'Reference': Color(0xFF0891B2),
  };

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(() {
      setState(() => _search = _searchCtrl.text);
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
        '/hub',
        parser: (data) =>
            (data['hub_items'] as List? ?? []).cast<Map<String, dynamic>>(),
      );
      if (mounted) {
        setState(() {
          _items = data;
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
    return _items.where((item) {
      if (!_isVisible(item)) return false;
      final title = (item['title'] as String? ?? '').toLowerCase();
      final body = (item['body'] as String? ?? '').toLowerCase();
      final cat = item['category'] as String? ?? '';
      final matchSearch = _search.isEmpty ||
          title.contains(_search.toLowerCase()) ||
          body.contains(_search.toLowerCase());
      final matchCategory = _category == 'All' ||
          cat.toLowerCase() == _category.toLowerCase();
      return matchSearch && matchCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final filtered = _filtered;
    // Live snapshot for layout-only consumers (empty-state copy).  The
    // interactive "+" controls are wrapped in a ListenableBuilder so they
    // pop in the moment a user is verified as advisor.
    final canCreate = UserState.instance.isAdvisorOrAdmin;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? FblaColors.darkBg : FblaColors.background;
    final surface = isDark ? FblaColors.darkSurface : FblaColors.surface;

    return Scaffold(
      backgroundColor: bg,
      appBar: FblaAppBar(
        title: const Text('Resource Hub'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search',
            onPressed: () => setState(() => _showSearch = !_showSearch),
          ),
          ListenableBuilder(
            listenable: UserState.instance,
            builder: (context, _) {
              if (!UserState.instance.isAdvisorOrAdmin) {
                return const SizedBox.shrink();
              }
              return IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Add resource',
                onPressed: () => _showCreateSheet(context),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Search bar (inline, conditional) ─────────────────────────────
          if (_showSearch)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                FblaSpacing.md,
                FblaSpacing.md,
                FblaSpacing.md,
                FblaSpacing.sm,
              ),
              child: _SearchBar(
                controller: _searchCtrl,
                onClear: () => _searchCtrl.clear(),
              ),
            ),

          // ── Category pills ───────────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: FblaSpacing.md,
              vertical: FblaSpacing.sm,
            ),
            child: Row(
              children: List.generate(
                _categories.length,
                (i) {
                  final cat = _categories[i];
                  final isSelected = _category == cat;
                  final color = _categoryColors[cat] ?? FblaColors.secondary;

                  return Padding(
                    padding: EdgeInsets.only(
                      right: i == _categories.length - 1 ? 0 : FblaSpacing.sm,
                    ),
                    child: _CategoryChip(
                      label: cat,
                      accentColor: color,
                      isSelected: isSelected,
                      onTap: () => setState(() => _category = cat),
                    )
                        .animate(delay: Duration(milliseconds: i * 30))
                        .fadeIn(duration: FblaMotion.fast)
                        .slideX(begin: -0.05, end: 0, duration: FblaMotion.fast, curve: FblaMotion.easeOut),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: FblaSpacing.md),

          // ── Competitive Events Banner ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: FblaSpacing.md),
            child: _CompetitiveEventsBanner(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CompetitiveEventsScreen(),
                  ),
                );
              },
            )
                .animate()
                .fadeIn(duration: FblaMotion.standard)
                .slideY(begin: 0.05, end: 0, duration: FblaMotion.standard, curve: FblaMotion.easeOut),
          ),

          const SizedBox(height: FblaSpacing.md),

          // ── Content ──────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(FblaColors.primary),
                    ),
                  )
                : _error != null
                    ? FblaErrorView(message: _error!, onRetry: _load)
                    : filtered.isEmpty
                        ? FblaEmptyView(
                            icon: Icons.library_books_outlined,
                            title: _search.isNotEmpty
                                ? 'No matches for "$_search"'
                                : 'No resources yet',
                            subtitle: _search.isNotEmpty
    ? 'Try a different search term.'
                                : canCreate
                                    ? 'Tap + to add the first resource.'
                                    : 'Check back later.',
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            color: FblaColors.secondary,
                            backgroundColor: surface,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(
                                FblaSpacing.md,
                                FblaSpacing.sm,
                                FblaSpacing.md,
                                FblaSpacing.md,
                              ),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: FblaSpacing.sm),
                              itemBuilder: (_, i) => _ResourceCard(
                                item: filtered[i],
                                onDeleted: _load,
                              )
                                  .animate(delay: Duration(milliseconds: i * 50))
                                  .fadeIn(duration: FblaMotion.standard)
                                  .slideY(
                                    begin: 0.06,
                                    end: 0,
                                    duration: FblaMotion.standard,
                                    curve: FblaMotion.easeOut,
                                  ),
                            ),
                          ),
          ),
        ],
      ),
      floatingActionButton: ListenableBuilder(
        listenable: UserState.instance,
        builder: (context, _) {
          if (!UserState.instance.isAdvisorOrAdmin) return const SizedBox.shrink();
          return _CreateResourceFAB(onPressed: () => _showCreateSheet(context));
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  void _showCreateSheet(BuildContext context) {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    final tagCtrl = TextEditingController();
    String category = 'Study Materials';
    String resourceType = 'document';
    final List<String> tags = [];
    bool saving = false;

    const resourceTypes = <String, IconData>{
      'document':    Icons.description_outlined,
      'link':        Icons.link_rounded,
      'video':       Icons.play_circle_outline_rounded,
      'study_guide': Icons.menu_book_outlined,
      'sample_test': Icons.quiz_outlined,
      'template':    Icons.dashboard_customize_outlined,
    };

    String prettyType(String t) =>
        t.split('_').map((p) => p[0].toUpperCase() + p.substring(1)).join(' ');

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: FblaColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(FblaRadius.xl)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => Padding(
          padding: EdgeInsets.only(
            left: FblaSpacing.xl,
            right: FblaSpacing.xl,
            top: FblaSpacing.lg,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + FblaSpacing.xl,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                Text(
                  'Add a resource',
                  style: FblaFonts.display(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: FblaColors.darkTextPrimary,
                  ),
                ),
                const SizedBox(height: FblaSpacing.md),
                TextField(
                  controller: titleCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(color: FblaColors.darkTextPrimary),
                  decoration: InputDecoration(
                    labelText: 'Title *',
                    labelStyle: TextStyle(color: FblaColors.darkTextSecond),
                    prefixIcon: Icon(Icons.title, color: FblaColors.darkTextSecond),
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
                const SizedBox(height: FblaSpacing.md),
                DropdownButtonFormField<String>(
                  value: category,
                  style: TextStyle(color: FblaColors.darkTextPrimary),
                  dropdownColor: FblaColors.darkSurfaceHigh,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    labelStyle: TextStyle(color: FblaColors.darkTextSecond),
                    prefixIcon: Icon(Icons.category_outlined, color: FblaColors.darkTextSecond),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(FblaRadius.md),
                      borderSide: BorderSide(color: FblaColors.darkOutline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(FblaRadius.md),
                      borderSide: const BorderSide(color: FblaColors.secondary, width: 2),
                    ),
                  ),
                  items: [
                    'Study Materials',
                    'Competition Rules',
                    'Templates',
                    'Leadership',
                    'Chapter Documents',
                    'Reference'
                  ]
                      .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c,
                              style:
                                  TextStyle(color: FblaColors.darkTextPrimary))))
                      .toList(),
                  onChanged: (v) =>
                      setInner(() => category = v ?? category),
                ),
                const SizedBox(height: FblaSpacing.md),
                // Resource type chips
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Resource type',
                    style: FblaFonts.label().copyWith(
                      fontSize: 11,
                      letterSpacing: 0.8,
                      color: FblaColors.darkTextSecond,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: FblaSpacing.sm),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: resourceTypes.entries.map((e) {
                    final selected = resourceType == e.key;
                    return ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            e.value,
                            size: 14,
                            color: selected
                                ? Colors.white
                                : FblaColors.darkTextSecond,
                          ),
                          const SizedBox(width: 4),
                          Text(prettyType(e.key),
                              style: TextStyle(
                                  color: selected
                                      ? Colors.white
                                      : FblaColors.darkTextPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12)),
                        ],
                      ),
                      selected: selected,
                      onSelected: (_) {
                        setInner(() => resourceType = e.key);
                      },
                      selectedColor: FblaColors.primary,
                      backgroundColor: FblaColors.darkSurfaceHigh,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                        side: BorderSide(color: FblaColors.darkOutline),
                      ),
                      showCheckmark: false,
                    );
                  }).toList(),
                ),
                const SizedBox(height: FblaSpacing.md),
                // External URL (optional)
                TextField(
                  controller: urlCtrl,
                  keyboardType: TextInputType.url,
                  style: TextStyle(color: FblaColors.darkTextPrimary),
                  decoration: InputDecoration(
                    labelText: 'Link URL (optional)',
                    labelStyle: TextStyle(color: FblaColors.darkTextSecond),
                    hintText: 'https://...',
                    hintStyle: TextStyle(color: FblaColors.darkTextTertiary),
                    prefixIcon:
                        Icon(Icons.link_rounded, color: FblaColors.darkTextSecond),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(FblaRadius.md),
                      borderSide: BorderSide(color: FblaColors.darkOutline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(FblaRadius.md),
                      borderSide: const BorderSide(
                          color: FblaColors.secondary, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: FblaSpacing.md),
                // Tags input
                TextField(
                  controller: tagCtrl,
                  style: TextStyle(color: FblaColors.darkTextPrimary),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (raw) {
                    final t = raw
                        .trim()
                        .toLowerCase()
                        .replaceAll(RegExp(r'[^a-z0-9\-]'), '');
                    if (t.isEmpty || tags.contains(t) || tags.length >= 10) {
                      tagCtrl.clear();
                      return;
                    }
                    setInner(() {
                      tags.add(t);
                      tagCtrl.clear();
                    });
                  },
                  decoration: InputDecoration(
                    labelText: 'Tags (optional, up to 10)',
                    labelStyle: TextStyle(color: FblaColors.darkTextSecond),
                    hintText: 'type and press enter',
                    hintStyle: TextStyle(color: FblaColors.darkTextTertiary),
                    prefixIcon:
                        Icon(Icons.tag_rounded, color: FblaColors.darkTextSecond),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(FblaRadius.md),
                      borderSide: BorderSide(color: FblaColors.darkOutline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(FblaRadius.md),
                      borderSide: const BorderSide(
                          color: FblaColors.secondary, width: 2),
                    ),
                  ),
                ),
                if (tags.isNotEmpty) const SizedBox(height: FblaSpacing.sm),
                if (tags.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: tags
                        .map((t) => InputChip(
                              label: Text('#$t',
                                  style: const TextStyle(fontSize: 12)),
                              onDeleted: () => setInner(() => tags.remove(t)),
                              backgroundColor: FblaColors.darkSurfaceHigh,
                              labelStyle: TextStyle(
                                  color: FblaColors.darkTextPrimary),
                            ))
                        .toList(),
                  ),
                const SizedBox(height: FblaSpacing.md),
                TextField(
                  controller: bodyCtrl,
                  maxLines: 5,
                  style: TextStyle(color: FblaColors.darkTextPrimary),
                  decoration: InputDecoration(
                    labelText: 'Content / description *',
                    labelStyle: TextStyle(color: FblaColors.darkTextSecond),
                    alignLabelWithHint: true,
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
                  onPressed: saving
                      ? null
                      : () async {
                          if (titleCtrl.text.isEmpty || bodyCtrl.text.isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                  content: Text('Title and content are required.')),
                            );
                            return;
                          }
                          setInner(() => saving = true);
                          try {
                            final body = <String, dynamic>{
                              'title': titleCtrl.text.trim(),
                              'body': bodyCtrl.text.trim(),
                              'category': category,
                              'resource_type': resourceType,
                            };
                            final trimmedUrl = urlCtrl.text.trim();
                            if (trimmedUrl.isNotEmpty) {
                              body['url'] = trimmedUrl;
                            }
                            if (tags.isNotEmpty) {
                              body['tags'] = tags;
                            }
                            await _api.post('/hub', body: body);
                            if (mounted) {
                              _load();
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Resource added!')),
                              );
                            }
                          } catch (e) {
                            setInner(() => saving = false);
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                  content: Text('Error: ${e.toString()}')),
                            );
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Add Resource'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search bar with smooth focus
// ─────────────────────────────────────────────────────────────────────────────

class _SearchBar extends StatefulWidget {
  const _SearchBar({required this.controller, required this.onClear});
  final TextEditingController controller;
  final VoidCallback onClear;

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  late final FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_updateFocus);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_updateFocus);
    _focusNode.dispose();
    super.dispose();
  }

  void _updateFocus() {
    setState(() => _isFocused = _focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: FblaMotion.fast,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(FblaRadius.full),
        boxShadow: _isFocused ? FblaShadow.blueGlow : [],
      ),
      child: TextField(
        focusNode: _focusNode,
        controller: widget.controller,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Search resources…',
          hintStyle: TextStyle(color: FblaColors.darkTextSecond),
          prefixIcon: Icon(Icons.search, color: FblaColors.darkTextSecond),
          suffixIcon: widget.controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: FblaColors.darkTextSecond),
                  tooltip: 'Clear search',
                  onPressed: widget.onClear,
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(FblaRadius.full),
            borderSide: BorderSide(color: FblaColors.darkOutline),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(FblaRadius.full),
            borderSide: BorderSide(color: FblaColors.darkOutline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(FblaRadius.full),
            borderSide: const BorderSide(color: FblaColors.secondary, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: FblaSpacing.md,
            vertical: FblaSpacing.sm,
          ),
          filled: true,
          fillColor: FblaColors.darkSurface,
        ),
        style: TextStyle(color: FblaColors.darkTextPrimary),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Category chip with accent color
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryChip extends StatefulWidget {
  const _CategoryChip({
    required this.label,
    required this.accentColor,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final Color accentColor;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_CategoryChip> createState() => _CategoryChipState();
}

class _CategoryChipState extends State<_CategoryChip> with SingleTickerProviderStateMixin {
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
          duration: FblaMotion.fast,
          curve: FblaMotion.strongEaseOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isSelected ? widget.accentColor : FblaColors.darkSurface,
            borderRadius: BorderRadius.circular(FblaRadius.full),
            border: widget.isSelected
                ? null
                : Border.all(color: FblaColors.darkOutline, width: 1),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: widget.accentColor.withAlpha(60),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Text(
            widget.label,
            style: FblaFonts.label(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: widget.isSelected ? Colors.white : FblaColors.darkTextPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Competitive Events Banner
// ─────────────────────────────────────────────────────────────────────────────

class _CompetitiveEventsBanner extends StatefulWidget {
  const _CompetitiveEventsBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_CompetitiveEventsBanner> createState() =>
      _CompetitiveEventsBannerState();
}

class _CompetitiveEventsBannerState extends State<_CompetitiveEventsBanner>
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
            borderRadius: BorderRadius.circular(FblaRadius.lg),
            border: Border.all(color: FblaColors.darkOutline),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                FblaColors.primary.withAlpha(20),
                FblaColors.secondary.withAlpha(15),
              ],
            ),
          ),
          padding: const EdgeInsets.all(FblaSpacing.md),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: FblaColors.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(FblaRadius.md),
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: FblaColors.secondary,
                  size: 24,
                ),
              ),
              const SizedBox(width: FblaSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Competitive Events',
                      style: FblaFonts.display(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: FblaColors.darkTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '70+ events · Practice quizzes · Study resources',
                      style: FblaFonts.label(
                        fontSize: 11,
                        color: FblaColors.darkTextSecond,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: FblaColors.darkTextTertiary,
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
// Resource card
// ─────────────────────────────────────────────────────────────────────────────

class _ResourceCard extends StatefulWidget {
  const _ResourceCard({
    required this.item,
    this.onDeleted,
  });
  final Map<String, dynamic> item;

  /// Fired after a successful DELETE /hub/<id> so the parent hub screen
  /// can reload its list.
  final VoidCallback? onDeleted;

  @override
  State<_ResourceCard> createState() => _ResourceCardState();
}

class _ResourceCardState extends State<_ResourceCard>
    with SingleTickerProviderStateMixin {
  static const _storage = FlutterSecureStorage();
  static const _bookmarkKey = 'bookmarked_resource_ids';

  late final AnimationController _pressCtrl;
  late final Animation<double> _pressScale;
  bool _bookmarked = false;

  String get _resId => widget.item['id']?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _pressScale = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _pressCtrl, curve: FblaMotion.strongEaseOut),
    );
    _loadBookmark();
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
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
    if (_resId.isEmpty) return;
    final ids = await _readBookmarks();
    if (mounted) setState(() => _bookmarked = ids.contains(_resId));
  }

  Future<void> _toggleBookmark() async {
    if (_resId.isEmpty) return;
    HapticFeedback.lightImpact();
    final ids = await _readBookmarks();
    final wasBookmarked = ids.contains(_resId);
    if (wasBookmarked) {
      ids.remove(_resId);
    } else {
      ids.add(_resId);
    }
    await _storage.write(key: _bookmarkKey, value: jsonEncode(ids));
    if (!mounted) return;
    setState(() => _bookmarked = !wasBookmarked);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(wasBookmarked ? 'Removed from saved' : 'Saved resource'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Color _getCategoryColor(String? category) {
    const colors = {
      'Study Materials': Color(0xFF2563EB),
      'Competition Rules': Color(0xFFFB923C),
      'Templates': Color(0xFF16A34A),
      'Leadership': Color(0xFF9333EA),
      'Chapter Documents': Color(0xFF64748B),
      'Reference': Color(0xFF0891B2),
    };
    return colors[category] ?? FblaColors.secondary;
  }

  bool get _isOwner {
    final me = Supabase.instance.client.auth.currentUser?.id;
    return me != null && widget.item['created_by'] == me;
  }

  Future<void> _confirmDelete() async {
    final id = widget.item['id'];
    if (id is! String || id.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FblaColors.darkSurface,
        title: Text(
          'Delete resource?',
          style: FblaFonts.heading(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: FblaColors.darkTextPrimary,
          ),
        ),
        content: Text(
          'This resource will be removed from the Hub for everyone.',
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
    if (ok != true || !mounted) return;
    try {
      await ApiService.instance.delete('/hub/$id');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Resource deleted'),
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
    final title = widget.item['title'] as String? ?? '';
    final body = widget.item['body'] as String? ?? '';
    final category = widget.item['category'] as String? ?? 'Reference';
    final categoryColor = _getCategoryColor(category);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardSurface = isDark ? FblaColors.darkSurface : FblaColors.surface;
    final cardOutline = isDark ? FblaColors.darkOutline : FblaColors.outline;
    final textPrimary =
        isDark ? FblaColors.darkTextPrimary : FblaColors.textPrimary;
    final textSecond =
        isDark ? FblaColors.darkTextSecond : FblaColors.textSecondary;
    final textTertiary =
        isDark ? FblaColors.darkTextTertiary : FblaColors.textTertiary;

    return GestureDetector(
      onTap: () => _showResourceDetail(context, widget.item, categoryColor),
      onTapDown: (_) => _pressCtrl.forward(),
      onTapUp: (_) => _pressCtrl.reverse(),
      onTapCancel: () => _pressCtrl.reverse(),
      child: ScaleTransition(
        scale: _pressScale,
        child: Container(
          decoration: BoxDecoration(
            color: cardSurface,
            borderRadius: BorderRadius.circular(FblaRadius.lg),
            border: Border.all(color: cardOutline, width: 1),
          ),
          padding: const EdgeInsets.all(FblaSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: categoryColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(FblaRadius.md),
                      border: Border.all(color: categoryColor.withAlpha(40), width: 1),
                    ),
                    child: Icon(
                      Icons.library_books_outlined,
                      color: categoryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: FblaSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: FblaFonts.display(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: categoryColor.withAlpha(15),
                            borderRadius: BorderRadius.circular(FblaRadius.full),
                            border: Border.all(
                              color: categoryColor.withAlpha(40),
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            category,
                            style: FblaFonts.label(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: categoryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Bookmark toggle
                  Semantics(
                    label: _bookmarked ? 'Remove bookmark' : 'Save resource',
                    button: true,
                    child: InkWell(
                      onTap: _toggleBookmark,
                      borderRadius: BorderRadius.circular(FblaRadius.md),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          _bookmarked
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          size: 20,
                          color: _bookmarked
                              ? FblaColors.secondary
                              : textTertiary,
                        ),
                      ),
                    ),
                  ),
                  if (_isOwner && widget.onDeleted != null)
                    _ResourceOwnerMenu(onDelete: _confirmDelete),
                ],
              ),
              const SizedBox(height: FblaSpacing.md),
              Text(
                body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: FblaFonts.body(
                  fontSize: 12,
                  color: textSecond,
                  height: 1.4,
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
// Create resource FAB
// ─────────────────────────────────────────────────────────────────────────────

class _CreateResourceFAB extends StatefulWidget {
  const _CreateResourceFAB({required this.onPressed});
  final VoidCallback onPressed;

  @override
  State<_CreateResourceFAB> createState() => _CreateResourceFABState();
}

class _CreateResourceFABState extends State<_CreateResourceFAB>
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
// Resource detail bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

String? _resolveResourceUrl(Map<String, dynamic> item) {
  // Prefer an explicit file_path (Supabase storage path) or url field.
  final filePath = (item['file_path'] as String?)?.trim();
  if (filePath != null && filePath.isNotEmpty) {
    if (filePath.startsWith('http://') || filePath.startsWith('https://')) {
      return filePath;
    }
    return '$kSupabaseUrl/storage/v1/object/public/media/$filePath';
  }
  final url = (item['url'] as String?)?.trim();
  if (url != null && url.isNotEmpty) return url;
  return null;
}

Future<void> _showResourceDetail(
  BuildContext context,
  Map<String, dynamic> item,
  Color categoryColor,
) async {
  final title = item['title'] as String? ?? 'Resource';
  final body = item['body'] as String? ?? '';
  final category = item['category'] as String? ?? 'Reference';
  final fileUrl = _resolveResourceUrl(item);

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: FblaColors.darkSurface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(FblaRadius.xl)),
    ),
    builder: (ctx) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            FblaSpacing.lg,
            FblaSpacing.md,
            FblaSpacing.lg,
            FblaSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: FblaColors.darkOutline,
                    borderRadius: BorderRadius.circular(FblaRadius.full),
                  ),
                ),
              ),
              const SizedBox(height: FblaSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: categoryColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(FblaRadius.md),
                      border: Border.all(color: categoryColor.withAlpha(50), width: 1),
                    ),
                    child: Icon(
                      Icons.library_books_outlined,
                      color: categoryColor,
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
                          style: FblaFonts.display(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: FblaColors.darkTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: categoryColor.withAlpha(20),
                            borderRadius: BorderRadius.circular(FblaRadius.full),
                          ),
                          child: Text(
                            category,
                            style: FblaFonts.label(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: categoryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: FblaSpacing.lg),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.45,
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    body.isEmpty ? 'No description provided.' : body,
                    style: FblaFonts.body(
                      fontSize: 14,
                      color: FblaColors.darkTextPrimary,
                      height: 1.55,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: FblaSpacing.lg),
              Row(
                children: [
                  if (fileUrl != null) ...[
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final uri = Uri.tryParse(fileUrl);
                          if (uri == null) return;
                          final ok = await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                          if (!ok && ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: const Text('Could not open file'),
                                backgroundColor: FblaColors.error,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: FblaColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(FblaRadius.md),
                          ),
                        ),
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: Text(
                          'Open Resource',
                          style: FblaFonts.label(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: FblaSpacing.sm),
                    OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: fileUrl));
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Link copied')),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: FblaColors.darkOutline),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(FblaRadius.md),
                        ),
                      ),
                      icon: Icon(Icons.link, size: 18, color: FblaColors.darkTextPrimary),
                      label: Text(
                        'Copy',
                        style: FblaFonts.label(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: FblaColors.darkTextPrimary,
                        ),
                      ),
                    ),
                  ] else ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: FblaColors.darkOutline),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(FblaRadius.md),
                          ),
                        ),
                        icon: Icon(Icons.check, size: 18, color: FblaColors.darkTextPrimary),
                        label: Text(
                          'Close',
                          style: FblaFonts.label(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: FblaColors.darkTextPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

// ── Owner-only kebab menu for hub resources ──────────────────────────────────
class _ResourceOwnerMenu extends StatelessWidget {
  const _ResourceOwnerMenu({required this.onDelete});

  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Resource options',
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
                'Delete resource',
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
