import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/gear.dart';
import '../providers/category_provider.dart';
import '../providers/data_transfer_provider.dart';
import '../providers/database_providers.dart';
import '../providers/gear_provider.dart';
import '../providers/packing_provider.dart';
import '../services/data_transfer_service.dart';
import '../utils/weight_format.dart';
import '../widgets/gear_list_tile.dart';
import 'category_list_screen.dart';
import 'gear_detail_screen.dart';
import 'gear_edit_screen.dart';
import 'packing_sets_screen.dart';
import 'theme_settings_screen.dart';

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

  Offset _clampFabOffset(Offset offset, Size size) {
    final maxX = size.width - _fabSize - _fabMargin;
    final maxY = size.height - _fabSize - _fabMargin;
    return Offset(
      offset.dx.clamp(_fabMargin, maxX).toDouble(),
      offset.dy.clamp(_fabMargin, maxY).toDouble(),
    );
  }

  void _openNewGearScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GearEditScreen()),
    );
  }

  Future<void> _exportJson() async {
    if (_transferring) return;
    setState(() => _transferring = true);
    try {
      final gear = ref.read(gearProvider);
      final categories = ref.read(categoryProvider);
      final packing = ref.read(packingProvider);
      final items = await ref.read(packingProvider.notifier).allSetItems();
      await ref.read(dataTransferServiceProvider).shareBackupJson(
            gear: gear.items,
            categories: categories.items,
            packingSets: packing.sets,
            packingItemsBySet: items,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エクスポートに失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _transferring = false);
    }
  }

  Future<void> _exportZip() async {
    if (_transferring) return;
    setState(() => _transferring = true);
    try {
      final gear = ref.read(gearProvider);
      final categories = ref.read(categoryProvider);
      final packing = ref.read(packingProvider);
      final items = await ref.read(packingProvider.notifier).allSetItems();
      await ref.read(dataTransferServiceProvider).shareBackupZip(
            gear: gear.items,
            categories: categories.items,
            packingSets: packing.sets,
            packingItemsBySet: items,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ZIPエクスポートに失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _transferring = false);
    }
  }

  Future<void> _importBackup({required bool fromZip}) async {
    if (_transferring) return;

    final mode = await showDialog<ImportMode>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(fromZip ? 'ZIPをインポート' : 'JSONをインポート'),
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
      final extra = fromZip ? '画像も含めて' : '';
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('データを置き換えますか？'),
          content: Text('現在の在庫・カテゴリ・持ち出しセット${extra}がすべて削除されます。'),
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
      final result = fromZip
          ? await service.pickAndImportBackupZip(mode: mode)
          : await service.pickAndImportBackup(mode: mode);
      if (result == null) return;

      await reloadAllProviders(ref);
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('インポート完了'),
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
          SnackBar(content: Text('インポートに失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _transferring = false);
    }
  }

  void _showDataMenu() {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text('JSONエクスポート'),
              subtitle: const Text('在庫データのみ（軽量）'),
              onTap: () {
                Navigator.pop(context);
                _exportJson();
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_zip),
              title: const Text('ZIPエクスポート（画像付き）'),
              subtitle: const Text('在庫データ + 写真'),
              onTap: () {
                Navigator.pop(context);
                _exportZip();
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('JSONインポート'),
              onTap: () {
                Navigator.pop(context);
                _importBackup(fromZip: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_zip_outlined),
              title: const Text('ZIPインポート（画像付き）'),
              onTap: () {
                Navigator.pop(context);
                _importBackup(fromZip: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSettingsMenu() {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('背景テーマ'),
              subtitle: const Text('Army Green / Navy / Air Force Blue / Starlight'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ThemeSettingsScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
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
    final filterName = gearState.filterCategoryName(categories);
    final weightTitle = filterName == null ? '積載合計重量' : '$filterNameの合計重量';

    final canReorder = gearState.sortOption == GearSortOption.manual &&
        gearState.searchQuery.trim().isEmpty &&
        gearState.filterCategoryId == null;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'GEAR BASE',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          PopupMenuButton<GearSortOption>(
            tooltip: '並び替え',
            icon: const Icon(Icons.sort),
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
          IconButton(
            tooltip: 'データの入出力',
            onPressed: _transferring ? null : _showDataMenu,
            icon: _transferring
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.swap_vert),
          ),
          IconButton(
            tooltip: '設定',
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsMenu,
          ),
          IconButton(
            tooltip: 'カテゴリ管理',
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
          IconButton(
            tooltip: '持ち出しセット',
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
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final offset = _clampFabOffset(
            _fabOffset ??
                Offset(
                  size.width - _fabSize - 18,
                  size.height - _fabSize - 18,
                ),
            size,
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
                            '$weightTitle：$weightLabel',
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
                        if (gearState.hasActiveFilters)
                          Text(
                            '${items.length} 件',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
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
                              '≡ をドラッグして並び替え / アイテムを重ねて格納',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          DragTarget<int>(
                            onAcceptWithDetails: (details) async {
                              await gearNotifier.updateParent(details.data, null);
                            },
                            builder: (context, candidateData, _) {
                              final active = candidateData.isNotEmpty;
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: active
                                      ? Theme.of(context).colorScheme.errorContainer
                                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: active
                                        ? Theme.of(context).colorScheme.error
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.outbox,
                                      size: 16,
                                      color: active
                                          ? Theme.of(context).colorScheme.onErrorContainer
                                          : null,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '格納解除',
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                            color: active
                                                ? Theme.of(context).colorScheme.onErrorContainer
                                                : null,
                                          ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: items.isEmpty
                        ? Center(child: Text(_emptyMessage(gearState, items)))
                        : canReorder
                            ? _buildReorderableList(items, gearNotifier)
                            : _buildNormalList(items, gearNotifier),
                  ),
                ],
              ),
              Positioned(
                left: offset.dx,
                top: offset.dy,
                child: GestureDetector(
                  onPanStart: (_) => setState(() => _fabDragging = true),
                  onPanUpdate: (details) {
                    setState(() {
                      _fabOffset = _clampFabOffset(
                        offset + details.delta,
                        size,
                      );
                    });
                  },
                  onPanEnd: (_) {
                    setState(() => _fabDragging = false);
                    _saveFabPosition();
                  },
                  child: Opacity(
                    opacity: _fabDragging ? 0.9 : 0.68,
                    child: FloatingActionButton(
                      heroTag: 'gear_list_add',
                      shape: const CircleBorder(),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      onPressed: _openNewGearScreen,
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

  Widget _buildNormalList(List<Gear> items, GearNotifier gearNotifier) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final gear = items[index];
        return Dismissible(
          key: ValueKey(gear.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: Theme.of(context).colorScheme.error,
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (_) async {
            return await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('削除しますか？'),
                content: Text('「${gear.name}」を削除します。'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('キャンセル'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('削除'),
                  ),
                ],
              ),
            );
          },
          onDismissed: (_) => gearNotifier.remove(gear.id!),
          child: _gearTile(gear),
        );
      },
    );
  }

  Widget _buildReorderableList(List<Gear> items, GearNotifier gearNotifier) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: items.length,
      onReorder: (oldIndex, newIndex) async {
        if (newIndex > oldIndex) newIndex--;

        final moved = items[oldIndex];
        // ターゲットが直上（インデックス newIndex）のアイテムかどうか。
        // ReorderableListView のデフォルト動作に「アイテムの上に落とす」という概念はないため、
        // ドラッグして移動した先が、本来の「並び順」の変更なのか、
        // それとも「あるアイテムの中に入れたい」のかを判別する必要があります。
        // ここではシンプルに、並び替えが発生した際、移動先が特定のアイテムと「重なった」場合を扱いたいですが、
        // 標準の ReorderableListView では位置情報の詳細取得が難しいため、
        // 「移動先の親の parentId を引き継ぐ」または「親を解除する」といった、
        // 並び替え結果から推測するロジックにします。

        final list = List<Gear>.of(items);
        final item = list.removeAt(oldIndex);
        list.insert(newIndex, item);

        // 基本的な並び替え保存
        await gearNotifier.reorderItems(list.map((g) => g.id!).toList());

        // 親子関係の推測:
        // 移動後の直前のアイテムが「親」になりうるか？
        // ここではユーザーが「上に持ってきてインデントさせる」操作を意図しているため、
        // ドラッグ後に「親を解除したい（左に戻したい）」場合は一番上か、特定の操作が必要になります。
        // 一旦、手動での parentId 更新は別のUI（詳細画面など）で行い、
        // ここでは「リストの並び順」の永続化に留めます。
        // ユーザーの要望である「ドラッグで上に持ってくると格納」を完全再現するには、
        // DragTarget を各タイルに仕込む必要があります。
      },
      itemBuilder: (context, index) {
        final gear = items[index];
        final isChild = gear.parentId != null;

        Widget tile = GearInventoryListTile(
          gear: gear,
          reorderIndex: index,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GearDetailScreen(gear: gear),
              ),
            );
          },
          trailing: IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GearEditScreen(existing: gear),
                ),
              );
            },
          ),
        );

        if (isChild) {
          tile = Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            child: tile,
          );
          tile = Dismissible(
            key: ValueKey('dismiss_${gear.id}'),
            direction: DismissDirection.startToEnd,
            background: Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 20),
              color: Theme.of(context).colorScheme.tertiary,
              child: const Icon(Icons.outbox, color: Colors.white),
            ),
            confirmDismiss: (direction) async {
              if (direction == DismissDirection.startToEnd) {
                await gearNotifier.updateParent(gear.id!, null);
                return false; // リストからは削除しない
              }
              return false;
            },
            child: tile,
          );
        }

        return DragTarget<int>(
          key: ValueKey(gear.id),
          onWillAcceptWithDetails: (details) => details.data != gear.id,
          onAcceptWithDetails: (details) async {
            final childId = details.data;
            await gearNotifier.updateParent(childId, gear.id);
          },
          builder: (context, candidateData, rejectedData) {
            final isCandidate = candidateData.isNotEmpty;
            return Material(
              color: isCandidate
                  ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
                  : Theme.of(context).colorScheme.surface,
              child: LongPressDraggable<int>(
                data: gear.id,
                axis: Axis.vertical,
                feedback: SizedBox(
                  width: MediaQuery.of(context).size.width - 32,
                  child: Material(
                    elevation: 8,
                    borderRadius: BorderRadius.circular(8),
                    child: GearInventoryListTile(gear: gear),
                  ),
                ),
                childWhenDragging: Opacity(
                  opacity: 0.3,
                  child: GearInventoryListTile(gear: gear, reorderIndex: index),
                ),
                child: tile,
              ),
            );
          },
        );
      },
    );
  }

  Widget _gearTile(Gear gear) {
    return GearInventoryListTile(
      gear: gear,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GearDetailScreen(gear: gear),
          ),
        );
      },
      trailing: IconButton(
        icon: const Icon(Icons.edit),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GearEditScreen(existing: gear),
            ),
          );
        },
      ),
    );
  }
}
