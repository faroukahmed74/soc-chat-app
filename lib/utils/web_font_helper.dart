// Web Font Helper
// Ensures Arabic fonts are properly loaded and used on web platform

import 'package:flutter/foundation.dart';

class WebFontHelper {
  /// Get font family fallback for Arabic text on web
  static List<String>? getArabicFontFallback() {
    if (kIsWeb) {
      return const ['NotoNaskhArabic', 'NotoSansArabic', 'Arial', 'Helvetica', 'sans-serif'];
    }
    return null;
  }
  
  /// Get text style with Arabic font support for web
  static TextStyle? getArabicTextStyle(TextStyle baseStyle) {
    if (kIsWeb) {
      return baseStyle.copyWith(
        fontFamilyFallback: getArabicFontFallback(),
      );
    }
    return baseStyle;
  }
}

