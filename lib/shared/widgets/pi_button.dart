import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pichat/core/theme/app_colors.dart';
import 'package:pichat/core/theme/app_motion.dart';
import 'package:pichat/core/theme/app_radius.dart';
import 'package:pichat/core/theme/app_shadows.dart';

// ─── Variant ─────────────────────────────────────────────────────────────────

enum PiButtonVariant {
  /// h48, radiusFull, primary500 fill, white text.
  primary,

  /// h48, radiusFull, outlined 1.5 px primary500, transparent fill.
  secondary,

  /// h40, radiusSM, transparent, primary500 text.
  ghost,

  /// h48, radiusFull, error500 fill, white text.
  destructive,
}

// ─── PiButton ────────────────────────────────────────────────────────────────

/// A design-system button.
///
/// Build from Flutter primitives (no ElevatedButton / TextButton / etc.).
///
/// ```dart
/// PiButton(label: 'Send', onTap: _send)
/// PiButton.secondary(label: 'Cancel', onTap: _cancel)
/// PiButton.ghost(label: 'Skip', onTap: _skip)
/// PiButton.destructive(label: 'Delete', onTap: _delete)
/// ```
class PiButton extends StatefulWidget {
  const PiButton({
    super.key,
    required this.label,
    required this.onTap,
    this.variant = PiButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.isDisabled = false,
    this.expand = true,
  });

  const PiButton.secondary({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.isLoading = false,
    this.isDisabled = false,
    this.expand = true,
  }) : variant = PiButtonVariant.secondary;

  const PiButton.ghost({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.isLoading = false,
    this.isDisabled = false,
    this.expand = true,
  }) : variant = PiButtonVariant.ghost;

  const PiButton.destructive({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.isLoading = false,
    this.isDisabled = false,
    this.expand = true,
  }) : variant = PiButtonVariant.destructive;

  final String label;
  final VoidCallback? onTap;
  final PiButtonVariant variant;

  /// Optional leading icon widget (e.g. `Icon(LucideIcons.send, size: 18)`).
  final Widget? icon;

  final bool isLoading;
  final bool isDisabled;

  /// When true the button fills its parent's width.
  final bool expand;

  @override
  State<PiButton> createState() => _PiButtonState();
}

class _PiButtonState extends State<PiButton> {
  bool _pressed = false;

  // ── Geometry ───────────────────────────────────────────────────────────────

  double get _height {
    return switch (widget.variant) {
      PiButtonVariant.ghost => 40,
      _ => 48,
    };
  }

  BorderRadius get _radius {
    return switch (widget.variant) {
      PiButtonVariant.ghost => PiRadius.brSM,
      _ => PiRadius.brFull,
    };
  }

  // ── Colors ─────────────────────────────────────────────────────────────────

  Color _background(BuildContext context) {
    if (widget.isDisabled) {
      return switch (widget.variant) {
        PiButtonVariant.primary      => PiPalette.primary200,
        PiButtonVariant.destructive  => PiPalette.error100,
        _ => Colors.transparent,
      };
    }

    return switch (widget.variant) {
      PiButtonVariant.primary when _pressed      => PiPalette.primary600,
      PiButtonVariant.primary                    => PiPalette.primary500,
      PiButtonVariant.destructive when _pressed  => const Color(0xFFB91C1C),
      PiButtonVariant.destructive                => PiPalette.error500,
      PiButtonVariant.ghost when _pressed        => PiPalette.primary50,
      _ => Colors.transparent,
    };
  }

  Border? _border(BuildContext context) {
    return switch (widget.variant) {
      PiButtonVariant.secondary => Border.all(
          color: widget.isDisabled ? PiPalette.primary200 : PiPalette.primary500,
          width: 1.5,
        ),
      _ => null,
    };
  }

  Color _textColor(BuildContext context) {
    if (widget.isDisabled) {
      return switch (widget.variant) {
        PiButtonVariant.primary     => PiPalette.ink400,
        PiButtonVariant.destructive => PiPalette.ink400,
        _ => PiPalette.primary200,
      };
    }

    return switch (widget.variant) {
      PiButtonVariant.primary      => PiPalette.white,
      PiButtonVariant.destructive  => PiPalette.white,
      _ => PiPalette.primary500,
    };
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final textColor = _textColor(context);
    final isActive  = !widget.isDisabled && !widget.isLoading;

    final child = AnimatedContainer(
      duration: PiMotion.fast,
      curve: PiMotion.easeOut,
      height: _height,
      decoration: BoxDecoration(
        color: _background(context),
        borderRadius: _radius,
        border: _border(context),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: Alignment.center,
      child: widget.isLoading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(textColor),
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  widget.icon!,
                  const SizedBox(width: 8),
                ],
                Text(
                  widget.label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                    height: 1,
                  ),
                ),
              ],
            ),
    );

    return Semantics(
      button: true,
      enabled: isActive,
      label: widget.label,
      child: GestureDetector(
        onTapDown: isActive ? (_) => setState(() => _pressed = true) : null,
        onTapUp: isActive
            ? (_) {
                setState(() => _pressed = false);
                widget.onTap?.call();
              }
            : null,
        onTapCancel: isActive ? () => setState(() => _pressed = false) : null,
        child: widget.expand ? SizedBox(width: double.infinity, child: child) : child,
      ),
    );
  }
}

// ─── PiIconButton ────────────────────────────────────────────────────────────

/// A 40 × 40 circular icon-only button.
class PiIconButton extends StatefulWidget {
  const PiIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.semanticLabel,
    this.size = 40,
    this.iconSize = 22,
    this.iconColor,
    this.backgroundColor,
    this.pressedColor,
  });

  final Widget icon;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final double size;
  final double iconSize;
  final Color? iconColor;
  final Color? backgroundColor;
  final Color? pressedColor;

  @override
  State<PiIconButton> createState() => _PiIconButtonState();
}

class _PiIconButtonState extends State<PiIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap?.call();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: PiMotion.fast,
          curve: PiMotion.easeOut,
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: _pressed
                ? (widget.pressedColor ?? PiPalette.ink100)
                : (widget.backgroundColor ?? Colors.transparent),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: IconTheme(
            data: IconThemeData(
              size: widget.iconSize,
              color: widget.iconColor ?? PiPalette.ink600,
            ),
            child: widget.icon,
          ),
        ),
      ),
    );
  }
}

// ─── PiFab ───────────────────────────────────────────────────────────────────

/// Floating action button — 56 × 56, primary500, shadow3.
class PiFab extends StatefulWidget {
  const PiFab({
    super.key,
    required this.icon,
    required this.onTap,
    this.semanticLabel = 'Floating action button',
  });

  final Widget icon;
  final VoidCallback onTap;
  final String semanticLabel;

  @override
  State<PiFab> createState() => _PiFabState();
}

class _PiFabState extends State<PiFab> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: PiMotion.fast,
          curve: PiMotion.easeOut,
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: _pressed ? PiPalette.primary600 : PiPalette.primary500,
            shape: BoxShape.circle,
            boxShadow: PiShadow.shadow3,
          ),
          alignment: Alignment.center,
          child: IconTheme(
            data: const IconThemeData(size: 24, color: PiPalette.white),
            child: widget.icon,
          ),
        ),
      ),
    );
  }
}
