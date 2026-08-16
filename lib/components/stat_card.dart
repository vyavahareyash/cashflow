import 'package:flutter/material.dart';
import '../theme/theme_constants.dart';

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final Color? accentColor;
  final VoidCallback? onTap;

  const StatCard({
    Key? key,
    required this.label,
    required this.value,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.accentColor,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = accentColor ?? AppColors.emerald700;
    final bg = isDark ? AppColors.darkSurface : AppColors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.gray200;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppBorderRadius.largeBorder,
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: AppBorderRadius.largeBorder,
            border: Border.all(color: borderColor, width: 1),
            boxShadow: isDark ? [] : [AppShadows.subtle],
          ),
          padding: const EdgeInsets.all(AppSpacing.md + 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (icon != null)
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.xs + 2),
                      decoration: BoxDecoration(
                        color: (iconColor ?? primaryColor).withOpacity(0.12),
                        borderRadius: AppBorderRadius.smallBorder,
                      ),
                      child: Icon(
                        icon,
                        color: iconColor ?? primaryColor,
                        size: 18,
                      ),
                    ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: icon != null ? AppSpacing.sm : 0),
                      child: Text(
                        label,
                        style: AppTypography.labelSmall.copyWith(
                          color: isDark ? AppColors.gray400 : AppColors.gray600,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                value,
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkText : AppColors.gray900,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  subtitle!,
                  style: AppTypography.labelSmall.copyWith(
                    color: isDark ? AppColors.gray500 : AppColors.gray400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
