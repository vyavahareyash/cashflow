import 'package:flutter/material.dart';
import '../theme/theme_constants.dart';

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Color? iconColor;
  final Color? borderLeftColor;

  const StatCard({
    Key? key,
    required this.label,
    required this.value,
    this.icon,
    this.iconColor,
    this.borderLeftColor = AppColors.green700,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkText : AppColors.gray900;
    final secondaryTextColor = isDark ? AppColors.gray400 : AppColors.gray700;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.white,
        borderRadius: AppBorderRadius.mediumBorder,
        boxShadow: [AppShadows.level1],
        border: Border(
          left: BorderSide(
            color: borderLeftColor ?? AppColors.green700,
            width: AppComponentSizes.cardBorderMedium,
          ),
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: (iconColor ?? AppColors.green700).withOpacity(0.1),
                borderRadius: AppBorderRadius.smallBorder,
              ),
              child: Icon(
                icon,
                color: iconColor ?? AppColors.green700,
                size: 24,
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.labelSmall.copyWith(
                    color: secondaryTextColor,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  value,
                  style: AppTypography.titleLarge.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
