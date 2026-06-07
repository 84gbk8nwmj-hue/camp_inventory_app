/// 重量（g / kg）をカンマ区切りで表示する
class WeightFormat {
  static String _commaInt(int n) {
    final s = n.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return n < 0 ? '-$buf' : buf.toString();
  }

  /// バナー等: 1000g以上は kg、未満は g（例: 1,234.56 kg / 500 g）
  static String label(double totalG) {
    if (totalG >= 1000) {
      final kg = totalG / 1000;
      final fixed = kg.toStringAsFixed(2);
      final parts = fixed.split('.');
      return '${_commaInt(int.parse(parts[0]))}.${parts[1]} kg';
    }
    return '${_commaInt(totalG.round())} g';
  }

  /// 一覧サブタイトル用（例: 　1,500g）
  static String gramsCompact(double grams) => '${_commaInt(grams.round())}g';

  /// 詳細画面用（例: 1,500 g）
  static String grams(double grams) => '${_commaInt(grams.round())} g';
}
