import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pichat/core/theme/app_theme.dart';

class BaseButton extends StatefulWidget {
  dynamic onTap;
  final String text;
  dynamic color;
  dynamic borcolor;
  dynamic textColor;
  double? textSize;
  dynamic width;
  dynamic height;
  String type;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final double? borderRadius;
  final bool? disabled;
  final bool? underline;
  final bool? isLoading;

  // ignore: use_key_in_widget_constructors
  BaseButton(
      {required this.onTap,
        required this.text,
        this.color,
        this.borcolor,
        this.textColor,
        this.textSize,
        this.width,
        this.height,
        this.type = "normal",
        this.suffixIcon,
        this.prefixIcon,
        this.borderRadius,
        this.disabled = false,
        this.underline = false,
        this.isLoading = false
      });

  @override
  _BaseButtonState createState() => _BaseButtonState();
}

class _BaseButtonState extends State<BaseButton> {
  @override
  Widget build(BuildContext context) {
    var media = MediaQuery.of(context).size;

    return InkWell(
      onTap: widget.disabled == true ? null : (widget.onTap != null ? () => widget.onTap() : null),
      child: Container(
        height: widget.height ?? media.height * .07,
        width: widget.width ?? media.width * 1,
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius ?? 5),
            color: widget.type == "outline" || widget.type == "text" ?
            Colors.transparent :
            widget.disabled == true ?
            (widget.color != null ? widget.color.withOpacity(.5) : AppColors.primary.withOpacity(.5)) :
            widget.color ?? AppColors.primary,
            border: Border.all(
              color: widget.type == "text" ? Colors.transparent : widget.disabled == true ?
              (widget.borcolor != null ? widget.borcolor.withOpacity(.5) : AppColors.primary.withOpacity(.5)) :
              widget.borcolor ?? AppColors.primary,
              width: widget.type == "text" ? 0 : 1.5,
            )),
        alignment: Alignment.center,
        child: FittedBox(
            fit: BoxFit.contain,
            child: Container(
              padding: widget.type == "text" ? EdgeInsets.all(0) : EdgeInsets.only(left: media.width * 0.053, right: media.width * 0.053),
              decoration: widget.underline == true ? BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: widget.disabled == true ?
                    (widget.borcolor != null ? widget.borcolor.withOpacity(.5) : AppColors.primary.withOpacity(.5)) :
                    widget.borcolor ?? AppColors.primary,
                    width: 1.0,
                  ),
                ),
              ) : null,
              child: widget.isLoading! ?
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  widget.type == "outline" || widget.type == "text" ? AppColors.primary : Colors.white
                ),
                strokeWidth: 1.5,
              )
              : Row(
                children: [
                  if (widget.prefixIcon != null)...[
                    widget.prefixIcon!,
                    SizedBox(
                      width: media.width * 0.02,
                    )
                  ],
                  Text(
                    widget.text,
                    style: GoogleFonts.roboto(
                        fontSize: widget.textSize ?? media.width * 0.045,
                        color: widget.type == "outline" || widget.type == "text" ?
                        widget.disabled == true ?
                        (widget.textColor != null ? widget.textColor.withOpacity(.5) : AppColors.primary.withOpacity(.5)) :
                        widget.textColor ?? AppColors.primary :
                        widget.textColor ?? Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1),
                  ),
                  if (widget.suffixIcon != null)...[
                    SizedBox(
                      width: media.width * 0.02,
                    ),
                    widget.suffixIcon!,
                  ]
                ],
              ),
            )
        ),
      ),
    );
  }
}