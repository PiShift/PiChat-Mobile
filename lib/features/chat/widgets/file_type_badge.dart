import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A coloured badge naming a file's type, drawn rather than shipped as assets.
///
/// Keeps the bubble honest about what an attachment actually is — a red block
/// on every document told the agent nothing — and avoids bundling or fetching
/// an icon set.
class FileTypeBadge extends StatelessWidget {
  const FileTypeBadge({required this.extension, this.size = 34, super.key});

  final String extension;
  final double size;

  static const _colors = <String, Color>{
    'pdf': Color(0xFFE5342A),
    'doc': Color(0xFF2B579A),
    'docx': Color(0xFF2B579A),
    'xls': Color(0xFF1D7044),
    'xlsx': Color(0xFF1D7044),
    'csv': Color(0xFF1D7044),
    'ppt': Color(0xFFD24726),
    'pptx': Color(0xFFD24726),
    'json': Color(0xFF6B7280),
    'xml': Color(0xFF6B7280),
    'txt': Color(0xFF6B7280),
    'zip': Color(0xFF9A6700),
    'rar': Color(0xFF9A6700),
  };

  String get _label {
    final ext = extension.toLowerCase().replaceAll('.', '');

    if (ext.isEmpty) return 'FILE';

    return ext.length > 4 ? ext.substring(0, 4).toUpperCase() : ext.toUpperCase();
  }

  Color get _color =>
      _colors[extension.toLowerCase().replaceAll('.', '')] ??
      const Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 1.18,
      child: CustomPaint(
        painter: _SheetPainter(_color),
        child: Center(
          child: Padding(
            // Sits below the folded corner.
            padding: EdgeInsets.only(top: size * 0.24),
            child: FittedBox(
              child: Text(
                _label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: size * 0.3,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A page with its top-right corner turned down.
class _SheetPainter extends CustomPainter {
  _SheetPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final fold = size.width * 0.32;
    final radius = size.width * 0.14;

    final body = Path()
      ..moveTo(radius, 0)
      ..lineTo(size.width - fold, 0)
      ..lineTo(size.width, fold)
      ..lineTo(size.width, size.height - radius)
      ..arcToPoint(
        Offset(size.width - radius, size.height),
        radius: Radius.circular(radius),
      )
      ..lineTo(radius, size.height)
      ..arcToPoint(Offset(0, size.height - radius),
          radius: Radius.circular(radius))
      ..lineTo(0, radius)
      ..arcToPoint(Offset(radius, 0), radius: Radius.circular(radius))
      ..close();

    canvas.drawPath(body, Paint()..color = color);

    // The turned corner, lightened so the fold reads.
    final corner = Path()
      ..moveTo(size.width - fold, 0)
      ..lineTo(size.width, fold)
      ..lineTo(size.width - fold, fold)
      ..close();

    canvas.drawPath(
      corner,
      Paint()..color = Colors.white.withValues(alpha: 0.35),
    );
  }

  @override
  bool shouldRepaint(_SheetPainter old) => old.color != color;
}
