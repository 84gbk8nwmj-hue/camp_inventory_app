import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/gear.dart';
import '../providers/gear_provider.dart';
import '../providers/category_provider.dart';
import '../widgets/gear_list_tile.dart';
import '../screens/gear_detail_screen.dart';
import '../screens/gear_edit_screen.dart';

class GearReorderableList extends ConsumerWidget {
  final List<Gear> items;
  final GearNotifier notifier;

  const GearReorderableList({
    super.key,
    required this.items,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoryProvider);

    return ReorderableListView.builder(
      onReorder: (oldIndex, newIndex) {
        notifier.reorderWithSubtree(oldIndex, newIndex, categories);
      },
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final gear = items[index];
        final id = gear.id;
        if (id == null) return const SizedBox.shrink(key: ValueKey('empty'));

        final isChild = gear.parentId != null;

        return Dismissible(
          key: ValueKey('item_$id'),
          direction: DismissDirection.horizontal,
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.startToEnd) {
              // 右スワイプ: 格納先の選択
              await _showParentSelector(context, gear);
            } else if (direction == DismissDirection.endToStart) {
              // 左スワイプ: 解除
              await notifier.unnestItem(id);
            }
            return false; // 実際にはリストから削除しない
          },
          background: Container(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 20),
            child: Row(
              children: [
                Icon(Icons.account_tree, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text('格納先を選択', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          secondaryBackground: Container(
            color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.2),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('解除', style: TextStyle(color: Theme.of(context).colorScheme.tertiary, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Icon(Icons.outbox, color: Theme.of(context).colorScheme.tertiary),
              ],
            ),
          ),
          child: _buildTile(context, gear, index, isChild),
        );
      },
    );
  }

  Future<void> _showParentSelector(BuildContext context, Gear gear) async {
    final candidates = notifier.getParentCandidates(gear.id!);
    final currentParentId = gear.parentId;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    '格納先を選択: ${gear.name}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: candidates.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return ListTile(
                          leading: const SizedBox(
                            width: 56,
                            height: 56,
                            child: Icon(Icons.not_interested),
                          ),
                          title: const Text('解除（親なし）'),
                          selected: currentParentId == null,
                          onTap: () {
                            notifier.updateParent(gear.id!, null);
                            Navigator.pop(context);
                          },
                        );
                      }
                      final candidate = candidates[index - 1];
                      return ListTile(
                        leading: SizedBox(
                          width: 56,
                          height: 56,
                          child: GearListTileLeading(gear: candidate),
                        ),
                        title: Text(candidate.name),
                        subtitle: Text(candidate.categoryName),
                        selected: currentParentId == candidate.id,
                        onTap: () {
                          notifier.updateParent(gear.id!, candidate.id);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTile(BuildContext context, Gear gear, int index, bool isChild) {
    // 境界線と総重量の判定
    bool isGroupStart = false;
    bool isGroupEnd = false;
    double? groupTotalWeight;

    // 親ギア（グループの開始）の判定
    final children = items.where((g) => g.parentId == gear.id).toList();
    if (children.isNotEmpty) {
      isGroupStart = true;
      // グループ総重量の計算（親 + 全ての子孫）
      groupTotalWeight = _calculateSubtreeWeight(gear);
    }

    // グループの終了判定（最後の子ギア）
    if (isChild) {
      final isLastItem = index == items.length - 1;
      if (isLastItem) {
        isGroupEnd = true;
      } else {
        final nextItem = items[index + 1];
        // 次のアイテムが同じ親を持たない、かつ次のアイテムが自分の子でもない場合、グループ終了
        if (nextItem.parentId != gear.parentId && nextItem.parentId != gear.id) {
          isGroupEnd = true;
        }
      }
    }

    // ReorderableListView ではハンドルが自動で付く場合もあるが、
    // GearListRowLeading 内でカスタムハンドルを表示するように設定されている
    final leading = GearListRowLeading(
      gear: gear,
      reorderIndex: index,
      // ReorderableListView の標準ハンドルを使用する場合は builder は null でよいが、
      // 既存のデザインを維持するため ReorderableDragStartListener で包む
      dragHandleBuilder: (context, handle) => ReorderableDragStartListener(
        index: index,
        child: handle,
      ),
    );

    Widget tile = GearInventoryListTile(
      gear: gear,
      leading: leading,
      isGroupStart: isGroupStart,
      isGroupEnd: isGroupEnd,
      groupTotalWeight: groupTotalWeight,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => GearDetailScreen(gear: gear)),
        );
      },
      trailing: IconButton(
        icon: const Icon(Icons.edit),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => GearEditScreen(existing: gear)),
          );
        },
      ),
    );

    if (isChild) {
      tile = Container(
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        child: tile,
      );
    }

    return tile;
  }

  double _calculateSubtreeWeight(Gear parent) {
    double total = (parent.weight ?? 0) * parent.quantity;
    final children = items.where((g) => g.parentId == parent.id);
    for (final child in children) {
      total += _calculateSubtreeWeight(child);
    }
    return total;
  }
}

class DragHandle extends StatelessWidget {
  final int index;
  const DragHandle({super.key, required this.index});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
    return Icon(Icons.menu, color: color);
  }
}
