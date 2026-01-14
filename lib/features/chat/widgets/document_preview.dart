import 'dart:io';
  import 'package:flutter/material.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'package:pichat/data/models/chat_media_model.dart';
  import 'package:pichat/features/chat/application/media_providers.dart';
  import 'package:open_file/open_file.dart';

  class DocumentPreview extends ConsumerWidget {
    final ChatMedia media;
    final String mediaId;
    final String mediaType;
    final String contactId;

    const DocumentPreview({
      required this.media,
      required this.mediaId,
      required this.mediaType,
      required this.contactId,
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
          return Icons.picture_as_pdf;
        case 'doc':
        case 'docx':
          return Icons.description;
        case 'video':
          return Icons.video_file;
        case 'audio':
          return Icons.audio_file;
        default:
          return Icons.insert_drive_file;
      }
    }

    @override
    Widget build(BuildContext context, WidgetRef ref) {
      final mediaState = ref.watch(mediaPlaybackProvider(mediaId));

      return Container(
        padding: const EdgeInsets.all(12),
        width: 240,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_getIconForMediaType(), size: 40, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        media.name ?? 'Document',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatFileSize(int.parse(media.size!)),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
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
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!mediaState.isDownloaded && !mediaState.isDownloading)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Download'),
                    onPressed: () {
                      ref
                          .read(mediaPlaybackProvider(mediaId).notifier)
                          .downloadMedia(contactId, mediaType);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(fontSize: 14),
                    ),
                  )
                else if (mediaState.isDownloaded)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Open'),
                    onPressed: () {
                      if (mediaState.localPath != null) {
                        OpenFile.open(mediaState.localPath);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(fontSize: 14),
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    }
  }