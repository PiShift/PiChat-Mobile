import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:open_file/open_file.dart';
import 'package:pichat/core/theme/app_colors.dart';
import 'package:pichat/features/chat/application/docx_document.dart';

/// Renders a Word document with its structure and character formatting intact.
///
/// Everything here is Flutter drawing Dart-parsed content, so an agent sees the
/// same document on Android, iOS or anywhere else — no native viewer involved
/// and no dependency on which apps a device happens to have installed.
class DocxViewerScreen extends StatefulWidget {
  const DocxViewerScreen({required this.path, this.title, super.key});

  final String path;
  final String? title;

  @override
  State<DocxViewerScreen> createState() => _DocxViewerScreenState();
}

class _DocxViewerScreenState extends State<DocxViewerScreen> {
  DocxDocument? _document;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final parsed = await DocxDocument.parse(widget.path);

    if (!mounted) return;

    setState(() {
      _document = parsed;
      _failed = parsed == null || parsed.blocks.isEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = PiColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, size: 22),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.title ?? 'Document',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Open in…',
            icon: const Icon(LucideIcons.externalLink, size: 19),
            onPressed: () => OpenFile.open(widget.path),
          ),
        ],
      ),
      body: _failed
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'This document could not be read.',
                  style: GoogleFonts.plusJakartaSans(color: colors.textSecondary),
                ),
              ),
            )
          : _document == null
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  // A page-like column on a tinted ground, so it reads as a
                  // document rather than a wall of chat text.
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 16,
                  ),
                  itemCount: _document!.blocks.length,
                  itemBuilder: (context, index) =>
                      _block(_document!.blocks[index], colors),
                ),
    );
  }

  Widget _block(DocxBlock block, PiColors colors) {
    switch (block.kind) {
      case DocxBlockKind.image:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(block.image!, fit: BoxFit.contain),
          ),
        );

      case DocxBlockKind.table:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              defaultColumnWidth: const IntrinsicColumnWidth(),
              border: TableBorder.all(color: colors.divider),
              children: [
                for (var r = 0; r < block.rows.length; r++)
                  TableRow(
                    // Word's first row is a header far more often than not.
                    decoration: r == 0
                        ? BoxDecoration(color: colors.surfaceRaised)
                        : null,
                    children: [
                      for (final cell in block.rows[r])
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          child: Text(
                            cell,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              fontWeight:
                                  r == 0 ? FontWeight.w700 : FontWeight.w400,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        );

      case DocxBlockKind.heading:
        return Padding(
          padding: EdgeInsets.only(top: block.level <= 1 ? 20 : 14, bottom: 6),
          child: _text(
            block,
            colors,
            size: switch (block.level) { 0 || 1 => 21.0, 2 => 18.0, _ => 15.5 },
            weight: FontWeight.w700,
          ),
        );

      case DocxBlockKind.bullet:
      case DocxBlockKind.numbered:
        return Padding(
          padding: EdgeInsets.only(
            left: 6 + block.level * 16.0,
            top: 3,
            bottom: 3,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6, right: 8),
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: colors.textSecondary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Expanded(child: _text(block, colors)),
            ],
          ),
        );

      case DocxBlockKind.paragraph:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: _text(block, colors),
        );
    }
  }

  /// Character formatting is carried per run, so a paragraph becomes one
  /// RichText with a span per run rather than a single flat string.
  Widget _text(
    DocxBlock block,
    PiColors colors, {
    double size = 14.5,
    FontWeight weight = FontWeight.w400,
  }) {
    return SelectableText.rich(
      TextSpan(
        children: [
          for (final run in block.runs)
            TextSpan(
              text: run.text,
              style: GoogleFonts.plusJakartaSans(
                fontSize: size,
                height: 1.55,
                color: colors.textPrimary,
                fontWeight: run.bold ? FontWeight.w700 : weight,
                fontStyle: run.italic ? FontStyle.italic : FontStyle.normal,
                decoration:
                    run.underline ? TextDecoration.underline : TextDecoration.none,
              ),
            ),
        ],
      ),
    );
  }
}
