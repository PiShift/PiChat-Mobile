import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pichat/core/theme/app_colors.dart';

/// The rounded day label used both as an inline separator between day groups
/// and as the chip pinned at the top of the thread while scrolling.
///
/// One widget for both so the pinned chip is visually identical to the
/// separator it stands in for — the pinned one is what an inline separator
/// looks like once it has scrolled past the top edge.
class ChatDateChip extends StatelessWidget {
  const ChatDateChip({
    required this.label,
    this.elevated = false,
    super.key,
  });

  final String label;

  /// Adds a shadow. Used by the pinned chip, which floats over messages and
  /// needs to read as being in front of them.
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final colors = PiColors.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.divider),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: colors.textSecondary,
          height: 1.2,
        ),
      ),
    );
  }
}

/// Inline separator: the chip centred on its own row between two days.
class ChatDateSeparator extends StatelessWidget {
  const ChatDateSeparator({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(child: ChatDateChip(label: label)),
    );
  }
}
