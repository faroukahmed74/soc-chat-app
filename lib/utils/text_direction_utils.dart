// =============================================================================
// TEXT DIRECTION UTILS
// =============================================================================
// Utilities for detecting RTL (right-to-left) text such as Arabic
// and providing correct TextDirection for proper display.

import 'package:flutter/material.dart';

/// Detects if text contains Arabic or other RTL script characters.
/// Arabic Unicode ranges: Basic, Supplement, Extended-A, Presentation Forms
bool isRTLText(String? text) {
  if (text == null || text.isEmpty) return false;
  return RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]')
      .hasMatch(text);
}

/// Returns TextDirection.rtl if text contains RTL characters, else TextDirection.ltr.
/// Use this for message content to ensure Arabic displays correctly.
TextDirection getTextDirection(String? text) {
  return isRTLText(text) ? TextDirection.rtl : TextDirection.ltr;
}
