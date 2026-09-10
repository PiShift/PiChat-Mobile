import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pichat/core/theme/app_colors.dart';
import 'package:pichat/core/theme/app_radius.dart';
import 'package:pichat/data/models/chat_media_model.dart';
import 'package:pichat/features/chat/application/local_media_manager.dart';
import 'package:pichat/features/chat/application/media_providers.dart';
import 'package:pichat/features/chat/presentation/video_player_screen.dart';
import 'package:pichat/features/chat/widgets/video_thumbnail_cache.dart';

/// A video message: poster frame in the thread, full screen on tap.
///
/// Videos previously fell through to the generic document row, so an agent saw
/// a file name and a size with no way to tell what had been sent.
class VideoPreview extends ConsumerWidget {
  const VideoPreview({
    required this.media,
    required this.mediaId,
    required this.contactId,
    this.metaId,
    this.localFilePath,
    super.key,
  });

  final ChatMedia media;
  final String mediaId;
  final String contactId;
  final String? metaId;
  final String? localFilePath;

  String _formatSize(String? raw) {
    final bytes = int.tryParse(raw ?? '');

    if (bytes == null || bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';

    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(mediaPlaybackProvider(mediaId));
    final colors = PiColors.of(context);

    final localPath = LocalMediaManager.resolve(
      localFilePath ??
          playback.localPath ??
          (media.location == 'local' ? media.path : null),
    );
    final hasFile = localPath != null && File(localPath).existsSync();

    void download() {
      ref.read(mediaPlaybackProvider(mediaId).notifier).downloadMedia(
            contactId,
            'video',
            metaUrl: media.metaUrl,
            metaId: metaId,
            mimeType: media.type,
          );
    }

    void open() {
      if (!hasFile) return;

      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => VideoPlayerScreen(path: localPath, title: media.name),
        ),
      );
    }

    return GestureDetector(
      onTap: hasFile ? open : download,
      behavior: HitTestBehavior.opaque,
      /*
       * No ClipRRect here: the bubble already clips with its own asymmetric
       * corner radii, and rounding the video separately left a white notch in
       * the corner where the two shapes disagreed.
       */
      child: SizedBox(
          width: double.infinity,
          height: 168,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasFile)
                FutureBuilder<VideoPoster?>(
                  future: VideoPosterCache.load(localPath),
                  builder: (context, snapshot) {
                    final poster = snapshot.data;

                    if (poster == null) return _backdrop(colors);

                    return Image.memory(poster.image, fit: BoxFit.cover);
                  },
                )
              else
                _backdrop(colors),

              // A film-strip tint so a dark poster still reads as a video and
              // the controls stay legible over any frame.
              Container(
                  color: Colors.black.withValues(alpha: hasFile ? 0.18 : 0.0)),

              Center(
                child: playback.isDownloading
                    ? _circle(
                        colors,
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : _circle(
                        colors,
                        Icon(
                          hasFile ? LucideIcons.play : LucideIcons.arrowDown,
                          size: 22,
                          color: Colors.white,
                        ),
                      ),
              ),

              // Size sits bottom-left the way a duration would; the real
              // duration is only knowable once the file is on the device.
              if (_formatSize(media.size).isNotEmpty)
                Positioned(
                  left: 8,
                  bottom: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.video,
                            size: 11, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          _formatSize(media.size),
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
        ),
    );
  }

  Widget _circle(PiColors colors, Widget child) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: colors.primary500,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(child: child),
    );
  }

  /// Stand-in shown before the file is here, or if no frame can be extracted.
  Widget _backdrop(PiColors colors) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.surfaceRaised, colors.surface],
        ),
      ),
    );
  }
}
