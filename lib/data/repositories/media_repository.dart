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
    required String mediaType,
    required String accessToken,
  }) async {
    // Check if already downloaded
    if (await _localManager.exists(
      contactId: contactId,
      mediaId: mediaId,
      mediaType: mediaType,
    )) {
      return _getLocalPath(contactId, mediaId, mediaType);
    }

    // Get media URL from Meta
    final mediaUrl = await _metaService.getMediaUrl(mediaId, accessToken);

    // Download media
    final bytes = await _metaService.downloadMedia(mediaUrl, accessToken);

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
}