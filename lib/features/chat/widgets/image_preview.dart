import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pichat/core/theme/app_colors.dart';
import 'package:pichat/core/theme/app_sizing.dart';
import 'package:pichat/data/models/chat_media_model.dart';
import 'package:pichat/features/chat/application/local_media_manager.dart';
import 'package:pichat/features/chat/presentation/image_viewer_screen.dart';
import 'package:pichat/features/chat/application/media_providers.dart';

import 'chat_item.dart';

class ImagePreview extends ConsumerWidget {
  final ChatMedia media;
  final String mediaId;
  final String contactId;
  final String? metaId;
  /// Local file path to use immediately (pending/sent outbound or already downloaded)
  final String? localFilePath;

  /// Stickers come down the same image pipeline but are not photos: they are
  /// small, usually transparent WebP art. Cropping one to the photo frame
  /// blew it up and cut its edges off, so sticker mode renders it uncropped
  /// at a fixed square and skips the full-screen viewer.
  final bool isSticker;

  const ImagePreview({
    required this.media,
    required this.mediaId,
    required this.contactId,
    this.metaId,
    this.localFilePath,
    this.isSticker = false,
    super.key,
  });

  /// Matches WhatsApp's sticker bubble.
  static const double stickerSize = 160.0;

  double get _width => isSticker ? stickerSize : double.infinity;
  double get _height =>
      isSticker ? stickerSize : ChatMessageItem.mediaMaxHeight;
  BoxFit get _fit => isSticker ? BoxFit.contain : BoxFit.cover;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playbackState = ref.watch(mediaPlaybackProvider(mediaId));

    // If the DB says this file was already downloaded (location == 'local'), use the stored path.
    // This survives app restarts where Riverpod state is reset to defaults.
    final localFromDb = media.location == 'local' ? media.path : null;

    // Also treat any non-http path as a local file (e.g. outbound images stored at /path/to/file)
    final pathIsLocal = media.path != null &&
        media.path!.isNotEmpty &&
        !media.path!.startsWith('http');
    final localFromPath = pathIsLocal ? media.path : null;

    // Priority: 1) Riverpod download state, 2) passed localFilePath, 3) DB
    // location flag, 4) non-http path.
    //
    // Re-anchored to the current app container: stored paths are relative, and
    // an absolute one written by an earlier install points nowhere. Without
    // this the file looked missing, Image.file failed into the download prompt,
    // and every image asked to be downloaded again after an app update.
    final resolvedLocal = LocalMediaManager.resolve(
      playbackState.localPath ?? localFilePath ?? localFromDb ?? localFromPath,
    );

    // When we have a local file, wrap in full-screen tap gesture
    if (resolvedLocal != null) {
      final image = Image.file(
        File(resolvedLocal),
        width: _width,
        height: _height,
        fit: _fit,
        errorBuilder: (_, __, ___) => _buildNetworkOrDownload(context, ref, playbackState),
      );

      if (isSticker) return image;

      return GestureDetector(
        onTap: () => _showFullScreenImage(context, resolvedLocal),
        child: image,
      );
    }

