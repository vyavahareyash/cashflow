import 'package:flutter/material.dart';
import '../theme/theme_constants.dart';

class CustomInputField extends StatelessWidget {
  final TextEditingController? controller;
  final String label;
  final String? hint;
  final String? prefixText;
  final TextInputType keyboardType;
  final int maxLines;
  final int minLines;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final bool obscureText;
  final bool autofocus;

  const CustomInputField({
    Key? key,
    this.controller,
    required this.label,
    this.hint,
    this.prefixText,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.minLines = 1,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.onChanged,
    this.obscureText = false,
    this.autofocus = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.gray300;
    final fillColor = isDark ? AppColors.darkSurface : AppColors.gray50;
    final textColor = isDark ? AppColors.darkText : AppColors.gray900;
    final hintColor = isDark ? AppColors.gray500 : AppColors.gray400;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTypography.labelMedium.copyWith(
            color: isDark ? AppColors.gray300 : AppColors.gray700,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          autofocus: autofocus,
          maxLines: obscureText ? 1 : maxLines,
          minLines: minLines,
          validator: validator,
          onChanged: onChanged,
          style: AppTypography.bodyLarge.copyWith(color: textColor),
          decoration: InputDecoration(
            filled: true,
            fillColor: fillColor,
            hintText: hint,
            hintStyle: AppTypography.bodyMedium.copyWith(color: hintColor),
            prefixText: prefixText,
            prefixStyle: AppTypography.bodyLarge.copyWith(
              color: AppColors.emerald600,
              fontWeight: FontWeight.bold,
            ),
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, color: AppColors.emerald700, size: 20)
                : null,
            suffixIcon: suffixIcon,
            border: OutlineInputBorder(
              borderRadius: AppBorderRadius.mediumBorder,
              borderSide: BorderSide(color: borderColor, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppBorderRadius.mediumBorder,
              borderSide: BorderSide(color: borderColor, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppBorderRadius.mediumBorder,
              borderSide: const BorderSide(
                color: AppColors.emerald500,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: AppBorderRadius.mediumBorder,
              borderSide: const BorderSide(
                color: AppColors.danger,
                width: 1,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: AppBorderRadius.mediumBorder,
              borderSide: const BorderSide(
                color: AppColors.danger,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
          ),
        ),
      ],
    );
  }
}
