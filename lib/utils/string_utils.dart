class StringUtils {
  StringUtils._();

  /// 大文字小文字・全角半角・ひらがなカタカナを区別しない検索用の正規化
  static String normalizeForSearch(String text) {
    var s = text.toLowerCase();
    
    // 全角英数字・記号を半角に変換
    s = s.replaceAllMapped(RegExp(r'[Ａ-Ｚａ-ｚ０-９]'), (m) {
      return String.fromCharCode(m.group(0)!.codeUnitAt(0) - 0xFEE0);
    });
    
    // カタカナをひらがなに変換して揺らぎを吸収
    s = s.replaceAllMapped(RegExp(r'[ァ-ヶ]'), (m) {
      return String.fromCharCode(m.group(0)!.codeUnitAt(0) - 0x60);
    });
    
    return s.trim();
  }
}
