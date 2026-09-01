import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import 'database_providers.dart';

const _settingKey = 'confirm_unnest_on_swipe';

class ConfirmUnnestNotifier extends Notifier<bool> {
  AppDatabase get _db => ref.read(appDatabaseProvider);

  @override
  bool build() => false;

  Future<void> load() async {
    final stored = await _db.getAppSetting(_settingKey);
    state = stored == 'true';
  }

  Future<void> setConfirmUnnest(bool enabled) async {
    await _db.setAppSetting(_settingKey, enabled ? 'true' : 'false');
    state = enabled;
  }
}

final confirmUnnestProvider =
    NotifierProvider<ConfirmUnnestNotifier, bool>(ConfirmUnnestNotifier.new);
