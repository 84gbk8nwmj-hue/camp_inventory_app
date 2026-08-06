  import 'package:flutter/material.dart';
  import 'package:url_launcher/url_launcher.dart' as url_launcher;
  import 'package:geolocator/geolocator.dart'; // 現在地取得のために追加
  import 'dart:io';

  // 周辺スポットのカテゴリ定義
  enum SpotCategory {
    supermarket, // スーパー
    homeCenter, // ホームセンター
    outdoorShop, // アウトドアショップ
    gasStation, // ガソリンスタンド
    hotSpring, // 温泉
    convenience, // コンビニ
  }

  // 周辺スポットのモデル (今回はUIのみなので簡略化)
  class NearbySpot {
    final String id;
    final String name;
    final SpotCategory category;

    NearbySpot({
      required this.id,
      required this.name,
      required this.category,
    });

    IconData get icon {
      switch (category) {
        case SpotCategory.supermarket:
          return Icons.local_grocery_store;
        case SpotCategory.homeCenter:
          return Icons.build;
        case SpotCategory.outdoorShop:
          return Icons.hiking;
        case SpotCategory.gasStation:
          return Icons.local_gas_station;
        case SpotCategory.hotSpring:
          return Icons.hot_tub;
        case SpotCategory.convenience:
          return Icons.storefront;
      }
    }

  }

  class NearbyStoreSearchScreen extends StatefulWidget {
    const NearbyStoreSearchScreen({super.key});

    @override
    State<NearbyStoreSearchScreen> createState() => _NearbyStoreSearchScreenState();
  }

  class _NearbyStoreSearchScreenState extends State<NearbyStoreSearchScreen> {
    Position? _currentPosition; // 現在地を保持するための変数

    final List<Map<String, dynamic>> _categories = [
      {'label': 'スーパー', 'category': SpotCategory.supermarket, 'icon': Icons.local_grocery_store, 'searchWord': 'スーパー'},
      {'label': 'ホームセンター', 'category': SpotCategory.homeCenter, 'icon': Icons.build, 'searchWord': 'ホームセンター'},
      {'label': 'アウトドアショップ', 'category': SpotCategory.outdoorShop, 'icon': Icons.hiking, 'searchWord': 'アウトドアショップ'},
      {'label': 'ガソリンスタンド', 'category': SpotCategory.gasStation, 'icon': Icons.local_gas_station, 'searchWord': 'ガソリンスタンド'},
      {'label': '温泉', 'category': SpotCategory.hotSpring, 'icon': Icons.hot_tub, 'searchWord': '日帰り温泉'},
      {'label': 'コンビニ', 'category': SpotCategory.convenience, 'icon': Icons.storefront, 'searchWord': 'コンビニ'},
    ];

  @override
  void initState() {
    super.initState();
    _determinePosition(); // 画面初期化時に現在地を取得
  }

  // 現在地取得のメソッド (前回のコードから再利用)
  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackBar('位置情報サービスが無効です。');
        return;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackBar('位置情報の使用が許可されませんでした。');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnackBar('位置情報の許可が永久に拒否されています。設定から許可してください。');
        return;
      }

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      debugPrint('現在地取得成功 (lat: ${_currentPosition?.latitude}, lng: ${_currentPosition?.longitude})');
    } catch (e, stack) {
      debugPrint('現在地取得エラー: $e\n$stack');
      _showSnackBar('現在地の取得中にエラーが発生しました。'); // 詳細なエラーメッセージはログに出力し、ユーザーには一般的なメッセージを表示
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 1),
      ),
    );
  }

Future<void> _launchGoogleMapsSearch(String searchWord) async {
  try {
    // 検索実行時に最新の現在地を取得
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    final double lat = position.latitude;
    final double lng = position.longitude;

    debugPrint(
      '検索時現在地 lat:$lat lng:$lng',
    );

    late final Uri uri;

    if (Platform.isAndroid) {
      // Android: geoインテントで現在地周辺検索
      uri = Uri.parse(
        'geo:$lat,$lng?q=${Uri.encodeComponent(searchWord)}',
      );
    } else if (Platform.isIOS) {
      // iOS: Google Maps URL
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(searchWord)}&center=$lat,$lng',
      );
    } else {
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(searchWord)}',
      );
    }

    debugPrint('検索URL: $uri');

    await url_launcher.launchUrl(
      uri,
      mode: url_launcher.LaunchMode.externalApplication,
    );

  } catch (e, stack) {
    debugPrint('Map起動エラー: $e\n$stack');

    if (!mounted) return;

    _showSnackBar('地図を起動できませんでした。');
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('周辺スポット検索'),
      ),
      body: ListView.builder(
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final categoryData = _categories[index];
          final label = categoryData['label'] as String;
          final icon = categoryData['icon'] as IconData;
          final searchWord = categoryData['searchWord'] as String;
          final colorScheme = Theme.of(context).colorScheme;

          return Card(
            color: colorScheme.surfaceContainerHighest,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: InkWell(
              onTap: () => _launchGoogleMapsSearch(searchWord),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(icon, color: colorScheme.primary, size: 30),
                    const SizedBox(width: 16),
                    Text(
                      label,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.arrow_forward_ios, color: colorScheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}