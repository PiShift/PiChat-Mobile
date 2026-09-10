import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:open_file/open_file.dart';

/// Full-screen image, consistent with the video and PDF viewers.
class ImageViewerScreen extends StatelessWidget {
  const ImageViewerScreen({
    required this.path,
    this.networkUrl,
    this.title,
    super.key,
  });

  final String? path;
  final String? networkUrl;
  final String? title;

  /// Meta rarely sends a filename for photos, so the media row carries "N/A".
  String get _displayTitle {
    final name = title?.trim();

    if (name == null || name.isEmpty || name.toUpperCase() == 'N/A') {
      return 'Photo';
    }

    return name;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, size: 22),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _displayTitle,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (path != null)
            IconButton(
              tooltip: 'Open in…',
              icon: const Icon(LucideIcons.externalLink, size: 19),
              onPressed: () => OpenFile.open(path),
            ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: path != null
              ? Image.file(File(path!), fit: BoxFit.contain)
              : networkUrl != null
                  ? Image.network(networkUrl!, fit: BoxFit.contain)
                  : const SizedBox.shrink(),
        ),
      ),
    );
  }
}
