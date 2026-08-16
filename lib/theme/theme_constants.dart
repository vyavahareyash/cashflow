import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Color Palette for Cashflow (Modern Emerald Fintech Theme)
class AppColors {
  // Primary Emerald Greens
  static const Color emerald900 = Color(0xFF064E3B);
  static const Color emerald800 = Color(0xFF065F46);
  static const Color emerald700 = Color(0xFF047857);
  static const Color emerald600 = Color(0xFF059669);
  static const Color emerald500 = Color(0xFF10B981);
  static const Color emerald400 = Color(0xFF34D399);
  static const Color emerald300 = Color(0xFF6EE7B7);
  static const Color emerald200 = Color(0xFFA7F3D0);
  static const Color emerald100 = Color(0xFFD1FAE5);
  static const Color emerald50 = Color(0xFFECFDF5);

  // Backward compatibility alias
  static const Color green900 = emerald900;
  static const Color green700 = emerald700;
  static const Color green500 = emerald500;
  static const Color green100 = emerald100;
  static const Color green50 = emerald50;

  // Accent & Brand Colors
  static const Color primary = emerald700;
  static const Color primaryDark = emerald900;
  static const Color primaryLight = emerald500;
  static const Color accent = Color(0xFF0EA5E9); // Ocean Blue

  // Semantic Colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);
  static const Color purple = Color(0xFF8B5CF6);
  static const Color pink = Color(0xFFEC4899);
  static const Color orange = Color(0xFFF97316);

  // Light Mode Neutrals
  static const Color gray900 = Color(0xFF0F172A); // Slate 900
  static const Color gray800 = Color(0xFF1E293B); // Slate 800
  static const Color gray700 = Color(0xFF334155); // Slate 700
  static const Color gray600 = Color(0xFF475569); // Slate 600
  static const Color gray500 = Color(0xFF64748B); // Slate 500
  static const Color gray400 = Color(0xFF94A3B8); // Slate 400
  static const Color gray300 = Color(0xFFCBD5E1); // Slate 300
  static const Color gray200 = Color(0xFFE2E8F0); // Slate 200
  static const Color gray100 = Color(0xFFF1F5F9); // Slate 100
  static const Color gray50 = Color(0xFFF8FAFC);  // Slate 50
  static const Color white = Color(0xFFFFFFFF);

  // Dark Mode Surfaces
  static const Color darkBg = Color(0xFF0B0F19);
  static const Color darkSurface = Color(0xFF131C2E);
  static const Color darkSurfaceElevated = Color(0xFF1A263D);
  static const Color darkBorder = Color(0xFF24324D);
  static const Color darkText = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
}

/// Spacing Constants (4px / 8px grid)
class AppSpacing {
  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
  static const double huge = 48.0;
}

/// Typography Scale
class AppTypography {
  static const TextStyle displayLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.2,
  );

  static const TextStyle headlineLarge = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.25,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.3,
  );

  static const TextStyle titleLarge = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    height: 1.35,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.3,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.3,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
    height: 1.2,
  );
}

/// Border Radius Constants
class AppBorderRadius {
  static const Radius small = Radius.circular(8);
  static const Radius medium = Radius.circular(12);
  static const Radius large = Radius.circular(16);
  static const Radius xlarge = Radius.circular(20);
  static const Radius pill = Radius.circular(999);

  static const BorderRadius smallBorder = BorderRadius.all(small);
  static const BorderRadius mediumBorder = BorderRadius.all(medium);
  static const BorderRadius largeBorder = BorderRadius.all(large);
  static const BorderRadius xlargeBorder = BorderRadius.all(xlarge);
  static const BorderRadius pillBorder = BorderRadius.all(pill);
}

/// Shadows (Subtle, modern ambient blur)
class AppShadows {
  static const BoxShadow subtle = BoxShadow(
    offset: Offset(0, 2),
    blurRadius: 8,
    spreadRadius: 0,
    color: Color.fromRGBO(15, 23, 42, 0.04),
  );

  static const BoxShadow level1 = BoxShadow(
    offset: Offset(0, 4),
    blurRadius: 12,
    spreadRadius: 0,
    color: Color.fromRGBO(15, 23, 42, 0.06),
  );

