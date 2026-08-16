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
  final Gradient? gradient;
  final BoxShadow? shadow;
  final BorderRadius? borderRadius;
  final Border? border;

  const CustomCard({
    Key? key,
    required this.child,
    this.padding,
    this.margin,
    this.borderLeftColor,
    this.borderLeftWidth = AppComponentSizes.cardBorderMedium,
    this.onTap,
    this.backgroundColor,
    this.gradient,
    this.shadow,
    this.borderRadius,
    this.border,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBg = isDark ? AppColors.darkSurface : AppColors.white;
    final defaultBorderColor = isDark ? AppColors.darkBorder : AppColors.gray200;
    final radius = borderRadius ?? AppBorderRadius.largeBorder;

    Widget cardContent = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: gradient == null ? (backgroundColor ?? defaultBg) : null,
        gradient: gradient,
        borderRadius: radius,
        boxShadow: shadow != null
            ? [shadow!]
            : (isDark ? [] : [AppShadows.level1]),
        border: border ??
            (borderLeftColor != null
                ? Border(
                    left: BorderSide(
                      color: borderLeftColor!,
                      width: borderLeftWidth,
                    ),
                    top: BorderSide(color: defaultBorderColor, width: 1),
                    right: BorderSide(color: defaultBorderColor, width: 1),
                    bottom: BorderSide(color: defaultBorderColor, width: 1),
                  )
                : Border.all(color: defaultBorderColor, width: 1)),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
        child: child,
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: cardContent,
        ),
      );
    }

    return cardContent;
  }
}
