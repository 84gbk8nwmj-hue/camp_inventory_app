import '../utils/string_utils.dart';

/// 主要キャンプ・アウトドアメーカー（重量検索・Amazon検索の精度向上用）
class CampManufacturers {
  CampManufacturers._();

  static const List<String> builtIn = [
    'スノーピーク',
    'ロゴス',
    'コールマン',
    'DOD',
    'ヘリノックス',
    'キャプテンスタッグ',
    'ユニフレーム',
    'モンベル',
    'ザ・ノース・フェイス',
    'パタゴニア',
    'アークテリクス',
    'マムート',
    'MSR',
    'ニーモ',
    'ビッグアグネス',
    'ジェットボイル',
    'SOTO',
    'イワタニ',
    'プリムス',
    'トランギア',
    'ゴールゼロ',
    'ネイチャーハイク',
    'CHUMS',
    'and wander',
    'BUNDOK',
    'ZANE ARTS',
    'DIETZ',
    'BAREBONES',
    'KOVEA',
    'オガサカ',
    'シェラデザイン',
    'マウンテンハードウェア',
    'フィールドア',
    'ワイルドワン',
    'プロテック',
    'その他',
  ];

  static List<String> mergeLists(List<String> custom) {
    final seen = <String>{};
    final merged = <String>[];
    for (final name in [...custom, ...builtIn]) {
      final key = StringUtils.normalizeForSearch(name);
      if (seen.add(key)) merged.add(name);
    }
    return merged;
  }

  static List<String> search(String query, List<String> all) {
    final q = StringUtils.normalizeForSearch(query);
    if (q.isEmpty) return all;
    return all.where((m) => StringUtils.normalizeForSearch(m).contains(q)).toList();
  }

  static String? normalize(String? value) {
    if (value == null) return null;
    final t = value.trim();
    return t.isEmpty ? null : t;
  }
}
