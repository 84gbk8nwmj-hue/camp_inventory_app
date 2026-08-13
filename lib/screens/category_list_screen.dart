import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/category.dart';
import '../providers/category_provider.dart';
import '../providers/database_providers.dart';
import '../providers/gear_provider.dart';

class CategoryListScreen extends ConsumerStatefulWidget {
  const CategoryListScreen({super.key});

  @override
  ConsumerState<CategoryListScreen> createState() => _CategoryListScreenState();
}

class _CategoryListScreenState extends ConsumerState<CategoryListScreen> {
  static const _fabPositionSettingKey = 'category_list_add_fab_position';
  static const _fabSize = 58.0;
  static const _fabMargin = 12.0;

  Offset? _fabOffset;
  bool _fabDragging = false;
  Offset? _startFabOffset;
  Offset? _startGlobalPosition;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadFabPosition);
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
    final minX = _fabMargin;
    // FABの左上隅の最大X座標 (画面右端からのマージンとFABの幅を考慮)
    final maxX = size.width - _fabSize - _fabMargin;

    // FABの左上隅の最小Y座標 (AppBarの下と上からのマージン)
    final minY = viewPadding.top + kToolbarHeight + _fabMargin;
    // FABの左上隅の最大Y座標 (画面下端からのマージンとFABの高さを考慮)
    final maxY = size.height - viewPadding.bottom - _fabSize - _fabMargin;

    return Offset(
      offset.dx.clamp(minX, maxX).toDouble(),
      offset.dy.clamp(minY, maxY).toDouble(),
    );
  }

  Future<void> _addCategory() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('カテゴリを追加'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'カテゴリ名'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('追加'),
          ),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      await ref.read(categoryProvider.notifier).add(ctrl.text);
      await ref.read(gearProvider.notifier).load();
    }
    ctrl.dispose();
  }

  Future<void> _renameCategory(GearCategory category) async {
    final ctrl = TextEditingController(text: category.name);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('カテゴリ名を変更'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      await ref.read(categoryProvider.notifier).rename(category, ctrl.text);
      await ref.read(gearProvider.notifier).load();
    }
    ctrl.dispose();
  }

  Future<void> _deleteCategory(GearCategory category) async {
    final db = ref.read(appDatabaseProvider);
    final count = await db.countGearInCategory(category.id!);
    final categories = ref.read(categoryProvider);
    final other = categories.otherCategory;

    if (count > 0 && other?.id == category.id) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('「その他」は削除できません')),
        );
      }
      return;
    }

    final message = count > 0
        ? '「${category.name}」のギア ${count} 件は「${other?.name}」へ移されます。'
        : '「${category.name}」を削除します。';

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('カテゴリを削除'),
        content: Text(message),
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

    if (ok == true) {
      final success = await ref.read(categoryProvider.notifier).remove(
            category,
            reassignToId: count > 0 ? other?.id : null,
          );
      if (success) {
        await ref.read(gearProvider.notifier).load();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('削除できませんでした')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoryProvider);
    final categoryNotifier = ref.read(categoryProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('カテゴリ管理')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final viewPadding = MediaQuery.of(context).padding;
          final offset = _clampFabOffset(
            _fabOffset ??
                Offset(
                  size.width - _fabSize - _fabMargin,
                  size.height - viewPadding.bottom - _fabSize - _fabMargin,
                ),
            size,
            viewPadding,
          );

          return Stack(
            children: [
              if (categories.items.isEmpty)
                const Center(child: Text('カテゴリがありません'))
              else
                SafeArea(
                  top: false,
                  left: false,
                  right: false,
                  bottom: true,
                  child: ReorderableListView.builder(
                    onReorder: (oldIndex, newIndex) {
                      final items = [...categories.items];
                      if (oldIndex < newIndex) {
                        newIndex -= 1;
                      }
                      final item = items.removeAt(oldIndex);
                      items.insert(newIndex, item);
                      categoryNotifier.reorderItems(
                        items.map((e) => e.id!).toList(),
                      );
                    },
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: categories.items.length,
                    itemBuilder: (context, index) {
                      final c = categories.items[index];
                      return Material(
                        key: ValueKey('category_${c.id}'),
                        color: Theme.of(context).colorScheme.surface,
                        child: ListTile(
                          leading: ReorderableDragStartListener(
                            index: index,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Icon(
                                Icons.drag_indicator,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                          title: Text(c.name),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _renameCategory(c),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _deleteCategory(c),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              Positioned(
                left: offset.dx,
                top: offset.dy,
                child: GestureDetector(
                  onPanStart: (details) {
                    setState(() {
                      _fabDragging = true;
                      _startFabOffset = offset;
                      _startGlobalPosition = details.globalPosition;
                    });
                  },
                  onPanUpdate: (details) {
                    setState(() {
                      if (_startFabOffset == null || _startGlobalPosition == null) return;
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
                  child: Opacity(
                    opacity: _fabDragging ? 0.9 : 0.68,
                    child: FloatingActionButton(
                      heroTag: 'category_list_add',
                      shape: const CircleBorder(),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      onPressed: _addCategory,
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
