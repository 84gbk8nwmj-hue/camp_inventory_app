import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 画像は Documents/gear_images/ に保存し、DBにはファイル名のみ保持する。
class ImageStorageService {
  static const imagesSubDir = 'gear_images';

  // 静的変数にして、アプリ全体で一つのパス設定を共有するようにする
  static Directory? _staticImagesDir;
  static Directory? _staticDocsDir;

  Future<void> init() async {
    if (_staticImagesDir != null) return;
    _staticDocsDir = await getApplicationDocumentsDirectory();
    _staticImagesDir = Directory(p.join(_staticDocsDir!.path, imagesSubDir));
    if (!await _staticImagesDir!.exists()) {
      await _staticImagesDir!.create(recursive: true);
    }
  }

  /// ピックした画像を永続フォルダへコピーし、ファイル名を返す。
  Future<String?> saveFromPath(String sourcePath) async {
    await init();
    final ext = p.extension(sourcePath);
    final fileName =
        'gear_${DateTime.now().millisecondsSinceEpoch}${ext.isEmpty ? '.jpg' : ext}';
    final dest = File(p.join(_staticImagesDir!.path, fileName));
    await File(sourcePath).copy(dest.path);
    return fileName;
  }

  File? resolveFile(String? imageFile) {
    if (imageFile == null || imageFile.isEmpty) return null;

    // パスが未設定の場合は、一度 Documents パスを取得し直す（同期的な代替案）
    if (_staticImagesDir == null) {
      // 本来は init() が終わっているべきだが、保険として saveFromPath を通っていればOK
      return null;
    }

    // 旧データ: 絶対パスが残っている場合
    if (imageFile.contains('/')) {
      final legacy = File(imageFile);
      if (legacy.existsSync()) return legacy;
      imageFile = p.basename(imageFile);
    }

    final file = File(p.join(_staticImagesDir!.path, imageFile));
    return file.existsSync() ? file : null;
  }

  Future<void> migrateLegacyImages(Iterable<String?> imageFiles) async {
    await init();
    for (final raw in imageFiles) {
      if (raw == null || raw.isEmpty) continue;
      final fileName = raw.contains('/') ? p.basename(raw) : raw;
      final dest = File(p.join(_staticImagesDir!.path, fileName));
      if (dest.existsSync()) continue;

      File? source;
      if (raw.contains('/')) {
        final legacy = File(raw);
        if (legacy.existsSync()) source = legacy;
      }
      source ??= File(p.join(_staticDocsDir!.path, fileName));
      if (source.existsSync()) {
        await source.copy(dest.path);
      }
    }
  }

  Future<void> deleteImage(String? imageFile) async {
    final file = resolveFile(imageFile);
    if (file != null && await file.exists()) {
      await file.delete();
    }
  }

  Future<void> clearAllImages() async {
    await init();
    if (_staticImagesDir == null || !await _staticImagesDir!.exists()) return;
    await for (final entity in _staticImagesDir!.list()) {
      if (entity is File) {
        await entity.delete();
      }
    }
  }

  Future<int> importFromDirectory(String sourceDirPath) async {
    await init();
    final sourceDir = Directory(p.join(sourceDirPath, imagesSubDir));
    if (!await sourceDir.exists()) return 0;

    var count = 0;
    await for (final entity in sourceDir.list()) {
      if (entity is! File) continue;
      final fileName = p.basename(entity.path);
      final dest = File(p.join(_staticImagesDir!.path, fileName));
      await entity.copy(dest.path);
      count++;
    }
    return count;
  }

  File? fileForExport(String? imageFile) => resolveFile(imageFile);
}
