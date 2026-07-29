import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'package:geolocator/geolocator.dart'; // 現在地取得のために追加

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

  Color get color {
    switch (category) {
      case SpotCategory.supermarket:
        return Colors.greenAccent;
      case SpotCategory.homeCenter:
        return Colors.blueAccent;
      case SpotCategory.outdoorShop:
        return Colors.purpleAccent;
      case SpotCategory.gasStation:
        return Colors.redAccent;
      case SpotCategory.hotSpring:
        return Colors.lightBlueAccent;
      case SpotCategory.convenience:
        return Colors.pinkAccent;
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
    } catch (e) {
      debugPrint('現在地取得エラー: $e');
      _showSnackBar('現在地の取得中にエラーが発生しました: $e');
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
    if (_currentPosition == null) {
      _showSnackBar('現在地が取得できませんでした。');
      await _determinePosition(); // 現在地を再取得
      return;
    }

    final String lat = _currentPosition!.latitude.toString();
    final String lng = _currentPosition!.longitude.toString();

    // Google Mapsアプリを優先して開くURIスキーム
    final String googleMapsUrl = 'comgooglemaps://?q=$searchWord&center=$lat,$lng';
    // ブラウザ版Google MapsのURL
    final String webUrl = 'https://www.google.com/maps/search/?api=1&query=$searchWord&query_place_id=&center=$lat,$lng';

    try {
      if (await url_launcher.canLaunchUrl(Uri.parse(googleMapsUrl))) {
        await url_launcher.launchUrl(Uri.parse(googleMapsUrl), mode: url_launcher.LaunchMode.externalApplication);
      } else if (await url_launcher.canLaunchUrl(Uri.parse(webUrl))) {
        await url_launcher.launchUrl(Uri.parse(webUrl), mode: url_launcher.LaunchMode.externalApplication);
      } else {
        _showSnackBar('Googleマップを起動できませんでした。');
      }
    } catch (e) {
      debugPrint('Google Maps起動エラー: $e');
      _showSnackBar('Googleマップの起動中にエラーが発生しました: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
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

          return Card(
            color: Colors.grey[900],
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: InkWell(
              onTap: () => _launchGoogleMapsSearch(searchWord), // ここを変更
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(icon, color: Colors.greenAccent, size: 30),
                    const SizedBox(width: 16),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_forward_ios, color: Colors.grey),
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
