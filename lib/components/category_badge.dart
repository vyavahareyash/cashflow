import 'package:flutter/material.dart';
import '../theme/theme_constants.dart';

class CategoryBadge extends StatelessWidget {
  final String label;
  final Color? color;
  final IconData? icon;
  final bool showIcon;

  const CategoryBadge({
    Key? key,
    required this.label,
    this.color,
    this.icon,
    this.showIcon = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final style = CategoryStyle.getStyle(label);
    final badgeColor = color ?? style.color;
    final badgeIcon = icon ?? style.icon;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? badgeColor.withOpacity(0.18)
            : badgeColor.withOpacity(0.1),
        border: Border.all(
          color: isDark
              ? badgeColor.withOpacity(0.3)
              : badgeColor.withOpacity(0.2),
          width: 1,
        ),
        borderRadius: AppBorderRadius.pillBorder,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(badgeIcon, size: 14, color: badgeColor),
            const SizedBox(width: AppSpacing.xs),
          ],
          Flexible(
            child: Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color: badgeColor,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
