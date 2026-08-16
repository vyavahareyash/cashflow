import 'package:flutter/material.dart';

import '../theme/theme_constants.dart';

enum ButtonVariant { primary, secondary, text }

class CustomButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final ButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool isEnabled;
  final double? width;

  const CustomButton({
    Key? key,
    required this.label,
    required this.onPressed,
    this.variant = ButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.isEnabled = true,
    this.width,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;
    Color borderColor;

    switch (variant) {
      case ButtonVariant.primary:
        backgroundColor = isEnabled ? AppColors.green700 : AppColors.gray400;
        textColor = Colors.white;
        borderColor = Colors.transparent;
        break;
      case ButtonVariant.secondary:
        backgroundColor = AppColors.green100;
        textColor = AppColors.green700;
        borderColor = AppColors.green700;
        break;
      case ButtonVariant.text:
        backgroundColor = Colors.transparent;
        textColor = AppColors.green700;
        borderColor = Colors.transparent;
        break;
    }

    return SizedBox(
      width: width ?? double.infinity,
      height: AppComponentSizes.buttonHeightMedium,
      child: ElevatedButton.icon(
        onPressed: isEnabled && !isLoading ? onPressed : null,
        icon: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(textColor),
                ),
              )
            : (icon != null ? Icon(icon) : SizedBox.shrink()),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          disabledBackgroundColor: AppColors.gray400,
          disabledForegroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: AppBorderRadius.smallBorder,
            side: BorderSide(color: borderColor, width: 1),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          elevation: 0,
        ),
      ),
    );
  }
}
