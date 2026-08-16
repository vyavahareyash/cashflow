import 'package:flutter/material.dart';
import '../theme/theme_constants.dart';

class CustomInputField extends StatelessWidget {
  final TextEditingController? controller;
  final String label;
  final String? hint;
  final TextInputType keyboardType;
  final int maxLines;
  final int minLines;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final bool obscureText;

  const CustomInputField({
    Key? key,
    this.controller,
    required this.label,
    this.hint,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.minLines = 1,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.onChanged,
    this.obscureText = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.gray700 : AppColors.gray400;
    final textColor = isDark ? AppColors.darkText : AppColors.gray900;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTypography.labelLarge.copyWith(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          maxLines: obscureText ? 1 : maxLines,
          minLines: minLines,
          validator: validator,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
            suffixIcon: suffixIcon,
            border: OutlineInputBorder(
              borderRadius: AppBorderRadius.smallBorder,
              borderSide: BorderSide(color: borderColor, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppBorderRadius.smallBorder,
              borderSide: BorderSide(color: borderColor, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppBorderRadius.smallBorder,
              borderSide: BorderSide(
                color: AppColors.green500,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: AppBorderRadius.smallBorder,
              borderSide: BorderSide(
                color: AppColors.danger,
                width: 1,
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
