import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/reorderable_list_widgets.dart';
import '../providers/category_provider.dart';
import '../providers/data_transfer_provider.dart';
import '../providers/database_providers.dart';
import '../providers/gear_provider.dart';
import '../services/data_transfer_service.dart';
import '../utils/weight_format.dart';
import 'category_list_screen.dart';
import 'gear_edit_screen.dart';
import 'packing_sets_screen.dart';
import 'theme_settings_screen.dart';
import 'nearby_store_search_screen.dart'; // 追加

class GearListScreen extends ConsumerStatefulWidget {
  const GearListScreen({super.key});

  @override
  ConsumerState<GearListScreen> createState() => _GearListScreenState();
}

class _GearListScreenState extends ConsumerState<GearListScreen> {
  static const _fabPositionSettingKey = 'gear_list_add_fab_position';
  static const _fabSize = 58.0;
  static const _fabMargin = 12.0;

  final _searchCtrl = TextEditingController();
  bool _transferring = false;
  Offset? _fabOffset;
  bool _fabDragging = false;
  Offset? _startFabOffset; // 追加
  Offset? _startGlobalPosition; // 追加

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadFabPosition);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFabPosition() async {
    final raw = await ref
        .read(appDatabaseProvider)
        .getAppSetting(_fabPositionSettingKey);
    if (raw == null || !mounted) return;

    final parts = raw.split(',');
    if (parts.length != 2) return;
    final dx = double.tryParse(parts[0]);
    final dy = double.tryParse(parts[1]);
    if (dx == null || dy == null) return;

    setState(() => _fabOffset = Offset(dx, dy));
  }

  Future<void> _saveFabPosition() async {
    final offset = _fabOffset;
    if (offset == null) return;
    await ref.read(appDatabaseProvider).setAppSetting(
          _fabPositionSettingKey,
          '${offset.dx},${offset.dy}',
        );
  }

  Offset _clampFabOffset(Offset offset, Size size, EdgeInsets viewPadding) {
    // FABが表示されうる最小のY座標 (AppBarの下より少し上まで許容)
    // 左右方向: FABを画面内に収める
    final minX = _fabMargin;
    final maxX = size.width - _fabSize - _fabMargin;

    // 上下方向: SafeAreaとAppBarを考慮し、FABが重ならないようにする
    final minY = viewPadding.top + kToolbarHeight + _fabMargin;
    final maxY = size.height - viewPadding.bottom - _fabSize - _fabMargin;

    return Offset(
      offset.dx.clamp(minX, maxX).toDouble(),
      offset.dy.clamp(minY, maxY).toDouble(),
    );
  }

  void _openNewGearScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GearEditScreen()),
    );
  }



  Future<void> _createBackup() async {
    if (_transferring) return;
    setState(() => _transferring = true);
    try {
      await ref.read(dataTransferServiceProvider).shareBackupZipFromDatabase();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('バックアップ作成に失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _transferring = false);
    }
  }

  // ZIPバックアップ復元処理
  Future<void> _importBackupZip() async {
    if (_transferring) return;

    final mode = await showDialog<ImportMode>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('バックアップを復元'),
        content: const Text(
          '「置き換え」は現在のデータをすべて削除してから復元します。\n'
          '「統合」は同名ギアを更新し、新しいデータを追加します。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ImportMode.merge),
            child: const Text('統合'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ImportMode.replace),
            child: const Text('置き換え'),
          ),
        ],
      ),
    );
    if (mode == null) return;

    if (mode == ImportMode.replace) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('データを置き換えますか？'),
          content: const Text('現在の在庫・カテゴリ・持ち出しセットがすべて削除されます（画像も含む）。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('置き換える'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() => _transferring = true);
    try {
      final service = ref.read(dataTransferServiceProvider);
      final result = await service.pickAndImportBackupZip(mode: mode);
      if (result == null) return;

      await reloadAllProviders(ref);
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('復元完了'),
            content: Text(result.summary),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('復元に失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _transferring = false);
    }
  }





  String _emptyMessage(GearState gear, List<dynamic> items) {
    if (gear.items.isEmpty) return 'まだギアが登録されていません';
    if (gear.searchQuery.trim().isNotEmpty) {
      return '「${gear.searchQuery.trim()}」に一致するギアがありません';
    }
    return 'このカテゴリのギアはありません';
  }

  @override
  Widget build(BuildContext context) {
    final gearState = ref.watch(gearProvider);
    final categories = ref.watch(categoryProvider);
    final gearNotifier = ref.read(gearProvider.notifier);

    final items = gearState.displayItems(categories);
    final totalG = gearState.filteredTotalWeight(items);
    final weightLabel = WeightFormat.label(totalG);

    final canReorder = gearState.sortOption == GearSortOption.manual &&
        gearState.searchQuery.trim().isEmpty &&
        gearState.filterCategoryId == null;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16.0,
        title: const Text(
          'GEAR BASE',
          maxLines: 1,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: '近くのお店を探す',
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.location_on_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NearbyStoreSearchScreen(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: '持ち出しセット',
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.backpack_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PackingSetsScreen(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'カテゴリ管理',
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.category_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CategoryListScreen(),
                ),
              );
            },
          ),
          PopupMenuButton<GearSortOption>(
            tooltip: '表示順',
            icon: const Icon(Icons.sort),
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            constraints: const BoxConstraints(),
            initialValue: gearState.sortOption,
            onSelected: gearNotifier.setSortOption,
            itemBuilder: (context) => GearSortOption.values
                .map(
                  (o) => PopupMenuItem(
                    value: o,
                    child: Row(
                      children: [
                        if (o == gearState.sortOption)
                          const Icon(Icons.check, size: 18)
                        else
                          const SizedBox(width: 18),
                        const SizedBox(width: 8),
                        Text(o.label),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          PopupMenuButton<String>(
            tooltip: 'メニュー',
            icon: const Icon(Icons.more_vert),
            padding: const EdgeInsets.only(left: 4.0, right: 12.0),
            constraints: const BoxConstraints(),
            onSelected: (value) {
              switch (value) {
                case 'settings':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ThemeSettingsScreen(),
                    ),
                  );
                  break;
                case 'createBackup':
                  _createBackup();
                  break;
                case 'restoreBackup':
                  _importBackupZip();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'createBackup',
                child: Row(
                  children: [
                    Icon(Icons.upload_file, size: 20),
                    SizedBox(width: 12),
                    Text('バックアップを作成'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'restoreBackup',
                child: Row(
                  children: [
                    Icon(Icons.download, size: 20),
                    SizedBox(width: 12),
                    Text('バックアップを復元'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, size: 20),
                    SizedBox(width: 12),
                    Text('設定'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final viewPadding = MediaQuery.of(context).padding;
          // FABの初期位置をSafeAreaとFABのサイズを考慮して設定
          final defaultFabOffset = Offset(
            size.width - _fabSize - _fabMargin,
            size.height - viewPadding.bottom - _fabSize - _fabMargin,
          );
          final offset = _clampFabOffset(
            _fabOffset ?? defaultFabOffset,
            size,
            viewPadding,
          );

          return Stack(
            children: [
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'ギア名・メーカー・メモで検索',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: gearState.searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  gearNotifier.setSearchQuery('');
                                },
                              )
                            : null,
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onChanged: gearNotifier.setSearchQuery,
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Row(
                      children: [
                        const Icon(Icons.monitor_weight_outlined),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Total：$weightLabel',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer,
                                ),
                          ),
                        ),
                        Text(
                          'count：${items.length}',
                          textAlign: TextAlign.right,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 56,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          final selected = gearState.filterCategoryId == null;
                          return ChoiceChip(
                            label: const Text('すべて'),
                            selected: selected,
                            onSelected: (_) =>
                                gearNotifier.setFilterCategoryId(null),
                          );
                        }
                        final c = categories.items[index - 1];
                        final selected = gearState.filterCategoryId == c.id;
                        return ChoiceChip(
                          label: Text(c.name),
                          selected: selected,
                          onSelected: (_) =>
                              gearNotifier.setFilterCategoryId(c.id),
                        );
                      },
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemCount: categories.items.length + 1,
                    ),
                  ),
                  const Divider(height: 1),
                  if (canReorder)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '⋮⋮ をドラッグして並べ替え / 左右スワイプで格納・解除',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: items.isEmpty
                        ? Center(child: Text(_emptyMessage(gearState, items)))
                        : GearReorderableList(
                            items: items,
                            notifier: gearNotifier,
                          ),
                  ),
                ],
              ),
              Positioned(
                left: offset.dx,
                top: offset.dy,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque, // 追加
                  onPanStart: (details) {
                   setState(() {
                      _fabDragging = true;
                      _startFabOffset = offset; // 現在のFABのオフセットを記録
                      _startGlobalPosition = details.globalPosition; // ドラッグ開始時のポインター位置を記録
                    });
                  },
                  onPanUpdate: (details) {
                    setState(() {
                      if (_startFabOffset == null || _startGlobalPosition == null) return; // 念のためnullチェック
                      _fabOffset = _clampFabOffset(
                        _startFabOffset! + (details.globalPosition - _startGlobalPosition!),
                        size,
                        viewPadding,
                      );
                    });
                  },
                  onPanEnd: (_) {
                   setState(() => _fabDragging = false);
                    _saveFabPosition();
                  },
                  onTap: () {
                    _openNewGearScreen();
                  },
                  child: Opacity(
                    opacity: _fabDragging ? 0.9 : 0.68,
                    child: FloatingActionButton(
                      heroTag: 'gear_list_add',
                      shape: const CircleBorder(),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      onPressed: null, // タップ処理をGestureDetectorに移したためnullに設定
                      child: const Icon(Icons.add),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
