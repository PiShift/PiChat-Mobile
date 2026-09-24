import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pichat/core/theme/app_colors.dart';
import 'package:pichat/core/theme/app_radius.dart';
import 'package:pichat/core/theme/app_sizing.dart';
import 'package:pichat/data/models/chat_media_model.dart';
import 'package:pichat/features/chat/application/local_media_manager.dart';
import 'package:pichat/features/chat/application/media_providers.dart';
import 'package:pichat/features/chat/presentation/docx_viewer_screen.dart';
import 'package:pichat/features/chat/presentation/pdf_viewer_screen.dart';
import 'package:pichat/features/chat/presentation/text_file_viewer_screen.dart';
import 'package:pichat/features/chat/widgets/pdf_first_page.dart';
import 'package:pichat/features/chat/widgets/file_type_badge.dart';
import 'package:open_file/open_file.dart';
import 'package:url_launcher/url_launcher.dart';

class DocumentPreview extends ConsumerWidget {
  final ChatMedia media;
  final String mediaId;
  final String mediaType;
  final String contactId;
  final String? metaId;

  /// The upload control of an outgoing document that is still sending or
  /// failed. Sits on the page preview of a PDF, in place of the type badge
  /// otherwise.
  final Widget? uploadControl;

  const DocumentPreview({
    required this.media,
    required this.mediaId,
    required this.mediaType,
    required this.contactId,
    this.metaId,
    this.uploadControl,
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

  bool get _isPdf =>
      mediaType.toLowerCase() == 'pdf' ||
      (media.name?.toLowerCase().endsWith('.pdf') ?? false);

  /// What to call the file in the info line. `mediaType` is the app's own
  /// bucket - everything non-media lands in "document" - so prefer the real
  /// extension when the filename carries one.
  String get _typeLabel {
    final name = media.name;

    if (name != null && name.contains('.')) {
      final ext = name.split('.').last.toLowerCase();

      if (ext.isNotEmpty && ext.length <= 5) return ext;
    }

    return mediaType.toLowerCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaState = ref.watch(mediaPlaybackProvider(mediaId));

    // Derive effective downloaded state from DB model (survives app restarts).
    final isAlreadyDownloaded =
        mediaState.isDownloaded || media.location == 'local';
    // Re-anchored: an absolute path stored by an earlier install points at a
    // container that no longer exists.
    final effectiveLocalPath = LocalMediaManager.resolve(
      mediaState.localPath ?? (media.location == 'local' ? media.path : null),
    );

    final colors = PiColors.of(context);
    final sizeLabel = _formatFileSize(int.tryParse(media.size ?? '') ?? 0);

    void download() {
      ref.read(mediaPlaybackProvider(mediaId).notifier).downloadMedia(
            contactId,
            mediaType,
            metaUrl: media.metaUrl,
            metaId: metaId,
            mimeType: media.type,
          );
    }

    Future<void> open() async {
      if (effectiveLocalPath == null) {
        if (media.path != null && media.path!.startsWith('http')) {
          await launchUrl(Uri.parse(media.path!),
              mode: LaunchMode.externalApplication);
        }

        return;
      }

      if (_isPdf) {
        final preview = await PdfFirstPageRenderer.render(effectiveLocalPath);
        final encrypted = preview?.needsPassword ?? false;

        // pdfx cannot open encrypted files on iOS, so those go to the system
        // viewer, which reads them without complaint.
        if (!encrypted && context.mounted) {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => PdfViewerScreen(
                path: effectiveLocalPath,
                title: media.name,
              ),
            ),
          );

          return;
        }
      }

      // Word documents render with their structure and formatting, in Dart, so
      // the result is identical on every platform.
      if ((media.name?.toLowerCase().endsWith('.docx') ?? false) &&
          context.mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => DocxViewerScreen(
              path: effectiveLocalPath,
              title: media.name,
            ),
          ),
        );

        return;
      }

