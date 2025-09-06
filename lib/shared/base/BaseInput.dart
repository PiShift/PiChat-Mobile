import 'dart:ui' as ui;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class BaseInput extends StatelessWidget {
  final String? hint;
  final String? errorText;
  final TextAlign textAlign;
  final bool forceLTR;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final bool isObscure;
  final bool isIcon;
  final bool readOnly;
  final TextInputType? inputType;
  final TextEditingController? textController;
  final EdgeInsets padding;
  final Color hintColor;
  final Color iconColor;
  final int? maxLength;
  final int? maxLines;
  final TextStyle? style;
  final InputDecoration? decoration;
  final FocusNode? focusNode;
  final ValueChanged? onFieldSubmitted;
  final ValueChanged? onChanged;
  final void Function()? onTap;
  final bool autoFocus;
  final TextInputAction? inputAction;
  final bool filled;
  final Color? fillColor;
  final Widget? label;
  final double? borderRadius;
  final double? borderWidth;
  final Color? borderColor;
  final String? Function(String)? validator;

  InputDecoration getInputDecoration(String locale) {
    if(forceLTR && locale == 'ar_EG') {
      return InputDecoration(
        border: OutlineInputBorder(
          borderSide: BorderSide(width: borderWidth!, color: borderColor!),
          borderRadius: BorderRadius.all(Radius.circular(borderRadius!)),
        ),
        hintText: hint ?? 'Type...',
        errorText: errorText,
        counterText: '',
        suffixIcon: prefixIcon,
        prefixIcon: suffixIcon,
        prefixStyle: TextStyle(
          locale: Locale('en', 'US'),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(width: borderWidth!, color: borderColor!),
          borderRadius: BorderRadius.all(Radius.circular(borderRadius!)),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(width: borderWidth!, color: borderColor!),
          borderRadius: BorderRadius.all(Radius.circular(borderRadius!)),
        ),
      );
    }else{
      return InputDecoration(
        border: OutlineInputBorder(
          borderSide: BorderSide(width: borderWidth!, color: borderColor!),
          borderRadius: BorderRadius.all(Radius.circular(borderRadius!)),
        ),
        hintText: hint ?? 'Type...',
        errorText: errorText,
        counterText: '',
        suffixIcon: suffixIcon,
        prefixIcon: prefixIcon,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(width: borderWidth!, color: borderColor!),
          borderRadius: BorderRadius.all(Radius.circular(borderRadius!)),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(width: borderWidth!, color: borderColor!),
          borderRadius: BorderRadius.all(Radius.circular(borderRadius!)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if(label != null)...[
            label!,
            const SizedBox(height: 10,),
          ],
          Padding(
            padding: padding,
            child: TextFormField(
              textDirection: forceLTR ? ui.TextDirection.ltr : null,
              textAlign: textAlign,
              controller: textController,
              focusNode: focusNode,
              onFieldSubmitted: onFieldSubmitted,
              onChanged: onChanged,
              onTap: onTap,
              autofocus: autoFocus,
              readOnly: readOnly,
              textInputAction: inputAction ?? TextInputAction.done,
              obscureText: isObscure,
              maxLength: maxLength,
              maxLines: maxLines ?? 1,
              keyboardType: inputType,
              style: style ?? Theme.of(context).textTheme.bodyLarge,
              decoration: decoration != null
                  ? decoration!.copyWith(errorText: errorText)
                  : getInputDecoration(context.locale.toString()),
              validator: validator != null ? (v) => validator!(v!) : null,
            ),
          )
        ],
      ),
    );
  }

  const BaseInput({
    Key? key,
    this.errorText,
    this.textController,
    this.inputType,
    this.hint,
    this.suffixIcon,
    this.prefixIcon,
    this.isObscure = false,
    this.readOnly = false,
    this.textAlign = TextAlign.start,
    this.forceLTR = false,
    this.isIcon = true,
    this.padding = const EdgeInsets.all(0),
    this.hintColor = Colors.grey,
    this.iconColor = Colors.grey,
    this.focusNode,
    this.onFieldSubmitted,
    this.onChanged,
    this.autoFocus = false,
    this.inputAction,
    this.decoration,
    this.maxLines,
    this.maxLength,
    this.style,
    this.filled = true,
    this.fillColor,
    this.onTap,
    this.label,
    this.borderRadius = 0,
    this.borderWidth = 1,
    this.borderColor = Colors.grey,
    this.validator,
  }) : super(key: key);
}