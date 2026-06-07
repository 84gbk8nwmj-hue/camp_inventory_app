import 'package:flutter/material.dart';

import 'app_color_theme.dart';
import 'app_typography.dart';

class AppTheme {
  static ThemeData build(AppColorTheme palette) {
    final textTheme = AppTypography.textTheme(palette);
    final buttonLabel = AppTypography.buttonLabel(palette);

    final colorScheme = ColorScheme.dark(
      primary: palette.accent,
      onPrimary: palette.onPrimary,
      secondary: Color.alphaBlend(
        palette.accent.withValues(alpha: 0.65),
        palette.surface,
      ),
      onSecondary: palette.onSurfaceText,
      surface: palette.surface,
      onSurface: palette.onSurfaceText,
      surfaceContainerHighest: palette.surfaceHigh,
      primaryContainer: palette.primaryContainer,
      onPrimaryContainer: palette.onPrimaryContainer,
      secondaryContainer: palette.surfaceHigh,
      onSecondaryContainer: palette.onSurfaceText,
      error: const Color(0xFFCF6679),
      onError: Colors.white,
    );

    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(6),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      scaffoldBackgroundColor: palette.scaffold,
      appBarTheme: AppBarTheme(
        backgroundColor: palette.surface,
        foregroundColor: palette.accent,
        elevation: 0,
        titleTextStyle: AppTypography.appBarTitle(palette),
        toolbarTextStyle: textTheme.titleMedium,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          textStyle: buttonLabel,
          shape: buttonShape,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          textStyle: buttonLabel,
          shape: buttonShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          textStyle: buttonLabel,
          shape: buttonShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(textStyle: buttonLabel),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(
            color: palette.accent.withValues(alpha: 0.35),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(
            color: palette.accent.withValues(alpha: 0.25),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: palette.accent, width: 1.5),
        ),
        labelStyle: AppTypography.inputLabel(palette),
        hintStyle: AppTypography.inputHint(palette),
        floatingLabelStyle: AppTypography.inputLabel(palette),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.surface,
        selectedColor: palette.primaryContainer,
        labelStyle: AppTypography.chipLabel(palette),
        secondaryLabelStyle: AppTypography.chipLabel(palette).copyWith(
          color: palette.accent,
        ),
        side: BorderSide(color: palette.accent.withValues(alpha: 0.3)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      dividerColor: palette.accent.withValues(alpha: 0.2),
      listTileTheme: ListTileThemeData(
        iconColor: palette.accent,
        titleTextStyle: AppTypography.listTitle(palette),
        subtitleTextStyle: AppTypography.listSubtitle(palette),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        titleTextStyle: textTheme.headlineSmall?.copyWith(color: palette.onSurfaceText),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: palette.onSurfaceText),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.surfaceHigh,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: palette.onSurfaceText),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surfaceHigh,
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: AppTypography.inputText(palette),
      ),
      popupMenuTheme: PopupMenuThemeData(
        textStyle: textTheme.bodyMedium,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(
            AppTypography.chipLabel(palette),
          ),
        ),
      ),
    );
  }

  /// 後方互換
  static ThemeData get dark => build(AppColorTheme.armyGreen);
}
