import 'package:flutter/services.dart';

class HapticHelper {
  /// Provides the lightest possible haptic feedback.
  static void lightFeedback() {
    HapticFeedback.selectionClick();
  }
}
