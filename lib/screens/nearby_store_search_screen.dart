import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart' as url_launcher;

// 周辺スポットのカテゴリ定義
enum SpotCategory {
  firewood, // 薪（キャンプ場、薪販売店）
  supermarket, // スーパー
  homeCenter, // ホームセンター
  convenience, // コンビニ
}

// 周辺スポットのモデル
class NearbySpot {
  final String id;
  final String name;
  final SpotCategory category;
  final double distanceKm; // 現在地からの距離 (km)
  final double angleDegrees; // 現在地からの方角 (0 = 北, 90 = 東, 180 = 南, 270 = 西)
  final String description;
  final String businessHours;
  final double latitude;
  final double longitude;

  NearbySpot({
    required this.id,
    required this.name,
    required this.category,
    required this.distanceKm,
    required this.angleDegrees,
    required this.description,
    required this.businessHours,
    required this.latitude,
    required this.longitude,
  });

  IconData get icon {
    switch (category) {
      case SpotCategory.firewood:
        return Icons.local_fire_department;
      case SpotCategory.supermarket:
        return Icons.local_grocery_store;
      case SpotCategory.homeCenter:
        return Icons.build;
      case SpotCategory.convenience:
        return Icons.storefront;
    }
  }

  Color get color {
    switch (category) {
      case SpotCategory.firewood:
        return Colors.orangeAccent;
      case SpotCategory.supermarket:
        return Colors.greenAccent;
      case SpotCategory.homeCenter:
        return Colors.blueAccent;
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

class _NearbyStoreSearchScreenState extends State<NearbyStoreSearchScreen>
    with SingleTickerProviderStateMixin {
  Position? _currentPosition;
  bool _isLoadingLocation = true;
  String _loadingMessage = '現在地を取得中...';
  String? _locationError;
  bool _showErrorBanner = false;
  SpotCategory _selectedCategory = SpotCategory.firewood;
  NearbySpot? _selectedSpot;
  double _maxDistanceKm = 2.0; // レーダーの最大表示距離（初期値を2.0kmに変更）

  late AnimationController _radarAnimationController;
  final List<NearbySpot> _allSpots = [];
  List<NearbySpot> _filteredSpots = [];

  @override
  void initState() {
    super.initState();
    _radarAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _determinePosition();
  }

  @override
  void dispose() {
    _radarAnimationController.dispose();
    super.dispose();
  }

  // OpenStreetMap / Overpass APIから周辺スポットを取得するメソッド
  Future<void> _fetchNearbySpotsFromOSM(double lat, double lng) async {
    setState(() {
      _isLoadingLocation = true;
      _loadingMessage = '周辺のスポット情報をスキャン中...';
    });
    
    _allSpots.clear();

    // 最大探索半径を現在の選択距離に合わせて動的に変更（初期は2km = 2000mとなり負荷軽減）
    final double radiusMeters = _maxDistanceKm * 1000;

    // Overpass QLクエリ (タイムアウト設定を60秒に変更)
    final query = '''
[out:json][timeout:60];
(
  node["shop"="supermarket"](around:$radiusMeters, $lat, $lng);
  way["shop"="supermarket"](around:$radiusMeters, $lat, $lng);
  
  node["shop"="convenience"](around:$radiusMeters, $lat, $lng);
  way["shop"="convenience"](around:$radiusMeters, $lat, $lng);
  
  node["shop"~"doityourself|hardware"](around:$radiusMeters, $lat, $lng);
  way["shop"~"doityourself|hardware"](around:$radiusMeters, $lat, $lng);
  
  node["tourism"="camp_site"](around:$radiusMeters, $lat, $lng);
  way["tourism"="camp_site"](around:$radiusMeters, $lat, $lng);
  
  node["shop"="firewood"](around:$radiusMeters, $lat, $lng);
  way["shop"="firewood"](around:$radiusMeters, $lat, $lng);
);
out center;
''';

    debugPrint('Overpass API: リクエスト送信準備中... (lat: $lat, lng: $lng, 半径: $radiusMeters m)');
    try {
      debugPrint('Overpass API: POST送信直前 - URL: https://overpass-api.de/api/interpreter');
      final response = await http.post(
        Uri.parse('https://overpass-api.de/api/interpreter'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': 'CampInventoryApp/1.0 (https://github.com/koichisaotome/camp_inventory_app)',
          'Accept': 'application/json',
        },
        body: {'data': query},
      ).timeout(const Duration(seconds: 70)); // クエリタイムアウト(60秒)に合わせて通信タイムアウトを70秒に延長
      debugPrint('Overpass API: レスポンス受信成功 - ステータスコード: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> elements = data['elements'] ?? [];

        for (final element in elements) {
          final tags = element['tags'] as Map<String, dynamic>? ?? {};
          final name = tags['name'] as String? ?? '名称未設定の施設';
          
          double? spotLat;
          double? spotLng;
          if (element['type'] == 'node') {
            spotLat = element['lat']?.toDouble();
            spotLng = element['lon']?.toDouble();
          } else if (element['type'] == 'way' && element['center'] != null) {
            spotLat = element['center']['lat']?.toDouble();
            spotLng = element['center']['lon']?.toDouble();
          }

          if (spotLat == null || spotLng == null) continue;

          final double distanceInMeters = Geolocator.distanceBetween(lat, lng, spotLat, spotLng);
          final double distanceKm = distanceInMeters / 1000.0;

          double bearing = Geolocator.bearingBetween(lat, lng, spotLat, spotLng);
          if (bearing < 0) {
            bearing += 360;
          }

          SpotCategory category;
          String description = '';
          String businessHours = tags['opening_hours'] as String? ?? '営業時間情報なし';

          if (tags['tourism'] == 'camp_site' || tags['shop'] == 'firewood') {
            category = SpotCategory.firewood;
            description = tags['tourism'] == 'camp_site'
                ? 'キャンプ場売店（薪・炭を購入できる場合があります）'
                : '薪販売店 / 木材販売所';
          } else if (tags['shop'] == 'supermarket') {
            category = SpotCategory.supermarket;
            description = '食材・BBQ用品の調達に便利なスーパーマーケット';
          } else if (tags['shop'] == 'doityourself' || tags['shop'] == 'hardware') {
            category = SpotCategory.homeCenter;
            description = 'ホームセンター（炭、アウトドアギア、ガス缶等）';
          } else if (tags['shop'] == 'convenience') {
            category = SpotCategory.convenience;
            description = 'コンビニエンスストア（氷、飲料、軽食）';
          } else {
            continue;
          }

          _allSpots.add(NearbySpot(
            id: '${element['type']}_${element['id']}',
            name: name,
            category: category,
            distanceKm: distanceKm,
            angleDegrees: bearing,
            description: description,
            businessHours: businessHours,
            latitude: spotLat,
            longitude: spotLng,
          ));
        }
      } else {
        if (response.statusCode == 504) {
          throw Exception('サーバーが混雑しています。しばらくしてから再試行してください。');
        } else {
          throw Exception('Overpass API returned status code ${response.statusCode}');
        }
      }
    } catch (e, st) {
      debugPrint('Overpass API: エラーが発生しました: $e');
      debugPrint('Overpass API: スタックトレース:\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('データ取得失敗: $e')),
        );
      }
      setState(() {
        _locationError = 'データ取得失敗: $e';
        _showErrorBanner = true;
      });
      _generateFallbackMockData(lat, lng);
    }

    setState(() {
      _isLoadingLocation = false;
    });
    _updateFilteredSpots();
  }

  void _generateFallbackMockData(double baseLat, double baseLng) {
    _allSpots.clear();
    
    final List<Map<String, dynamic>> templates = [
      {
        'id': 'fw_1',
        'name': '周辺 薪販売所 (無人モック)',
        'category': SpotCategory.firewood,
        'offsetLat': 0.008,
        'offsetLng': 0.008,
        'description': '広葉樹・針葉樹あり。1束500円（オフラインモックデータ）',
        'businessHours': '24時間営業',
      },
      {
        'id': 'sp_1',
        'name': 'ローカルフレッシュ スーパー (モック)',
        'category': SpotCategory.supermarket,
        'offsetLat': -0.025,
        'offsetLng': -0.015,
        'description': 'BBQ食材や飲み物の調達用（オフラインモックデータ）',
        'businessHours': '09:00 - 21:00',
      },
      {
        'id': 'hc_1',
        'name': 'コメリ ハード＆グリーン (モック)',
        'category': SpotCategory.homeCenter,
        'offsetLat': 0.035,
        'offsetLng': -0.01,
        'description': '炭・OD缶・着火剤あり（オフラインモックデータ）',
        'businessHours': '09:00 - 19:30',
      },
      {
        'id': 'cv_1',
        'name': 'コンビニエンスストア (モック)',
        'category': SpotCategory.convenience,
        'offsetLat': 0.012,
        'offsetLng': -0.005,
        'description': '氷や飲み物の追加に便利（オフラインモックデータ）',
        'businessHours': '24時間営業',
      },
    ];

    for (final temp in templates) {
      final spotLat = baseLat + (temp['offsetLat'] as double);
      final spotLng = baseLng + (temp['offsetLng'] as double);

      final double distanceInMeters = Geolocator.distanceBetween(baseLat, baseLng, spotLat, spotLng);
      final double distanceKm = distanceInMeters / 1000.0;

      double bearing = Geolocator.bearingBetween(baseLat, baseLng, spotLat, spotLng);
      if (bearing < 0) {
        bearing += 360;
      }

      _allSpots.add(NearbySpot(
        id: temp['id'] as String,
        name: temp['name'] as String,
        category: temp['category'] as SpotCategory,
        distanceKm: distanceKm,
        angleDegrees: bearing,
        description: temp['description'] as String,
        businessHours: temp['businessHours'] as String,
        latitude: spotLat,
        longitude: spotLng,
      ));
    }
  }

  void _updateFilteredSpots() {
    setState(() {
      _filteredSpots = _allSpots
          .where((spot) =>
              spot.category == _selectedCategory &&
              spot.distanceKm <= _maxDistanceKm)
          .toList();
      _filteredSpots.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
      if (_selectedSpot != null &&
          (_selectedSpot!.category != _selectedCategory ||
              _selectedSpot!.distanceKm > _maxDistanceKm)) {
        _selectedSpot = null;
      }
    });
  }

  Future<void> _determinePosition() async {
    setState(() {
      _isLoadingLocation = true;
      _loadingMessage = '現在地を取得中...';
      _locationError = null;
      _showErrorBanner = false;
    });

    bool serviceEnabled;
    LocationPermission permission;

    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isLoadingLocation = false;
          _locationError = '位置情報サービスが無効です。';
          _showErrorBanner = true;
        });
        _fetchNearbySpotsFromOSM(35.4014, 138.5615);
        return;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLoadingLocation = false;
            _locationError = '位置情報の使用が許可されませんでした。';
            _showErrorBanner = true;
          });
          _fetchNearbySpotsFromOSM(35.4014, 138.5615);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLoadingLocation = false;
          _locationError = '位置情報の許可が永久に拒否されています。設定から許可してください。';
          _showErrorBanner = true;
        });
        _fetchNearbySpotsFromOSM(35.4014, 138.5615);
        return;
      }

      debugPrint('Geolocator: 現在地取得を開始します。');
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      debugPrint('Geolocator: 現在地取得成功 (lat: ${position.latitude}, lng: ${position.longitude})');
      setState(() {
        _currentPosition = position;
        _showErrorBanner = false;
      });
      await _fetchNearbySpotsFromOSM(position.latitude, position.longitude);
    } catch (e, st) {
      debugPrint('Geolocator: エラーが発生しました: $e');
      debugPrint('Geolocator: スタックトレース:\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('データ取得失敗: $e')),
        );
      }
      setState(() {
        _isLoadingLocation = false;
        _locationError = '現在地の取得中にエラーが発生しました: $e';
        _showErrorBanner = true;
      });
      _fetchNearbySpotsFromOSM(35.4014, 138.5615);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('周辺スポットレーダー'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _determinePosition,
            tooltip: '現在地を更新',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 6,
            child: Stack(
              children: [
                AnimatedBuilder(
                  animation: _radarAnimationController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: RadarPainter(
                        sweepAngle: _radarAnimationController.value * 2 * math.pi,
                        spots: _filteredSpots,
                        selectedSpot: _selectedSpot,
                        maxDistanceKm: _maxDistanceKm,
                      ),
                      child: Container(),
                    );
                  },
                ),
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.greenAccent.withOpacity(0.8),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_isLoadingLocation)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black54,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _loadingMessage,
                              style: const TextStyle(color: Colors.greenAccent, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else if (_locationError != null && _showErrorBanner)
                  Positioned(
                    top: 10,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.white, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _locationError!,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 16),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              setState(() {
                                _showErrorBanner = false;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                Positioned(
                  right: 16,
                  top: 16,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        if (_maxDistanceKm == 10.0) {
                          _maxDistanceKm = 2.0;
                        } else if (_maxDistanceKm == 2.0) {
                          _maxDistanceKm = 5.0;
                        } else {
                          _maxDistanceKm = 10.0;
                        }
                        _updateFilteredSpots();
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withOpacity(0.12),
                        border: Border.all(color: Colors.greenAccent, width: 1),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.greenAccent.withOpacity(0.2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Text(
                        'RANGE: ${_maxDistanceKm.toInt()} km',
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              border: const Border(
                top: BorderSide(color: Colors.greenAccent, width: 0.5),
                bottom: BorderSide(color: Colors.greenAccent, width: 0.5),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildCategoryButton(SpotCategory.firewood, '薪', Icons.local_fire_department),
                _buildCategoryButton(SpotCategory.supermarket, 'スーパー', Icons.local_grocery_store),
                _buildCategoryButton(SpotCategory.homeCenter, 'ホムセン', Icons.build),
                _buildCategoryButton(SpotCategory.convenience, 'コンビニ', Icons.storefront),
              ],
            ),
          ),
          Expanded(
            flex: 5,
            child: Container(
              color: Colors.grey[950],
              child: _filteredSpots.isEmpty
                  ? const Center(
                      child: Text(
                        '周辺にスポットが見つかりません',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredSpots.length,
                      itemBuilder: (context, index) {
                        final spot = _filteredSpots[index];
                        final isSelected = _selectedSpot?.id == spot.id;

                        return InkWell(
                            onTap: () {
                              setState(() {
                                _selectedSpot = spot;
                              });
                            },
                           child: AnimatedContainer(
                             duration: const Duration(milliseconds: 300),
                             margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                             padding: const EdgeInsets.all(12),
                             decoration: BoxDecoration(
                               color: isSelected
                                   ? spot.color.withOpacity(0.15)
                                   : Colors.grey[900],
                               border: Border.all(
                                 color: isSelected ? spot.color : Colors.transparent,
                                 width: 1.5,
                               ),
                               borderRadius: BorderRadius.circular(10),
                               boxShadow: isSelected
                                   ? [
                                       BoxShadow(
                                         color: spot.color.withOpacity(0.3),
                                         blurRadius: 8,
                                         spreadRadius: 1,
                                       )
                                     ]
                                   : [],
                             ),
                             child: Column( // Main Column
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Row( // Top Row: Icon, Name, Distance
                                   children: [
                                     CircleAvatar(
                                       backgroundColor: spot.color.withOpacity(0.2),
                                       child: Icon(spot.icon, color: spot.color),
                                     ),
                                     const SizedBox(width: 12),
                                     Expanded(
                                       child: Column( // Middle Column: Name/Distance, Description, Hours
                                         crossAxisAlignment: CrossAxisAlignment.start,
                                         children: [
                                           Row( // Name and Distance Row
                                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                             children: [
                                               Expanded(
                                                 child: Text(
                                                   spot.name,
                                                   style: const TextStyle(
                                                     color: Colors.white,
                                                     fontSize: 16,
                                                     fontWeight: FontWeight.bold,
                                                   ),
                                                   overflow: TextOverflow.ellipsis,
                                                 ),
                                               ),
                                               const SizedBox(width: 8),
                                               Text(
                                                 '${spot.distanceKm.toStringAsFixed(1)} km',
                                                 style: TextStyle(
                                                   color: spot.color,
                                                   fontWeight: FontWeight.bold,
                                                 ),
                                               ),
                                             ],
                                           ),
                                           const SizedBox(height: 4),
                                           Text(
                                             spot.description,
                                             style: TextStyle(color: Colors.grey[400], fontSize: 13),
                                           ),
                                           const SizedBox(height: 4),
                                           Row( // Hours Row
                                             children: [
                                               Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                                               const SizedBox(width: 4),
                                               Text(
                                                 spot.businessHours,
                                                 style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                               ),
                                             ],
                                           ),
                                         ],
                                       ),
                                     ),
                                   ],
                                 ),
                                 if (isSelected) // Navigation Button
                                   Padding(
                                     padding: const EdgeInsets.only(top: 8.0),
                                     child: FilledButton.icon(
                                       onPressed: () {
                                         if (_selectedSpot != null) {
                                           _launchGoogleMaps(_selectedSpot!); // 選択中のスポットでナビ開始
                                         }
                                       },
                                       icon: const Icon(Icons.navigation, size: 18),
                                       label: const Text('ナビ開始'),
                                       style: FilledButton.styleFrom(
                                         backgroundColor: spot.color,
                                         foregroundColor: Colors.black,
                                         textStyle: const TextStyle(fontWeight: FontWeight.bold),
                                         padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                       ),
                                     ),
                                   ),
                               ],
                             ),
                           ));
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // Google Mapsでナビを開始するメソッド
  Future<void> _launchGoogleMaps(NearbySpot spot) async {
    final String navUrl =
        'google.navigation:q=${spot.latitude},${spot.longitude}';
    final String webUrl =
        'https://www.google.com/maps/dir/?api=1&destination=${spot.latitude},${spot.longitude}';

    try {
      // Androidの場合、google.navigationを優先して試行
      if (Theme.of(context).platform == TargetPlatform.android) {
        if (await url_launcher.launchUrl(
          Uri.parse(navUrl),
          mode: url_launcher.LaunchMode.externalApplication,
        )) {
          return;
        }
      }

      // google.navigationが失敗した場合、またはAndroid以外の場合、Web版を試行
      if (await url_launcher.launchUrl(
        Uri.parse(webUrl),
        mode: url_launcher.LaunchMode.externalApplication,
      )) {
        return;
      }

      // どちらも失敗した場合
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: const Text('Googleマップを起動できませんでした。')),
        );
      }
    } catch (e) {
      debugPrint('Google Maps起動エラー: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Googleマップの起動中にエラーが発生しました: $e')),
        );
      }
    }
  }

  Widget _buildCategoryButton(SpotCategory category, String label, IconData icon) {
    final isSelected = _selectedCategory == category;
    Color buttonColor;
    switch (category) {
      case SpotCategory.firewood:
        buttonColor = Colors.orangeAccent;
        break;
      case SpotCategory.supermarket:
        buttonColor = Colors.greenAccent;
        break;
      case SpotCategory.homeCenter:
        buttonColor = Colors.blueAccent;
        break;
      case SpotCategory.convenience:
        buttonColor = Colors.pinkAccent;
        break;
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = category;
          _updateFilteredSpots();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? buttonColor.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? buttonColor : Colors.grey[700]!,
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? buttonColor : Colors.grey[400],
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[400],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RadarPainter extends CustomPainter {
  final double sweepAngle;
  final List<NearbySpot> spots;
  final NearbySpot? selectedSpot;
  final double maxDistanceKm;

  RadarPainter({
    required this.sweepAngle,
    required this.spots,
    required this.selectedSpot,
    required this.maxDistanceKm,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 * 0.9;

    final bgPaint = Paint()
      ..color = const Color(0xFF041208)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    final gridPaint = Paint()
      ..color = Colors.green.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(center, radius * 0.33, gridPaint);
    canvas.drawCircle(center, radius * 0.66, gridPaint);
    canvas.drawCircle(center, radius, gridPaint);

    canvas.drawLine(Offset(center.dx - radius, center.dy), Offset(center.dx + radius, center.dy), gridPaint);
    canvas.drawLine(Offset(center.dx, center.dy - radius), Offset(center.dx, center.dy + radius), gridPaint);

    const textStyle = TextStyle(color: Colors.greenAccent, fontSize: 10, fontFamily: 'monospace');
    _drawText(canvas, 'N', Offset(center.dx, center.dy - radius - 15), textStyle);
    _drawText(canvas, 'S', Offset(center.dx, center.dy + radius + 5), textStyle);
    _drawText(canvas, 'W', Offset(center.dx - radius - 15, center.dy - 6), textStyle);
    _drawText(canvas, 'E', Offset(center.dx + radius + 8, center.dy - 6), textStyle);

    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        colors: [
          Colors.green.withOpacity(0.0),
          Colors.greenAccent.withOpacity(0.4),
        ],
        stops: const [0.85, 1.0],
        transform: GradientRotation(sweepAngle - 2 * math.pi),
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, sweepPaint);

    for (final spot in spots) {
      final angleRad = (spot.angleDegrees - 90) * math.pi / 180;
      final spotDistanceRatio = spot.distanceKm / maxDistanceKm;
      
      if (spotDistanceRatio > 1.0) continue;

      final spotOffset = Offset(
        center.dx + radius * spotDistanceRatio * math.cos(angleRad),
        center.dy + radius * spotDistanceRatio * math.sin(angleRad),
      );

      final currentAngle = (sweepAngle) % (2 * math.pi);
      double spotAngleNormalized = angleRad % (2 * math.pi);
      if (spotAngleNormalized < 0) spotAngleNormalized += 2 * math.pi;

      double angleDiff = (currentAngle - spotAngleNormalized) % (2 * math.pi);
      if (angleDiff < 0) angleDiff += 2 * math.pi;

      double intensity = 0.2;
      if (angleDiff < math.pi / 2) {
        intensity = 1.0 - (angleDiff / (math.pi / 2));
        intensity = math.max(0.2, intensity);
      }

      final isSelected = selectedSpot?.id == spot.id;

      if (isSelected) {
        final highlightPaint = Paint()
          ..color = spot.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
        canvas.drawCircle(spotOffset, 12, highlightPaint);
        
        final pulsePaint = Paint()
          ..color = spot.color.withOpacity(0.3)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(spotOffset, 8 + 4 * math.sin(sweepAngle * 2), pulsePaint);
      }

      final spotPaint = Paint()
        ..color = isSelected ? spot.color : spot.color.withOpacity(intensity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(spotOffset, isSelected ? 7 : 5, spotPaint);

      final glowPaint = Paint()
        ..color = spot.color.withOpacity(isSelected ? 0.4 : 0.3 * intensity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(spotOffset, isSelected ? 12 : 8, glowPaint);
    }
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant RadarPainter oldDelegate) {
    return oldDelegate.sweepAngle != sweepAngle ||
        oldDelegate.spots != spots ||
        oldDelegate.selectedSpot != selectedSpot;
  }
}
