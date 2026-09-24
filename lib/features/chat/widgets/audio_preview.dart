import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pichat/features/chat/widgets/voice_waveform.dart';
import 'package:pichat/core/theme/app_colors.dart';
import 'package:pichat/core/theme/app_sizing.dart';
import 'package:pichat/data/models/chat_media_model.dart';
import 'package:pichat/features/chat/application/local_media_manager.dart';
import 'package:pichat/features/chat/application/media_providers.dart';
import 'package:pichat/features/chat/application/waveform_provider.dart';
import 'package:pichat/features/chat/application/voice_chain.dart';
import 'package:pichat/features/chat/application/voice_player.dart';

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

  /// Shown in place of the play button — the upload control while an
  /// outgoing voice note is being sent or has failed.
  final Widget? transport;

  const AudioPreview({
    required this.media,
    required this.mediaId,
    required this.contactId,
    this.metaId,
    this.localFilePath,
    this.transport,
    super.key,
  });

  @override
  ConsumerState<AudioPreview> createState() => _AudioPreviewState();
}

class _AudioPreviewState extends ConsumerState<AudioPreview> {
  // No player, and no position/duration/playing fields, on purpose. All of it
  // lives in voicePlayerProvider. Held here it was destroyed whenever the list
  // rebuilt this bubble — a few pixels of scrolling was enough — so playback
  // stopped mid-note and every timestamp reset at once.

  @override
  void initState() {
    super.initState();

    // Play from a notification. fireImmediately, because the request is
    // usually set before this bubble exists: the tap opens the conversation
    // and the note only arrives with its messages.
    ref.listenManual<String?>(playOnOpenProvider, (_, id) {
      if (id == widget.mediaId) Future.microtask(_playOnOpen);
    }, fireImmediately: true);
  }

  /// Start this note for Play on its notification, fetching it first if it
  /// has not been downloaded yet.
  Future<void> _playOnOpen() async {
    final request = ref.read(playOnOpenProvider.notifier);
    if (request.state != widget.mediaId) return;
    request.state = null;

    var path = _resolveLocalPath(ref.read(mediaPlaybackProvider(widget.mediaId)));

    if (path == null || !File(path).existsSync()) {
      await _download();
      if (!mounted) return;
      path = LocalMediaManager.resolve(
          ref.read(mediaPlaybackProvider(widget.mediaId)).localPath);
    }

    if (path == null || !mounted) return;

    await ref.read(voicePlayerProvider.notifier).play(widget.mediaId, path);
  }

  /// Start this note because the previous one just finished.
  Future<void> _playFromChain(String path) async {
    await ref.read(voicePlayerProvider.notifier).play(widget.mediaId, path);
  }

  /// Whether [path] is on disk, remembered for this bubble.
  ///
  /// The check used to run on every build. A conversation rebuilds for all
  /// sorts of reasons, and a synchronous stat per audio bubble per frame both
  /// cost real time and let the duration label flip to a file size whenever a
  /// check came back false under load. Paths here only change when a download
  /// completes, which replaces the key and re-checks anyway.
  final Map<String, bool> _existsCache = {};

  bool _fileExists(String path) =>
      _existsCache[path] ??= File(path).existsSync();

