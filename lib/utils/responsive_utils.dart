// =============================================================================
// RESPONSIVE DESIGN UTILITIES
// =============================================================================
// This file provides consistent responsive design utilities across the app.
// It includes breakpoint definitions, responsive sizing helpers, and
// adaptive layout methods for different screen sizes.
//
// KEY FEATURES:
// - Consistent breakpoint definitions
// - Responsive sizing calculations
// - Adaptive layout helpers
// - Platform-aware responsive design
//
// USAGE:
// - Import this file in screens that need responsive design
// - Use ResponsiveUtils.getScreenType(context) to determine screen size
// - Apply responsive sizing with ResponsiveUtils.getResponsiveValue()
//
// BREAKPOINTS:
// - Mobile: < 600px (phones)
// - Tablet: 600px - 900px (tablets, small laptops)
// - Desktop: > 900px (desktops, large screens)

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// Enum defining different screen sizes for responsive design
enum ScreenType {
  mobile,   // < 600px
  tablet,   // 600px - 900px
  desktop,  // > 900px
}

/// Utility class for responsive design across the app
class ResponsiveUtils {
  // Private constructor to prevent instantiation
  ResponsiveUtils._();
  
  // =============================================================================
  // BREAKPOINT CONSTANTS
  // =============================================================================
  
  /// Mobile breakpoint (phones)
  static const double mobileBreakpoint = 600.0;
  
  /// Tablet breakpoint (tablets, small laptops)
  static const double tabletBreakpoint = 900.0;
  
  /// Large desktop breakpoint (large screens)
  static const double largeDesktopBreakpoint = 1200.0;
  
  // =============================================================================
  // SCREEN TYPE DETECTION
  // =============================================================================
  
