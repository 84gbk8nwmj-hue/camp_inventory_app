import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/data_transfer_service.dart';
import 'bootstrap_provider.dart';
import 'category_provider.dart';
import 'database_providers.dart';
import 'gear_provider.dart';
import 'packing_provider.dart';

final dataTransferServiceProvider = Provider<DataTransferService>((ref) {
  return DataTransferService(
    db: ref.watch(appDatabaseProvider),
    images: ref.watch(imageStorageProvider),
  );
});

Future<void> reloadAllProviders(WidgetRef ref) async {
  await ref.read(categoryProvider.notifier).load();
  await ref.read(gearProvider.notifier).load();
  await ref.read(packingProvider.notifier).load();
}

Future<void> rerunBootstrap(WidgetRef ref) async {
  ref.invalidate(bootstrapProvider);
  await ref.read(bootstrapProvider.future);
}
