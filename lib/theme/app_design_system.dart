// =============================================================================
// MODERN DESIGN SYSTEM
// =============================================================================
// Comprehensive design system with colors, typography, spacing, and styling
// for all platforms (Android, iOS, Web)

import 'package:flutter/material.dart';

class AppDesignSystem {
  // =============================================================================
  // COLOR SYSTEM - Modern Gray & Blue Palette
  // =============================================================================
  // Based on: #353941, #26282B, #5F85DB, #90B8F8
  
  // Primary Colors (Blue Palette)
  static const Color primaryColor = Color(0xFF5F85DB); // Medium blue #5F85DB
  static const Color primaryDark = Color(0xFF353941); // Dark charcoal gray #353941
  static const Color primaryLight = Color(0xFF90B8F8); // Light pastel blue #90B8F8
  
  // Secondary Colors
  static const Color secondaryColor = Color(0xFF90B8F8); // Light pastel blue
  static const Color secondaryDark = Color(0xFF5F85DB); // Medium blue
  static const Color secondaryLight = Color(0xFFA8C7FF); // Lighter blue variant
  
  // Accent Colors
  static const Color accentColor = Color(0xFF90B8F8); // Light pastel blue #90B8F8
  static const Color successColor = Color(0xFF10B981); // Green
  static const Color warningColor = Color(0xFFF59E0B); // Amber
  static const Color errorColor = Color(0xFFEF4444); // Red
  static const Color infoColor = Color(0xFF5F85DB); // Medium blue
  
  // Neutral Colors (Light Mode - Light Grays)
  static const Color neutral50 = Color(0xFFFAFAFA); // Very light gray
  static const Color neutral100 = Color(0xFFF5F5F5); // Light gray
  static const Color neutral200 = Color(0xFFE5E5E5); // Light gray
  static const Color neutral300 = Color(0xFFD4D4D4); // Medium light gray
  static const Color neutral400 = Color(0xFFA3A3A3); // Medium gray
  static const Color neutral500 = Color(0xFF737373); // Medium gray
  static const Color neutral600 = Color(0xFF525252); // Dark gray
  
  // Neutral Colors (Dark Mode - Charcoal & Dark Grays)
  static const Color neutral700 = Color(0xFF353941); // Dark charcoal gray #353941
  static const Color neutral800 = Color(0xFF26282B); // Very dark gray #26282B
  static const Color neutral900 = Color(0xFF1A1C1E); // Almost black (slightly lighter than #26282B)
  
