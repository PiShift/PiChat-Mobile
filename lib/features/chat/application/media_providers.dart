import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:pichat/core/state/auth_state.dart';
import 'package:pichat/data/db/database_provider.dart';
import 'package:pichat/data/repositories/media_repository.dart';
import 'package:pichat/data/services/media_storage_service.dart';
import 'package:pichat/data/services/meta_media_service.dart';

import 'local_media_manager.dart';

final mediaRepositoryProvider = Provider<MediaRepository>((ref) {
  return MediaRepository(
    metaService: MetaMediaService(),
    localManager: LocalMediaManager(),
    db: ref.watch(appDatabaseProvider),
  );
});

final mediaStorageServiceProvider = Provider<MediaStorageService>((ref) {
  return MediaStorageService();
});

final mediaPlaybackProvider = StateNotifierProvider.family<MediaPlaybackNotifier, MediaPlaybackState, String>((ref, mediaId) {
  return MediaPlaybackNotifier(ref, mediaId);
});

class MediaPlaybackState {
  final bool isPlaying;
  final double progress;
  final bool isDownloaded;
  final bool isDownloading;
  final String? localPath;
  final String? error;

  /// Whether the one automatic fetch has already been tried for this media.
  /// Without it a sticker that fails to download would ask for itself again
  /// on every rebuild, which on a scrolling thread is a request loop.
  final bool autoAttempted;

  MediaPlaybackState({
    this.isPlaying = false,
    this.progress = 0,
    this.isDownloaded = false,
    this.isDownloading = false,
    this.localPath,
    this.error,
    this.autoAttempted = false,
  });

  MediaPlaybackState copyWith({
    bool? isPlaying,
    double? progress,
    bool? isDownloaded,
    bool? isDownloading,
    String? localPath,
    String? error,
    bool? autoAttempted,
    // `error: null` cannot clear a field that falls back to the old value, so
    // a failed download used to keep showing its error through every retry.
    bool clearError = false,
  }) {
    return MediaPlaybackState(
      isPlaying: isPlaying ?? this.isPlaying,
      progress: progress ?? this.progress,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      isDownloading: isDownloading ?? this.isDownloading,
      localPath: localPath ?? this.localPath,
      error: clearError ? null : (error ?? this.error),
      autoAttempted: autoAttempted ?? this.autoAttempted,
    );
  }
}

class MediaPlaybackNotifier extends StateNotifier<MediaPlaybackState> {
  final Ref _ref;
  final String _mediaId;

  MediaPlaybackNotifier(this._ref, this._mediaId) : super(MediaPlaybackState());

  /// Fetch without the user asking for it.
  ///
  /// Used for stickers: WhatsApp shows them inline, they are a few dozen KB,
  /// and a download button over one is not a real choice. Runs at most once
  /// per media — if it fails, the bubble falls back to the manual retry
  /// button rather than hammering Meta.
  Future<void> autoDownload(
    String contactId,
    String mediaType, {
    String? metaId,
    String? metaUrl,
    String? mimeType,
  }) async {
    if (state.autoAttempted) return;

    state = state.copyWith(autoAttempted: true);

    await downloadMedia(
      contactId,
      mediaType,
      metaId: metaId,
      metaUrl: metaUrl,
      mimeType: mimeType,
    );
  }

  Future<void> downloadMedia(
    String contactId,
    String mediaType, {
    String? metaId,
    String? metaUrl,
    String? mimeType,
  }) async {
    if (state.isDownloading || state.isDownloaded) return;

    state = state.copyWith(isDownloading: true, clearError: true);

    try {
      final org = _ref.read(organizationProvider);
      if (org == null) throw 'No organization selected';

      final metadata = org.metadata;
      final accessToken = metadata!['whatsapp']['access_token'] as String;

      final mediaRepo = _ref.read(mediaRepositoryProvider);
      final localPath = await mediaRepo.downloadAndSaveMedia(
        contactId: contactId,
        mediaId: _mediaId,
        metaId: metaId,
        metaUrl: metaUrl,
        mediaType: mediaType,
        mimeType: mimeType,
        accessToken: accessToken,
      );

      state = state.copyWith(
        isDownloading: false,
        isDownloaded: true,
        localPath: localPath,
      );
    } catch (e) {
      state = state.copyWith(
        isDownloading: false,
        error: e.toString(),
      );
    }
  }

  void togglePlayback() {
    state = state.copyWith(isPlaying: !state.isPlaying);
  }

  void updateProgress(double progress) {
    state = state.copyWith(progress: progress);
  }

  void setDownloaded(String localPath) {
    state = state.copyWith(
      isDownloaded: true,
      localPath: localPath,
    );
  }
}