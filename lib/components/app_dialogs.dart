import 'package:flutter/material.dart';

import '../theme/theme_constants.dart';
import 'custom_button.dart';

class AppDialogs {
  /// Shows a modal warning dialog for validation errors or constraints,
  /// rendering prominently above bottom sheets and soft keyboards.
  static Future<void> showWarning(
    BuildContext context, {
    String title = 'Validation Error',
    required String message,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: AppBorderRadius.largeBorder,
        ),
        titlePadding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xs,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        actionsPadding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: AppColors.warning,
          size: 38,
        ),
        title: Text(
          title,
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkText : AppColors.gray900,
          ),
          textAlign: TextAlign.center,
        ),
        content: Text(
          message,
          style: AppTypography.bodyMedium.copyWith(
            color: isDark ? AppColors.gray300 : AppColors.gray700,
          ),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          CustomButton(
            label: 'OK',
            width: 110,
            onPressed: () => Navigator.pop(dialogCtx),
          ),
        ],
      ),
    );
  }
}
