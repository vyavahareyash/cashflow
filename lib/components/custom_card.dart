import 'package:flutter/material.dart';
import '../theme/theme_constants.dart';

class CustomCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Color? borderLeftColor;
  final double borderLeftWidth;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final BoxShadow? shadow;

  const CustomCard({
    Key? key,
    required this.child,
    this.padding,
    this.margin,
    this.borderLeftColor,
    this.borderLeftWidth = AppComponentSizes.cardBorderMedium,
    this.onTap,
    this.backgroundColor,
    this.shadow,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBg = isDark ? AppColors.darkSurface : AppColors.white;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: margin,
        decoration: BoxDecoration(
          color: backgroundColor ?? defaultBg,
          borderRadius: AppBorderRadius.mediumBorder,
          boxShadow: shadow != null ? [shadow!] : [AppShadows.level1],
          border: borderLeftColor != null
              ? Border(
                  left: BorderSide(
                    color: borderLeftColor!,
                    width: borderLeftWidth,
                  ),
                )
              : null,
        ),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
          child: child,
        ),
      ),
    );
  }
}
