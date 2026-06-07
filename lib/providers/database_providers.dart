import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import '../services/image_storage_service.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) => AppDatabase.instance);

final imageStorageProvider = Provider<ImageStorageService>((ref) {
  final service = ImageStorageService();
  // ignore: discarded_futures
  service.init();
  return service;
});
