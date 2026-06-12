import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:croppy/croppy.dart';

import '../models/packing_set.dart';
import '../providers/database_providers.dart';
import '../providers/gear_provider.dart';
import '../providers/packing_provider.dart';
import '../utils/weight_format.dart';
import '../widgets/gear_list_tile.dart';
import 'packing_select_screen.dart';

class PackingChecklistScreen extends ConsumerStatefulWidget {
  final int setId;
  const PackingChecklistScreen({super.key, required this.setId});

  @override
  ConsumerState<PackingChecklistScreen> createState() =>
      _PackingChecklistScreenState();
}

class _PackingChecklistScreenState
    extends ConsumerState<PackingChecklistScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await ref.read(packingProvider.notifier).load(); // プロバイダー全体を最新にする
    await ref.read(packingProvider.notifier).selectSet(widget.setId);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _addPlacement() async {
    final nameCtrl = TextEditingController();
    String? imageFile;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('積載場所を追加'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '例: 左サイドバック, リヤボックス',
                  labelText: '場所の名前',
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () async {
                  final picker = ImagePicker();
                  final picked = await picker.pickImage(source: ImageSource.gallery);
                  if (picked != null && context.mounted) {
                    await _editPlacementImageWithProEditor(
                      context,
                      picked.path,
                      (savedName) => setDialogState(() => imageFile = savedName),
                    );
                  }
                },
                icon: const Icon(Icons.image_outlined),
                label: Text(imageFile == null ? '背景画像を選択' : '画像を変更済'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('追加')),
          ],
        ),
      ),
    );

    if (result == true && nameCtrl.text.trim().isNotEmpty) {
      // データベースを直接呼ぶのではなく、将来的に PackingNotifier に引数を追加することを考慮
      // 現状は addPlacement が名前のみなので、後で update するか notifier を拡張する
      await ref.read(packingProvider.notifier).addPlacement(nameCtrl.text.trim());
      // 追加直後の最新Placementを取得して画像をセット
      final packing = ref.read(packingProvider);
      if (imageFile != null && packing.activePlacements.isNotEmpty) {
        final newP = packing.activePlacements.last;
        await ref.read(packingProvider.notifier).updatePlacement(newP.copyWith(imageFile: imageFile));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final gearState = ref.watch(gearProvider);
    final packing = ref.watch(packingProvider);
    final notifier = ref.read(packingProvider.notifier);
    
    final placements = packing.activePlacements;
    final unassignedItems = packing.viewsInPlacement(null, gearState.items);

    return Scaffold(
      appBar: AppBar(
        title: Text(packing.activeSet?.name ?? '積載バランス調整'),
        actions: [
          IconButton(
            tooltip: '積載場所を追加',
            icon: const Icon(Icons.add_box_outlined),
            onPressed: _addPlacement,
          ),
          IconButton(
            tooltip: 'ギアを選ぶ',
            icon: const Icon(Icons.playlist_add_check),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PackingSelectScreen(setId: widget.setId)),
            ).then((_) => _load()),
          ),
        ],
      ),
      body: Column(
        children: [
          // 上部：積載場所（ドロップターゲット）
          SizedBox(
            height: 130,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                // 未配置ターゲット
                _PlacementDropZone(
                  key: const ValueKey('unassigned_zone'),
                  placement: null,
                  name: '未配置へ戻す',
                  weight: packing.placementWeight(null, gearState.items),
                  count: unassignedItems.length,
                  onDrop: (view) => notifier.setPlacementForGear(widget.setId, view.gear.id!, null),
                  isUnassigned: true,
                ),
                // ユーザー定義の場所
                ...placements.map((p) => Padding(
                  key: ValueKey('placement_${p.id}'),
                  padding: const EdgeInsets.only(left: 12),
                  child: _PlacementDropZone(
                    placement: p,
                    name: p.name,
                    weight: packing.placementWeight(p.id, gearState.items),
                    count: packing.viewsInPlacement(p.id, gearState.items).length,
                    onDrop: (view) => notifier.setPlacementForGear(widget.setId, view.gear.id!, p.id),
                    onEdit: () => _editPlacement(p),
                  ),
                )),
              ],
            ),
          ),
          const Divider(height: 1),
          // 下部：ドラッグ可能なギアリスト
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: RichText(
                    text: TextSpan(
                      style: Theme.of(context).textTheme.bodySmall,
                      children: [
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Icon(
                            Icons.menu,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const TextSpan(text: ' をドラッグして上の場所に仕分け'),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: packing.viewsFor(gearState.items).length,
                    itemBuilder: (context, index) {
                      final view = packing.viewsFor(gearState.items)[index];
                      final pName = view.placementId == null 
                          ? null 
                          : placements.where((p) => p.id == view.placementId).firstOrNull?.name;

                      return _DraggableGearTile(
                        view: view,
                        placementName: pName,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editPlacementImageWithProEditor(
    BuildContext context,
    String inputPath,
    Function(String) onDone,
  ) async {
    final file = File(inputPath);
    if (!await file.exists()) return;

    final result = await showCupertinoImageCropper(
      context,
      imageProvider: FileImage(file),
      allowedAspectRatios: [
        const CropAspectRatio(width: 140, height: 114),
      ],
    );

    if (result != null) {
      final uiImage = result.uiImage;
      final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        final bytes = byteData.buffer.asUint8List();
        await file.writeAsBytes(bytes);
        final savedName = await ref.read(imageStorageProvider).saveFromPath(file.path);
        if (savedName != null) {
          onDone(savedName);
        }
      }
    }
  }

  Future<void> _editPlacement(PackingPlacement placement) async {
    final nameCtrl = TextEditingController(text: placement.name);
    String? currentImage = placement.imageFile;

    final result = await showDialog<String?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final imageProvider = ref.read(imageStorageProvider);
          final file = imageProvider.resolveFile(currentImage);

          return AlertDialog(
            title: const Text('場所の編集'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('名前', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      hintText: '例: 右サイドバック',
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('背景画像', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (file != null) ...[
                    AspectRatio(
                      aspectRatio: 140 / 114, // メイン画面のカード(140x114相当)に合わせる
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(file, fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () async {
                            await _editPlacementImageWithProEditor(
                              context,
                              file.path,
                              (savedName) => setDialogState(() => currentImage = savedName),
                            );
                          },
                          icon: const Icon(Icons.crop_rotate, size: 18),
                          label: const Text('切り抜き・回転'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picker = ImagePicker();
                            final picked = await picker.pickImage(source: ImageSource.gallery);
                            if (picked != null && context.mounted) {
                              await _editPlacementImageWithProEditor(
                                context,
                                picked.path,
                                (savedName) => setDialogState(() => currentImage = savedName),
                              );
                            }
                          },
                          icon: Icon(currentImage == null ? Icons.image_outlined : Icons.sync),
                          label: Text(currentImage == null ? '画像を選択' : '画像を変更'),
                        ),
                      ),
                      if (currentImage != null)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => setDialogState(() => currentImage = null),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, 'DELETE'),
                child: const Text('この場所を削除', style: TextStyle(color: Colors.red)),
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('キャンセル'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, 'SAVE'),
                    child: const Text('保存'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    if (result == 'DELETE') {
      await ref.read(packingProvider.notifier).deletePlacement(placement.id!);
    } else if (result == 'SAVE' && nameCtrl.text.trim().isNotEmpty) {
      await ref.read(packingProvider.notifier).updatePlacement(
        placement.copyWith(
          name: nameCtrl.text.trim(),
          imageFile: currentImage,
          clearImage: currentImage == null,
        ),
      );
    }
  }
}

class _PlacementDropZone extends ConsumerWidget {
  final PackingPlacement? placement;
  final String name;
  final double weight;
  final int count;
  final Function(PackingGearView) onDrop;
  final VoidCallback? onEdit;
  final bool isUnassigned;

  const _PlacementDropZone({
    super.key,
    required this.placement,
    required this.name,
    required this.weight,
    required this.count,
    required this.onDrop,
    this.onEdit,
    this.isUnassigned = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageFile = ref.read(imageStorageProvider).resolveFile(placement?.imageFile);

    return DragTarget<PackingGearView>(
      onWillAcceptWithDetails: (details) {
        return details.data.placementId != placement?.id;
      },
      onAcceptWithDetails: (details) => onDrop(details.data),
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 140,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isHovering ? Theme.of(context).colorScheme.primary : Colors.transparent,
              width: 2,
            ),
            image: imageFile != null ? DecorationImage(
              image: FileImage(imageFile),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(isHovering ? 0.4 : 0.6),
                BlendMode.darken,
              ),
            ) : null,
            color: imageFile != null ? null : (isHovering 
                ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                : (isUnassigned ? Theme.of(context).colorScheme.surfaceContainerHighest : Theme.of(context).colorScheme.secondaryContainer)),
          ),
          child: InkWell(
            onTap: onEdit,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      height: 1.1,
                      color: imageFile != null ? Colors.white : (isUnassigned ? Theme.of(context).colorScheme.outline : null),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    WeightFormat.label(weight),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: imageFile != null ? Colors.white : Theme.of(context).colorScheme.primary,
                      letterSpacing: -0.5,
                      shadows: imageFile != null ? [const Shadow(blurRadius: 4, color: Colors.black)] : null,
                    ),
                  ),
                  Text(
                    '$count 点',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: imageFile != null ? Colors.white70 : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DraggableGearTile extends StatelessWidget {
  final PackingGearView view;
  final String? placementName;

  const _DraggableGearTile({
    required this.view,
    this.placementName,
  });

  @override
  Widget build(BuildContext context) {
    final isChild = view.gear.parentId != null;
    final customLeading = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isChild) const SizedBox(width: GearListTileLayout.indentSize),
        Draggable<PackingGearView>(
          data: view,
          feedback: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.7,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(view.gear.name),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
            color: Colors.transparent,
            child: const Icon(Icons.menu, color: Colors.grey, size: 24),
          ),
        ),
        GearListTileLeading(gear: view.gear),
      ],
    );

    Widget tile = GearInventoryListTile(
      gear: view.gear,
      leading: customLeading,
      trailing: placementName != null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                placementName!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),
            )
          : null,
    );

    if (isChild) {
      tile = Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        child: tile,
      );
      tile = Consumer(
        builder: (context, ref, child) {
          return Dismissible(
            key: ValueKey('dismiss_packing_${view.gear.id}'),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              color: Theme.of(context).colorScheme.tertiary,
              child: const Icon(Icons.outbox, color: Colors.white),
            ),
            confirmDismiss: (direction) async {
              if (direction == DismissDirection.endToStart) {
                await ref.read(gearProvider.notifier).updateParent(view.gear.id!, null);
                return false;
              }
              return false;
            },
            child: child!,
          );
        },
        child: tile,
      );
    }

    return tile;
  }
}
