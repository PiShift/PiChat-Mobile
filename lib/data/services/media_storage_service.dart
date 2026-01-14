import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class MediaStorageService {
  static const String _baseDir = 'chat_media';

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/$_baseDir';
    await Directory(path).create(recursive: true);
    return path;
  }

  Future<String?> getLocalPath(String mediaId, String originalUrl) async {
    final path = await _localPath;
    final file = File('$path/$mediaId');
    if (await file.exists()) {
      return file.path;
    }
    return null;
  }

  Future<String> downloadMedia(String mediaId, String url) async {
    final path = await _localPath;
    final file = File('$path/$mediaId');

    if (await file.exists()) {
      return file.path;
    }

    final response = await http.get(Uri.parse(url));
    await file.writeAsBytes(response.bodyBytes);
    return file.path;
  }
}