  static const BoxShadow level2 = BoxShadow(
    offset: Offset(0, 8),
    blurRadius: 20,
    spreadRadius: -2,
    color: Color.fromRGBO(15, 23, 42, 0.08),
  );

  static const BoxShadow cardGlow = BoxShadow(
    offset: Offset(0, 8),
    blurRadius: 24,
    spreadRadius: -4,
    color: Color.fromRGBO(16, 185, 129, 0.25),
  );
}

/// Component Sizes
class AppComponentSizes {
  static const double buttonHeightSmall = 36;
  static const double buttonHeightMedium = 46;
  static const double buttonHeightLarge = 54;
  static const double cardBorderMedium = 3;
}

/// Helper Formatters
class AppFormatters {
  static final NumberFormat _currencyFormatter = NumberFormat.currency(
    symbol: '₹',
    decimalDigits: 2,
  );

  static final NumberFormat _currencyNoDecimal = NumberFormat.currency(
    symbol: '₹',
    decimalDigits: 0,
  );

  static String currency(double amount, {bool hideDecimals = false, bool isPrivate = false}) {
    if (isPrivate) return '••••••';
    if (hideDecimals || amount == amount.roundToDouble()) {
      return _currencyNoDecimal.format(amount);
    }
    return _currencyFormatter.format(amount);
  }

  static String compactCurrency(double amount, {bool isPrivate = false}) {
    if (isPrivate) return '••••';
    if (amount >= 10000000) {
      return '₹${(amount / 10000000).toStringAsFixed(1)}Cr';
    } else if (amount >= 100000) {
      return '₹${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '₹${(amount / 1000).toStringAsFixed(1)}k';
    }
    return '₹${amount.toStringAsFixed(0)}';
  }

  static String date(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  static String monthYear(DateTime date) {
    return DateFormat('MMMM yyyy').format(date);
  }
}

/// Category Visual Registry (Icons & Colors)
class CategoryStyle {
  final IconData icon;
  final Color color;

  const CategoryStyle({required this.icon, required this.color});

  static CategoryStyle getStyle(String name) {
    final lower = name.toLowerCase().trim();
    if (lower.contains('groc') || lower.contains('supermarket')) {
      return const CategoryStyle(icon: Icons.shopping_basket_rounded, color: AppColors.emerald600);
    } else if (lower.contains('din') || lower.contains('food') || lower.contains('eat') || lower.contains('restaurant')) {
      return const CategoryStyle(icon: Icons.restaurant_rounded, color: AppColors.orange);
    } else if (lower.contains('trans') || lower.contains('fuel') || lower.contains('cab') || lower.contains('auto') || lower.contains('travel')) {
      return const CategoryStyle(icon: Icons.directions_car_rounded, color: AppColors.info);
    } else if (lower.contains('entertain') || lower.contains('movie') || lower.contains('game') || lower.contains('ott')) {
      return const CategoryStyle(icon: Icons.movie_filter_rounded, color: AppColors.purple);
    } else if (lower.contains('bill') || lower.contains('util') || lower.contains('rent') || lower.contains('elec')) {
      return const CategoryStyle(icon: Icons.electric_bolt_rounded, color: AppColors.warning);
    } else if (lower.contains('shop') || lower.contains('cloth') || lower.contains('apparel')) {
      return const CategoryStyle(icon: Icons.shopping_bag_rounded, color: AppColors.pink);
    } else if (lower.contains('health') || lower.contains('med') || lower.contains('doc')) {
      return const CategoryStyle(icon: Icons.medical_services_rounded, color: AppColors.danger);
    } else if (lower.contains('invest') || lower.contains('sip') || lower.contains('stock')) {
      return const CategoryStyle(icon: Icons.trending_up_rounded, color: AppColors.emerald700);
    } else if (lower.contains('edu') || lower.contains('course') || lower.contains('book')) {
      return const CategoryStyle(icon: Icons.school_rounded, color: Color(0xFF0284C7));
    }
    return const CategoryStyle(icon: Icons.category_rounded, color: AppColors.emerald700);
  }
}
