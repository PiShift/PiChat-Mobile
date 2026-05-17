import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pichat/core/theme/app_colors.dart';
import 'package:pichat/core/theme/app_sizing.dart';
import 'package:pichat/data/models/chat_media_model.dart';
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

    // Priority: 1) Riverpod download state, 2) passed localFilePath, 3) DB location flag, 4) non-http path
    final resolvedLocal = playbackState.localPath ?? localFilePath ?? localFromDb ?? localFromPath;

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
        _buildPlaceholder(context, isLoading: playbackState.isDownloading),
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
        if (!playbackState.isDownloading && !playbackState.isDownloaded)
          GestureDetector(
            onTap: () => _downloadFromMeta(ref),
            child: _downloadOverlay(isLoading: false),
          ),
      ],
    );
  }

  Widget _downloadOverlay({required bool isLoading}) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(
        color: Colors.black54,
        shape: BoxShape.circle,
      ),
      child: isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Icon(LucideIcons.download, color: Colors.white, size: 24),
    );
  }

  Widget _buildPlaceholder(BuildContext context, {required bool isLoading}) {
    return SizedBox(
      width: double.infinity,
      height: ChatMessageItem.mediaMaxHeight,
      child: Center(
        child: isLoading
            ? const CircularProgressIndicator(strokeWidth: 2)
            : Icon(LucideIcons.image, size: 48, color: PiColors.of(context).ink400),
      ),
    );
  }

  /// Download via stored meta_url; falls back to Meta API if url unavailable
  Future<void> _downloadFromMeta(WidgetRef ref) async {
    await ref
        .read(mediaPlaybackProvider(mediaId).notifier)
        .downloadMedia(contactId, media.type ?? 'image/jpeg', metaUrl: media.metaUrl, metaId: metaId);
  }

  void _showFullScreenImage(BuildContext context, String? resolvedLocal) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              child: resolvedLocal != null
                  ? Image.file(File(resolvedLocal), fit: BoxFit.contain)
                  : media.path != null
                      ? Image.network(media.path!, fit: BoxFit.contain)
                      : _buildPlaceholder(context, isLoading: false),
            ),
          ),
        ),
      ),
    );
  }
}
