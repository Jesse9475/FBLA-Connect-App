import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart' as share_plus;
import 'package:url_launcher/url_launcher.dart';

import 'api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Share Service
//
//   shareToXText(text)       → Opens X directly via URL intent (no share sheet)
//   shareWithImage(text, path) → iOS share sheet with image attached
//   shareText(text)          → iOS share sheet with text (Web Share API equiv.)
//   downloadImageToTemp(url) → Downloads a URL to a temp file, returns path
// ─────────────────────────────────────────────────────────────────────────────

enum ShareContentType { post, event, announcement }

class ShareResult {
  ShareResult.ok({this.message})
      : success = true,
        canceled = false;
  ShareResult.canceled()
      : success = false,
        canceled = true,
        message = null;
  ShareResult.failed(this.message)
      : success = false,
        canceled = false;

  final bool success;
  final bool canceled;
  final String? message;
}

class ShareService {
  ShareService._();
  static final instance = ShareService._();

  final _api = ApiService.instance;

  // ── 1. X text-only ───────────────────────────────────────────────────────
  //
  // url_launcher → twitter.com/intent/tweet → opens X app directly.
  // No share_plus involved at all.

  Future<ShareResult> shareToXText({required String text}) async {
    final encoded = Uri.encodeComponent(text);

    // Try twitter.com intent (Universal Links → X app)
    try {
      final ok = await launchUrl(
        Uri.parse('https://twitter.com/intent/tweet?text=$encoded'),
        mode: LaunchMode.externalApplication,
      );
      if (ok) return ShareResult.ok();
    } catch (e) {
      debugPrint('twitter.com intent: $e');
    }

    // Fallback: x.com intent
    try {
      final ok = await launchUrl(
        Uri.parse('https://x.com/intent/post?text=$encoded'),
        mode: LaunchMode.externalApplication,
      );
      if (ok) return ShareResult.ok();
    } catch (e) {
      debugPrint('x.com intent: $e');
    }

    // Last resort: clipboard
    await Clipboard.setData(ClipboardData(text: text));
    return ShareResult.ok(message: 'Copied to clipboard — paste it in X');
  }

  // ── 2. Share with image (iOS share sheet) ────────────────────────────────
  //
  // Opens UIActivityViewController with the image file + text.
  // User picks X, Messages, AirDrop, etc. Image ACTUALLY attaches.
  // This is the only way iOS allows sharing an image to X.

  Future<ShareResult> shareWithImage({
    required String text,
    required String imagePath,
  }) async {
    try {
      // Determine mime type from extension
      final mime = imagePath.toLowerCase().endsWith('.png')
          ? 'image/png'
          : 'image/jpeg';

      final result = await share_plus.Share.shareXFiles(
        [share_plus.XFile(imagePath, mimeType: mime)],
        text: text,
      );
      if (result.status == share_plus.ShareResultStatus.dismissed) {
        return ShareResult.canceled();
      }
      return ShareResult.ok();
    } catch (e) {
      debugPrint('shareWithImage failed: $e');
      await Clipboard.setData(ClipboardData(text: text));
      return ShareResult.ok(message: 'Share failed — text copied');
    }
  }

  // ── 3. Share text (iOS share sheet / Web Share API equivalent) ───────────
  //
  // Opens UIActivityViewController with just text.
  // This IS the iOS equivalent of the Web Share API (navigator.share).
  // Standard bottom popup: AirDrop, Messages, X, Copy, etc.

  Future<ShareResult> shareText({required String text}) async {
    try {
      await share_plus.Share.share(text);
      return ShareResult.ok();
    } catch (e) {
      debugPrint('shareText failed: $e');
      await Clipboard.setData(ClipboardData(text: text));
      return ShareResult.ok(message: 'Share failed — text copied');
    }
  }

  // ── Download image URL to temp file ──────────────────────────────────────
  //
  // Downloads a network image (e.g. the post's media_url from Supabase
  // storage) to a local temp file so it can be passed to shareWithImage.

  Future<String?> downloadImageToTemp(String imageUrl) async {
    try {
      final httpClient = HttpClient();
      final request = await httpClient.getUrl(Uri.parse(imageUrl));
      final response = await request.close();

      if (response.statusCode != 200) {
        debugPrint('downloadImageToTemp: HTTP ${response.statusCode}');
        return null;
      }

      final bytes = await consolidateHttpClientResponseBytes(response);
      if (bytes.isEmpty) {
        debugPrint('downloadImageToTemp: empty response');
        return null;
      }

      // Determine extension from URL or content type
      final ext = imageUrl.toLowerCase().contains('.png') ? 'png' : 'jpg';

      Directory dir;
      try {
        dir = await getTemporaryDirectory();
      } catch (_) {
        dir = await getApplicationDocumentsDirectory();
      }

      final ts = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}${Platform.pathSeparator}fbla_share_$ts.$ext');
      await file.writeAsBytes(bytes, flush: true);

      if (await file.exists() && await file.length() > 0) {
        return file.path;
      }
      return null;
    } catch (e, st) {
      debugPrint('downloadImageToTemp failed: $e\n$st');
      return null;
    }
  }

  // ── Generate Share Text ───────────────────────────────────────────────────

  String generateShareText({
    required ShareContentType type,
    required Map<String, dynamic> content,
  }) {
    switch (type) {
      case ShareContentType.post:
        final caption = (content['caption'] as String? ?? '').trim();
        final preview = caption.length > 140
            ? '${caption.substring(0, 140)}\u2026'
            : caption;
        return preview.isEmpty
            ? 'Check out this post on FBLA Connect.'
            : '"$preview" \u2014 via FBLA Connect';

      case ShareContentType.event:
        final title = content['title'] as String? ?? 'Event';
        final location = content['location'] as String? ?? '';
        final startAt = content['start_at'] as String? ?? '';
        return '\ud83d\udcc5 $title'
            '${location.isNotEmpty ? ' at $location' : ''}'
            '${startAt.isNotEmpty ? ' \u2014 $startAt' : ''}'
            '. Join us! \u2014 via FBLA Connect';

      case ShareContentType.announcement:
        final title = content['title'] as String? ?? '';
        final body = (content['body'] as String? ?? '').trim();
        final preview = body.length > 140
            ? '${body.substring(0, 140)}\u2026'
            : body;
        return '\ud83d\udce2 $title: $preview \u2014 via FBLA Connect';
    }
  }

  // ── Track Share in Backend ────────────────────────────────────────────────

  Future<void> trackShare({
    required ShareContentType type,
    required String contentId,
    required String platform,
  }) async {
    if (contentId.isEmpty) return;
    try {
      final endpoint = switch (type) {
        ShareContentType.post => '/posts/$contentId/share',
        ShareContentType.event => '/events/$contentId/share',
        ShareContentType.announcement => '/announcements/$contentId/share',
      };
      await _api.post(
        endpoint,
        body: {'platform': platform},
        parser: (data) => data,
      );
    } catch (e) {
      debugPrint('Share tracking failed: $e');
    }
  }

  // ── Capture Widget as Image ───────────────────────────────────────────────

  Future<Uint8List?> captureWidgetToImage(
    GlobalKey repaintKey, {
    double pixelRatio = 3.0,
  }) async {
    try {
      final boundary = repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Widget capture failed: $e');
      return null;
    }
  }
}
