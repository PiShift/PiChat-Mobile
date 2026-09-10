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

  const ImagePreview({
    required this.media,
    required this.mediaId,
    required this.contactId,
    this.metaId,
    this.localFilePath,
    super.key,
  });

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
      return GestureDetector(
        onTap: () => _showFullScreenImage(context, resolvedLocal),
        child: Image.file(
          File(resolvedLocal),
          width: double.infinity,
          height: ChatMessageItem.mediaMaxHeight,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildNetworkOrDownload(context, ref, playbackState),
        ),
      );
    }

    // No local file — show network image or download prompt (no full-screen wrapper that would eat taps)
    return _buildNetworkOrDownload(context, ref, playbackState);
  }

  Widget _buildNetworkOrDownload(BuildContext context, WidgetRef ref, MediaPlaybackState playbackState) {
    // Has a server/storage URL — just display it. No download button needed; image is already accessible.
    if (media.path != null && media.path!.isNotEmpty && media.path!.startsWith('http')) {
      return GestureDetector(
        onTap: () => _showFullScreenImage(context, null),
        child: Image.network(
          media.path!,
          width: double.infinity,
          height: ChatMessageItem.mediaMaxHeight,
          fit: BoxFit.cover,
          loadingBuilder: (ctx, child, progress) =>
              progress == null ? child : _buildPlaceholder(ctx, isLoading: true),
          errorBuilder: (ctx, __, ___) => _buildPlaceholder(ctx, isLoading: false),
        ),
      );
    }

    // No server path yet — show placeholder with a download button
    return Stack(
      alignment: Alignment.center,
      children: [
        _buildPlaceholder(context, isLoading: false),
        if (playbackState.error != null)
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
        if (playbackState.isDownloading)
          _downloadOverlay(isLoading: true, progress: playbackState.progress),
        if (!playbackState.isDownloading && !playbackState.isDownloaded)
          GestureDetector(
            onTap: () => _downloadFromMeta(ref),
            child: _downloadOverlay(isLoading: false),
          ),
      ],
    );
  }

  Widget _downloadOverlay({required bool isLoading, double? progress}) {
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
          : const Icon(LucideIcons.download, color: Colors.white, size: 24),
    );
  }

  Widget _buildPlaceholder(BuildContext context, {required bool isLoading}) {
    final colors = PiColors.of(context);

    return SizedBox(
      width: double.infinity,
      height: ChatMessageItem.mediaMaxHeight,
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
              LucideIcons.image,
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
        .downloadMedia(contactId, media.type ?? 'image/jpeg', metaUrl: media.metaUrl, metaId: metaId);
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
