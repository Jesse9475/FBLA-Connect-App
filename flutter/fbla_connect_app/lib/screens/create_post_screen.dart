import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';
import '../services/user_state.dart';
import '../theme/app_theme.dart';
import 'celebration_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Create Post Screen — Instagram-exact 3-stage flow.
//
// Stage 1 ─ PICK
//   Black canvas. Big square preview at top. "Recents" header.
//   Below: camera tile + recently picked thumbnails grid + open-gallery tile.
//   Top bar: ✕ on left, "New post" centred, "Next →" gold on right.
//
// Stage 2 ─ EDIT
//   Same black canvas. Big preview at top with the active filter applied via
//   ColorFiltered. Below: a horizontal "Filter" carousel — each card shows the
//   image with that filter so the user can preview it before committing.
//   Top bar: ← back, "Edit" centred, "Next →" gold on right.
//
// Stage 3 ─ COMPOSE
//   Small (64×64) thumbnail top-left next to a multi-line caption field.
//   Accessory rows underneath: Add location, Tag people, Visibility, Advanced.
//   Footer: "Posting to <chapter>" hint + the share button.
//   Top bar: ← back, "New post" centred, "Share →" gold on right.
//
// Pre-upload pattern: image starts uploading the moment Stage 2 appears so by
// the time the user finishes typing the caption it's already in storage.
// ─────────────────────────────────────────────────────────────────────────────

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _api = ApiService.instance;
  final _picker = ImagePicker();
  final _captionCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  // ── Stage state ──
  // 0 = pick, 1 = edit/filter, 2 = compose
  int _stage = 0;

  // ── Picker state ──
  XFile? _selectedImage;
  /// Recently picked images this session (local only — not gallery scan).
  /// Acts like Instagram's "Recents" row when the user has picked more than
  /// one image already.
  final List<XFile> _recents = [];

  // ── Edit state ──
  _Filter _activeFilter = _Filter.original;

  // ── Upload state ──
  String? _uploadedMediaUrl;
  double _uploadProgress = 0;
  bool _uploading = false;
  bool _uploadFailed = false;
  String? _uploadError;

  // ── Compose state ──
  bool _hideLikeCount = false;
  bool _disableComments = false;

  // ── Submit state ──
  bool _posting = false;

  // ── First-open auto-launch gallery (Instagram opens picker immediately) ──
  bool _autoLaunchedGallery = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_autoLaunchedGallery || !mounted) return;
      _autoLaunchedGallery = true;
      await _openGallery();
    });
  }

  @override
  void dispose() {
    _captionCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  // ── Image picking ─────────────────────────────────────────────────────────

  void _resetUploadState() {
    _uploadedMediaUrl = null;
    _uploadProgress = 0;
    _uploading = false;
    _uploadFailed = false;
    _uploadError = null;
  }

  Future<void> _openGallery() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 90,
    );
    if (image == null) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedImage = image;
      _resetUploadState();
      _recents.removeWhere((x) => x.path == image.path);
      _recents.insert(0, image);
      if (_recents.length > 12) {
        _recents.removeRange(12, _recents.length);
      }
    });
  }

  Future<void> _openCamera() async {
    final image = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      imageQuality: 90,
    );
    if (image == null) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedImage = image;
      _resetUploadState();
      _recents.removeWhere((x) => x.path == image.path);
      _recents.insert(0, image);
    });
  }

  void _selectRecent(XFile image) {
    if (image.path == _selectedImage?.path) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedImage = image;
      _resetUploadState();
    });
  }

  // ── Stage transitions ─────────────────────────────────────────────────────

  void _goToEdit() {
    if (_selectedImage == null) {
      HapticFeedback.mediumImpact();
      return;
    }
    setState(() => _stage = 1);
    _startPreUpload();
  }

  void _goToCompose() {
    setState(() => _stage = 2);
  }

  void _goBack() {
    if (_stage == 0) {
      Navigator.of(context).pop();
    } else {
      setState(() => _stage = _stage - 1);
    }
  }

  // ── Pre-upload (Instagram pattern — upload while user is editing) ─────────

  Future<void> _startPreUpload() async {
    if (_selectedImage == null) return;
    if (_uploadedMediaUrl != null) return; // already done

    setState(() {
      _uploading = true;
      _uploadFailed = false;
      _uploadError = null;
      _uploadProgress = 0;
    });

    try {
      final url = await _api.uploadFileAndGetUrl(
        _selectedImage!,
        folder: 'posts',
        onProgress: (sent, total) {
          if (total > 0 && mounted) {
            setState(() => _uploadProgress = sent / total);
          }
        },
      );

      if (!mounted) return;
      setState(() {
        _uploadedMediaUrl = url;
        _uploading = false;
        _uploadProgress = 1.0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _uploadFailed = true;
        _uploadError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // ── Share ──────────────────────────────────────────────────────────────────

  Future<void> _sharePost() async {
    final caption = _captionCtrl.text.trim();
    if (caption.isEmpty && _uploadedMediaUrl == null) {
      HapticFeedback.mediumImpact();
      return;
    }
    if (_selectedImage != null && _uploading) return;

    setState(() => _posting = true);

    try {
      final body = <String, dynamic>{
        'caption': caption,
        if (_uploadedMediaUrl != null) 'media_url': _uploadedMediaUrl,
        if (_locationCtrl.text.trim().isNotEmpty)
          'location': _locationCtrl.text.trim(),
      };

      final result = await _api.post<Map<String, dynamic>>(
        '/posts',
        body: body,
        parser: (data) =>
            (data['post'] as Map<String, dynamic>?) ?? (data as Map<String, dynamic>),
      );

      if (!mounted) return;
      HapticFeedback.heavyImpact();

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => CelebrationScreen(
            contentType: 'post',
            contentId: result['id'] as String? ?? '',
            content: {
              'caption': caption,
              if (_uploadedMediaUrl != null) 'media_url': _uploadedMediaUrl,
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _posting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
            style: const TextStyle(fontFamily: 'Mulish'),
          ),
          backgroundColor: FblaColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FblaRadius.md),
          ),
        ),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Instagram's create flow lives on a near-black canvas regardless of theme.
    return Scaffold(
      backgroundColor: FblaColors.darkBg,
      body: SafeArea(
        bottom: false,
        child: WillPopScope(
          onWillPop: () async {
            if (_stage > 0) {
              _goBack();
              return false;
            }
            return true;
          },
          child: AnimatedSwitcher(
            duration: FblaMotion.standard,
            switchInCurve: FblaMotion.strongEaseOut,
            switchOutCurve: FblaMotion.strongEaseOut,
            transitionBuilder: (child, animation) {
              // Slide-right Instagram transition.
              final slide = Tween<Offset>(
                begin: const Offset(0.06, 0),
                end: Offset.zero,
              ).animate(animation);
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: slide, child: child),
              );
            },
            child: _stage == 0
                ? _PickStage(
                    key: const ValueKey('pick'),
                    selectedImage: _selectedImage,
                    recents: _recents,
                    onClose: _goBack,
                    onNext: _goToEdit,
                    onOpenCamera: _openCamera,
                    onOpenGallery: _openGallery,
                    onSelectRecent: _selectRecent,
                  )
                : _stage == 1
                    ? _EditStage(
                        key: const ValueKey('edit'),
                        image: _selectedImage!,
                        activeFilter: _activeFilter,
                        onChangeFilter: (f) =>
                            setState(() => _activeFilter = f),
                        onBack: _goBack,
                        onNext: _goToCompose,
                        uploading: _uploading,
                        uploadProgress: _uploadProgress,
                        uploadFailed: _uploadFailed,
                        uploadError: _uploadError,
                        onRetryUpload: _startPreUpload,
                      )
                    : _ComposeStage(
                        key: const ValueKey('compose'),
                        image: _selectedImage,
                        filter: _activeFilter,
                        captionCtrl: _captionCtrl,
                        locationCtrl: _locationCtrl,
                        hideLikeCount: _hideLikeCount,
                        disableComments: _disableComments,
                        onToggleHideLikes: (v) =>
                            setState(() => _hideLikeCount = v),
                        onToggleDisableComments: (v) =>
                            setState(() => _disableComments = v),
                        chapterName:
                            UserState.instance.displayName ?? 'your chapter',
                        uploading: _uploading,
                        uploadProgress: _uploadProgress,
                        uploadFailed: _uploadFailed,
                        posting: _posting,
                        onBack: _goBack,
                        onShare: _sharePost,
                      ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// STAGE 1 — PICK
// ═════════════════════════════════════════════════════════════════════════════

class _PickStage extends StatelessWidget {
  const _PickStage({
    super.key,
    required this.selectedImage,
    required this.recents,
    required this.onClose,
    required this.onNext,
    required this.onOpenCamera,
    required this.onOpenGallery,
    required this.onSelectRecent,
  });

  final XFile? selectedImage;
  final List<XFile> recents;
  final VoidCallback onClose;
  final VoidCallback onNext;
  final VoidCallback onOpenCamera;
  final VoidCallback onOpenGallery;
  final void Function(XFile) onSelectRecent;

  @override
  Widget build(BuildContext context) {
    final hasImage = selectedImage != null;

    return Column(
      children: [
        _IgTopBar(
          leading: _IgIconButton(
            icon: Icons.close_rounded,
            onTap: onClose,
            tooltip: 'Close create post',
          ),
          title: 'New post',
          trailing: _IgNextButton(
            label: 'Next',
            enabled: hasImage,
            onTap: onNext,
          ),
        ),

        // Big square preview
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            color: Colors.black,
            width: double.infinity,
            child: hasImage
                ? _XFileImage(
                    xfile: selectedImage!,
                    key: ValueKey(selectedImage!.path),
                    fit: BoxFit.cover,
                    semanticLabel: 'Selected photo preview',
                  )
                    .animate()
                    .fadeIn(duration: 200.ms, curve: FblaMotion.strongEaseOut)
                : const _EmptyPreview(),
          ),
        ),

        // Sticky "Recents" / actions header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
          color: FblaColors.darkBg,
          child: Row(
            children: [
              Text(
                'Recents',
                style: FblaFonts.label().copyWith(
                  color: FblaColors.darkTextPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  letterSpacing: 0.2,
                ),
              ),
              const Spacer(),
              _IconActionPill(
                icon: Icons.photo_camera_outlined,
                label: 'Camera',
                onTap: onOpenCamera,
              ),
              const SizedBox(width: 8),
              _IconActionPill(
                icon: Icons.photo_library_outlined,
                label: 'Gallery',
                onTap: onOpenGallery,
              ),
            ],
          ),
        ),

        // Recents grid
        Expanded(
          child: recents.isEmpty
              ? _RecentsEmpty(onOpenGallery: onOpenGallery)
              : GridView.builder(
                  padding: const EdgeInsets.all(2),
                  physics: const BouncingScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 2,
                    mainAxisSpacing: 2,
                  ),
                  itemCount: recents.length,
                  itemBuilder: (context, i) {
                    final img = recents[i];
                    final isSelected = img.path == selectedImage?.path;
                    return GestureDetector(
                      onTap: () => onSelectRecent(img),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _XFileImage(
                            xfile: img,
                            fit: BoxFit.cover,
                            excludeFromSemantics: true,
                          ),
                          if (isSelected)
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.35),
                                border: Border.all(
                                  color: FblaColors.secondary,
                                  width: 2,
                                ),
                              ),
                              child: const Align(
                                alignment: Alignment.topRight,
                                child: Padding(
                                  padding: EdgeInsets.all(6),
                                  child: Icon(
                                    Icons.check_circle_rounded,
                                    color: FblaColors.secondary,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _EmptyPreview extends StatelessWidget {
  const _EmptyPreview();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: FblaColors.darkOutline,
                width: 1.5,
              ),
            ),
            child: Icon(
              Icons.add_a_photo_outlined,
              size: 28,
              color: FblaColors.darkTextSecond,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Choose a photo to share',
            style: FblaFonts.body(fontSize: 14).copyWith(
              color: FblaColors.darkTextSecond,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentsEmpty extends StatelessWidget {
  const _RecentsEmpty({required this.onOpenGallery});
  final VoidCallback onOpenGallery;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_outlined,
              size: 32,
              color: FblaColors.darkTextTertiary,
            ),
            const SizedBox(height: 10),
            Text(
              'No recent photos yet',
              style: FblaFonts.body(fontSize: 13).copyWith(
                color: FblaColors.darkTextSecond,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onOpenGallery,
              icon: const Icon(Icons.photo_library_outlined, size: 18),
              label: const Text('Open gallery'),
              style: FilledButton.styleFrom(
                backgroundColor: FblaColors.secondary,
                foregroundColor: FblaColors.onSecondary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(FblaRadius.md),
                ),
                textStyle: FblaFonts.label().copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// STAGE 2 — EDIT (filters)
// ═════════════════════════════════════════════════════════════════════════════

class _EditStage extends StatelessWidget {
  const _EditStage({
    super.key,
    required this.image,
    required this.activeFilter,
    required this.onChangeFilter,
    required this.onBack,
    required this.onNext,
    required this.uploading,
    required this.uploadProgress,
    required this.uploadFailed,
    required this.uploadError,
    required this.onRetryUpload,
  });

  final XFile image;
  final _Filter activeFilter;
  final ValueChanged<_Filter> onChangeFilter;
  final VoidCallback onBack;
  final VoidCallback onNext;

  final bool uploading;
  final double uploadProgress;
  final bool uploadFailed;
  final String? uploadError;
  final VoidCallback onRetryUpload;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _IgTopBar(
          leading: _IgIconButton(
            icon: Icons.arrow_back_rounded,
            onTap: onBack,
            tooltip: 'Back to photo selection',
          ),
          title: 'Edit',
          trailing: _IgNextButton(
            label: 'Next',
            enabled: !uploadFailed,
            onTap: onNext,
          ),
        ),

        // Hairline upload progress
        SizedBox(
          height: 2,
          child: uploading || uploadFailed
              ? LinearProgressIndicator(
                  value: uploadFailed ? 1 : uploadProgress.clamp(0, 1),
                  backgroundColor: FblaColors.darkSurfaceHigh,
                  color: uploadFailed
                      ? FblaColors.error
                      : FblaColors.secondary,
                  minHeight: 2,
                )
              : const SizedBox.shrink(),
        ),

        if (uploadFailed)
          Container(
            width: double.infinity,
            color: FblaColors.error.withOpacity(0.12),
            padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 16, color: FblaColors.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    uploadError ?? 'Upload failed',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: FblaFonts.body(fontSize: 12).copyWith(
                      color: FblaColors.error,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onRetryUpload,
                  child: Text(
                    'Retry',
                    style: FblaFonts.label().copyWith(
                      color: FblaColors.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Big preview with active filter
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            color: Colors.black,
            child: ColorFiltered(
              colorFilter: activeFilter.matrixFilter,
              child: _XFileImage(
                xfile: image,
                fit: BoxFit.cover,
                semanticLabel: 'Photo with ${activeFilter.label} filter',
              ),
            ),
          ),
        ),

        // Filter strip
        Expanded(
          child: Container(
            color: FblaColors.darkBg,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                  child: Text(
                    'Filters',
                    style: FblaFonts.label().copyWith(
                      color: FblaColors.darkTextPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _Filter.values.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, i) {
                      final f = _Filter.values[i];
                      final selected = f == activeFilter;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onChangeFilter(f);
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedContainer(
                              duration: FblaMotion.standard,
                              curve: FblaMotion.strongEaseOut,
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                borderRadius:
                                    BorderRadius.circular(FblaRadius.sm),
                                border: Border.all(
                                  color: selected
                                      ? FblaColors.secondary
                                      : Colors.transparent,
                                  width: 2,
                                ),
                                boxShadow: selected
                                    ? [
                                        BoxShadow(
                                          color: FblaColors.secondary
                                              .withOpacity(0.25),
                                          blurRadius: 12,
                                          spreadRadius: 1,
                                        ),
                                      ]
                                    : const [],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: ColorFiltered(
                                colorFilter: f.matrixFilter,
                                child: _XFileImage(
                                  xfile: image,
                                  fit: BoxFit.cover,
                                  excludeFromSemantics: true,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              f.label,
                              style: FblaFonts.label().copyWith(
                                fontSize: 11,
                                color: selected
                                    ? FblaColors.secondary
                                    : FblaColors.darkTextSecond,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// STAGE 3 — COMPOSE
// ═════════════════════════════════════════════════════════════════════════════

class _ComposeStage extends StatefulWidget {
  const _ComposeStage({
    super.key,
    required this.image,
    required this.filter,
    required this.captionCtrl,
    required this.locationCtrl,
    required this.hideLikeCount,
    required this.disableComments,
    required this.onToggleHideLikes,
    required this.onToggleDisableComments,
    required this.chapterName,
    required this.uploading,
    required this.uploadProgress,
    required this.uploadFailed,
    required this.posting,
    required this.onBack,
    required this.onShare,
  });

  final XFile? image;
  final _Filter filter;
  final TextEditingController captionCtrl;
  final TextEditingController locationCtrl;
  final bool hideLikeCount;
  final bool disableComments;
  final ValueChanged<bool> onToggleHideLikes;
  final ValueChanged<bool> onToggleDisableComments;
  final String chapterName;

  final bool uploading;
  final double uploadProgress;
  final bool uploadFailed;
  final bool posting;
  final VoidCallback onBack;
  final VoidCallback onShare;

  @override
  State<_ComposeStage> createState() => _ComposeStageState();
}

class _ComposeStageState extends State<_ComposeStage> {
  @override
  void initState() {
    super.initState();
    widget.captionCtrl.addListener(_onCaptionChanged);
  }

  @override
  void dispose() {
    widget.captionCtrl.removeListener(_onCaptionChanged);
    super.dispose();
  }

  void _onCaptionChanged() {
    if (mounted) setState(() {});
  }

  bool get _canShare =>
      !widget.posting &&
      !widget.uploading &&
      widget.captionCtrl.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _IgTopBar(
          leading: _IgIconButton(
            icon: Icons.arrow_back_rounded,
            onTap: widget.onBack,
            tooltip: 'Back to edit photo',
          ),
          title: 'New post',
          trailing: _IgNextButton(
            label: widget.posting
                ? 'Posting…'
                : widget.uploading
                    ? 'Uploading…'
                    : 'Share',
            enabled: _canShare,
            onTap: widget.onShare,
          ),
        ),

        // Hairline upload progress
        SizedBox(
          height: 2,
          child: (widget.uploading && widget.uploadProgress < 1) ||
                  widget.uploadFailed
              ? LinearProgressIndicator(
                  value: widget.uploadFailed
                      ? 1
                      : widget.uploadProgress.clamp(0, 1),
                  backgroundColor: FblaColors.darkSurfaceHigh,
                  color: widget.uploadFailed
                      ? FblaColors.error
                      : FblaColors.secondary,
                  minHeight: 2,
                )
              : const SizedBox.shrink(),
        ),

        Expanded(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            children: [
              // Thumbnail + caption row
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.image != null)
                      ClipRRect(
                        borderRadius:
                            BorderRadius.circular(FblaRadius.sm),
                        child: SizedBox(
                          width: 64,
                          height: 64,
                          child: ColorFiltered(
                            colorFilter: widget.filter.matrixFilter,
                            child: _XFileImage(
                              xfile: widget.image!,
                              fit: BoxFit.cover,
                              excludeFromSemantics: true,
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: FblaColors.darkSurfaceHigh,
                          borderRadius:
                              BorderRadius.circular(FblaRadius.sm),
                          border: Border.all(color: FblaColors.darkOutline),
                        ),
                        child: Icon(
                          Icons.text_fields_rounded,
                          color: FblaColors.darkTextTertiary,
                        ),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Semantics(
                        label: 'Post caption',
                        textField: true,
                        child: TextField(
                          controller: widget.captionCtrl,
                          maxLines: 6,
                          minLines: 3,
                          maxLength: 2200,
                          buildCounter: (_,
                                  {required currentLength,
                                  required isFocused,
                                  maxLength}) =>
                              null,
                          cursorColor: FblaColors.secondary,
                          style: FblaFonts.body(fontSize: 14).copyWith(
                            height: 1.45,
                            color: FblaColors.darkTextPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Write a caption…',
                            hintStyle: FblaFonts.body(fontSize: 14).copyWith(
                              color: FblaColors.darkTextTertiary,
                            ),
                            isDense: true,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const _IgDivider(),

              // Add location
              _AccessoryRow(
                leading: Icon(
                  Icons.location_on_outlined,
                  color: FblaColors.darkTextPrimary,
                ),
                child: Semantics(
                  label: 'Post location',
                  textField: true,
                  child: TextField(
                    controller: widget.locationCtrl,
                    cursorColor: FblaColors.secondary,
                    style: FblaFonts.body(fontSize: 14).copyWith(
                      color: FblaColors.darkTextPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Add location',
                      hintStyle: FblaFonts.body(fontSize: 14).copyWith(
                        color: FblaColors.darkTextSecond,
                      ),
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
              const _IgDivider(),

              // Tag people (placeholder — opens chapter directory in v2)
              _AccessoryRow(
                leading: Icon(
                  Icons.person_add_alt_1_outlined,
                  color: FblaColors.darkTextPrimary,
                ),
                child: Text(
                  'Tag people',
                  style: FblaFonts.body(fontSize: 14).copyWith(
                    color: FblaColors.darkTextPrimary,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: FblaColors.darkTextSecond,
                ),
                onTap: () {
                  HapticFeedback.selectionClick();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Member tagging is coming soon.',
                        style: TextStyle(fontFamily: 'Mulish'),
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              const _IgDivider(),

              // Visibility — fixed to chapter (info row)
              _AccessoryRow(
                leading: Icon(
                  Icons.groups_2_outlined,
                  color: FblaColors.darkTextPrimary,
                ),
                child: RichText(
                  text: TextSpan(
                    style: FblaFonts.body(fontSize: 14).copyWith(
                      color: FblaColors.darkTextPrimary,
                    ),
                    children: [
                      const TextSpan(text: 'Posting to '),
                      TextSpan(
                        text: widget.chapterName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
              const _IgDivider(),

              // Advanced settings (expandable)
              _AdvancedSettings(
                hideLikeCount: widget.hideLikeCount,
                disableComments: widget.disableComments,
                onToggleHideLikes: widget.onToggleHideLikes,
                onToggleDisableComments: widget.onToggleDisableComments,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AdvancedSettings extends StatefulWidget {
  const _AdvancedSettings({
    required this.hideLikeCount,
    required this.disableComments,
    required this.onToggleHideLikes,
    required this.onToggleDisableComments,
  });

  final bool hideLikeCount;
  final bool disableComments;
  final ValueChanged<bool> onToggleHideLikes;
  final ValueChanged<bool> onToggleDisableComments;

  @override
  State<_AdvancedSettings> createState() => _AdvancedSettingsState();
}

class _AdvancedSettingsState extends State<_AdvancedSettings> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AccessoryRow(
          leading: Icon(
            Icons.tune_rounded,
            color: FblaColors.darkTextPrimary,
          ),
          child: Text(
            'Advanced settings',
            style: FblaFonts.body(fontSize: 14).copyWith(
              color: FblaColors.darkTextPrimary,
            ),
          ),
          trailing: AnimatedRotation(
            turns: _expanded ? 0.5 : 0,
            duration: FblaMotion.standard,
            curve: FblaMotion.strongEaseOut,
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: FblaColors.darkTextSecond,
            ),
          ),
          onTap: () => setState(() => _expanded = !_expanded),
        ),
        AnimatedSize(
          duration: FblaMotion.standard,
          curve: FblaMotion.strongEaseOut,
          child: _expanded
              ? Column(
                  children: [
                    const _IgDivider(),
                    _ToggleRow(
                      label: 'Hide like count',
                      sublabel:
                          'Only you will see the total number of likes on this post.',
                      value: widget.hideLikeCount,
                      onChanged: widget.onToggleHideLikes,
                    ),
                    const _IgDivider(),
                    _ToggleRow(
                      label: 'Turn off commenting',
                      sublabel:
                          'You can change this in post settings later.',
                      value: widget.disableComments,
                      onChanged: widget.onToggleDisableComments,
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.sublabel,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final String sublabel;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: FblaFonts.body(fontSize: 14).copyWith(
                    color: FblaColors.darkTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sublabel,
                  style: FblaFonts.body(fontSize: 12).copyWith(
                    color: FblaColors.darkTextSecond,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch.adaptive(
            value: value,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              onChanged(v);
            },
            activeColor: FblaColors.onSecondary,
            activeTrackColor: FblaColors.secondary,
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SHARED CHROME — Instagram-style top bar, accessory rows, divider, pills
// ═════════════════════════════════════════════════════════════════════════════

class _IgTopBar extends StatelessWidget {
  const _IgTopBar({
    required this.leading,
    required this.title,
    required this.trailing,
  });
  final Widget leading;
  final String title;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: FblaColors.darkBg,
        border: Border(
          bottom: BorderSide(color: FblaColors.darkOutlineVar, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          SizedBox(width: 44, child: leading),
          Expanded(
            child: Center(
              child: Text(
                title,
                style: FblaFonts.heading(fontSize: 16).copyWith(
                  color: FblaColors.darkTextPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(child: trailing),
        ],
      ),
    );
  }
}

class _IgIconButton extends StatelessWidget {
  const _IgIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final label = tooltip ?? _defaultTooltipFor(icon);
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: FblaColors.darkTextPrimary, size: 24),
      splashRadius: 22,
      tooltip: label,
    );
  }

  static String _defaultTooltipFor(IconData icon) {
    if (icon == Icons.close_rounded) return 'Close';
    if (icon == Icons.arrow_back_rounded) return 'Back';
    return 'Action';
  }
}

class _IgNextButton extends StatelessWidget {
  const _IgNextButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: FblaMotion.standard,
      opacity: enabled ? 1 : 0.45,
      child: TextButton(
        onPressed: enabled ? onTap : null,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          label,
          style: FblaFonts.label().copyWith(
            color: FblaColors.secondary,
            fontWeight: FontWeight.w700,
            fontSize: 14,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

class _IconActionPill extends StatelessWidget {
  const _IconActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: FblaColors.darkSurfaceHigh,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: FblaColors.darkTextPrimary, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: FblaFonts.label().copyWith(
                color: FblaColors.darkTextPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IgDivider extends StatelessWidget {
  const _IgDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 0.5,
      color: FblaColors.darkOutlineVar,
      margin: const EdgeInsets.symmetric(horizontal: 16),
    );
  }
}

class _AccessoryRow extends StatelessWidget {
  const _AccessoryRow({
    required this.leading,
    required this.child,
    this.trailing,
    this.onTap,
  });
  final Widget leading;
  final Widget child;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          IconTheme(
            data: const IconThemeData(size: 22),
            child: leading,
          ),
          const SizedBox(width: 14),
          Expanded(child: child),
          if (trailing != null) trailing!,
        ],
      ),
    );

    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      child: row,
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// FILTERS — ColorMatrix presets that approximate Instagram's named filters
// ═════════════════════════════════════════════════════════════════════════════

enum _Filter {
  original,
  clarendon,
  gingham,
  moon,
  lark,
  reyes,
  juno,
  slumber,
  crema,
  ludwig,
  aden,
  perpetua,
}

extension _FilterExt on _Filter {
  String get label {
    switch (this) {
      case _Filter.original:
        return 'Original';
      case _Filter.clarendon:
        return 'Clarendon';
      case _Filter.gingham:
        return 'Gingham';
      case _Filter.moon:
        return 'Moon';
      case _Filter.lark:
        return 'Lark';
      case _Filter.reyes:
        return 'Reyes';
      case _Filter.juno:
        return 'Juno';
      case _Filter.slumber:
        return 'Slumber';
      case _Filter.crema:
        return 'Crema';
      case _Filter.ludwig:
        return 'Ludwig';
      case _Filter.aden:
        return 'Aden';
      case _Filter.perpetua:
        return 'Perpetua';
    }
  }

  /// 4×5 color matrix applied via ColorFiltered.  These are tuned by hand to
  /// mimic the look of the named Instagram filter without third-party deps.
  ColorFilter get matrixFilter => ColorFilter.matrix(_matrix);

  List<double> get _matrix {
    switch (this) {
      case _Filter.original:
        return const [
          1, 0, 0, 0, 0,
          0, 1, 0, 0, 0,
          0, 0, 1, 0, 0,
          0, 0, 0, 1, 0,
        ];
      case _Filter.clarendon:
        return const [
          1.20, 0, 0, 0, -10,
          0, 1.15, 0, 0, -5,
          0, 0, 1.25, 0, -10,
          0, 0, 0, 1, 0,
        ];
      case _Filter.gingham:
        return const [
          0.95, 0.05, 0.05, 0, 8,
          0.05, 0.95, 0.05, 0, 8,
          0.05, 0.05, 0.95, 0, 8,
          0, 0, 0, 1, 0,
        ];
      case _Filter.moon:
        // Black & white with slight contrast lift.
        return const [
          0.33, 0.33, 0.33, 0, 0,
          0.33, 0.33, 0.33, 0, 0,
          0.33, 0.33, 0.33, 0, 0,
          0, 0, 0, 1, 0,
        ];
      case _Filter.lark:
        return const [
          1.10, 0, 0, 0, 0,
          0, 1.05, 0, 0, 5,
          0, 0, 0.95, 0, 0,
          0, 0, 0, 1, 0,
        ];
      case _Filter.reyes:
        return const [
          1.05, 0.05, 0, 0, 15,
          0.05, 1.00, 0, 0, 10,
          0, 0, 0.85, 0, 5,
          0, 0, 0, 1, 0,
        ];
      case _Filter.juno:
        return const [
          1.15, 0, 0, 0, -5,
          0, 1.10, 0, 0, 0,
          0, 0, 1.10, 0, -5,
          0, 0, 0, 1, 0,
        ];
      case _Filter.slumber:
        return const [
          0.95, 0, 0, 0, 10,
          0, 0.90, 0, 0, 5,
          0, 0, 0.90, 0, 0,
          0, 0, 0, 1, 0,
        ];
      case _Filter.crema:
        return const [
          1.02, 0.04, 0, 0, 8,
          0.02, 1.00, 0, 0, 8,
          0, 0, 0.95, 0, 5,
          0, 0, 0, 1, 0,
        ];
      case _Filter.ludwig:
        return const [
          1.10, 0.05, 0, 0, -5,
          0, 1.05, 0, 0, -2,
          0, 0, 1.00, 0, 0,
          0, 0, 0, 1, 0,
        ];
      case _Filter.aden:
        return const [
          0.85, 0.05, 0.05, 0, 10,
          0.05, 0.95, 0, 0, 10,
          0.05, 0.05, 0.90, 0, 15,
          0, 0, 0, 1, 0,
        ];
      case _Filter.perpetua:
        return const [
          1.00, 0, 0, 0, 0,
          0.05, 1.05, 0.05, 0, 0,
          0.05, 0.10, 1.05, 0, 0,
          0, 0, 0, 1, 0,
        ];
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _XFileImage — cross-platform image preview for an `XFile` from image_picker.
//
// `Image.file(File(xfile.path))` crashes on Flutter web because dart:io's File
// is a stub in the browser and the underlying file reader never fires — the
// runtime throws "Image.file is not supported on Flutter web" as soon as the
// image provider tries to resolve.
//
// The fix is platform-aware:
//   • Native (iOS / Android / macOS / Windows / Linux) → Image.file(File(path))
//   • Web                                              → Image.network(path)
//
// On web, image_picker returns an `XFile` whose `.path` is a `blob:` URL that
// the browser can render directly via `<img src>` — which is exactly what
// Image.network does under the hood. Works for the preview on the pick screen,
// the filter carousel, the filtered preview, and the compose-stage thumbnail.
// ─────────────────────────────────────────────────────────────────────────────
class _XFileImage extends StatelessWidget {
  const _XFileImage({
    super.key,
    required this.xfile,
    this.fit,
    this.semanticLabel,
    this.excludeFromSemantics = false,
  });

  final XFile xfile;
  final BoxFit? fit;
  final String? semanticLabel;
  final bool excludeFromSemantics;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      // On web, xfile.path is a blob: URL that <img> can render directly.
      return Image.network(
        xfile.path,
        fit: fit,
        semanticLabel: semanticLabel,
        excludeFromSemantics: excludeFromSemantics,
      );
    }
    return Image.file(
      File(xfile.path),
      fit: fit,
      semanticLabel: semanticLabel,
      excludeFromSemantics: excludeFromSemantics,
    );
  }
}
