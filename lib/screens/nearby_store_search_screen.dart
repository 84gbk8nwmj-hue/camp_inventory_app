  import 'package:flutter/material.dart';
  import 'package:url_launcher/url_launcher.dart' as url_launcher;
  import 'package:geolocator/geolocator.dart'; // 現在地取得のために追加
  import 'dart:io';
  import 'dart:convert';
  import '../db/app_database.dart';

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

  // カスタム検索項目のモデル
  class CustomSpotSearchItem {
    final String id;
    final String name;
    final String searchWord;

    CustomSpotSearchItem({
      required this.id,
      required this.name,
      required this.searchWord,
    });

    Map<String, dynamic> toJson() => {
      'id': id,
      'name': name,
      'searchWord': searchWord,
    };

    factory CustomSpotSearchItem.fromJson(Map<String, dynamic> json) {
      return CustomSpotSearchItem(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        searchWord: json['searchWord'] as String? ?? '',
      );
    }
  }

  class NearbyStoreSearchScreen extends StatefulWidget {
    const NearbyStoreSearchScreen({super.key});

    @override
    State<NearbyStoreSearchScreen> createState() => _NearbyStoreSearchScreenState();
  }

  class _NearbyStoreSearchScreenState extends State<NearbyStoreSearchScreen> {
    Position? _currentPosition; // 現在地を保持するための変数

    static const _customItemsKey = 'custom_spot_search_items';
    List<CustomSpotSearchItem> _customItems = [];

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
    _loadCustomItems(); // 保存されたカスタム検索項目を読み込み
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

  Future<void> _loadCustomItems() async {
    try {
      final jsonStr = await AppDatabase.instance.getAppSetting(_customItemsKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final decoded = jsonDecode(jsonStr);
        if (decoded is List) {
          final loaded = <CustomSpotSearchItem>[];
          for (final item in decoded) {
            if (item is Map) {
              loaded.add(CustomSpotSearchItem.fromJson(Map<String, dynamic>.from(item)));
            }
          }
          if (mounted) {
            setState(() {
              _customItems = loaded;
            });
          }
        }
      }
    } catch (e, stack) {
      debugPrint('カスタム検索項目の読み込みエラー: $e\n$stack');
    }
  }

  Future<void> _saveCustomItems() async {
    try {
      final jsonStr = jsonEncode(_customItems.map((item) => item.toJson()).toList());
      await AppDatabase.instance.setAppSetting(_customItemsKey, jsonStr);
    } catch (e, stack) {
      debugPrint('カスタム検索項目の保存エラー: $e\n$stack');
    }
  }

  Future<void> _showAddOrEditDialog({CustomSpotSearchItem? item}) async {
    final isEdit = item != null;
    final nameCtrl = TextEditingController(text: item?.name ?? '');
    final wordCtrl = TextEditingController(text: item?.searchWord ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isEdit ? 'カスタム項目を編集' : 'カスタム項目を追加'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: '表示名称',
                  hintText: '例: 釣具店',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: wordCtrl,
                decoration: const InputDecoration(
                  labelText: '検索キーワード',
                  hintText: '例: 釣具',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(isEdit ? '保存' : '追加'),
          ),
        ],
      ),
    );

    if (ok == true) {
      final name = nameCtrl.text.trim();
      final searchWord = wordCtrl.text.trim();
      if (name.isNotEmpty && searchWord.isNotEmpty) {
        setState(() {
          if (isEdit) {
            final index = _customItems.indexWhere((e) => e.id == item.id);
            if (index != -1) {
              _customItems[index] = CustomSpotSearchItem(
                id: item.id,
                name: name,
                searchWord: searchWord,
              );
            }
          } else {
            _customItems.add(
              CustomSpotSearchItem(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: name,
                searchWord: searchWord,
              ),
            );
          }
        });
        await _saveCustomItems();
      }
    }
    nameCtrl.dispose();
    wordCtrl.dispose();
  }

  Future<void> _deleteCustomItem(CustomSpotSearchItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('カスタム項目を削除'),
        content: Text('「${item.name}」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (ok == true) {
      setState(() {
        _customItems.removeWhere((e) => e.id == item.id);
      });
      await _saveCustomItems();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('周辺スポット検索'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'カスタム項目を追加',
            onPressed: () => _showAddOrEditDialog(),
          ),
        ],
      ),
      body: ListView(
        children: [
          // 既存の固定カテゴリ
          ..._categories.map((categoryData) {
            final label = categoryData['label'] as String;
            final icon = categoryData['icon'] as IconData;
            final searchWord = categoryData['searchWord'] as String;

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
          }),

          // カスタム検索セクションヘッダー
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'カスタム検索',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showAddOrEditDialog(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('追加'),
                ),
              ],
            ),
          ),

          if (_customItems.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Card(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Center(
                    child: Text(
                      '登録されたカスタム検索項目はありません。\n「追加」からキーワードを登録できます。',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
            ..._customItems.map((item) {
              return Card(
                color: colorScheme.surfaceContainerHighest,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                clipBehavior: Clip.antiAlias,
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _launchGoogleMapsSearch(item.searchWord),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                          child: Row(
                            children: [
                              Icon(Icons.search, color: colorScheme.primary, size: 30),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      style: TextStyle(
                                        color: colorScheme.onSurface,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'キーワード: ${item.searchWord}',
                                      style: TextStyle(
                                        color: colorScheme.onSurfaceVariant,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      color: colorScheme.onSurfaceVariant,
                      tooltip: '編集',
                      onPressed: () => _showAddOrEditDialog(item: item),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      color: colorScheme.error,
                      tooltip: '削除',
                      onPressed: () => _deleteCustomItem(item),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              );
            }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}