import 'dart:io';
import 'dart:typed_data' show Uint8List;
import 'package:path_provider/path_provider.dart';
import 'package:pichat/data/db/app_database.dart';
import 'package:pichat/data/services/meta_media_service.dart';
import 'package:pichat/features/chat/application/local_media_manager.dart';

// ... rest of the code stays the same
class MediaRepository {
  final MetaMediaService _metaService;
  final LocalMediaManager _localManager;
  final AppDatabase _db;

  MediaRepository({
    required MetaMediaService metaService,
    required LocalMediaManager localManager,
    required AppDatabase db,
  })  : _metaService = metaService,
        _localManager = localManager,
        _db = db;

  Future<String> downloadAndSaveMedia({
    required String contactId,
    required String mediaId,
    String? metaId,
    String? metaUrl,
    required String mediaType,
    required String accessToken,
  }) async {
    // Check if already downloaded on disk
    if (await _localManager.exists(
      contactId: contactId,
      mediaId: mediaId,
      mediaType: mediaType,
    )) {
      final localPath = await _getLocalPath(contactId, mediaId, mediaType);
      // Always sync location to DB — guards against the row being overwritten
      // by a server fetch after the file was saved (e.g. location reset to null).
      await _db.updateMediaPath(mediaId, localPath);
      return localPath;
    }

    // Use stored meta_url directly; only fetch from Meta API if not available
    final downloadUrl = metaUrl ?? await _metaService.getMediaUrl(metaId ?? mediaId, accessToken);

    // Download media — if the stored URL is expired (404), get a fresh one via Meta API
    late Uint8List bytes;
    try {
      bytes = await _metaService.downloadMedia(downloadUrl, accessToken);
    } catch (_) {
      // Extract WhatsApp media ID from the expired URL's `mid` query param, or use metaId
      final whatsappId = _extractMidFromUrl(metaUrl) ?? metaId;
      if (whatsappId == null) rethrow;
      print('====== meta_url expired, fetching fresh URL for mid=$whatsappId');
      final freshUrl = await _metaService.getMediaUrl(whatsappId, accessToken);
      bytes = await _metaService.downloadMedia(freshUrl, accessToken);
    }

    // Save locally
    final localPath = await _localManager.saveMedia(
      contactId: contactId,
      mediaId: mediaId,
      mediaType: mediaType,
      bytes: bytes
    );

    // Update database
    await _db.updateMediaPath(mediaId, localPath);

    return localPath;
  }

  Future<String> _getLocalPath(
    String contactId,
    String mediaId,
    String mediaType,
  ) async {
    final path = await _localManager.getMediaPath(contactId, mediaType);
    return '$path/$mediaId${_localManager.getExtensionFromMimeType(mediaType)}';
  }

  /// Extracts the `mid` query parameter from a Meta CDN URL.
  /// e.g. https://lookaside.fbsbx.com/...?mid=940895221910061&...  → "940895221910061"
  String? _extractMidFromUrl(String? url) {
    if (url == null) return null;
    try {
      return Uri.parse(url).queryParameters['mid'];
    } catch (_) {
      return null;
    }
  }
}