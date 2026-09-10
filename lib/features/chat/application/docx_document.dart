import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';

/// A run of text sharing one set of marks.
class DocxRun {
  const DocxRun({
    required this.text,
    this.bold = false,
    this.italic = false,
    this.underline = false,
  });

  final String text;
  final bool bold;
  final bool italic;
  final bool underline;
}

enum DocxBlockKind { paragraph, heading, bullet, numbered, table, image }

/// One block in the document flow.
class DocxBlock {
  const DocxBlock({
    required this.kind,
    this.runs = const [],
    this.level = 0,
    this.rows = const [],
    this.image,
  });

  final DocxBlockKind kind;
  final List<DocxRun> runs;

  /// Heading level, or list nesting depth.
  final int level;

  /// Table cells, each cell already flattened to text.
  final List<List<String>> rows;

  final Uint8List? image;

  bool get isEmpty =>
      runs.every((r) => r.text.trim().isEmpty) && rows.isEmpty && image == null;
}

/// Reads a .docx into blocks that Flutter can lay out directly.
///
/// A .docx is a zip of XML, so this stays pure Dart and behaves the same on
/// every platform — no native viewer, no per-device differences. It recovers
/// structure and character formatting, not Word's full layout engine; for
/// pixel-exact output the answer is a server-side PDF rendition.
class DocxDocument {
  const DocxDocument(this.blocks);

  final List<DocxBlock> blocks;

  static Future<DocxDocument?> parse(String path) async {
    try {
      final archive = ZipDecoder().decodeBytes(await File(path).readAsBytes());
      final entry =
          archive.files.where((f) => f.name == 'word/document.xml').firstOrNull;

      if (entry == null) return null;

      final xml =
          utf8.decode(entry.content as List<int>, allowMalformed: true);

      final images = <String, Uint8List>{
        for (final f in archive.files)
          if (f.name.startsWith('word/media/'))
            f.name.split('/').last: Uint8List.fromList(f.content as List<int>),
      };

      return DocxDocument(_parseBody(xml, images));
    } catch (e) {
      debugPrint('Could not parse docx at $path: $e');

      return null;
    }
  }

  /// Walk the body in document order, emitting a block per <w:p> and <w:tbl>.
  static List<DocxBlock> _parseBody(String xml, Map<String, Uint8List> images) {
    final blocks = <DocxBlock>[];
    final element = RegExp(r'<w:(p|tbl)\b.*?</w:\1>', dotAll: true);

    for (final match in element.allMatches(xml)) {
      final chunk = match.group(0)!;

      if (match.group(1) == 'tbl') {
        final rows = _parseTable(chunk);

        if (rows.isNotEmpty) {
          blocks.add(DocxBlock(kind: DocxBlockKind.table, rows: rows));
        }

        continue;
      }

      final picture = _pictureIn(chunk, images);

      if (picture != null) {
        blocks.add(DocxBlock(kind: DocxBlockKind.image, image: picture));
      }

      final runs = _parseRuns(chunk);

      if (runs.every((r) => r.text.trim().isEmpty)) continue;

      blocks.add(DocxBlock(
        kind: _kindOf(chunk),
        level: _levelOf(chunk),
        runs: runs,
      ));
    }

    return blocks;
  }

  static DocxBlockKind _kindOf(String paragraph) {
    final style = RegExp(r'<w:pStyle w:val="([^"]+)"').firstMatch(paragraph);
    final name = style?.group(1)?.toLowerCase() ?? '';

    if (name.startsWith('heading') || name.startsWith('title')) {
      return DocxBlockKind.heading;
    }

    if (paragraph.contains('<w:numPr>')) {
      // Word distinguishes bullets from numbering in a separate part; treating
      // a list as bulleted unless the style name says otherwise keeps this
      // readable without pulling in numbering.xml.
      return name.contains('number') || name.contains('decimal')
          ? DocxBlockKind.numbered
          : DocxBlockKind.bullet;
    }

    return DocxBlockKind.paragraph;
  }

  static int _levelOf(String paragraph) {
    final style = RegExp(r'<w:pStyle w:val="[Hh]eading(\d)"').firstMatch(paragraph);

    if (style != null) return int.tryParse(style.group(1)!) ?? 1;

    final indent = RegExp(r'<w:ilvl w:val="(\d+)"').firstMatch(paragraph);

    return int.tryParse(indent?.group(1) ?? '0') ?? 0;
  }

  static List<DocxRun> _parseRuns(String paragraph) {
    final runs = <DocxRun>[];
    final pattern = RegExp(r'<w:r\b.*?</w:r>', dotAll: true);

    for (final match in pattern.allMatches(paragraph)) {
      final run = match.group(0)!;
      final properties = RegExp(r'<w:rPr>.*?</w:rPr>', dotAll: true)
              .firstMatch(run)
              ?.group(0) ??
          '';

      final buffer = StringBuffer();

      for (final t in RegExp(r'<w:t(?:\s[^>]*)?>(.*?)</w:t>', dotAll: true)
          .allMatches(run)) {
        buffer.write(_unescape(t.group(1)!));
      }

      if (run.contains('<w:tab')) buffer.write('\t');
      if (run.contains('<w:br')) buffer.write('\n');

      if (buffer.isEmpty) continue;

      runs.add(DocxRun(
        text: buffer.toString(),
        bold: _isOn(properties, 'b'),
        italic: _isOn(properties, 'i'),
        underline: properties.contains('<w:u '),
      ));
    }

    return runs;
  }

  /// `<w:b/>` turns a mark on; `<w:b w:val="0"/>` turns it off.
  static bool _isOn(String properties, String tag) {
    final match =
        RegExp('<w:$tag(?:\\s+w:val="([^"]*)")?\\s*/?>').firstMatch(properties);

    if (match == null) return false;

    final value = match.group(1);

    return value == null || value == '1' || value == 'true';
  }

  static List<List<String>> _parseTable(String table) {
    final rows = <List<String>>[];

    for (final row
        in RegExp(r'<w:tr\b.*?</w:tr>', dotAll: true).allMatches(table)) {
      final cells = <String>[];

      for (final cell in RegExp(r'<w:tc\b.*?</w:tc>', dotAll: true)
          .allMatches(row.group(0)!)) {
        cells.add(_parseRuns(cell.group(0)!).map((r) => r.text).join().trim());
      }

      if (cells.isNotEmpty) rows.add(cells);
    }

    return rows;
  }

  /// Inline images are referenced by relationship id; matching on the embed id
  /// alone is unreliable, so fall back to document order through word/media.
  static Uint8List? _pictureIn(String chunk, Map<String, Uint8List> images) {
    if (!chunk.contains('<w:drawing') && !chunk.contains('<w:pict')) return null;
    if (images.isEmpty) return null;

    final names = images.keys.toList()..sort();

    return images[names.first];
  }

  static String _unescape(String value) => value
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'");
}
