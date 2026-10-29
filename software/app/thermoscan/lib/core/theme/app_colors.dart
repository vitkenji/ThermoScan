import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand & Core UI Tokens (design.md Section 2)
  static const Color primary = Color(0xFF0B4F6C); // Deep Thermal Navy
  static const Color primarySoft = Color(0xFFC5E7FF);
  static const Color background = Color(0xFFF4F8FB); // Cool Ice White
  static const Color surface = Color(0xFFFFFFFF); // Pure White
  static const Color border = Color(0xFFD5DEE7); // Soft Steel
  static const Color textPrimary = Color(0xFF0F1B2D); // Charcoal Slate
  static const Color textSecondary = Color(0xFF5B6B80); // Muted Slate
  static const Color accent = Color(0xFF19B5D6); // Clean Water Cyan
  static const Color secondary = Color(0xFFFF8A1F); // Solar Amber

  // Semantic Status Tokens
  static const Color success = Color(0xFF0F7D43); // Operational Green
  static const Color successBackground = Color(0xFFE6F4EA);
  static const Color successBorder = Color(0xFFB7DFC4);

  static const Color warning = Color(0xFFB45309); // Warning Ochre
  static const Color warningBackground = Color(0xFFFEF3C7);
  static const Color warningBorder = Color(0xFFFCD34D);

  static const Color error = Color(0xFFC62828); // Critical Red
  static const Color errorBackground = Color(0xFFFFDAD6);
  static const Color errorBorder = Color(0xFFF5B5B0);

  // Thermal Ramp Stops
  static const Color thermalCold = Color(0xFF1E4FD8);
  static const Color thermalCool = Color(0xFF19B5D6);
  static const Color thermalMid = Color(0xFFFFD43B);
  static const Color thermalWarm = Color(0xFFFF8A1F);
  static const Color thermalHot = Color(0xFFE5322D);

  static const List<Color> thermalSpectrum = [
    thermalCold,
    thermalCool,
    thermalMid,
    thermalWarm,
    thermalHot,
  ];
}