  /// Determines the current screen type based on width
  static ScreenType getScreenType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    
    if (width < mobileBreakpoint) {
      return ScreenType.mobile;
    } else if (width < tabletBreakpoint) {
      return ScreenType.tablet;
    } else {
      return ScreenType.desktop;
    }
  }
  
  /// Checks if the current screen is mobile-sized
  static bool isMobile(BuildContext context) {
    return getScreenType(context) == ScreenType.mobile;
  }
  
  /// Checks if the current screen is tablet-sized
  static bool isTablet(BuildContext context) {
    return getScreenType(context) == ScreenType.tablet;
  }
  
  /// Checks if the current screen is desktop-sized
  static bool isDesktop(BuildContext context) {
    return getScreenType(context) == ScreenType.desktop;
  }
  
  /// Checks if the current screen is large desktop-sized
  static bool isLargeDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= largeDesktopBreakpoint;
  }
  
  // =============================================================================
  // RESPONSIVE SIZING
  // =============================================================================
  
  /// Gets a responsive value based on screen type
  /// [mobile] - Value for mobile screens
  /// [tablet] - Value for tablet screens
  /// [desktop] - Value for desktop screens
  static T getResponsiveValue<T>(
    BuildContext context, {
    required T mobile,
    required T tablet,
    required T desktop,
  }) {
    final screenType = getScreenType(context);
    
    switch (screenType) {
      case ScreenType.mobile:
        return mobile;
      case ScreenType.tablet:
        return tablet;
      case ScreenType.desktop:
        return desktop;
    }
  }
  
  /// Gets responsive padding based on screen type
  static EdgeInsets getResponsivePadding(BuildContext context) {
    return getResponsiveValue(
      context,
      mobile: const EdgeInsets.all(16.0),
      tablet: const EdgeInsets.all(24.0),
      desktop: const EdgeInsets.all(32.0),
    );
  }
  
  /// Gets responsive horizontal padding based on screen type
  static EdgeInsets getResponsiveHorizontalPadding(BuildContext context) {
    return getResponsiveValue(
      context,
      mobile: const EdgeInsets.symmetric(horizontal: 16.0),
      tablet: const EdgeInsets.symmetric(horizontal: 24.0),
      desktop: const EdgeInsets.symmetric(horizontal: 32.0),
    );
  }
  
  /// Gets responsive spacing between elements
  static double getResponsiveSpacing(BuildContext context) {
    return getResponsiveValue(
      context,
      mobile: 12.0,
      tablet: 16.0,
      desktop: 24.0,
    );
  }
  
  /// Gets responsive icon size based on screen type
  static double getResponsiveIconSize(BuildContext context) {
    return getResponsiveValue(
      context,
      mobile: 20.0,
      tablet: 24.0,
      desktop: 28.0,
    );
  }
  
  /// Gets responsive font size based on screen type
  static double getResponsiveFontSize(
    BuildContext context, {
    required double baseSize,
    double? mobileMultiplier,
    double? tabletMultiplier,
    double? desktopMultiplier,
  }) {
    final mobileMultiplierValue = mobileMultiplier ?? 0.9;
    final tabletMultiplierValue = tabletMultiplier ?? 1.0;
    final desktopMultiplierValue = desktopMultiplier ?? 1.1;
    
    return getResponsiveValue(
      context,
      mobile: baseSize * mobileMultiplierValue,
      tablet: baseSize * tabletMultiplierValue,
      desktop: baseSize * desktopMultiplierValue,
    );
  }
  
  // =============================================================================
  // RESPONSIVE LAYOUT HELPERS
  // =============================================================================
  
  /// Gets responsive card constraints based on screen type
  static BoxConstraints getResponsiveCardConstraints(BuildContext context) {
    return getResponsiveValue(
      context,
      mobile: const BoxConstraints(maxWidth: double.infinity),
      tablet: const BoxConstraints(maxWidth: 600),
      desktop: const BoxConstraints(maxWidth: 800),
    );
  }
  
  /// Gets responsive button height based on screen type
  static double getResponsiveButtonHeight(BuildContext context) {
    return getResponsiveValue(
      context,
      mobile: 48.0,
      tablet: 52.0,
      desktop: 56.0,
    );
  }
  
  /// Gets responsive avatar radius based on screen type
  static double getResponsiveAvatarRadius(BuildContext context) {
    return getResponsiveValue(
      context,
      mobile: 40.0,
      tablet: 45.0,
      desktop: 50.0,
    );
  }
  
  // =============================================================================
  // PLATFORM-AWARE RESPONSIVE DESIGN
  // =============================================================================
  
  /// Checks if the app is running on web
  static bool get isWeb => kIsWeb;
  
  /// Checks if the app is running on mobile (iOS/Android)
  static bool get isMobilePlatform => !kIsWeb;
  
  /// Gets platform-aware responsive value
  static T getPlatformResponsiveValue<T>(
    BuildContext context, {
    required T mobile,
    required T tablet,
    required T desktop,
    T? webMobile,
    T? webTablet,
    T? webDesktop,
  }) {
    if (isWeb) {
      // Use web-specific values if provided, otherwise fall back to general values
      return getResponsiveValue(
        context,
        mobile: webMobile ?? mobile,
        tablet: webTablet ?? tablet,
        desktop: webDesktop ?? desktop,
      );
    } else {
      // Use general values for mobile platforms
      return getResponsiveValue(
        context,
        mobile: mobile,
        tablet: tablet,
        desktop: desktop,
      );
    }
  }
  
  // =============================================================================
  // RESPONSIVE TEXT STYLES
  // =============================================================================
  
  /// Gets responsive text style for headings
  static TextStyle getResponsiveHeadingStyle(
    BuildContext context, {
    Color? color,
    FontWeight? weight,
  }) {
    final fontSize = getResponsiveFontSize(
      context,
      baseSize: 24.0,
      mobileMultiplier: 0.9,
      tabletMultiplier: 1.0,
      desktopMultiplier: 1.1,
    );
    
    return TextStyle(
      fontSize: fontSize,
      fontWeight: weight ?? FontWeight.bold,
      color: color,
    );
  }
  
  /// Gets responsive text style for body text
  static TextStyle getResponsiveBodyStyle(
    BuildContext context, {
    Color? color,
    FontWeight? weight,
  }) {
    final fontSize = getResponsiveFontSize(
      context,
      baseSize: 16.0,
      mobileMultiplier: 0.9,
      tabletMultiplier: 1.0,
      desktopMultiplier: 1.05,
    );
    
    return TextStyle(
      fontSize: fontSize,
      fontWeight: weight ?? FontWeight.normal,
      color: color,
    );
  }
  
  /// Gets responsive text style for captions
  static TextStyle getResponsiveCaptionStyle(
    BuildContext context, {
    Color? color,
    FontWeight? weight,
  }) {
    final fontSize = getResponsiveFontSize(
      context,
      baseSize: 14.0,
      mobileMultiplier: 0.9,
      tabletMultiplier: 1.0,
      desktopMultiplier: 1.0,
    );
    
    return TextStyle(
      fontSize: fontSize,
      fontWeight: weight ?? FontWeight.normal,
      color: color,
    );
  }
}
