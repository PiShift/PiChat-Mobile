import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pichat/data/models/chat_media_model.dart';
import 'package:pichat/features/chat/application/media_providers.dart';

import 'chat_item.dart';

class ImagePreview extends ConsumerWidget {
  final ChatMedia media;
  final String mediaId;

  const ImagePreview({
    required this.media,
    required this.mediaId,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playbackState = ref.watch(mediaPlaybackProvider(mediaId));

    return GestureDetector(
      onTap: () => _showFullScreenImage(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: playbackState.localPath != null
            ? Image.file(
          File(playbackState.localPath!),
          width: ChatMessageItem.mediaMaxWidth,
          height: ChatMessageItem.mediaMaxWidth,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildErrorWidget(),
        )
            : FutureBuilder<String?>(
          future: _loadImage(context, ref),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }
            return Image.network(
              media.path ?? '',
              width: ChatMessageItem.mediaMaxWidth,
              height: ChatMessageItem.mediaMaxWidth,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildErrorWidget(),
            );
          },
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: ChatMessageItem.mediaMaxWidth,
      height: ChatMessageItem.mediaMaxWidth,
      color: Colors.grey[200],
      child: const Center(
        child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
      ),
    );
  }

  Future<String?> _loadImage(BuildContext context, WidgetRef ref) async {
    try {
      final storage = ref.read(mediaStorageServiceProvider);
      final localPath = await storage.downloadMedia(mediaId, media.path!);
      ref.read(mediaPlaybackProvider(mediaId).notifier).setDownloaded(localPath);
      return localPath;
    } catch (e) {
      return media.path;
    }
  }

  void _showFullScreenImage(BuildContext context) {
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
              child: Image.network(
                media.path ?? '',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}