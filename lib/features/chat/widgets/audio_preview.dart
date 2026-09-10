import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pichat/features/chat/widgets/voice_waveform.dart';
import 'package:pichat/core/theme/app_colors.dart';
import 'package:pichat/core/theme/app_sizing.dart';
import 'package:pichat/data/models/chat_media_model.dart';
import 'package:pichat/features/chat/application/local_media_manager.dart';
import 'package:pichat/features/chat/application/media_providers.dart';

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

  /// Agents triage a lot of voice notes, so being able to run one at 1.5x or 2x
  /// is a real time saver. Cycles on tap.
  static const _speeds = <double>[1.0, 1.5, 2.0];
  int _speedIndex = 0;

  double get _speed => _speeds[_speedIndex];

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
  /// Stored paths are relative to the app's documents directory, so they are
  /// re-anchored to wherever that container lives right now.
  String? _resolveLocalPath(MediaPlaybackState playback) {
    // Prefer a freshly-recorded/sent file that still lives on this device.
    final recorded = LocalMediaManager.resolve(widget.localFilePath);
    if (recorded != null && File(recorded).existsSync()) {
      return recorded;
    }
    final downloaded = LocalMediaManager.resolve(playback.localPath);
    if (downloaded != null) return downloaded;
    if (widget.media.location == 'local' && widget.media.path != null) {
      return LocalMediaManager.resolve(widget.media.path);
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

  /// Jump to a fraction of the note, from a tap or drag on the waveform.
  Future<void> _seekToFraction(double fraction, String path) async {
    final total = _duration;

    if (total == null || total.inMilliseconds <= 0) return;

    await _ensureLoaded(path);

    if (_loadedPath != path) return;

    await _player.seek(
      Duration(milliseconds: (total.inMilliseconds * fraction).round()),
    );
  }

  Future<void> _cycleSpeed() async {
    setState(() => _speedIndex = (_speedIndex + 1) % _speeds.length);

    await _player.setSpeed(_speed);
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

    final colors = PiColors.of(context);
    final isVoiceNote = _isVoiceNote;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTransportButton(playback, hasLocalFile, localPath, colors),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isVoiceNote)
                  VoiceWaveform(
                    // Stable per message so the shape never changes between
                    // rebuilds or app launches.
                    seed: widget.media.id,
                    progress: progress,
                    playedColor: colors.primary500,
                    remainingColor: colors.divider,
                    height: 26,
                    onSeek: hasLocalFile
                        ? (fraction) => _seekToFraction(fraction, localPath)
                        : null,
                  )
                else
                  LinearProgressIndicator(
                    value: hasLocalFile ? progress : 0.0,
                    minHeight: 3,
                    color: colors.primary500,
                    backgroundColor: colors.divider,
                  ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Icon(
                      isVoiceNote ? LucideIcons.mic : LucideIcons.music,
                      size: 13,
                      color: colors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: Sz.sp(context, 11),
                        color: colors.textSecondary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const Spacer(),
                    // Only worth offering once the audio is actually playable.
                    if (hasLocalFile)
                      GestureDetector(
                        onTap: _cycleSpeed,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _speedIndex == 0
                                ? colors.divider.withValues(alpha: 0.5)
                                : colors.primary500.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            '${_speed % 1 == 0 ? _speed.toInt() : _speed}x',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: Sz.sp(context, 10),
                              fontWeight: FontWeight.w600,
                              color: _speedIndex == 0
                                  ? colors.textSecondary
                                  : colors.primary500,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                if (playback.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      playback.error!,
                      style: GoogleFonts.plusJakartaSans(
                        color: colors.error,
                        fontSize: Sz.sp(context, 10),
                      ),
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

  /// True for a recorded voice note as opposed to an attached audio file.
  /// WhatsApp marks these with `voice: true`; an .ogg/opus mime is the fallback
  /// signal for older rows that predate that flag.
  bool get _isVoiceNote {
    final type = widget.media.type?.toLowerCase() ?? '';

    return type.contains('ogg') ||
        type.contains('opus') ||
        widget.media.path?.toLowerCase().endsWith('.ogg') == true ||
        widget.localFilePath?.toLowerCase().endsWith('.m4a') == true ||
        widget.media.type == 'audio/mp4';
  }

  /// Play, pause, download, or a progress ring while the file is coming down.
  Widget _buildTransportButton(
    MediaPlaybackState playback,
    bool hasLocalFile,
    String? localPath,
    PiColors colors,
  ) {
    if (playback.isDownloading) {
      return SizedBox(
        width: 36,
        height: 36,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colors.primary500,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: hasLocalFile && localPath != null
          ? () => _togglePlay(localPath)
          : _download,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: colors.primary500,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(
            hasLocalFile
                ? (_isPlaying ? LucideIcons.pause : LucideIcons.play)
                : LucideIcons.arrowDown,
            size: 17,
            color: PiPalette.white,
          ),
        ),
      ),
    );
  }
}