  // =============================================================================
  // LIGHT THEME
  // =============================================================================
  
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    // Use local bundled Roboto fonts for consistent offline web rendering
    fontFamily: 'Roboto',
    fontFamilyFallback: const ['NotoColorEmoji', 'NotoNaskhArabic', 'NotoSansArabic', 'Arial', 'Helvetica', 'Segoe UI', 'Tahoma', 'sans-serif'],
    primaryColor: primaryColor,
    scaffoldBackgroundColor: neutral50, // Very light gray background
    colorScheme: const ColorScheme.light(
      primary: primaryColor, // Medium blue #5F85DB
      secondary: secondaryColor, // Light pastel blue #90B8F8
      surface: Colors.white,
      background: neutral50, // Very light gray
      error: errorColor,
      onPrimary: Colors.white,
      onSecondary: primaryDark, // Dark charcoal for text on light blue
      onSurface: primaryDark, // Dark charcoal gray for text
      onBackground: primaryDark, // Dark charcoal gray for text
      onError: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: primaryDark, // Dark charcoal gray #353941
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: primaryDark,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: neutral200, width: 1),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: neutral100, // Light gray fill
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: neutral300, width: 1), // Gray border
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: neutral300, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryColor, width: 2), // Medium blue focus
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: errorColor, width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: CircleBorder(),
    ),
  );
  
  // =============================================================================
  // DARK THEME
  // =============================================================================
  
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    // Use local bundled Roboto fonts for consistent offline web rendering
    fontFamily: 'Roboto',
    fontFamilyFallback: const ['NotoColorEmoji', 'NotoNaskhArabic', 'NotoSansArabic', 'Arial', 'Helvetica', 'Segoe UI', 'Tahoma', 'sans-serif'],
    primaryColor: primaryColor, // Medium blue #5F85DB
    scaffoldBackgroundColor: neutral800, // Very dark gray #26282B
    colorScheme: const ColorScheme.dark(
      primary: primaryColor, // Medium blue #5F85DB
      secondary: secondaryColor, // Light pastel blue #90B8F8
      surface: neutral700, // Dark charcoal gray #353941
      background: neutral800, // Very dark gray #26282B
      error: errorColor,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: primaryLight, // Light pastel blue for text
      onBackground: primaryLight, // Light pastel blue for text
      onError: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: neutral700, // Dark charcoal gray #353941
      foregroundColor: primaryLight, // Light pastel blue #90B8F8
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: primaryLight,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
      ),
    ),
    cardTheme: CardThemeData(
      color: neutral700, // Dark charcoal gray #353941
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: primaryColor, width: 1), // Medium blue border
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: neutral700, // Dark charcoal gray #353941
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryColor, width: 1), // Medium blue border
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryColor, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryColor, width: 2), // Medium blue focus
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: errorColor, width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryLight,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryLight,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primaryLight,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: CircleBorder(),
    ),
  );
  
  // =============================================================================
  // TYPOGRAPHY
  // =============================================================================
  
  static const TextStyle displayLarge = TextStyle(
    fontSize: 57,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.5,
    height: 1.2,
  );
  
  static const TextStyle displayMedium = TextStyle(
    fontSize: 45,
    fontWeight: FontWeight.w700,
    letterSpacing: -1,
    height: 1.2,
  );
  
  static const TextStyle displaySmall = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    height: 1.2,
  );
  
  static const TextStyle headlineLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    height: 1.3,
  );
  
  static const TextStyle headlineMedium = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    height: 1.3,
  );
  
  static const TextStyle headlineSmall = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.4,
  );
  
  static const TextStyle titleLarge = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.4,
  );
  
  static const TextStyle titleMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.15,
    height: 1.5,
  );
  
  static const TextStyle titleSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.5,
  );
  
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.5,
    height: 1.5,
  );
  
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.25,
    height: 1.5,
  );
  
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
    height: 1.5,
  );
  
  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.4,
  );
  
  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.4,
  );
  
  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.4,
  );
  
  // =============================================================================
  // SPACING
  // =============================================================================
  
  static const double spacingXS = 4.0;
  static const double spacingSM = 8.0;
  static const double spacingMD = 16.0;
  static const double spacingLG = 24.0;
  static const double spacingXL = 32.0;
  static const double spacingXXL = 48.0;
  
  // =============================================================================
  // BORDER RADIUS
  // =============================================================================
  
  static const double radiusSM = 8.0;
  static const double radiusMD = 12.0;
  static const double radiusLG = 16.0;
  static const double radiusXL = 24.0;
  static const double radiusFull = 9999.0;
  
  // =============================================================================
  // SHADOWS
  // =============================================================================
  
  static List<BoxShadow> shadowSM = [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];
  
  static List<BoxShadow> shadowMD = [
    BoxShadow(
      color: Colors.black.withOpacity(0.1),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];
  
  static List<BoxShadow> shadowLG = [
    BoxShadow(
      color: Colors.black.withOpacity(0.15),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];
  
  static List<BoxShadow> shadowXL = [
    BoxShadow(
      color: Colors.black.withOpacity(0.2),
      blurRadius: 24,
      offset: const Offset(0, 12),
    ),
  ];
  
  // =============================================================================
  // GRADIENTS
  // =============================================================================
  
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryColor, primaryLight], // Medium blue to Light pastel blue
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient accentGradient = LinearGradient(
    colors: [primaryLight, primaryColor], // Light pastel blue to Medium blue
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient successGradient = LinearGradient(
    colors: [successColor, primaryColor], // Green to Medium Blue
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // =============================================================================
  // ANIMATIONS
  // =============================================================================
  
  static const Duration animationDurationFast = Duration(milliseconds: 150);
  static const Duration animationDurationNormal = Duration(milliseconds: 300);
  static const Duration animationDurationSlow = Duration(milliseconds: 500);
  
  static const Curve animationCurve = Curves.easeInOutCubic;
  
  // =============================================================================
  // RESPONSIVE BREAKPOINTS
  // =============================================================================
  
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;
}