      // JSON, CSV and friends have no preview handler on iOS, so tapping them
      // only ever produced a share sheet. Read them here instead.
      if (TextFileViewerScreen.handles(media.name) && context.mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => TextFileViewerScreen(
              path: effectiveLocalPath,
              title: media.name,
            ),
          ),
        );

        return;
      }

      final result = await OpenFile.open(effectiveLocalPath);

      // The result used to be discarded, so a type iOS cannot handle looked
      // like a dead tap rather than a missing app.
      if (result.type != ResultType.done && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.type == ResultType.noAppToOpen
                  ? 'No app on this device can open ${media.name ?? 'this file'}.'
                  : 'This file could not be opened.',
            ),
          ),
        );
      }
    }

    return GestureDetector(
      onTap: isAlreadyDownloaded ? open : download,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        // Fill the bubble: a fixed width left a bare strip down one side,
        // because the bubble itself is sized by its 75% maximum.
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isPdf)
              _buildPreviewArea(
                context,
                colors,
                isAlreadyDownloaded: isAlreadyDownloaded,
                isDownloading: mediaState.isDownloading,
                localPath: effectiveLocalPath,
                onDownload: download,
              ),
            _buildInfoRow(context, colors, sizeLabel, effectiveLocalPath),
            if (mediaState.error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                child: Text(
                  mediaState.error!,
                  style: GoogleFonts.plusJakartaSans(
                    color: colors.error,
                    fontSize: Sz.sp(context, 11),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// The page-one preview, or a placeholder standing in for it.
  Widget _buildPreviewArea(
    BuildContext context,
    PiColors colors, {
    required bool isAlreadyDownloaded,
    required bool isDownloading,
    required String? localPath,
    required VoidCallback onDownload,
  }) {
    return ClipRRect(
      borderRadius:
          const BorderRadius.vertical(top: Radius.circular(PiRadius.lg)),
      child: Container(
        // Trimmed from 150: the card was dominating the thread.
        height: 122,
        width: double.infinity,
        color: colors.surface,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (isAlreadyDownloaded && localPath != null)
              FutureBuilder<PdfFirstPage?>(
                future: PdfFirstPageRenderer.render(localPath),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return _buildPlaceholder(colors, shimmer: true);
                  }

                  final page = snapshot.data;

                  if (page == null) return _buildPlaceholder(colors);

                  if (page.needsPassword || page.image == null) {
                    return _buildLocked(colors);
                  }

                  return Image.memory(
                    page.image!,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  );
                },
              )
            else
              _buildPlaceholder(colors),

            if (uploadControl != null) Center(child: uploadControl),

            /*
               * Before the file is here there is nothing to preview: unlike the
               * WhatsApp client, which renders the thumbnail on the sender's
               * device and ships it with the message, the Cloud API gives us
               * only the file id. So the placeholder carries the download
               * affordance instead of a blurred page.
               */
            if (!isAlreadyDownloaded && uploadControl == null)
              Center(
                child: isDownloading
                    ? Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: colors.primary500,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(12),
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: PiPalette.white,
                        ),
                      )
                    : GestureDetector(
                        onTap: onDownload,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: colors.primary500,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: PiPalette.ink900.withValues(alpha: 0.18),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            LucideIcons.arrowDown,
                            size: 20,
                            color: PiPalette.white,
                          ),
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
  }

  /// Shown for an encrypted file, which pdfx cannot render on iOS. The document
  /// itself is usually perfectly readable - encryption here normally restricts
  /// printing and copying, not opening - so tapping hands it to the system
  /// viewer, which displays it without prompting for anything.
  Widget _buildLocked(PiColors colors) {
    return Container(
      color: colors.surface,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.lock, size: 24, color: colors.ink400),
          const SizedBox(height: 6),
          Text(
            'Preview unavailable',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Tap to open this document',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10.5,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// A neutral page-shaped stand-in for the real first page.
  Widget _buildPlaceholder(PiColors colors, {bool shimmer = false}) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colors.surfaceRaised,
            colors.surface,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          LucideIcons.fileText,
          size: 40,
          color: colors.ink400.withValues(alpha: shimmer ? 0.25 : 0.4),
        ),
      ),
    );
  }

  /// Filename and the "N pages • 168 KB • pdf" line beneath the preview.
  Widget _buildInfoRow(
    BuildContext context,
    PiColors colors,
    String sizeLabel,
    String? localPath,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      child: Row(
        children: [
          if (uploadControl != null && !_isPdf)
            SizedBox(width: 36, height: 36, child: uploadControl)
          else
            FileTypeBadge(extension: _typeLabel, size: 26),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  media.name ?? 'Document',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: Sz.sp(context, 13),
                    color: colors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                // The page count only becomes knowable once the file is here,
                // so it joins the line when the preview does.
                FutureBuilder<PdfFirstPage?>(
                  future: _isPdf && localPath != null
                      ? PdfFirstPageRenderer.render(localPath)
                      : Future.value(null),
                  builder: (context, snapshot) {
                    final pages = snapshot.data?.pageCount;
                    final parts = <String>[
                      if (pages != null)
                        '$pages ${pages == 1 ? 'page' : 'pages'}',
                      if (sizeLabel.isNotEmpty) sizeLabel,
                      _typeLabel,
                    ];

                    return Text(
                      parts.join(' • '),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: Sz.sp(context, 11),
                        color: colors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
