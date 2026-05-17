  import 'package:flutter/material.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'package:google_fonts/google_fonts.dart';
  import 'package:lucide_icons_flutter/lucide_icons.dart';
  import 'package:pichat/core/theme/app_colors.dart';
  import 'package:pichat/core/theme/app_radius.dart';
  import 'package:pichat/core/theme/app_sizing.dart';
  import 'package:pichat/data/models/chat_media_model.dart';
  import 'package:pichat/features/chat/application/media_providers.dart';
  import 'package:open_file/open_file.dart';
  import 'package:url_launcher/url_launcher.dart';

  class DocumentPreview extends ConsumerWidget {
    final ChatMedia media;
    final String mediaId;
    final String mediaType;
    final String contactId;
    final String? metaId;

    const DocumentPreview({
      required this.media,
      required this.mediaId,
      required this.mediaType,
      required this.contactId,
      this.metaId,
      Key? key,
    }) : super(key: key);

    String _formatFileSize(int? bytes) {
      if (bytes == null) return '';
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }

    IconData _getIconForMediaType() {
      switch (mediaType.toLowerCase()) {
        case 'pdf':
          return LucideIcons.fileText;
        case 'doc':
        case 'docx':
          return LucideIcons.fileText;
        case 'video':
          return LucideIcons.video;
        case 'audio':
          return LucideIcons.mic;
        default:
          return LucideIcons.file;
      }
    }

    @override
    Widget build(BuildContext context, WidgetRef ref) {
      final mediaState = ref.watch(mediaPlaybackProvider(mediaId));

    // Derive effective downloaded state from DB model (survives app restarts).
    final isAlreadyDownloaded = mediaState.isDownloaded || media.location == 'local';
    final effectiveLocalPath = mediaState.localPath ?? (media.location == 'local' ? media.path : null);

      return Container(
        padding: const EdgeInsets.all(12),
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_getIconForMediaType(), size: 36, color: PiColors.of(context).primary500),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        media.name ?? 'Document',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w600,
                          fontSize: Sz.sp(context, 13),
                          color: PiColors.of(context).textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatFileSize(int.tryParse(media.size ?? '') ?? 0),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: Sz.sp(context, 12),
                          color: PiColors.of(context).textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (mediaState.isDownloading)
              LinearProgressIndicator(value: mediaState.progress),
            if (mediaState.error != null)
              Text(
                'Error: ${mediaState.error}',
                style: GoogleFonts.plusJakartaSans(
                  color: PiColors.of(context).error,
                  fontSize: Sz.sp(context, 12),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!isAlreadyDownloaded && !mediaState.isDownloading)
                  GestureDetector(
                    onTap: () {
                      ref
                          .read(mediaPlaybackProvider(mediaId).notifier)
                          .downloadMedia(contactId, mediaType, metaUrl: media.metaUrl, metaId: metaId);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: PiColors.of(context).primary500,
                        borderRadius: BorderRadius.circular(PiRadius.full),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.download, size: 16, color: PiPalette.white),
                          const SizedBox(width: 6),
                          Text(
                            'Download',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: Sz.sp(context, 13),
                              fontWeight: FontWeight.w600,
                              color: PiPalette.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (isAlreadyDownloaded)
                  GestureDetector(
                    onTap: () async {
                      if (effectiveLocalPath != null) {
                        final result = await OpenFile.open(effectiveLocalPath);
                        if (result.type != ResultType.done &&
                            media.metaUrl != null) {
                          final uri = Uri.tryParse(media.metaUrl!);
                          if (uri != null) {
                            await launchUrl(uri,
                                mode: LaunchMode.externalApplication);
                          }
                        }
                      } else if (media.metaUrl != null) {
                        final uri = Uri.tryParse(media.metaUrl!);
                        if (uri != null) {
                          await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: PiPalette.success500,
                        borderRadius: BorderRadius.circular(PiRadius.full),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.externalLink, size: 16, color: PiPalette.white),
                          const SizedBox(width: 6),
                          Text(
                            'Open',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: Sz.sp(context, 13),
                              fontWeight: FontWeight.w600,
                              color: PiPalette.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    }
  }