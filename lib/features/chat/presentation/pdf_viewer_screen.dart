import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:open_file/open_file.dart';
import 'package:pdfx/pdfx.dart';
import 'package:pichat/core/theme/app_colors.dart';

/// Reads a PDF inside the app.
///
/// Handing the file to the OS viewer pushed the agent out of PiChat and, on a
/// shared device, into whatever app happened to claim the type. Opening it here
/// keeps them in the conversation; "Open in…" is still offered for anything
/// they want to do outside.
class PdfViewerScreen extends StatefulWidget {
  const PdfViewerScreen({
    required this.path,
    this.title,
    super.key,
  });

  final String path;
  final String? title;

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  late final PdfControllerPinch _controller;
  int _page = 1;
  int _pages = 0;

  @override
  void initState() {
    super.initState();
    _controller = PdfControllerPinch(
      document: PdfDocument.openFile(widget.path),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title ?? 'Document',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (_pages > 0)
              Text(
                '$_page / $_pages',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: colors.textSecondary,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Open in…'.tr(),
            icon: const Icon(LucideIcons.externalLink, size: 20),
            onPressed: () => OpenFile.open(widget.path),
          ),
        ],
      ),
      body: PdfViewPinch(
        controller: _controller,
        onDocumentLoaded: (document) {
          if (mounted) setState(() => _pages = document.pagesCount);
        },
        onPageChanged: (page) {
          if (mounted) setState(() => _page = page);
        },
      ),
    );
  }
}
