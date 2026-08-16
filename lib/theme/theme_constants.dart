import 'package:flutter/material.dart';

/// Color Palette for Cashflow App
class AppColors {
  // Primary Green
  static const Color green900 = Color(0xFF1b5e20);
  static const Color green700 = Color(0xFF388e3c);
  static const Color green500 = Color(0xFF4caf50);
  static const Color green100 = Color(0xFFC8e6c9);
  static const Color green50 = Color(0xFFF1f8e9);

  // Semantic Colors
  static const Color success = Color(0xFF4caf50);
  static const Color warning = Color(0xFFff9800);
  static const Color danger = Color(0xFFf44336);
  static const Color info = Color(0xFF2196f3);

  // Neutral Colors (Light Mode)
  static const Color gray900 = Color(0xFF212121);
  static const Color gray700 = Color(0xFF424242);
  static const Color gray400 = Color(0xFF9e9e9e);
  static const Color gray200 = Color(0xFFeeeeee);
  static const Color gray50 = Color(0xFFFafafa);
  static const Color white = Color(0xFFFFFFFF);

  // Dark Mode Colors
  static const Color darkBg = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1e1e1e);
  static const Color darkText = Color(0xFFffffff);
}

/// Spacing Constants (8px base unit)
class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 48.0;
}

/// Typography Scale
class AppTypography {
  // Display Large: 32px, weight 400
  static const TextStyle displayLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w400,
    height: 1.25, // 40px line-height
  );

  // Headline Large: 28px, weight 600
  static const TextStyle headlineLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    height: 1.29, // 36px line-height
  );

  // Headline Medium: 24px, weight 600
  static const TextStyle headlineMedium = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.33, // 32px line-height
  );

  // Title Large: 20px, weight 500
  static const TextStyle titleLarge = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w500,
    height: 1.4, // 28px line-height
  );

  // Title Medium: 16px, weight 500
  static const TextStyle titleMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.5, // 24px line-height
  );

  // Body Large: 16px, weight 400
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5, // 24px line-height
  );

  // Body Medium: 14px, weight 400
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.43, // 20px line-height
  );

  // Label Large: 14px, weight 500
  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.43, // 20px line-height
  );

  // Label Medium: 12px, weight 400
  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.33, // 16px line-height
  );

  // Label Small: 12px, weight 500
  static const TextStyle labelSmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.33, // 16px line-height
  );
}

/// Shadow Definitions
class AppShadows {
  // Level 1: Subtle shadow
  static const BoxShadow level1 = BoxShadow(
    offset: Offset(0, 1),
    blurRadius: 3,
    spreadRadius: 0,
    color: Color.fromRGBO(0, 0, 0, 0.12),
  );

  // Level 2: Medium shadow
  static const BoxShadow level2 = BoxShadow(
    offset: Offset(0, 3),
    blurRadius: 6,
    spreadRadius: 0,
    color: Color.fromRGBO(0, 0, 0, 0.16),
  );

  // Level 3: Strong shadow
  static const BoxShadow level3 = BoxShadow(
    offset: Offset(0, 6),
    blurRadius: 12,
    spreadRadius: 0,
    color: Color.fromRGBO(0, 0, 0, 0.18),
  );
}

/// Border Radius Constants
class AppBorderRadius {
  static const Radius small = Radius.circular(8);
  static const Radius medium = Radius.circular(12);
  static const Radius large = Radius.circular(16);
  static const BorderRadius smallBorder = BorderRadius.all(small);
  static const BorderRadius mediumBorder = BorderRadius.all(medium);
  static const BorderRadius largeBorder = BorderRadius.all(large);
}

/// Animation Durations
class AppAnimations {
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
}

/// Component Sizes
class AppComponentSizes {
  // Button sizes
  static const double buttonHeightSmall = 40;
  static const double buttonHeightMedium = 48;
  static const double buttonHeightLarge = 56;

  // FAB size
  static const double fabSize = 60;

  // Bottom Nav height
  static const double bottomNavHeight = 80;

  // Card border widths
  static const double cardBorderSmall = 1;
  static const double cardBorderMedium = 3;
  static const double cardBorderLarge = 4;

  // Progress bar height
  static const double progressBarHeight = 8;
}
