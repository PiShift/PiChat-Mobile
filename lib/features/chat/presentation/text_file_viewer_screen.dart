import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:open_file/open_file.dart';
import 'package:pichat/core/theme/app_colors.dart';
import 'package:pichat/features/chat/application/office_text_extractor.dart';

/// Reads text-based attachments in the app.
///
/// iOS has no preview handler for several types an agent is routinely sent —
/// .json most of all — so tapping them did nothing at all. Rendering the text
/// here means the agent can read the contents without leaving the conversation
/// or hunting for a third-party app.
class TextFileViewerScreen extends StatefulWidget {
  const TextFileViewerScreen({
    required this.path,
    this.title,
    super.key,
  });

  final String path;
  final String? title;

  /// Types worth rendering as text rather than handing to the system.
  static const supportedExtensions = <String>{
    'json',
    'csv',
    'txt',
    'log',
    'xml',
    'md',
    'yml',
    'yaml',
    'ini',
    'tsv',
  };

  static bool handles(String? fileName) {
    if (fileName == null || !fileName.contains('.')) return false;

    final ext = fileName.split('.').last.toLowerCase();

    // Office files are read in Dart too, so an agent sees the same thing on
    // Android and iOS rather than whatever viewer the device happens to have.
    return supportedExtensions.contains(ext) ||
        OfficeTextExtractor.supportedExtensions.contains(ext);
  }

  @override
  State<TextFileViewerScreen> createState() => _TextFileViewerScreenState();
}

class _TextFileViewerScreenState extends State<TextFileViewerScreen> {
  String? _contents;
  String? _error;

  /// True when the text was pulled out of an Office file, so the reader can be
  /// told that formatting has been dropped.
  bool _isExtracted = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      if (OfficeTextExtractor.handles(widget.title)) {
        final text =
            await OfficeTextExtractor.extract(widget.path, widget.title);

        setState(() {
          if (text == null || text.trim().isEmpty) {
            _error = 'No readable text was found in this document.\n'
                'Use "Open in…" to view it with its original formatting.';
          } else {
            _contents = text;
            _isExtracted = true;
          }
        });

        return;
      }

      final raw = await File(widget.path).readAsString();

      setState(() => _contents = _prettify(raw));
    } catch (e) {
      setState(() => _error = 'This file could not be read as text.');
    }
  }

  /// JSON arrives minified far more often than not, which is unreadable on a
  /// phone. Indent it when it parses; leave anything else exactly as it is.
  String _prettify(String raw) {
    final name = widget.title?.toLowerCase() ?? '';

    if (!name.endsWith('.json')) return raw;

    try {
      return const JsonEncoder.withIndent('  ').convert(jsonDecode(raw));
    } catch (_) {
      return raw;
    }
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
          widget.title ?? 'File',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_contents != null)
            IconButton(
              tooltip: 'Copy',
              icon: const Icon(LucideIcons.copy, size: 19),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _contents!));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied')),
                );
              },
            ),
          IconButton(
            tooltip: 'Open in…',
            icon: const Icon(LucideIcons.externalLink, size: 19),
            onPressed: () => OpenFile.open(widget.path),
          ),
        ],
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style:
                      GoogleFonts.plusJakartaSans(color: colors.textSecondary),
                ),
              ),
            )
          : _contents == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_isExtracted)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        color: colors.surfaceRaised,
                        child: Text(
                          'Text only — open in another app to see the original '
                          'formatting.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    Expanded(
                      child: Scrollbar(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(14),
                          child: SingleChildScrollView(
                            // Long lines scroll sideways rather than wrapping,
                            // which keeps CSV columns and JSON indentation
                            // readable.
                            scrollDirection: Axis.horizontal,
                            child: SelectableText(
                              _contents!,
                              style: GoogleFonts.robotoMono(
                                fontSize: 12,
                                height: 1.45,
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
