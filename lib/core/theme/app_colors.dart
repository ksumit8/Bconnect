import 'package:flutter/material.dart';

/// Palette tokens for the dark-only Bconnect theme (spec section 6.3).
abstract final class AppColors {
  static const Color background = Color(0xFF0B1020);
  static const Color surface = Color(0xFF121826);
  static const Color surfaceRaised = Color(0xFF1B2437);

  static const Color primary = Color(0xFF2563EB);
  static const Color onPrimary = Color(0xFFFFFFFF);

  /// Active-group state: the member badge and "Group is Active" dot.
  static const Color active = Color(0xFF22C55E);

  /// End Call.
  static const Color danger = Color(0xFFDC2626);

  /// The create-group avatar.
  static const Color accent = Color(0xFF7C3AED);

  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color divider = Color(0xFF1F2937);
}
