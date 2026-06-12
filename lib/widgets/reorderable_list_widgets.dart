import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/gear.dart';
import '../providers/gear_provider.dart';
import '../widgets/gear_list_tile.dart';
import '../screens/gear_detail_screen.dart';
import '../screens/gear_edit_screen.dart';

class GearReorderableList extends ConsumerStatefulWidget {
  final List<Gear> items;
  final GearNotifier notifier;

  const GearReorderableList({
    super.key,
    required this.items,
    required this.notifier,
  });

  @override
  ConsumerState<GearReorderableList> createState() => _GearReorderableListState();
}

class _GearReorderableListState extends ConsumerState<GearReorderableList> {
  int? _targetId;
  int? _draggedId;
  // 0: none, 1: insert above, 2: nest into, 3: insert below
  int _targetMode = 0;

  void _clearTarget() {
    if (_targetId != null || _targetMode != 0) {
      setState(() {
        _targetId = null;
        _targetMode = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      // ドラッグ中はスクロールを禁止してジェスチャー競合を防ぐ
      physics: _draggedId != null
          ? const NeverScrollableScrollPhysics()
          : const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: widget.items.length,
      itemBuilder: (context, index) {
        final gear = widget.items[index];
        final id = gear.id;
        if (id == null) return const SizedBox.shrink();

        final isChild = gear.parentId != null;

        return DragTarget<int>(
          key: ValueKey('target_$id'),
          onWillAcceptWithDetails: (details) => details.data != id,
          onMove: (details) {
            const mode = 2; // 常に格納モード
            if (_targetId != id || _targetMode != mode) {
              setState(() {
                _targetId = id;
                _targetMode = mode;
              });
            }
          },
          onLeave: (_) => _clearTarget(),
          onAcceptWithDetails: (details) async {
            final movedId = details.data;
            _clearTarget();

            await widget.notifier.reorderItemsWithHierarchy(
              movedId: movedId,
              targetId: id,
              mode: 2, // 常に格納モード
            );
          },
          builder: (context, candidateData, rejectedData) {
            final isTarget = _targetId == id;

            return LongPressDraggable<int>(
              key: ValueKey('drag_$id'),
              data: id,
              // axis を指定しないことで iOS のジェスチャー判定を安定させる
              delay: const Duration(milliseconds: 300),
              hapticFeedbackOnStart: true,
              dragAnchorStrategy: childDragAnchorStrategy,
              onDragStarted: () {
                setState(() => _draggedId = id);
              },
              onDragEnd: (_) {
                setState(() => _draggedId = null);
                _clearTarget();
              },
              onDraggableCanceled: (_, __) {
                setState(() => _draggedId = null);
                _clearTarget();
              },
              childWhenDragging: Opacity(
                opacity: 0.2,
                child: _buildTile(gear, index, isChild),
              ),
              feedback: Opacity(
                opacity: 0.9,
                child: Material(
                  elevation: 12,
                  borderRadius: BorderRadius.circular(8),
                  color: Theme.of(context).colorScheme.surface,
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width - 16,
                    child: _buildTile(gear, index, isChild, isFeedback: true),
                  ),
                ),
              ),
              child: Stack(
                children: [
                  _buildTile(gear, index, isChild),
                  if (isTarget)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: _buildDropGuide(context),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  bool _isDescendantOf(Gear gear, int? potentialParentId) {
    if (potentialParentId == null) return false;
    int? currentParentId = gear.parentId;
    while (currentParentId != null) {
      if (currentParentId == potentialParentId) return true;
      final parent = widget.items.firstWhere(
        (g) => g.id == currentParentId,
        orElse: () => gear,
      );
      if (parent.id == gear.id) break;
      currentParentId = parent.parentId;
    }
    return false;
  }

  Widget _buildDropGuide(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.move_to_inbox, color: color),
            const SizedBox(width: 8),
            Text(
              '格納',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(Gear gear, int index, bool isChild, {bool isFeedback = false}) {
    Widget tile = GearInventoryListTile(
      gear: gear,
      reorderIndex: index,
      onTap: isFeedback ? null : () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => GearDetailScreen(gear: gear)),
        );
      },
      trailing: isFeedback ? const IconButton(
        icon: Icon(Icons.edit),
        onPressed: null,
      ) : IconButton(
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
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        child: tile,
      );
      if (!isFeedback) {
        tile = Dismissible(
          key: ValueKey('dismiss_${gear.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: Theme.of(context).colorScheme.tertiary,
            child: const Icon(Icons.outbox, color: Colors.white),
          ),
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.endToStart) {
              await widget.notifier.updateParent(gear.id!, null);
            }
            return false;
          },
          child: tile,
        );
      }
    }
    return tile;
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
