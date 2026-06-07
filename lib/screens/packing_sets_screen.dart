import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/packing_set.dart';
import '../providers/data_transfer_provider.dart';
import '../providers/gear_provider.dart';
import '../providers/packing_provider.dart';
import 'packing_checklist_screen.dart';

class PackingSetsScreen extends ConsumerStatefulWidget {
  const PackingSetsScreen({super.key});

  @override
  ConsumerState<PackingSetsScreen> createState() => _PackingSetsScreenState();
}

class _PackingSetsScreenState extends ConsumerState<PackingSetsScreen> {
  Offset? _fabOffset;
  bool _fabDragging = false;
  static const double _fabSize = 56.0;

  Offset _clampFabOffset(Offset offset, Size size) {
    final double minX = 8;
    final double minY = 8;
    final double maxX = size.width - _fabSize - 8;
    final double maxY = size.height - _fabSize - 8;
    return Offset(
      offset.dx.clamp(minX, maxX),
      offset.dy.clamp(minY, maxY),
    );
  }

  Future<void> _createSet(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('持ち出しセットを作成'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '例: 夏キャンプ'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('作成'),
          ),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      final id = await ref.read(packingProvider.notifier).createSet(ctrl.text);
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PackingChecklistScreen(setId: id),
          ),
        );
      }
    }
    ctrl.dispose();
  }

  Future<void> _importTemplate(BuildContext context, WidgetRef ref) async {
    try {
      final result =
          await ref.read(dataTransferServiceProvider).pickAndImportPackingTemplate();
      if (result == null) return;

      await reloadAllProviders(ref);
      if (!context.mounted) return;

      var message = result.summary;
      if (result.skippedGearNames.isNotEmpty) {
        final names = result.skippedGearNames.take(5).join('、');
        final more = result.skippedGearNames.length > 5
            ? ' 他${result.skippedGearNames.length - 5}件'
            : '';
        message += '\n\n未登録: $names$more';
      }

      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('テンプレート読み込み完了'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('読み込みに失敗しました: $e')),
        );
      }
    }
  }

  Future<void> _shareTemplate(
    BuildContext context,
    WidgetRef ref,
    PackingSet set,
  ) async {
    final gearState = ref.read(gearProvider);
    final gearInSet = await ref
        .read(packingProvider.notifier)
        .gearForSet(set.id!, gearState.items);

    if (gearInSet.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('セットにギアがありません')),
        );
      }
      return;
    }

    try {
      await ref.read(dataTransferServiceProvider).sharePackingSetTemplate(
            set: set,
            gearInSet: gearInSet,
          );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('共有に失敗しました: $e')),
        );
      }
    }
  }

  Future<void> _renameSet(
    BuildContext context,
    WidgetRef ref,
    PackingSet set,
  ) async {
    final ctrl = TextEditingController(text: set.name);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('セット名を変更'),
        content: TextField(controller: ctrl, autofocus: true),
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
      await ref.read(packingProvider.notifier).renameSet(set.id!, ctrl.text);
    }
    ctrl.dispose();
  }

  Future<void> _duplicateSet(
    BuildContext context,
    WidgetRef ref,
    PackingSet set,
  ) async {
    final ctrl = TextEditingController(text: '${set.name} のコピー');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('セットを複製'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('複製'),
          ),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      await ref
          .read(packingProvider.notifier)
          .duplicateSet(set.id!, ctrl.text);
    }
    ctrl.dispose();
  }

  Future<void> _deleteSet(
    BuildContext context,
    WidgetRef ref,
    PackingSet set,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('セットを削除'),
        content: Text('「${set.name}」を削除します。'),
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
      await ref.read(packingProvider.notifier).deleteSet(set.id!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final packing = ref.watch(packingProvider);
    final notifier = ref.read(packingProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('持ち出しセット'),
        actions: [
          IconButton(
            tooltip: 'テンプレートを読み込む',
            icon: const Icon(Icons.file_download_outlined),
            onPressed: () => _importTemplate(context, ref),
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
              packing.sets.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('セットがありません'),
                          const SizedBox(height: 24),
                          OutlinedButton.icon(
                            onPressed: () => _importTemplate(context, ref),
                            icon: const Icon(Icons.file_download_outlined),
                            label: const Text('テンプレートを読み込む'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: packing.sets.length,
                      itemBuilder: (context, index) {
                        final set = packing.sets[index];
                        final isActive = set.id == packing.activeSetId;
                        return FutureBuilder<int>(
                          future: notifier.itemCountForSet(set.id!),
                          builder: (context, snap) {
                            final count = snap.data ?? 0;
                            return ListTile(
                              leading: Icon(
                                isActive
                                    ? Icons.check_circle
                                    : Icons.backpack_outlined,
                                color: isActive
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                              ),
                              title: Text(set.name),
                              subtitle: Text('$count 点'),
                              onTap: () async {
                                await notifier.selectSet(set.id!);
                                if (context.mounted) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PackingChecklistScreen(
                                          setId: set.id!),
                                    ),
                                  );
                                }
                              },
                              trailing: PopupMenuButton<String>(
                                onSelected: (v) {
                                  switch (v) {
                                    case 'share':
                                      _shareTemplate(context, ref, set);
                                    case 'rename':
                                      _renameSet(context, ref, set);
                                    case 'duplicate':
                                      _duplicateSet(context, ref, set);
                                    case 'delete':
                                      _deleteSet(context, ref, set);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'share',
                                    child: Text('テンプレートを共有'),
                                  ),
                                  PopupMenuItem(
                                      value: 'rename', child: Text('名前変更')),
                                  PopupMenuItem(
                                      value: 'duplicate', child: Text('複製')),
                                  PopupMenuItem(
                                      value: 'delete', child: Text('削除')),
                                ],
                              ),
                            );
                          },
                        );
                      },
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
                  onPanEnd: (_) => setState(() => _fabDragging = false),
                  child: Opacity(
                    opacity: _fabDragging ? 0.9 : 0.68,
                    child: FloatingActionButton(
                      heroTag: 'add_packing_set',
                      shape: const CircleBorder(),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      onPressed: () => _createSet(context, ref),
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
