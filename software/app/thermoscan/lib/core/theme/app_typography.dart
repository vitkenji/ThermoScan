import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thermoscan/core/theme/app_colors.dart';

class AppTypography {
  AppTypography._();

  // H1 — Screen Title: Space Grotesk Bold, 32 px / 40 px, -0.02em
  static TextStyle get h1 => GoogleFonts.spaceGrotesk(
        fontSize: 32,
        height: 40 / 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.64,
        color: AppColors.textPrimary,
      );

  // H2 — Section Header: Space Grotesk Bold, 24 px / 32 px, -0.01em
  static TextStyle get h2 => GoogleFonts.spaceGrotesk(
        fontSize: 24,
        height: 32 / 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.24,
        color: AppColors.textPrimary,
      );

  // H3 — Card Title: Space Grotesk Medium, 18 px / 24 px
  static TextStyle get h3 => GoogleFonts.spaceGrotesk(
        fontSize: 18,
        height: 24 / 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  // Body — Primary Copy: Inter Regular, 16 px / 24 px
  static TextStyle get body => GoogleFonts.inter(
        fontSize: 16,
        height: 24 / 16,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      );

  // Body Small: Inter Regular, 14 px / 20 px
  static TextStyle get bodySmall => GoogleFonts.inter(
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      );

  // Data Value: Inter SemiBold, 14 px / 20 px, tabular-nums
  static TextStyle get dataValue => GoogleFonts.inter(
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w600,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: AppColors.textPrimary,
      );

  // Caption / Label: Inter Regular, 12 px / 16 px
  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 12,
        height: 16 / 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      );

  // Chip Label: Inter SemiBold, 12 px / 16 px
  static TextStyle get chip => GoogleFonts.inter(
        fontSize: 12,
        height: 16 / 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );
}