  /// Resolve a usable local file path from media metadata + Riverpod state.
  /// Stored paths are relative to the app's documents directory, so they are
  /// re-anchored to wherever that container lives right now.
  String? _resolveLocalPath(MediaPlaybackState playback) {
    // Prefer a freshly-recorded/sent file that still lives on this device.
    final recorded = LocalMediaManager.resolve(widget.localFilePath);
    if (recorded != null && _fileExists(recorded)) {
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

  Future<void> _togglePlay(String path) async {
    await ref.read(voicePlayerProvider.notifier).toggle(widget.mediaId, path);
  }

  /// Jump to a fraction of the note, from a tap or drag on the waveform.
  Future<void> _seekToFraction(double fraction, String path) async {
    final player = ref.read(voicePlayerProvider.notifier);

    // Seeking a note that is not the one loaded has to load it first, or the
    // drag would move the position of whatever else was playing.
    if (!player.isActive(widget.mediaId)) {
      await player.play(widget.mediaId, path);
    }

    await player.seekFraction(fraction);
  }

  Future<void> _cycleSpeed() async {
    await ref.read(voicePlayerProvider.notifier).cycleSpeed();
  }

  Future<void> _download() async {
    final notifier = ref.read(mediaPlaybackProvider(widget.mediaId).notifier);

    // A download is the one thing that turns a missing path into a real file,
    // so drop what we remembered about what is on disk before starting.
    _existsCache.clear();

    // Outbound media lives on our own server under a public URL; inbound has
    // to be fetched from Meta. Both go through the same downloader, which
    // names the file from its mime type and stores it relative to the
    // documents directory — the previous shortcut for http URLs wrote a file
    // with no extension and never checked the status code, so an error page
    // was saved as if it were audio and nothing would play.
    //
    // Passing metaId as well means a URL that has gone missing falls back to
    // re-fetching from Meta instead of simply failing.
    final p = widget.media.path;
    final metaUrl = (p != null && p.startsWith('http')) ? p : widget.media.metaUrl;

    await notifier.downloadMedia(
      widget.contactId,
      widget.media.type ?? 'audio/ogg',
      metaId: widget.metaId ?? widget.media.metaId,
      metaUrl: metaUrl,
      mimeType: widget.media.type,
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
    final hasLocalFile = localPath != null && _fileExists(localPath);

    // The note before this one finished and named this bubble as next. The
    // request is consumed straight away so that pausing what it starts does
    // not immediately restart it.
    ref.listen<VoiceChain>(voiceChainProvider, (_, chain) {
      if (chain.autoPlay != widget.mediaId) return;

      ref.read(voiceChainProvider.notifier).consume(widget.mediaId);

      if (hasLocalFile) _playFromChain(localPath);
    });

    // Selected field by field, and position only while this bubble is the one
    // playing. Watching the whole object rebuilt every audio bubble in the
    // thread on every position tick, several times a second, for a playhead
    // that only moves in one of them.
    final id = widget.mediaId;

    final isActive =
        ref.watch(voicePlayerProvider.select((v) => v.mediaId == id));
    final isPlaying = ref
        .watch(voicePlayerProvider.select((v) => v.mediaId == id && v.playing));
    final speed = ref.watch(voicePlayerProvider.select((v) => v.speed));
    final livePosition = ref.watch(voicePlayerProvider
        .select((v) => v.mediaId == id ? v.position : Duration.zero));
    final liveDuration = ref.watch(
        voicePlayerProvider.select((v) => v.mediaId == id ? v.duration : null));

    // Read once per file and cached, so it survives this bubble being rebuilt.
    // While active, prefer the live figure from the player itself.
    final cached = hasLocalFile
        ? ref.watch(voiceDurationProvider(localPath)).value
        : null;
    final total = isActive ? (liveDuration ?? cached) : cached;
    final position = livePosition;

    // Tell the shared player where this note lives, so a run can carry on into
    // it even after this bubble has scrolled out of the list.
    if (hasLocalFile) {
      ref.read(voicePlayerProvider.notifier).register(widget.mediaId, localPath);
    }

    final progress = (total != null && total.inMilliseconds > 0)
        ? (position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    final sizeLabel = _formatSize(widget.media.size);
    // Single label under the progress bar:
    //  - while playing: current position (counter)
    //  - loaded but idle: total duration
    //  - loaded but duration not yet known: --:--
    //  - not yet downloaded: file size (e.g. 24 KB)
    final String label;
    if (hasLocalFile && total != null) {
      label = isPlaying ? _formatDuration(position) : _formatDuration(total);
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
          widget.transport ??
              _buildTransportButton(
                  playback, hasLocalFile, localPath, colors, isPlaying),
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
                    // Real peaks, decoded off the build path. Null until they
                    // arrive — and on a file this device cannot decode — in
                    // which case the seeded shape is drawn instead.
                    amplitudes: hasLocalFile
                        ? ref.watch(waveformProvider(localPath)).value
                        : null,
                    progress: progress,
                    playedColor: colors.primary500,
                    // Derived from the bubble's own text colour rather than
                    // `divider`. In dark mode divider (#2C2A28) sits on a sent
                    // bubble of #3D2A00 — near enough to the same colour that
                    // the unplayed half of the waveform disappeared. Text
                    // colour is guaranteed to contrast with whatever bubble it
                    // is on, in both themes.
                    remainingColor: colors.textPrimary.withValues(alpha: 0.45),
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
                            color: speed == 1.0
                                ? colors.divider.withValues(alpha: 0.5)
                                : colors.primary500.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            '${speed % 1 == 0 ? speed.toInt() : speed}x',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: Sz.sp(context, 10),
                              fontWeight: FontWeight.w600,
                              color: speed == 1.0
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
    bool isPlaying,
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
                ? (isPlaying ? LucideIcons.pause : LucideIcons.play)
                : LucideIcons.arrowDown,
            size: 17,
            color: PiPalette.white,
          ),
        ),
      ),
    );
  }
}
