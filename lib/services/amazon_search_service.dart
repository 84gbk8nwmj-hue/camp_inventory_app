import 'package:url_launcher/url_launcher.dart';

/// Amazon.co.jp の商品検索をブラウザで開く（重量はユーザーがページで確認）
class AmazonSearchService {
  /// メーカー名 + 商品名で Amazon 検索 URL を生成
  static Uri buildSearchUri({
    required String productName,
    String? manufacturer,
  }) {
    final parts = <String>[
      if (manufacturer != null && manufacturer.isNotEmpty) manufacturer,
      productName.trim(),
    ];
    return Uri.https(
      'www.amazon.co.jp',
      '/s',
      {'k': parts.join(' '), 'i': 'sporting'},
    );
  }

  static Future<void> openProductSearch({
    required String productName,
    String? manufacturer,
  }) async {
    final uri = buildSearchUri(
      productName: productName,
      manufacturer: manufacturer,
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      throw Exception('Amazonを開けませんでした');
    }
  }
}
