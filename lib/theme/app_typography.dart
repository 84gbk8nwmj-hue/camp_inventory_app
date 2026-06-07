import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_color_theme.dart';

/// 軍用UI向けの無骨・高密度タイポグラフィ（日本語 + 英字）
class AppTypography {
  AppTypography._();

  static const _latinFallback = ['Barlow Semi Condensed', 'Arial'];

  static TextStyle _style(
    AppColorTheme palette, {
    required double size,
    FontWeight weight = FontWeight.w700,
    double letterSpacing = 0.65,
    double height = 1.2,
    Color? color,
  }) {
    return GoogleFonts.notoSansJp(
      fontSize: size,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      height: height,
      color: color ?? palette.onSurfaceText,
    ).copyWith(fontFamilyFallback: _latinFallback);
  }

  static TextTheme textTheme(AppColorTheme palette) {
    return TextTheme(
      displayLarge: _style(
        palette,
        size: 34,
        weight: FontWeight.w900,
        letterSpacing: 1.4,
        color: palette.accent,
      ),
      displayMedium: _style(
        palette,
        size: 28,
        weight: FontWeight.w900,
        letterSpacing: 1.1,
      ),
      displaySmall: _style(
        palette,
        size: 24,
        weight: FontWeight.w800,
        letterSpacing: 1.0,
      ),
      headlineLarge: _style(
        palette,
        size: 22,
        weight: FontWeight.w800,
        letterSpacing: 0.95,
      ),
      headlineMedium: _style(
        palette,
        size: 20,
        weight: FontWeight.w800,
        letterSpacing: 0.85,
      ),
      headlineSmall: _style(
        palette,
        size: 18,
        weight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
      titleLarge: _style(
        palette,
        size: 18,
        weight: FontWeight.w700,
        letterSpacing: 0.9,
      ),
      titleMedium: _style(
        palette,
        size: 16,
        weight: FontWeight.w700,
        letterSpacing: 0.75,
      ),
      titleSmall: _style(
        palette,
        size: 14,
        weight: FontWeight.w700,
        letterSpacing: 0.7,
      ),
      bodyLarge: _style(
        palette,
        size: 16,
        weight: FontWeight.w600,
        letterSpacing: 0.45,
        height: 1.35,
      ),
      bodyMedium: _style(
        palette,
        size: 14,
        weight: FontWeight.w600,
        letterSpacing: 0.4,
        height: 1.35,
      ),
      bodySmall: _style(
        palette,
        size: 12,
        weight: FontWeight.w600,
        letterSpacing: 0.35,
        height: 1.3,
      ),
      labelLarge: _style(
        palette,
        size: 14,
        weight: FontWeight.w700,
        letterSpacing: 0.85,
      ),
      labelMedium: _style(
        palette,
        size: 12,
        weight: FontWeight.w700,
        letterSpacing: 0.75,
      ),
      labelSmall: _style(
        palette,
        size: 11,
        weight: FontWeight.w700,
        letterSpacing: 0.65,
      ),
    );
  }

  static TextStyle appBarTitle(AppColorTheme palette) {
    return _style(
      palette,
      size: 19,
      weight: FontWeight.w800,
      letterSpacing: 1.1,
      color: palette.accent,
    );
  }

  static TextStyle inputLabel(AppColorTheme palette) {
    return _style(
      palette,
      size: 14,
      weight: FontWeight.w700,
      letterSpacing: 0.7,
      color: palette.accent.withValues(alpha: 0.9),
    );
  }

  static TextStyle inputHint(AppColorTheme palette) {
    return _style(
      palette,
      size: 14,
      weight: FontWeight.w600,
      letterSpacing: 0.5,
      color: palette.accent.withValues(alpha: 0.5),
    );
  }

  static TextStyle inputText(AppColorTheme palette) {
    return _style(
      palette,
      size: 16,
      weight: FontWeight.w600,
      letterSpacing: 0.4,
    );
  }

  static TextStyle buttonLabel(AppColorTheme palette) {
    return _style(
      palette,
      size: 15,
      weight: FontWeight.w800,
      letterSpacing: 0.9,
    );
  }

  static TextStyle chipLabel(AppColorTheme palette) {
    return _style(
      palette,
      size: 13,
      weight: FontWeight.w700,
      letterSpacing: 0.6,
    );
  }

  static TextStyle listTitle(AppColorTheme palette) {
    return _style(
      palette,
      size: 16,
      weight: FontWeight.w700,
      letterSpacing: 0.55,
    );
  }

  static TextStyle listSubtitle(AppColorTheme palette) {
    return _style(
      palette,
      size: 13,
      weight: FontWeight.w600,
      letterSpacing: 0.4,
      color: palette.onSurfaceText.withValues(alpha: 0.82),
    );
  }
}
