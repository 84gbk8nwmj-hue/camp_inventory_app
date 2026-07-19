import 'package:flutter/material.dart';

/// アプリ背景のカラーテーマ
enum AppColorTheme {
  armyGreen(
    'army_green',
    'Army Green',
    'アーミーグリーン',
    Color(0xFF3A4228),
    Color(0xFF2E3420),
    Color(0xFF454D34),
    Color(0xFF8E8A71),
    Color(0xFFE8E4D4),
    Brightness.dark,
  ),
  navy(
    'navy',
    'Navy',
    'ネイビー',
    Color(0xFF152238),
    Color(0xFF0F1A2C),
    Color(0xFF243552),
    Color(0xFF9AABB8),
    Color(0xFFE2E8F0),
    Brightness.dark,
  ),
  airForceBlue(
    'air_force_blue',
    'Air Force Blue',
    'エアフォースブルー',
    Color(0xFF3D5568),
    Color(0xFF334A5A),
    Color(0xFF4D6B7D),
    Color(0xFFB8CCD8),
    Color(0xFFE8EFF4),
    Brightness.dark,
  ),
  starlight(
    'starlight',
    'Starlight',
    'スターライト',
    Color(0xFF0B101A),
    Color(0xFF05070A),
    Color(0xFF161F2E),
    Color(0xFF6488B4),
    Color(0xFFE1E5EA),
    Brightness.dark,
  ),
  sakura(
    'sakura',
    'Sakura',
    'サクラ',
    Color(0xFFEEDCD3), // Base: 和紙
    Color(0xFFD8B2AD), // Main: 薄桜
    Color(0xFFE5C9C5), // surfaceHigh
    Color(0xFF7A5553), // Accent: 梅鼠を濃くした色（視認性向上）
    Color(0xFF3B2C2B), // onSurfaceText
    Brightness.light,
  ),
  sandBeige(
    'sand_beige',
    'Sand Beige',
    'サンドベージュ',
    Color(0xFFDCD6CC), // Base: ライトコンテナ
    Color(0xFFC1B4A1), // Main: サンド
    Color(0xFFCDC3B2), // surfaceHigh
    Color(0xFF70624E), // Accent: コヨーテを濃くした色（視認性向上）
    Color(0xFF302B24), // onSurfaceText
    Brightness.light,
  );

  final String storageKey;
  final String labelEn;
  final String labelJa;
  final Color scaffold;
  final Color surface;
  final Color surfaceHigh;
  final Color accent;
  final Color onSurfaceText;
  final Brightness brightness;

  const AppColorTheme(
    this.storageKey,
    this.labelEn,
    this.labelJa,
    this.scaffold,
    this.surface,
    this.surfaceHigh,
    this.accent,
    this.onSurfaceText,
    this.brightness,
  );

  static AppColorTheme fromStorage(String? value) {
    return AppColorTheme.values.firstWhere(
      (t) => t.storageKey == value,
      orElse: () => AppColorTheme.armyGreen,
    );
  }

  Color get primaryContainer {
    return Color.alphaBlend(accent.withValues(alpha: 0.22), surfaceHigh);
  }

  Color get onPrimary => surface;

  Color get onPrimaryContainer => accent;
}
