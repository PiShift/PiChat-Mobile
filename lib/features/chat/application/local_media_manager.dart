import 'dart:io';
import 'dart:typed_data' show Uint8List;
import 'package:path_provider/path_provider.dart';

class LocalMediaManager {
    static const String _baseDir = 'chat_media';

    /// The documents directory, cached so stored paths can be resolved without
    /// an await in widget build methods.
    static String? _documentsPath;

    /// Call once at start-up, before any media is rendered.
    static Future<void> init() async {
      _documentsPath ??= (await getApplicationDocumentsDirectory()).path;
    }

    /// Turn a stored media path into one that is valid right now.
    ///
    /// Paths are stored relative to the documents directory because iOS moves
    /// that container: its UUID changes on reinstall and can change across app
    /// updates. An absolute path saved yesterday can point nowhere today, which
    /// made already-downloaded files look missing and asked the agent to
    /// download them all over again after every restart.
    ///
    /// Absolute paths written by older builds are re-anchored by their
    /// `chat_media/...` tail, so nothing has to be downloaded twice.
    static String? resolve(String? stored) {
      if (stored == null || stored.isEmpty) return null;

      final docs = _documentsPath;

      if (!stored.startsWith('/')) {
        return docs == null ? null : '$docs/$stored';
      }

      if (File(stored).existsSync()) return stored;

      final marker = stored.indexOf('/$_baseDir/');

      if (marker == -1 || docs == null) return null;

      return '$docs${stored.substring(marker)}';
    }

    /// The path to store in the database: relative to the documents directory.
    static String relativePath({
      required String contactId,
      required String mediaType,
      required String fileName,
    }) {
      return '$_baseDir/$contactId/$mediaType/$fileName';
    }

    /// The form of [absolutePath] that is safe to persist.
    ///
    /// Anything already inside our own media tree is stored relative, so it
    /// survives iOS moving the documents container. A path from somewhere else
    /// — a gallery pick, a file picker's cache — is returned unchanged: it is
    /// still valid for this run, and the message can be re-downloaded later.
    static String storedPath(String absolutePath) {
      final marker = absolutePath.indexOf('/$_baseDir/');

      return marker == -1 ? absolutePath : absolutePath.substring(marker + 1);
    }

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
      String? mimeType,
    }) async {
      final path = await _getMediaPath(contactId, mediaType);
      // The extension comes from the real MIME type. `mediaType` is the app's
      // own bucket - "document", "image" - and passing that in produced files
      // with no extension at all, which left the OS unable to work out how to
      // open them.
      final extension = getExtensionFromMimeType(mimeType ?? mediaType);
      final fileName = '$mediaId$extension';
      final file = File('$path/$fileName');

      await file.writeAsBytes(bytes);

      // Relative, so it survives the container moving.
      return relativePath(
        contactId: contactId,
        mediaType: mediaType,
        fileName: fileName,
      );
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
      } else if (type.startsWith('text/')) {
        if (type.contains('csv')) return '.csv';
        if (type.contains('html')) return '.html';
        if (type.contains('xml')) return '.xml';
        return '.txt';
      } else if (type.startsWith('application/')) {
        // Checked before the generic fallthrough so structured text keeps a
        // usable extension - a .file suffix left iOS unable to type it and the
        // in-app text viewer unable to recognise it.
        if (type.contains('json')) return '.json';
        if (type.contains('xml')) return '.xml';
        if (type.contains('csv')) return '.csv';
        if (type.contains('pdf')) return '.pdf';
        if (type.contains('wordprocessingml') || type.contains('docx')) return '.docx';
        if (type.contains('spreadsheetml') || type.contains('xlsx')) return '.xlsx';
        if (type.contains('msword') || type.contains('doc')) return '.doc';
        if (type.contains('excel') || type.contains('xls')) return '.xls';
        if (type.contains('zip')) return '.zip';
        return '.file';
      }

      // Bare buckets ("pdf", "document") reach here when no MIME type was
      // available; keep a usable extension rather than none at all.
      if (type == 'pdf') return '.pdf';
      if (type == 'document' || type == 'file') return '.file';

      return '';
    }

    Future<bool> exists({
      required String contactId,
      required String mediaId,
      required String mediaType,
      String? mimeType,
    }) async {
      final path = await _getMediaPath(contactId, mediaType);
      final extension = getExtensionFromMimeType(mimeType ?? mediaType);
      final file = File('$path/$mediaId$extension');
      return file.exists();
    }

    Future<String> getMediaPath(String contactId, String mediaType) async {
      return _getMediaPath(contactId, mediaType);
    }
  }