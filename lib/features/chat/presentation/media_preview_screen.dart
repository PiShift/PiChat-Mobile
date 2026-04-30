import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:pichat/core/theme/app_theme.dart';

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

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
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
    final fileName = widget.file.path.split('/').last;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          fileName,
          style: const TextStyle(fontSize: 14, color: Colors.white70),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        children: [
          // Preview area
          Expanded(
            child: widget.isImage
                ? InteractiveViewer(
                    child: Center(
                      child: Image.file(
                        widget.file,
                        fit: BoxFit.contain,
                      ),
                    ),
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.insert_drive_file,
                            size: 80, color: Colors.white54),
                        const SizedBox(height: 16),
                        Text(
                          fileName,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
          ),

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
