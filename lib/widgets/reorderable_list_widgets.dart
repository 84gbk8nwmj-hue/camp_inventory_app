import 'package:flutter/material.dart';

/// 左端のドラッグハンドル（≡ 3本線）
class DragHandle extends StatelessWidget {
  final int index;
  const DragHandle({super.key, required this.index});

  @override
  Widget build(BuildContext context) {
    final color =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
    return ReorderableDragStartListener(
      index: index,
      child: _ThreeLineIcon(color: color),
    );
  }
}

class _ThreeLineIcon extends StatelessWidget {
  final Color color;
  const _ThreeLineIcon({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          3,
          (_) => Container(
            width: 18,
            height: 2,
            margin: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
      ),
    );
  }
}
