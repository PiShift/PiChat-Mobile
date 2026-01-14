import 'dart:io';
import 'dart:typed_data' show Uint8List;
import 'package:path_provider/path_provider.dart';

class LocalMediaManager {
    static const String _baseDir = 'chat_media';

    Future<String> _getMediaPath(String contactId, String mediaType) async {
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/$_baseDir/$contactId/$mediaType';
      await Directory(path).create(recursive: true);
      return path;
    }

    Future<String> saveMedia({
      required String contactId,
      required String mediaId,
      required String mediaType,
      required Uint8List bytes,
    }) async {
      final path = await _getMediaPath(contactId, mediaType);
      final extension = getExtensionFromMimeType(mediaType);
      final file = File('$path/$mediaId$extension');

      await file.writeAsBytes(bytes);

      return file.path;
    }

    String getExtensionFromMimeType(String mimeType) {
      final type = mimeType.toLowerCase();
      if (type.startsWith('audio/')) {
        if (type.contains('ogg')) return '.ogg';
        if (type.contains('mpeg') || type.contains('mp3')) return '.mp3';
        if (type.contains('wav')) return '.wav';
        return '.audio';
      } else if (type.startsWith('image/')) {
        if (type.contains('jpeg') || type.contains('jpg')) return '.jpg';
        if (type.contains('png')) return '.png';
        if (type.contains('gif')) return '.gif';
        return '.img';
      } else if (type.startsWith('video/')) {
        if (type.contains('mp4')) return '.mp4';
        if (type.contains('mpeg')) return '.mpeg';
        return '.video';
      } else if (type.startsWith('application/')) {
        if (type.contains('pdf')) return '.pdf';
        if (type.contains('doc')) return '.doc';
        if (type.contains('docx')) return '.docx';
        return '.file';
      }
      return '';
    }

    Future<bool> exists({
      required String contactId,
      required String mediaId,
      required String mediaType,
    }) async {
      final path = await _getMediaPath(contactId, mediaType);
      final extension = getExtensionFromMimeType(mediaType);
      final file = File('$path/$mediaId$extension');
      return file.exists();
    }

    Future<String> getMediaPath(String contactId, String mediaType) async {
      return _getMediaPath(contactId, mediaType);
    }
  }