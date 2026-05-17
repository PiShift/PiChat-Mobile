import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pichat/core/constants/app_constants.dart';
import 'package:pichat/core/theme/app_colors.dart';
import 'package:pichat/core/theme/app_theme.dart';
import 'package:pichat/data/repositories/chat_repository.dart';
import 'package:url_launcher/url_launcher.dart';

/// Provider for fetching contact media
final contactMediaProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, contactUuid) async {
  final chatRepo = ref.watch(chatRepositoryProvider);
  return chatRepo.getContactMedia(contactUuid);
});

/// Ensure [url] is absolute. Relative paths like `/media/public/...` are
/// prefixed with [AppConstants.baseUrl].
String _resolveUrl(String url) {
  if (url.isEmpty) return url;
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  final base = AppConstants.baseUrl.endsWith('/')
      ? AppConstants.baseUrl.substring(0, AppConstants.baseUrl.length - 1)
      : AppConstants.baseUrl;
  return '$base$url';
}

class MediaGalleryScreen extends ConsumerStatefulWidget {
  final String contactUuid;
  final String contactName;

  const MediaGalleryScreen({
    required this.contactUuid,
    required this.contactName,
    super.key,
  });

  @override
  ConsumerState<MediaGalleryScreen> createState() => _MediaGalleryScreenState();
}

class _MediaGalleryScreenState extends ConsumerState<MediaGalleryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    // Always fetch fresh media when opening this screen so the gallery
    // reflects recently received files (provider result is cached otherwise).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(contactMediaProvider(widget.contactUuid));
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaAsync = ref.watch(contactMediaProvider(widget.contactUuid));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: PiPalette.primary500,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.contactName,
          style: const TextStyle(color: Colors.white),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.image), text: 'Photos'),
            Tab(icon: Icon(Icons.videocam), text: 'Videos'),
            Tab(icon: Icon(Icons.insert_drive_file), text: 'Docs'),
            Tab(icon: Icon(Icons.audiotrack), text: 'Audio'),
          ],
        ),
      ),
      body: mediaAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: PiPalette.ink400),
              const SizedBox(height: 16),
              Text('Error loading media: $e'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(contactMediaProvider(widget.contactUuid)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (data) {
          final media = data['media'] as Map<String, dynamic>? ?? {};
          final images = (media['images'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          final videos = (media['videos'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          final documents = (media['documents'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          final audio = (media['audio'] as List?)?.cast<Map<String, dynamic>>() ?? [];

          return TabBarView(
            controller: _tabController,
            children: [
              _MediaGrid(items: images, type: MediaType.image),
              _MediaGrid(items: videos, type: MediaType.video),
              _MediaList(items: documents, type: MediaType.document),
              _MediaList(items: audio, type: MediaType.audio),
            ],
          );
        },
      ),
    );
  }
}

enum MediaType { image, video, document, audio }

class _MediaGrid extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final MediaType type;

  const _MediaGrid({required this.items, required this.type});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type == MediaType.image ? Icons.image_not_supported : Icons.videocam_off,
              size: 64,
              color: PiColors.of(context).ink400,
            ),
            const SizedBox(height: 16),
            Text(
              'No ${type == MediaType.image ? 'photos' : 'videos'} yet',
              style: TextStyle(color: PiColors.of(context).textSecondary, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final url = _resolveUrl(item['url'] as String? ?? '');
        final isVideo = type == MediaType.video;

        return GestureDetector(
          onTap: () => _openMediaViewer(context, item, type),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: PiColors.of(context).surface,
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                errorWidget: (context, url, error) => Container(
                  color: PiColors.of(context).surface,
                  child: Icon(Icons.broken_image, color: PiColors.of(context).ink400),
                ),
              ),
              if (isVideo)
                Positioned.fill(
                  child: Container(
                    color: Colors.black26,
                    child: const Center(
                      child: Icon(Icons.play_circle_fill, color: Colors.white, size: 40),
                    ),
                  ),
                ),
              // Direction indicator
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    item['direction'] == 'inbound' ? Icons.arrow_downward : Icons.arrow_upward,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openMediaViewer(BuildContext context, Map<String, dynamic> item, MediaType type) {
    final url = _resolveUrl(item['url'] as String? ?? '');
    
    if (type == MediaType.image) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _FullScreenImageViewer(
            url: url,
            name: item['name'] as String? ?? 'Image',
          ),
        ),
      );
    } else {
      // For video, open in external player
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }
}

class _MediaList extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final MediaType type;

  const _MediaList({required this.items, required this.type});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type == MediaType.document ? Icons.folder_open : Icons.music_off,
              size: 64,
              color: PiColors.of(context).ink400,
            ),
            const SizedBox(height: 16),
            Text(
              'No ${type == MediaType.document ? 'documents' : 'audio files'} yet',
              style: TextStyle(color: PiColors.of(context).textSecondary, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = items[index];
        final name = item['name'] as String? ?? 'Unknown';
        final size = item['size'] as String? ?? '';
        final sentAt = item['sent_at'] as String? ?? '';
        final url = _resolveUrl(item['url'] as String? ?? '');
        final isInbound = item['direction'] == 'inbound';

        return ListTile(
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: type == MediaType.document ? Colors.blue[50] : Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              type == MediaType.document ? Icons.description : Icons.audio_file,
              color: type == MediaType.document ? Colors.blue : Colors.orange,
            ),
          ),
          title: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Row(
            children: [
              Text(_formatSize(size)),
              const SizedBox(width: 8),
              Icon(
                isInbound ? Icons.arrow_downward : Icons.arrow_upward,
                size: 12,
                color: PiColors.of(context).ink400,
              ),
              const SizedBox(width: 4),
              Text(
                _formatDate(sentAt),
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          trailing: IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
          ),
          onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        );
      },
    );
  }

  String _formatSize(String size) {
    if (size.isEmpty) return '';
    final bytes = int.tryParse(size) ?? 0;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(String isoDate) {
    if (isoDate.isEmpty) return '';
    try {
      final date = DateTime.parse(isoDate);
      final now = DateTime.now();
      if (date.year == now.year && date.month == now.month && date.day == now.day) {
        return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      }
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return '';
    }
  }
}

class _FullScreenImageViewer extends StatelessWidget {
  final String url;
  final String name;

  const _FullScreenImageViewer({required this.url, required this.name});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(name, style: const TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
          ),
        ],
      ),
      body: InteractiveViewer(
        child: Center(
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.contain,
            placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
            errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.white, size: 48),
          ),
        ),
      ),
    );
  }
}
