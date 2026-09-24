import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:pichat/core/theme/app_theme.dart';
import 'package:pichat/features/chat/widgets/file_type_badge.dart';

/// WhatsApp-style media preview screen.
///
/// Shows the picked file before sending, allows an optional caption,
/// and calls [onSend] with the file and caption when the user confirms.
class MediaPreviewScreen extends StatefulWidget {
  final File file;
  final bool isImage;
  final void Function(File file, String? caption) onSend;

  const MediaPreviewScreen({
    super.key,
    required this.file,
    required this.isImage,
    required this.onSend,
  });

  @override
  State<MediaPreviewScreen> createState() => _MediaPreviewScreenState();
}

class _MediaPreviewScreenState extends State<MediaPreviewScreen> {
  final TextEditingController _captionController = TextEditingController();
  bool _isSending = false;

  /// Set for a PDF, so the agent reads what they are about to send instead
  /// of just its file name.
  PdfControllerPinch? _pdf;
  int _page = 1;
  int _pages = 0;

  String get _fileName => widget.file.path.split('/').last;

  String get _extension {
    final name = _fileName;
    return name.contains('.') ? name.split('.').last.toLowerCase() : '';
  }

  @override
  void initState() {
    super.initState();
    if (!widget.isImage && _extension == 'pdf') {
      _pdf = PdfControllerPinch(
        document: PdfDocument.openFile(widget.file.path),
      );
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    _pdf?.dispose();
    super.dispose();
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Any file with no inline preview: its type, name and size.
  Widget _buildFileCard() {
    int? bytes;
    try {
      bytes = widget.file.lengthSync();
    } catch (_) {}

    final details = [
      if (_pages > 0) '$_pages ${_pages == 1 ? 'page' : 'pages'}',
      if (bytes != null) _formatSize(bytes),
      if (_extension.isNotEmpty) _extension.toUpperCase(),
    ].join(' • ');

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FileTypeBadge(extension: _extension, size: 72),
            const SizedBox(height: 16),
            Text(
              _fileName,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (details.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                details,
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    if (widget.isImage) {
      return InteractiveViewer(
        child: Center(
          child: Image.file(widget.file, fit: BoxFit.contain),
        ),
      );
    }

    final pdf = _pdf;
    if (pdf == null) return _buildFileCard();

    return PdfViewPinch(
      controller: pdf,
      backgroundDecoration: const BoxDecoration(color: Colors.black),
      onDocumentLoaded: (document) {
        if (mounted) setState(() => _pages = document.pagesCount);
      },
      onPageChanged: (page) {
        if (mounted) setState(() => _page = page);
      },
      // An encrypted PDF cannot be rendered here (pdfx on iOS); it still
      // sends and opens fine elsewhere, so fall back to the file card.
      builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
        options: const DefaultBuilderOptions(),
        errorBuilder: (_, __) => _buildFileCard(),
      ),
    );
  }

  void _send() {
    if (_isSending) return;
    setState(() => _isSending = true);
    final caption = _captionController.text.trim().isEmpty
        ? null
        : _captionController.text.trim();
    Navigator.of(context).pop();
    widget.onSend(widget.file, caption);
  }

  @override
  Widget build(BuildContext context) {
    final fileName = _fileName;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              fileName,
              style: const TextStyle(fontSize: 14, color: Colors.white70),
              overflow: TextOverflow.ellipsis,
            ),
            if (_pdf != null && _pages > 0)
              Text(
                '$_page / $_pages',
                style: const TextStyle(fontSize: 12, color: Colors.white38),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Preview area
          Expanded(child: _buildPreview()),

          // Caption + send row
          Container(
            color: const Color(0xFF1A1A1A),
            padding: EdgeInsets.only(
              left: 12,
              right: 8,
              top: 8,
              bottom: MediaQuery.of(context).viewInsets.bottom + 8,
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TextField(
                        controller: _captionController,
                        style: const TextStyle(color: Colors.white),
                        maxLines: 4,
                        minLines: 1,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'chat.input.hint'.tr(),
                          hintStyle: const TextStyle(color: Colors.white38),
                          border: InputBorder.none,
                          isDense: true,
                          isCollapsed: true,
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _isSending ? null : _send,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: _isSending
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
