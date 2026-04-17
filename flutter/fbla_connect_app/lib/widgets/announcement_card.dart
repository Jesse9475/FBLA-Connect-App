import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../services/api_service.dart';
import '../services/user_state.dart';
import '../theme/app_theme.dart';

/// Opens a full-detail bottom sheet for an announcement.
///
/// [onChanged] is called after an edit or delete so the parent can refresh.
void showAnnouncementDetail(
  BuildContext context,
  Map<String, dynamic> announcement, {
  VoidCallback? onChanged,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: true,
    enableDrag: true,
    builder: (_) => _AnnouncementDetailSheet(
      announcement: announcement,
      onChanged: onChanged,
    ),
  );
}

/// Announcement card — scope conveyed by full-border accent and badge,
/// not a left-strip. Typography-led hierarchy; clean single surface.
class AnnouncementCard extends StatefulWidget {
  const AnnouncementCard({
    super.key,
    required this.announcement,
    this.onChanged,
  });

  final Map<String, dynamic> announcement;
  final VoidCallback? onChanged;

  @override
  State<AnnouncementCard> createState() => _AnnouncementCardState();
}

class _AnnouncementCardState extends State<AnnouncementCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _pressScale;

  String get _title =>
      widget.announcement['title'] as String? ?? 'Announcement';
  String get _body => widget.announcement['body'] as String? ?? '';
  String get _scope =>
      (widget.announcement['scope'] as String?)?.toLowerCase() ?? 'national';

  DateTime? get _createdAt =>
      DateTime.tryParse(widget.announcement['created_at'] as String? ?? '');

  /// Scope-keyed accent + badge styling
  ({Color accent, Color badgeBg, Color badgeFg, IconData icon, String label}) get _scopeStyle =>
      switch (_scope) {
        'chapter' => (
            accent: FblaColors.primaryLight,
            badgeBg: FblaColors.primary.withAlpha(20),
            badgeFg: FblaColors.primaryLight,
            icon: Icons.groups_2_outlined,
            label: 'Chapter',
          ),
        'district' => (
            accent: FblaColors.secondary,
            badgeBg: FblaColors.secondary.withAlpha(18),
            badgeFg: FblaColors.secondary,
            icon: Icons.location_city_outlined,
            label: 'District',
          ),
        _ => (
            accent: FblaColors.success,
            badgeBg: FblaColors.success.withAlpha(18),
            badgeFg: FblaColors.success,
            icon: Icons.public_outlined,
            label: 'National',
          ),
      };

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

  @override
  Widget build(BuildContext context) {
    final style = _scopeStyle;

    return Semantics(
      label: 'Announcement: $_title, scope: $_scope',
      button: true,
      child: ScaleTransition(
        scale: _pressScale,
        child: GestureDetector(
          onTapDown: (_) => _pressCtrl.forward(),
          onTapUp: (_) {
            _pressCtrl.reverse();
            HapticFeedback.lightImpact();
            showAnnouncementDetail(
              context,
              widget.announcement,
              onChanged: widget.onChanged,
            );
          },
          onTapCancel: () => _pressCtrl.reverse(),
          child: Container(
            decoration: BoxDecoration(
              color: FblaColors.darkSurface,
              borderRadius: BorderRadius.circular(FblaRadius.xl),
              border: Border.all(
                color: style.accent.withAlpha(50),
                width: 1,
              ),
            ),
            padding: const EdgeInsets.all(FblaSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header row: scope badge + timestamp ───────────────────────
                Row(
                  children: [
                    // Scope badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: style.badgeBg,
                        borderRadius: BorderRadius.circular(FblaRadius.full),
                        border: Border.all(
                          color: style.accent.withAlpha(55),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(style.icon, size: 10, color: style.badgeFg),
                          const SizedBox(width: 4),
                          Text(
                            style.label,
                            style: FblaFonts.label(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: style.badgeFg,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Timestamp
                    if (_createdAt != null)
                      Text(
                        timeago.format(_createdAt!, allowFromNow: true),
                        style: FblaFonts.label(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: FblaColors.darkTextTertiary,
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 10),

                // ── Title ─────────────────────────────────────────────────────
                Text(
                  _title,
                  style: FblaFonts.heading(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: FblaColors.darkTextPrimary,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                // ── Body preview ──────────────────────────────────────────────
                if (_body.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    _body,
                    style: FblaFonts.body(
                      fontSize: 13,
                      color: FblaColors.darkTextSecond,
                      height: 1.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                // ── Read-more hint ────────────────────────────────────────────
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Read more',
                      style: FblaFonts.label(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: style.accent.withAlpha(200),
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 9,
                      color: style.accent.withAlpha(180),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Detail bottom sheet ───────────────────────────────────────────────────────

class _AnnouncementDetailSheet extends StatefulWidget {
  const _AnnouncementDetailSheet({
    required this.announcement,
    this.onChanged,
  });

  final Map<String, dynamic> announcement;
  final VoidCallback? onChanged;

  @override
  State<_AnnouncementDetailSheet> createState() =>
      _AnnouncementDetailSheetState();
}

class _AnnouncementDetailSheetState extends State<_AnnouncementDetailSheet> {
  late Map<String, dynamic> _data;

  @override
  void initState() {
    super.initState();
    _data = Map<String, dynamic>.from(widget.announcement);
  }

  String get _title => _data['title'] as String? ?? 'Announcement';
  String get _body => _data['body'] as String? ?? '';
  String get _scope =>
      (_data['scope'] as String?)?.toLowerCase() ?? 'national';
  String? get _authorName => _data['author_name'] as String?;
  String? get _announcementId => _data['id'] as String?;
  String? get _createdBy => _data['created_by'] as String?;

  DateTime? get _createdAt =>
      DateTime.tryParse(_data['created_at'] as String? ?? '');

  bool get _canEditOrDelete {
    final me = Supabase.instance.client.auth.currentUser?.id;
    if (me == null) return false;
    if (UserState.instance.isAdmin) return true;
    return _createdBy != null && _createdBy == me;
  }

  ({Color accent, Color badgeBg, Color badgeFg, IconData icon, String label})
      get _scopeStyle => switch (_scope) {
            'chapter' => (
                accent: FblaColors.primaryLight,
                badgeBg: FblaColors.primary.withAlpha(20),
                badgeFg: FblaColors.primaryLight,
                icon: Icons.groups_2_outlined,
                label: 'Chapter',
              ),
            'district' => (
                accent: FblaColors.secondary,
                badgeBg: FblaColors.secondary.withAlpha(18),
                badgeFg: FblaColors.secondary,
                icon: Icons.location_city_outlined,
                label: 'District',
              ),
            _ => (
                accent: FblaColors.success,
                badgeBg: FblaColors.success.withAlpha(18),
                badgeFg: FblaColors.success,
                icon: Icons.public_outlined,
                label: 'National',
              ),
          };

  // ── Delete ──────────────────────────────────────────────────────────────────

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FblaColors.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FblaRadius.lg),
        ),
        title: Text(
          'Delete announcement?',
          style: FblaFonts.heading(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: FblaColors.darkTextPrimary,
          ),
        ),
        content: Text(
          'This cannot be undone.',
          style: FblaFonts.body(
            fontSize: 14,
            color: FblaColors.darkTextSecond,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: FblaFonts.label(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: FblaColors.darkTextSecond,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: FblaColors.error),
            child: Text(
              'Delete',
              style: FblaFonts.label(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: FblaColors.error,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ApiService.instance
          .delete<dynamic>('/announcements/$_announcementId');
      if (!mounted) return;
      Navigator.pop(context); // close detail sheet
      widget.onChanged?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Announcement deleted',
            style: TextStyle(
                fontFamily: 'Mulish', color: FblaColors.darkTextPrimary),
          ),
          backgroundColor: FblaColors.darkSurface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(FblaRadius.md)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Couldn\u2019t delete: $e',
            style: TextStyle(
                fontFamily: 'Mulish', color: FblaColors.darkTextPrimary),
          ),
          backgroundColor: FblaColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(FblaRadius.md)),
        ),
      );
    }
  }

  // ── Edit ────────────────────────────────────────────────────────────────────

  Future<void> _openEdit() async {
    final updated = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditAnnouncementSheet(announcement: _data),
    );

    if (updated == null || !mounted) return;

    setState(() {
      _data = {..._data, ...updated};
    });
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final style = _scopeStyle;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.70,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: FblaColors.darkSurface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(FblaRadius.xl),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x60000000),
              blurRadius: 48,
              offset: Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Drag handle ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: FblaColors.darkTextTertiary.withAlpha(60),
                    borderRadius: BorderRadius.circular(FblaRadius.full),
                  ),
                ),
              ),
            ),

            // ── Header — scope badge + title + menu ────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                FblaSpacing.xl,
                FblaSpacing.md,
                FblaSpacing.sm, // tighter right for menu button
                FblaSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Scope badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: style.badgeBg,
                          borderRadius:
                              BorderRadius.circular(FblaRadius.full),
                          border: Border.all(
                            color: style.accent.withAlpha(55),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(style.icon, size: 10, color: style.badgeFg),
                            const SizedBox(width: 4),
                            Text(
                              style.label,
                              style: FblaFonts.label(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: style.badgeFg,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // ── Kebab menu (edit / delete) ──────────────────────────
                      if (_canEditOrDelete)
                        PopupMenuButton<String>(
                          icon: Icon(
                            Icons.more_vert_rounded,
                            size: 20,
                            color: FblaColors.darkTextTertiary,
                          ),
                          color: FblaColors.darkSurfaceHigh,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(FblaRadius.md),
                          ),
                          onSelected: (value) {
                            if (value == 'edit') _openEdit();
                            if (value == 'delete') _confirmDelete();
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined,
                                      size: 16,
                                      color: FblaColors.darkTextPrimary),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Edit',
                                    style: FblaFonts.label(
                                      fontSize: 14,
                                      color: FblaColors.darkTextPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline_rounded,
                                      size: 16, color: FblaColors.error),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Delete',
                                    style: FblaFonts.label(
                                      fontSize: 14,
                                      color: FblaColors.error,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _title,
                    style: FblaFonts.heading(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: FblaColors.darkTextPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),

            Divider(height: 1, color: FblaColors.darkOutline),

            // ── Body ───────────────────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  FblaSpacing.xl,
                  FblaSpacing.lg,
                  FblaSpacing.xl,
                  FblaSpacing.xxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Meta row: time + author
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 12,
                          color: FblaColors.darkTextTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _createdAt != null
                              ? timeago.format(_createdAt!,
                                  allowFromNow: true)
                              : 'Recent',
                          style: FblaFonts.label(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: FblaColors.darkTextTertiary,
                          ),
                        ),
                        if (_authorName != null) ...[
                          Text(
                            '  \u00b7  ',
                            style: TextStyle(
                              color: FblaColors.darkTextTertiary,
                              fontSize: 12,
                            ),
                          ),
                          Icon(
                            Icons.person_outline_rounded,
                            size: 12,
                            color: FblaColors.darkTextTertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _authorName!,
                            style: FblaFonts.label(
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: FblaColors.darkTextTertiary,
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: FblaSpacing.lg),

                    if (_body.isNotEmpty)
                      Text(
                        _body,
                        style: FblaFonts.body(
                          fontSize: 15,
                          color: FblaColors.darkTextSecond,
                          height: 1.7,
                        ),
                      )
                    else
                      Text(
                        'No additional details.',
                        style: FblaFonts.body(
                          fontSize: 15,
                          color: FblaColors.darkTextTertiary,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Safe-area padding at the bottom
            SizedBox(height: MediaQuery.paddingOf(context).bottom),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 220.ms, curve: FblaMotion.strongEaseOut)
        .scale(
          begin: const Offset(0.97, 0.97),
          end: const Offset(1, 1),
          duration: 220.ms,
          curve: FblaMotion.strongEaseOut,
        );
  }
}

// ─── Edit Announcement Sheet ─────────────────────────────────────────────────

class _EditAnnouncementSheet extends StatefulWidget {
  const _EditAnnouncementSheet({required this.announcement});

  final Map<String, dynamic> announcement;

  @override
  State<_EditAnnouncementSheet> createState() => _EditAnnouncementSheetState();
}

class _EditAnnouncementSheetState extends State<_EditAnnouncementSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _bodyCtrl;
  bool _saving = false;

  String get _announcementId => widget.announcement['id'] as String? ?? '';

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(
        text: widget.announcement['title'] as String? ?? '');
    _bodyCtrl = TextEditingController(
        text: widget.announcement['body'] as String? ?? '');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final result = await ApiService.instance
          .patch<Map<String, dynamic>>('/announcements/$_announcementId',
              body: {
                'title': _titleCtrl.text.trim(),
                'body': _bodyCtrl.text.trim(),
              },
              parser: (json) =>
                  (json as Map<String, dynamic>)['announcement']
                      as Map<String, dynamic>);

      if (!mounted) return;
      Navigator.pop(context, result);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Announcement updated',
            style: TextStyle(
                fontFamily: 'Mulish', color: FblaColors.darkTextPrimary),
          ),
          backgroundColor: FblaColors.darkSurface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(FblaRadius.md)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Couldn\u2019t save: $e',
            style: TextStyle(
                fontFamily: 'Mulish', color: FblaColors.darkTextPrimary),
          ),
          backgroundColor: FblaColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(FblaRadius.md)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: FblaColors.darkSurface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(FblaRadius.xl)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x60000000),
            blurRadius: 48,
            offset: Offset(0, -6),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + bottomInset),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: FblaColors.darkTextTertiary.withAlpha(60),
                  borderRadius: BorderRadius.circular(FblaRadius.full),
                ),
              ),
            ),
            const SizedBox(height: 18),

            Text(
              'Edit Announcement',
              style: FblaFonts.heading(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: FblaColors.darkTextPrimary,
              ),
            ),
            const SizedBox(height: 18),

            // Title field
            TextFormField(
              controller: _titleCtrl,
              style: FblaFonts.body(
                fontSize: 15,
                color: FblaColors.darkTextPrimary,
              ),
              maxLength: 200,
              decoration: InputDecoration(
                labelText: 'Title',
                labelStyle: FblaFonts.label(
                  fontSize: 13,
                  color: FblaColors.darkTextTertiary,
                ),
                counterStyle: TextStyle(
                  fontSize: 11,
                  color: FblaColors.darkTextTertiary,
                ),
                filled: true,
                fillColor: FblaColors.darkBg,
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
                  borderSide:
                      BorderSide(color: FblaColors.primaryLight, width: 1.5),
                ),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Title is required' : null,
            ),
            const SizedBox(height: 14),

            // Body field
            TextFormField(
              controller: _bodyCtrl,
              style: FblaFonts.body(
                fontSize: 15,
                color: FblaColors.darkTextPrimary,
              ),
              maxLines: 5,
              minLines: 3,
              maxLength: 6000,
              decoration: InputDecoration(
                labelText: 'Message',
                labelStyle: FblaFonts.label(
                  fontSize: 13,
                  color: FblaColors.darkTextTertiary,
                ),
                counterStyle: TextStyle(
                  fontSize: 11,
                  color: FblaColors.darkTextTertiary,
                ),
                filled: true,
                fillColor: FblaColors.darkBg,
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
                  borderSide:
                      BorderSide(color: FblaColors.primaryLight, width: 1.5),
                ),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Message is required' : null,
            ),
            const SizedBox(height: 18),

            // Save button
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: FblaColors.primaryLight,
                  disabledBackgroundColor:
                      FblaColors.primaryLight.withAlpha(100),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(FblaRadius.md),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Save Changes',
                        style: FblaFonts.label(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Legacy empty / error views (kept to not break existing refs) ──────────────

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
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: FblaColors.primary.withAlpha(15),
                shape: BoxShape.circle,
                border:
                    Border.all(color: FblaColors.primary.withAlpha(40)),
              ),
              child: Icon(
                Icons.campaign_outlined,
                size: 30,
                color: FblaColors.primaryLight.withAlpha(160),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              scope == 'all' ? 'No Announcements' : 'Nothing in $scope',
              style: FblaFonts.heading(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: FblaColors.darkTextPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Check back later for updates from your chapter and district.',
              textAlign: TextAlign.center,
              style: FblaFonts.body(
                fontSize: 13,
                color: FblaColors.darkTextSecond,
                height: 1.5,
              ),
            ),
          ],
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
        padding: const EdgeInsets.all(FblaSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: FblaColors.error, size: 40),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: FblaFonts.body(
                fontSize: 14,
                color: FblaColors.darkTextSecond,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onRetry,
              child: Text(
                'Retry',
                style: FblaFonts.label(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: FblaColors.primaryLight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