    // Nothing on disk. A sticker fetches itself rather than making the user
    // tap a button for a few dozen KB. Provider state cannot be written during
    // build, so the request goes out after this frame; `autoDownload` is
    // single-shot, which makes the repeated post-frame calls from rebuilds and
    // scrolling harmless.
    if (isSticker && !_hasRemotePath) {
      // The notifier is resolved here, during build, rather than inside the
      // callback: `ref` belongs to this widget and throws once it is disposed,
      // which is what a sticker scrolled off-screen before the frame ends
      // would do. The notifier outlives the bubble, so it is safe to call late.
      final notifier = ref.read(mediaPlaybackProvider(mediaId).notifier);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifier.autoDownload(
          contactId,
          media.type ?? 'image/webp',
          metaUrl: media.metaUrl,
          metaId: metaId,
        );
      });
    }

    // No local file — show network image or download prompt (no full-screen wrapper that would eat taps)
    return _buildNetworkOrDownload(context, ref, playbackState);
  }

  /// True when the media row already carries a URL we can render directly,
  /// so nothing needs downloading from Meta.
  bool get _hasRemotePath =>
      media.path != null &&
      media.path!.isNotEmpty &&
      media.path!.startsWith('http');

  Widget _buildNetworkOrDownload(BuildContext context, WidgetRef ref, MediaPlaybackState playbackState) {
    // Has a server/storage URL — just display it. No download button needed; image is already accessible.
    if (_hasRemotePath) {
      final image = Image.network(
        media.path!,
        width: _width,
        height: _height,
        fit: _fit,
        loadingBuilder: (ctx, child, progress) =>
            progress == null ? child : _buildPlaceholder(ctx, isLoading: true),
        errorBuilder: (ctx, __, ___) => _buildPlaceholder(ctx, isLoading: false),
      );

      if (isSticker) return image;

      return GestureDetector(
        onTap: () => _showFullScreenImage(context, null),
        child: image,
      );
    }

    // No server path yet — show placeholder with a download button
    final failed = playbackState.error != null;

    // A photo waits for the user to ask. A sticker is already fetching itself,
    // so its button means "that failed, try again" and only earns its place
    // once something has actually gone wrong.
    final showButton = isSticker
        ? failed
        : !playbackState.isDownloading && !playbackState.isDownloaded;
    final showSpinner = playbackState.isDownloading ||
        (isSticker && !failed && !playbackState.isDownloaded);

    return Stack(
      alignment: Alignment.center,
      children: [
        _buildPlaceholder(context, isLoading: false),
        // The raw exception text is too long for a 160px sticker box; there the
        // retry button carries the message on its own.
        if (failed && !isSticker)
          Positioned(
            bottom: 4,
            child: Text(
              playbackState.error!,
              style: GoogleFonts.plusJakartaSans(
                color: PiColors.of(context).error,
                fontSize: Sz.sp(context, 10),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        if (showSpinner)
          _downloadOverlay(isLoading: true, progress: playbackState.progress),
        if (showButton)
          GestureDetector(
            onTap: () => _downloadFromMeta(ref),
            child: _downloadOverlay(isLoading: false, isRetry: isSticker),
          ),
      ],
    );
  }

  Widget _downloadOverlay({
    required bool isLoading,
    double? progress,
    bool isRetry = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(
        color: Colors.black54,
        shape: BoxShape.circle,
      ),
      child: isLoading
          ? SizedBox(
              width: 24,
              height: 24,
              // A determinate ring once the download reports progress, so a
              // large photo on a slow connection shows movement instead of a
              // spinner that says nothing.
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
                value: (progress != null && progress > 0 && progress < 1)
                    ? progress
                    : null,
              ),
            )
          : Icon(
              isRetry ? LucideIcons.refreshCw : LucideIcons.download,
              color: Colors.white,
              size: 24,
            ),
    );
  }

  Widget _buildPlaceholder(BuildContext context, {required bool isLoading}) {
    final colors = PiColors.of(context);

    return SizedBox(
      width: _width,
      height: _height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // A tinted ground rather than a bare icon, matching the video and
          // document cards.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colors.surfaceRaised, colors.surface],
              ),
            ),
          ),
          Center(
            child: Icon(
              isSticker ? LucideIcons.smile : LucideIcons.image,
              size: 40,
              color: colors.ink400.withValues(alpha: 0.45),
            ),
          ),
          if (_sizeLabel != null)
            Positioned(
              left: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.image, size: 11, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      _sizeLabel!,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Size matters before downloading on mobile data, so it is shown up front.
  String? get _sizeLabel {
    final bytes = int.tryParse(media.size ?? '');

    if (bytes == null || bytes <= 0) return null;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';

    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Download via stored meta_url; falls back to Meta API if url unavailable
  Future<void> _downloadFromMeta(WidgetRef ref) async {
    await ref
        .read(mediaPlaybackProvider(mediaId).notifier)
        .downloadMedia(
          contactId,
          media.type ?? (isSticker ? 'image/webp' : 'image/jpeg'),
          metaUrl: media.metaUrl,
          metaId: metaId,
        );
  }

  void _showFullScreenImage(BuildContext context, String? resolvedLocal) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ImageViewerScreen(
          path: resolvedLocal,
          networkUrl: media.path != null && media.path!.startsWith('http')
              ? media.path
              : null,
          title: media.name,
        ),
      ),
    );
  }
}
