import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pichat/core/theme/app_colors.dart';

// ─── Size enum ────────────────────────────────────────────────────────────────

enum PiAvatarSize { xs, sm, md, lg, xl }

extension _PiAvatarSizeExt on PiAvatarSize {
  double get dimension {
    return switch (this) {
      PiAvatarSize.xs => 28,
      PiAvatarSize.sm => 36,
      PiAvatarSize.md => 44,
      PiAvatarSize.lg => 56,
      PiAvatarSize.xl => 80,
    };
  }

  double get fontSize {
    return switch (this) {
      PiAvatarSize.xs => 10,
      PiAvatarSize.sm => 13,
      PiAvatarSize.md => 16,
      PiAvatarSize.lg => 20,
      PiAvatarSize.xl => 28,
    };
  }
}

// ─── Fallback palette ────────────────────────────────────────────────────────

/// 6 muted background colours for avatar fallback, deterministically chosen
/// from the contact's display name.
const List<Color> _fallbackBg = [
  Color(0xFFE8D5FF), // lavender
  Color(0xFFD5E8FF), // sky blue
  Color(0xFFD5FFE8), // mint
  Color(0xFFFFE8D5), // peach
  Color(0xFFFFD5D5), // blush
  Color(0xFFD5F0FF), // powder blue
];

/// Matching darker foreground text colours for each background.
const List<Color> _fallbackFg = [
  Color(0xFF7C3AED), // purple 600
  Color(0xFF2563EB), // blue 600
  Color(0xFF059669), // emerald 600
  Color(0xFFD97706), // amber 600
  Color(0xFFDC2626), // red 600
  Color(0xFF0284C7), // sky 600
];

// ─── PiAvatar ─────────────────────────────────────────────────────────────────

/// A design-system avatar.
///
/// Shows a network image when [imageUrl] is provided.
/// Falls back to a coloured circle with initials extracted from [name].
///
/// Optional status indicators:
/// - [showOnline] — green dot (success500).
/// - [showUnread] — primary500 dot (replaces online dot).
///
/// ```dart
/// PiAvatar(name: 'Alice Martin', imageUrl: contact.avatarUrl)
/// PiAvatar(name: 'Bob', size: PiAvatarSize.lg, showOnline: true)
/// ```
class PiAvatar extends StatelessWidget {
  const PiAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = PiAvatarSize.md,
    this.showOnline = false,
    this.showUnread = false,
  });

  final String name;
  final String? imageUrl;
  final PiAvatarSize size;
  final bool showOnline;
  final bool showUnread;

  // ── Helpers ───────────────────────────────────────────────────────────────

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isEmpty ? '?' : name[0].toUpperCase();
  }

  /// Deterministically pick a fallback colour index from the name.
  int get _colorIndex {
    int hash = 0;
    for (final codeUnit in name.codeUnits) {
      hash = codeUnit + ((hash << 5) - hash);
    }
    return hash.abs() % _fallbackBg.length;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final d = size.dimension;
    final dotSize = 10.0;
    final dotOffset = d * 0.07;

    return SizedBox(
      width: d,
      height: d,
      child: Stack(
        children: [
          // ── Avatar circle ───────────────────────────────────────────────
          ClipOval(
            child: SizedBox.square(
              dimension: d,
              child: _buildImage(d),
            ),
          ),

          // ── Status indicator dot ────────────────────────────────────────
          if (showOnline || showUnread)
            Positioned(
              bottom: dotOffset,
              right: dotOffset,
              child: Container(
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  color: showUnread ? PiPalette.primary500 : PiPalette.success500,
                  shape: BoxShape.circle,
                  border: Border.all(color: PiPalette.white, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImage(double d) {
    final url = imageUrl;
    if (url != null && url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        width: d,
        height: d,
        errorWidget: (_, __, ___) => _buildFallback(d),
        placeholder: (_, __) => _buildFallback(d),
      );
    }
    return _buildFallback(d);
  }

  Widget _buildFallback(double d) {
    final idx = _colorIndex;
    return Container(
      width: d,
      height: d,
      color: _fallbackBg[idx],
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: GoogleFonts.plusJakartaSans(
          fontSize: size.fontSize,
          fontWeight: FontWeight.w600,
          color: _fallbackFg[idx],
          height: 1,
        ),
      ),
    );
  }
}
