import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pichat/core/theme/app_colors.dart';
import 'package:pichat/core/theme/app_motion.dart';
import 'package:pichat/core/theme/app_radius.dart';
import 'package:pichat/core/theme/app_spacing.dart';

// ─── PiInput ─────────────────────────────────────────────────────────────────

/// A standard single-line / multi-line text field.
///
/// Spec: h52, radiusSM, fill ink50 (unfocused) / white (focused),
/// border 1 px ink200 → 2 px primary500 (focused) → 2 px error500 (error).
///
/// ```dart
/// PiInput(
///   controller: _ctrl,
///   label: 'Email',
///   hint: 'you@example.com',
///   prefixIcon: Icon(LucideIcons.mail),
/// )
/// ```
class PiInput extends StatefulWidget {
  const PiInput({
    super.key,
    this.controller,
    this.focusNode,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.isObscure = false,
    this.readOnly = false,
    this.maxLines = 1,
    this.maxLength,
    this.inputType,
    this.inputAction,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.validator,
    this.enabled = true,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool isObscure;
  final bool readOnly;
  final int maxLines;
  final int? maxLength;
  final TextInputType? inputType;
  final TextInputAction? inputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final String? Function(String?)? validator;
  final bool enabled;

  @override
  State<PiInput> createState() => _PiInputState();
}

class _PiInputState extends State<PiInput> {
  late final FocusNode _focus;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus = widget.focusNode ?? FocusNode();
    _focus.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    setState(() => _focused = _focus.hasFocus);
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focus.removeListener(_onFocusChange);
      _focus.dispose();
    }
    super.dispose();
  }

  bool get _hasError => widget.errorText != null && widget.errorText!.isNotEmpty;

  Color get _borderColor {
    if (_hasError) return PiPalette.error500;
    if (_focused) return PiPalette.primary500;
    return PiPalette.ink200;
  }

  double get _borderWidth {
    if (_hasError || _focused) return 2;
    return 1;
  }

  Color get _fillColor => _focused ? PiPalette.white : PiPalette.ink50;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Optional label ──────────────────────────────────────────────────
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: PiColors.of(context).textPrimary,
            ),
          ),
          const SizedBox(height: PiSpacing.space6),
        ],

        // ── Animated border container ────────────────────────────────────────
        AnimatedContainer(
          duration: PiMotion.fast,
          curve: PiMotion.easeOut,
          decoration: BoxDecoration(
            color: _fillColor,
            borderRadius: PiRadius.brSM,
            border: Border.all(color: _borderColor, width: _borderWidth),
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focus,
            obscureText: widget.isObscure,
            readOnly: widget.readOnly,
            maxLines: widget.maxLines,
            maxLength: widget.maxLength,
            keyboardType: widget.inputType,
            textInputAction: widget.inputAction,
            enabled: widget.enabled,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            onTap: widget.onTap,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: PiColors.of(context).textPrimary,
            ),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: PiPalette.ink400,
              ),
              prefixIcon: widget.prefixIcon != null
                  ? Padding(
                      padding: const EdgeInsets.only(left: 12, right: 8),
                      child: IconTheme(
                        data: const IconThemeData(size: 18, color: PiPalette.ink400),
                        child: widget.prefixIcon!,
                      ),
                    )
                  : null,
              prefixIconConstraints: const BoxConstraints(),
              suffixIcon: widget.suffixIcon != null
                  ? Padding(
                      padding: const EdgeInsets.only(left: 8, right: 12),
                      child: IconTheme(
                        data: const IconThemeData(size: 18, color: PiPalette.ink400),
                        child: widget.suffixIcon!,
                      ),
                    )
                  : null,
              suffixIconConstraints: const BoxConstraints(),
              // Override theme borders — we handle them via AnimatedContainer.
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              isDense: true,
              filled: false,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: PiSpacing.space16,
                vertical: PiSpacing.space16,
              ),
              counterText: '',
            ),
          ),
        ),

        // ── Error / helper text ─────────────────────────────────────────────
        if (_hasError || widget.helperText != null) ...[
          const SizedBox(height: PiSpacing.space4),
          Text(
            _hasError ? widget.errorText! : widget.helperText!,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: _hasError ? PiPalette.error500 : PiPalette.ink400,
            ),
          ),
        ],
      ],
    );
  }
}

// ─── PiSearchInput ────────────────────────────────────────────────────────────

/// A search-variant input — h44, radiusFull, ink100 fill,
/// no border unfocused → 1.5 px primary500 border focused.
///
/// ```dart
/// PiSearchInput(
///   controller: _ctrl,
///   hint: 'Search contacts...',
///   onChanged: _filter,
/// )
/// ```
class PiSearchInput extends StatefulWidget {
  const PiSearchInput({
    super.key,
    this.controller,
    this.focusNode,
    this.hint = 'Search…',
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.autofocus = false,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final bool autofocus;

  @override
  State<PiSearchInput> createState() => _PiSearchInputState();
}

class _PiSearchInputState extends State<PiSearchInput> {
  late final FocusNode _focus;
  bool _focused = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _focus = widget.focusNode ?? FocusNode();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
    widget.controller?.addListener(_onTextChanged);
    _hasText = widget.controller?.text.isNotEmpty ?? false;
  }

  void _onTextChanged() {
    if (!mounted) return;
    final hasText = widget.controller?.text.isNotEmpty ?? false;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onTextChanged);
    if (widget.focusNode == null) _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: PiMotion.fast,
      curve: PiMotion.easeOut,
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: PiSpacing.space16),
      decoration: BoxDecoration(
        color: PiColors.of(context).surface,
        borderRadius: PiRadius.brFull,
        border: _focused
            ? Border.all(color: PiPalette.primary500, width: 1.5)
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 14, right: 8),
            child: Icon(LucideIcons.search, size: 18, color: PiPalette.ink400),
          ),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              autofocus: widget.autofocus,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              textInputAction: TextInputAction.search,
              textAlignVertical: TextAlignVertical.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: PiColors.of(context).textPrimary,
              ),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: PiPalette.ink400,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          if (widget.onClear != null && _hasText)
            GestureDetector(
              onTap: () {
                widget.controller?.clear();
                widget.onClear?.call();
              },
              child: const Padding(
                padding: EdgeInsets.only(right: 14, left: 4),
                child: Icon(LucideIcons.x, size: 16, color: PiPalette.ink400),
              ),
            )
          else
            const SizedBox(width: 14),
        ],
      ),
    );
  }
}
