import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

/// The outcome of trying to preview a PDF.
class PdfFirstPage {
  const PdfFirstPage({
    this.image,
    this.pageCount,
    this.needsPassword = false,
  });

  /// Page one, when it could be rendered.
  final Uint8List? image;
  final int? pageCount;

  /// The file is encrypted, so no inline preview can be produced here.
  ///
  /// This does *not* mean the reader needs a password. Bank statements are
  /// commonly encrypted with an owner password only - printing and copying are
  /// restricted while the user password is empty - so iOS opens them without
  /// prompting. pdfx cannot: its `password` argument is web-only, so PDFium
  /// refuses every encrypted file on iOS and reports "Invalid PDF format".
  /// These still open perfectly in the system viewer.
  final bool needsPassword;
}

/// Renders page one of a local PDF.
///
/// WhatsApp can show this before the file is downloaded because the *sending*
/// device generates the thumbnail and ships it with the message. Meta's Cloud
/// API does not forward that to us, so the earliest we can produce one is once
/// the file is on the device. Results are cached per path: rendering is not
/// free and a bubble rebuilds often while scrolling.
class PdfFirstPageRenderer {
  /// Look for the encryption dictionary. Checked only after a render failure,
  /// so the cost is paid once for a file we already know we cannot open.
  static Future<bool> _isEncrypted(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      const needle = [0x2F, 0x45, 0x6E, 0x63, 0x72, 0x79, 0x70, 0x74]; // "/Encrypt"

      for (var i = 0; i <= bytes.length - needle.length; i++) {
        var matched = true;

        for (var j = 0; j < needle.length; j++) {
          if (bytes[i + j] != needle[j]) {
            matched = false;
            break;
          }
        }

        if (matched) return true;
      }
    } catch (_) {
      // Fall through: treat as an ordinary failure.
    }

    return false;
  }

  static final Map<String, Future<PdfFirstPage?>> _cache = {};

  static Future<PdfFirstPage?> render(String path, {int width = 480}) {
    return _cache.putIfAbsent(path, () => _render(path, width));
  }

  static Future<PdfFirstPage?> _render(String path, int width) async {
    PdfDocument? document;
    PdfPage? page;

    try {
      document = await PdfDocument.openFile(path);
      final pageCount = document.pagesCount;

      page = await document.getPage(1);

      // Keep the source aspect ratio so the preview is not distorted.
      final height = (width * (page.height / page.width)).round();
      final rendered = await page.render(
        width: width.toDouble(),
        height: height.toDouble(),
        format: PdfPageImageFormat.jpeg,
        backgroundColor: '#FFFFFF',
      );

      if (rendered == null) return null;

      return PdfFirstPage(image: rendered.bytes, pageCount: pageCount);
    } catch (e) {
      if (await _isEncrypted(path)) {
        return const PdfFirstPage(needsPassword: true);
      }

      debugPrint('Could not render PDF preview for $path: $e');

      return null;
    } finally {
      await page?.close();
      await document?.close();
    }
  }
}
