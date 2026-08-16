import 'package:flutter/material.dart';
import '../theme/theme_constants.dart';

enum ButtonVariant { primary, secondary, outlined, text, danger }

class CustomButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final ButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool isEnabled;
  final double? width;
  final double? height;

  const CustomButton({
    Key? key,
    required this.label,
    required this.onPressed,
    this.variant = ButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.isEnabled = true,
    this.width,
    this.height,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color backgroundColor;
    Color textColor;
    Color borderColor;

    switch (variant) {
      case ButtonVariant.primary:
        backgroundColor = isEnabled ? AppColors.emerald700 : (isDark ? AppColors.gray700 : AppColors.gray300);
        textColor = Colors.white;
        borderColor = Colors.transparent;
        break;
      case ButtonVariant.secondary:
        backgroundColor = isDark ? AppColors.emerald900.withOpacity(0.6) : AppColors.emerald50;
        textColor = isDark ? AppColors.emerald300 : AppColors.emerald800;
        borderColor = isDark ? AppColors.emerald700 : AppColors.emerald200;
        break;
      case ButtonVariant.outlined:
        backgroundColor = Colors.transparent;
        textColor = isDark ? AppColors.emerald400 : AppColors.emerald700;
        borderColor = isDark ? AppColors.darkBorder : AppColors.gray300;
        break;
      case ButtonVariant.danger:
        backgroundColor = AppColors.danger;
        textColor = Colors.white;
        borderColor = AppColors.danger;
        break;
      case ButtonVariant.text:
        backgroundColor = Colors.transparent;
        textColor = isDark ? AppColors.emerald400 : AppColors.emerald700;
        borderColor = Colors.transparent;
        break;
    }

    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(textColor),
            ),
          )
        else if (icon != null) ...[
          Icon(icon, size: 18, color: textColor),
          const SizedBox(width: AppSpacing.sm),
        ],
        Text(
          label,
          style: AppTypography.labelLarge.copyWith(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );

    return SizedBox(
      width: width ?? double.infinity,
      height: height ?? AppComponentSizes.buttonHeightMedium,
      child: ElevatedButton(
        onPressed: isEnabled && !isLoading ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          disabledBackgroundColor: isDark ? AppColors.gray800 : AppColors.gray300,
          disabledForegroundColor: isDark ? AppColors.gray600 : AppColors.gray500,
          shape: RoundedRectangleBorder(
            borderRadius: AppBorderRadius.mediumBorder,
            side: BorderSide(color: borderColor, width: 1.5),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          elevation: 0,
        ),
        child: content,
      ),
    );
  }
}
