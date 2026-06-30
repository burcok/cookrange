import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_typography.dart';

/// Cookrange DS — branded text input field.
///
/// Handles focus/error/disabled visual states, optional password toggle,
/// prefix/suffix icons, and keyboard configuration. Uses DS palette tokens
/// and the primary color from ThemeProvider for the focus border.
class AppTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? hintText;
  final String? labelText;
  final String? errorText;
  final String? helperText;
  final bool obscureText;
  final bool showPasswordToggle;
  final bool autofocus;
  final bool enabled;
  final bool readOnly;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? suffixText;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final FocusNode? focusNode;

  const AppTextField({
    super.key,
    this.controller,
    this.hintText,
    this.labelText,
    this.errorText,
    this.helperText,
    this.obscureText = false,
    this.showPasswordToggle = false,
    this.autofocus = false,
    this.enabled = true,
    this.readOnly = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onChanged,
    this.onTap,
    this.onSubmitted,
    this.inputFormatters,
    this.prefixIcon,
    this.suffixIcon,
    this.suffixText,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.focusNode,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscure;

  @override
  void initState() {
    super.initState();
    _obscure = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final primary = context.watch<ThemeProvider>().primaryColor;
    final hasError = widget.errorText != null;

    final suffixWidget = widget.showPasswordToggle
        ? IconButton(
            icon: Icon(
              _obscure
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: palette.textSecondary,
              size: AppSize.iconSm.r,
            ),
            onPressed: () => setState(() => _obscure = !_obscure),
          )
        : widget.suffixIcon;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.labelText != null) ...[
          Text(
            widget.labelText!,
            style: t.labelL.copyWith(color: palette.textPrimary),
          ),
          SizedBox(height: AppSpacing.xs.h),
        ],
        TextField(
          controller: widget.controller,
          obscureText: _obscure,
          autofocus: widget.autofocus,
          enabled: widget.enabled,
          readOnly: widget.readOnly,
          keyboardType: widget.maxLines != 1
              ? TextInputType.multiline
              : widget.keyboardType,
          textInputAction: widget.textInputAction,
          autofillHints: widget.autofillHints,
          onChanged: widget.onChanged,
          onTap: widget.onTap,
          onSubmitted: widget.onSubmitted,
          inputFormatters: widget.inputFormatters,
          focusNode: widget.focusNode,
          maxLines: _obscure ? 1 : widget.maxLines,
          minLines: widget.minLines,
          maxLength: widget.maxLength,
          cursorColor: primary,
          style: t.bodyL.copyWith(
            color: widget.enabled ? palette.textPrimary : palette.textTertiary,
          ),
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: t.bodyL.copyWith(color: palette.textTertiary),
            suffixText: widget.suffixText,
            suffixStyle: t.bodyL.copyWith(color: palette.textSecondary),
            prefixIcon: widget.prefixIcon,
            suffixIcon: suffixWidget,
            counterText: '',
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input.r),
              borderSide: BorderSide(
                color: hasError ? palette.error : palette.border,
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input.r),
              borderSide: BorderSide(
                color: hasError ? palette.error : primary,
                width: 2.0,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input.r),
              borderSide: BorderSide(color: palette.error, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input.r),
              borderSide: BorderSide(color: palette.error, width: 2.0),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input.r),
              borderSide: BorderSide(
                  color: palette.border.withValues(alpha: 0.4), width: 1.5),
            ),
            filled: true,
            fillColor: widget.enabled
                ? palette.surfaceVariant.withValues(alpha: 0.5)
                : palette.surfaceVariant.withValues(alpha: 0.25),
            contentPadding: EdgeInsets.symmetric(
              horizontal: AppSpacing.xl.w,
              vertical: AppSpacing.md.h,
            ),
          ),
        ),
        if (hasError) ...[
          SizedBox(height: AppSpacing.xs.h),
          Row(
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 13.r, color: palette.error),
              SizedBox(width: 4.w),
              Expanded(
                child: Text(
                  widget.errorText!,
                  style: t.labelS.copyWith(color: palette.error),
                ),
              ),
            ],
          ),
        ] else if (widget.helperText != null) ...[
          SizedBox(height: AppSpacing.xs.h),
          Text(
            widget.helperText!,
            style: t.labelS.copyWith(color: palette.textTertiary),
          ),
        ],
      ],
    );
  }
}
