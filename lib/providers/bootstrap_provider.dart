import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_theme_provider.dart';
import 'category_provider.dart';
import 'database_providers.dart';
import 'gear_provider.dart';
import 'packing_provider.dart';

final bootstrapProvider = FutureProvider<void>((ref) async {
  final images = ref.read(imageStorageProvider);
  await images.init();
  await ref.read(appThemeProvider.notifier).load();
  await ref.read(categoryProvider.notifier).load();
  await ref.read(gearProvider.notifier).load();
  await ref.read(packingProvider.notifier).load();
  final gear = ref.read(gearProvider).items;
  await images.migrateLegacyImages(gear.map((g) => g.imageFile));
});
