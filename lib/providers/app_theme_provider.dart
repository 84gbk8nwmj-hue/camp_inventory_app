import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import '../theme/app_color_theme.dart';
import 'database_providers.dart';

const _settingKey = 'app_color_theme';

class AppThemeNotifier extends Notifier<AppColorTheme> {
  AppDatabase get _db => ref.read(appDatabaseProvider);

  @override
  AppColorTheme build() => AppColorTheme.armyGreen;

  Future<void> load() async {
    final stored = await _db.getAppSetting(_settingKey);
    state = AppColorTheme.fromStorage(stored);
  }

  Future<void> setTheme(AppColorTheme theme) async {
    await _db.setAppSetting(_settingKey, theme.storageKey);
    state = theme;
  }
}

final appThemeProvider =
    NotifierProvider<AppThemeNotifier, AppColorTheme>(AppThemeNotifier.new);
