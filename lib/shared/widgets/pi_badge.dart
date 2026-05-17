import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pichat/core/theme/app_colors.dart';
import 'package:pichat/core/theme/app_motion.dart';
import 'package:pichat/core/theme/app_radius.dart';

// ─── PiStatusBadge ───────────────────────────────────────────────────────────

enum PiBadgeStatus { open, pending, closed, unread }

/// A small coloured status label badge.
///
/// ```dart
/// PiStatusBadge(status: PiBadgeStatus.open)   // "OPEN" — green
/// PiStatusBadge(status: PiBadgeStatus.unread) // "UNREAD" — primary
/// ```
class PiStatusBadge extends StatelessWidget {
  const PiStatusBadge({super.key, required this.status, this.label});

  final PiBadgeStatus status;

  /// Override the displayed label text.  Defaults to the status name.
  final String? label;

  String get _label {
    return (label ?? status.name).toUpperCase();
  }

  Color get _bg {
    return switch (status) {
      PiBadgeStatus.open    => PiPalette.success100,
      PiBadgeStatus.pending => PiPalette.warning100,
      PiBadgeStatus.closed  => PiPalette.ink100,
      PiBadgeStatus.unread  => PiPalette.primary500,
    };
  }

  Color get _fg {
    return switch (status) {
      PiBadgeStatus.open    => PiPalette.success500,
      PiBadgeStatus.pending => PiPalette.warning500,
      PiBadgeStatus.closed  => PiPalette.ink500,
      PiBadgeStatus.unread  => PiPalette.white,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: PiRadius.brXS,
      ),
      alignment: Alignment.center,
      child: Text(
        _label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: _fg,
          height: 1,
        ),
      ),
    );
  }
}

// ─── PiCountBadge ────────────────────────────────────────────────────────────

/// A circular unread-count badge.
///
/// Minimum size 20 × 20. Expands horizontally for counts ≥ 100.
///
/// ```dart
/// PiCountBadge(count: 3)
/// PiCountBadge(count: 99, maxCount: 99)
/// ```
class PiCountBadge extends StatelessWidget {
  const PiCountBadge({super.key, required this.count, this.maxCount = 99});

  final int count;
  final int maxCount;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return const SizedBox.shrink();
    }

    final label = count > maxCount ? '$maxCount+' : '$count';

    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: const BoxDecoration(
        color: PiPalette.primary500,
        borderRadius: PiRadius.brFull,
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: PiPalette.white,
          height: 1,
        ),
      ),
    );
  }
}

// ─── PiFilterChip ────────────────────────────────────────────────────────────

/// A toggleable filter chip — h32, radiusFull.
///
/// Active:   primary500 background, white text.
/// Inactive: transparent background, ink100 border, ink600 text.
///
/// ```dart
/// PiFilterChip(label: 'All', isActive: true, onTap: () { ... })
/// ```
class PiFilterChip extends StatelessWidget {
  const PiFilterChip({
    super.key,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.leadingIcon,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Widget? leadingIcon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: PiMotion.fast,
        curve: PiMotion.easeOut,
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isActive ? PiPalette.primary500 : Colors.transparent,
          borderRadius: PiRadius.brFull,
          border: isActive
              ? null
              : Border.all(color: PiColors.of(context).divider, width: 1),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leadingIcon != null) ...[
              IconTheme(
                data: IconThemeData(
                  size: 14,
                  color: isActive ? PiPalette.white : PiColors.of(context).textSecondary,
                ),
                child: leadingIcon!,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive ? PiPalette.white : PiColors.of(context).textSecondary,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
