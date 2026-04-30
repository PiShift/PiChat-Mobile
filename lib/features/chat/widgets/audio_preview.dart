import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:pichat/data/models/chat_media_model.dart';
import 'package:pichat/features/chat/application/media_providers.dart';

import 'chat_item.dart';

class AudioPreview extends ConsumerStatefulWidget {
  final ChatMedia media;
  final String mediaId;
  final String contactId;
  final String? metaId;
  /// Local file path on disk (e.g. the just-recorded voice note that was
  /// uploaded). When provided, playback uses this file directly instead of
  /// requiring a download — so an outbound audio plays immediately after
  /// send instead of showing a download button.
  final String? localFilePath;

  const AudioPreview({
    required this.media,
    required this.mediaId,
    required this.contactId,
    this.metaId,
    this.localFilePath,
    super.key,
  });

  @override
  ConsumerState<AudioPreview> createState() => _AudioPreviewState();
}

class _AudioPreviewState extends ConsumerState<AudioPreview> {
  final AudioPlayer _player = AudioPlayer();
  String? _loadedPath;
  String? _loadingPath;
  Future<void>? _loadingFuture;
  Duration? _duration;
  Duration _position = Duration.zero;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _player.durationStream.listen((d) {
      if (mounted && d != null) setState(() => _duration = d);
    });
    _player.positionStream.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.playerStateStream.listen((s) {
      if (!mounted) return;
      setState(() => _isPlaying = s.playing);
      if (s.processingState == ProcessingState.completed) {
        _player.seek(Duration.zero);
        _player.pause();
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  /// Resolve a usable local file path from media metadata + Riverpod state.
  String? _resolveLocalPath(MediaPlaybackState playback) {
    // Prefer a freshly-recorded/sent file that still lives on this device.
    final recorded = widget.localFilePath;
    if (recorded != null && recorded.isNotEmpty && File(recorded).existsSync()) {
      return recorded;
    }
    if (playback.localPath != null) return playback.localPath;
    if (widget.media.location == 'local' && widget.media.path != null) {
      return widget.media.path;
    }
    final p = widget.media.path;
    if (p != null && p.isNotEmpty && !p.startsWith('http')) return p;
    return null;
  }

  Future<void> _ensureLoaded(String path, {bool showError = false}) async {
    if (_loadedPath == path) return;
    // Dedupe: if a load for this same path is already in flight (e.g. the
    // post-frame auto-load fired and the user immediately tapped play),
    // await the existing future instead of issuing another setFilePath()
    // which just_audio aborts with "Loading interrupted".
    if (_loadingPath == path && _loadingFuture != null) {
      try {
        await _loadingFuture;
      } catch (_) {
        // The original caller will surface the error if needed.
      }
      return;
    }
    _loadingPath = path;
    final future = _player.setFilePath(path);
    _loadingFuture = future.then((_) {
      if (!mounted) return;
      _loadedPath = path;
    });
    try {
      await _loadingFuture;
    } catch (e) {
      if (!mounted) return;
      if (showError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load audio: $e')),
        );
      }
    } finally {
      if (_loadingPath == path) {
        _loadingPath = null;
        _loadingFuture = null;
      }
    }
  }

  Future<void> _togglePlay(String path) async {
    await _ensureLoaded(path, showError: true);
    if (_loadedPath != path) return;
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> _download() async {
    final notifier = ref.read(mediaPlaybackProvider(widget.mediaId).notifier);

    // 1) If we have a public http path, just cache it through MediaStorageService.
    final p = widget.media.path;
    if (p != null && p.startsWith('http')) {
      try {
        final storage = ref.read(mediaStorageServiceProvider);
        final localPath = await storage.downloadMedia(widget.mediaId, p);
        notifier.setDownloaded(localPath);
        return;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to download: $e')),
          );
        }
        return;
      }
    }

    // 2) Otherwise fall back to Meta API (voice notes have no public URL).
    await notifier.downloadMedia(
      widget.contactId,
      widget.media.type ?? 'audio/ogg',
      metaId: widget.metaId ?? widget.media.metaId,
      metaUrl: widget.media.metaUrl,
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// Human readable byte size, e.g. 24 KB / 1.2 MB.
  String? _formatSize(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final bytes = int.tryParse(raw);
    if (bytes == null || bytes <= 0) return null;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final playback = ref.watch(mediaPlaybackProvider(widget.mediaId));
    final localPath = _resolveLocalPath(playback);
    final hasLocalFile = localPath != null && File(localPath).existsSync();

    // Auto-load the file so duration becomes available without requiring play.
    if (hasLocalFile && _loadedPath != localPath && _loadingPath != localPath) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ensureLoaded(localPath);
      });
    }

    final progress = (_duration != null && _duration!.inMilliseconds > 0)
        ? (_position.inMilliseconds / _duration!.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    final sizeLabel = _formatSize(widget.media.size);
    // Single label under the progress bar:
    //  - while playing: current position (counter)
    //  - loaded but idle: total duration
    //  - loaded but duration not yet known: --:--
    //  - not yet downloaded: file size (e.g. 24 KB)
    final String label;
    if (hasLocalFile && _duration != null) {
      label = _isPlaying
          ? _formatDuration(_position)
          : _formatDuration(_duration!);
    } else if (hasLocalFile) {
      label = '--:--';
    } else if (sizeLabel != null) {
      label = sizeLabel;
    } else {
      label = '';
    }

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
          if (playback.isDownloading)
            const SizedBox(
              width: 32,
              height: 32,
              child: Padding(
                padding: EdgeInsets.all(4),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: hasLocalFile ? () => _togglePlay(localPath) : _download,
              icon: Icon(
                hasLocalFile
                    ? (_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill)
                    : Icons.download_for_offline,
                size: 32,
              ),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(
                  value: hasLocalFile ? progress : 0.0,
                  minHeight: 3,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.mic, size: 14, color: Colors.black54),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: const TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                  ],
                ),
                if (playback.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      playback.error!,
                      style: const TextStyle(color: Colors.red, fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
