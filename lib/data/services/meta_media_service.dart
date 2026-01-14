import 'dart:typed_data' show Uint8List;
import 'package:dio/dio.dart';

class MetaMediaService {
  final String baseUrl = 'https://graph.facebook.com/v23.0';
  final _dio = Dio();

  Future<String> getMediaUrl(String mediaId, String accessToken) async {
    try {
      print("====== Fetching media URL for mediaId: $mediaId =====");
      print("Using accessToken: ${accessToken.substring(0, 10)}...");
      final response = await _dio.get(
        '$baseUrl/$mediaId',
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
          },
          // Explicitly clear any default content type headers
          contentType: null,
        ),
      );

      if (response.statusCode == 200) {
        return response.data['url'];
      }
      throw 'Failed to get media URL';
    } catch (e) {
      throw 'Media URL fetch failed: $e';
    }
  }

  Future<Uint8List> downloadMedia(String url, String accessToken) async {
    try {
      final response = await _dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Authorization': 'Bearer $accessToken'},
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        return Uint8List.fromList(response.data!);
      }
      throw 'Failed to download media';
    } catch (e) {
      throw 'Media download failed: $e';
    }
  }
}