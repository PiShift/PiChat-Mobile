import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';

/// Pulls readable text out of Office files, in Dart.
///
/// Handing these to the operating system meant the agent's experience depended
/// on which apps happened to be installed on their phone, and differed between
/// Android and iOS. This reads the document ourselves so the same thing happens
/// everywhere.
///
/// It recovers text, not layout. A faithful renderer would have to implement
/// OOXML styling, tables, floats and RTL layout — a project in its own right.
/// For full fidelity the answer is server-side conversion to PDF, which the
/// existing in-app PDF viewer then renders identically on every platform.
class OfficeTextExtractor {
  static const supportedExtensions = <String>{'docx', 'xlsx', 'pptx'};

  static bool handles(String? fileName) {
    if (fileName == null || !fileName.contains('.')) return false;

    return supportedExtensions.contains(fileName.split('.').last.toLowerCase());
  }

  static Future<String?> extract(String path, String? fileName) async {
    final ext = fileName?.split('.').last.toLowerCase();

    try {
      final archive = ZipDecoder().decodeBytes(await File(path).readAsBytes());

      switch (ext) {
        case 'docx':
          return _fromParts(archive, const ['word/document.xml']);
        case 'pptx':
          // Slides are numbered, so sort to keep them in presentation order.
          final slides = archive.files
              .map((f) => f.name)
              .where((n) => n.startsWith('ppt/slides/slide') && n.endsWith('.xml'))
              .toList()
            ..sort();

          return _fromParts(archive, slides, separator: '\n\n— — —\n\n');
        case 'xlsx':
          return _fromXlsx(archive);
      }
    } catch (e) {
      debugPrint('Could not read $fileName as an Office document: $e');
    }

    return null;
  }

  static String? _fromParts(
    Archive archive,
    List<String> parts, {
    String separator = '\n\n',
  }) {
    final chunks = <String>[];

    for (final name in parts) {
      final file = archive.files.where((f) => f.name == name).firstOrNull;

      if (file == null) continue;

      final text = _paragraphs(utf8.decode(file.content as List<int>, allowMalformed: true));

      if (text.trim().isNotEmpty) chunks.add(text);
    }

    return chunks.isEmpty ? null : chunks.join(separator);
  }

  /// Cell text lives in a shared string table; the sheet holds indexes into it.
  static String? _fromXlsx(Archive archive) {
    final sharedFile =
        archive.files.where((f) => f.name == 'xl/sharedStrings.xml').firstOrNull;

    if (sharedFile == null) return null;

    final shared = _runs(
      utf8.decode(sharedFile.content as List<int>, allowMalformed: true),
    );

    return shared.isEmpty ? null : shared.join('\n');
  }

  /// `<w:t>` runs carry the visible characters; `<w:p>` marks a paragraph.
  static String _paragraphs(String xml) {
    final withBreaks = xml
        .replaceAll(RegExp(r'</w:p>|</a:p>'), '\n')
        .replaceAll(RegExp(r'<w:br[^>]*/>'), '\n')
        .replaceAll(RegExp(r'<w:tab[^>]*/>'), '\t');

    return _runs(withBreaks, keepBreaks: true).join();
  }

  static List<String> _runs(String xml, {bool keepBreaks = false}) {
    final out = <String>[];
    final pattern = RegExp(r'<(?:w|a):t(?:\s[^>]*)?>(.*?)</(?:w|a):t>|(\n)',
        dotAll: true);

    for (final match in pattern.allMatches(xml)) {
      if (match.group(1) != null) {
        out.add(_unescape(match.group(1)!));
      } else if (keepBreaks) {
        out.add('\n');
      }
    }

    if (keepBreaks) return out;

    // Shared strings: one entry per <t>, blanks dropped.
    return out.where((s) => s.trim().isNotEmpty).toList();
  }

  static String _unescape(String value) {
    return value
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");
  }
}
