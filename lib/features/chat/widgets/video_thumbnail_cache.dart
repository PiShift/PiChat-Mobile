import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

/// A video's poster frame and duration.
class VideoPoster {
  const VideoPoster({required this.image, this.duration});

  final Uint8List image;
  final Duration? duration;
}

/// Produces the still shown in a video bubble.
///
/// Same constraint as PDFs: Meta's Cloud API sends no thumbnail, so the poster
/// frame can only be made once the file is on the device. Cached per path
/// because bubbles rebuild constantly while scrolling and extracting a frame is
/// not cheap.
class VideoPosterCache {
  static final Map<String, Future<VideoPoster?>> _cache = {};

  static Future<VideoPoster?> load(String path) {
    return _cache.putIfAbsent(path, () => _load(path));
  }

  static Future<VideoPoster?> _load(String path) async {
    try {
      if (!File(path).existsSync()) return null;

      final bytes = await VideoThumbnail.thumbnailData(
        video: path,
        imageFormat: ImageFormat.JPEG,
        // Wide enough to stay sharp in the bubble without decoding the frame
        // at full video resolution.
        maxWidth: 480,
        quality: 70,
      );

      if (bytes == null) return null;

      return VideoPoster(image: bytes);
    } catch (e) {
      debugPrint('Could not build a poster frame for $path: $e');

      return null;
    }
  }
}
