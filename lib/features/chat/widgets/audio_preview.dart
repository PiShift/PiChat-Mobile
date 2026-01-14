import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pichat/data/models/chat_media_model.dart';
import 'package:pichat/features/chat/application/media_providers.dart';

import 'chat_item.dart';

class AudioPreview extends ConsumerWidget {
  final ChatMedia media;
  final String mediaId;

  const AudioPreview({
    required this.media,
    required this.mediaId,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playbackState = ref.watch(mediaPlaybackProvider(mediaId));

    return Container(
      width: ChatMessageItem.mediaMaxWidth,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () {
              if (playbackState.isDownloaded) {
                ref.read(mediaPlaybackProvider(mediaId).notifier).togglePlayback();
              } else {
                _downloadAndPlay(context, ref);
              }
            },
            icon: Icon(
              playbackState.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
              size: 32,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(value: playbackState.progress),
                const SizedBox(height: 4),
                Text(
                  media.name ?? 'Audio',
                  style: const TextStyle(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadAndPlay(BuildContext context, WidgetRef ref) async {
    try {
      final storage = ref.read(mediaStorageServiceProvider);
      final localPath = await storage.downloadMedia(mediaId, media.path!);

      ref.read(mediaPlaybackProvider(mediaId).notifier).setDownloaded(localPath);
      ref.read(mediaPlaybackProvider(mediaId).notifier).togglePlayback();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to download: $e')),
      );
    }
  }
}