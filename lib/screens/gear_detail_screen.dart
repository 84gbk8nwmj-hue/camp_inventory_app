import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/gear.dart';
import '../utils/weight_format.dart';
import '../widgets/gear_list_tile.dart';

class GearDetailScreen extends ConsumerWidget {
  final Gear gear;
  const GearDetailScreen({super.key, required this.gear});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(gear.name),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // --- ヒーローイメージ ---
          GearImagePreview(gear: gear),
          const SizedBox(height: 20),

          // --- 基本情報グリッド (カテゴリ / メーカー) ---
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _InfoCard(
                  icon: Icons.category_outlined,
                  label: 'カテゴリ',
                  value: gear.categoryName,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InfoCard(
                  icon: Icons.branding_watermark_outlined,
                  label: 'メーカー',
                  value: (gear.manufacturer?.isNotEmpty ?? false)
                      ? gear.manufacturer!
                      : '未設定',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // --- 重量ダッシュボード ---
          _WeightDashboard(gear: gear),

          const SizedBox(height: 12),

          // --- メモセクション ---
          if (gear.note?.isNotEmpty ?? false)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.notes,
                            size: 18, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        Text('メモ',
                            style: textTheme.labelLarge?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            )),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      gear.note!,
                      style: textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          
          // 下部の余白（ジェスチャー干渉防止用）
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: colorScheme.secondary),
            const SizedBox(height: 12),
            Text(label,
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                )),
            const SizedBox(height: 4),
            Text(
              value,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _WeightDashboard extends StatelessWidget {
  final Gear gear;
  const _WeightDashboard({required this.gear});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final hasWeight = gear.weight != null;
    final totalWeight = gear.weight != null ? gear.weight! * gear.quantity : 0.0;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: colorScheme.primaryContainer.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('積載重量',
                    style: textTheme.labelLarge?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    )),
                if (gear.weightVerified)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade700,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified, size: 14, color: Colors.white),
                        SizedBox(width: 4),
                        Text('FIX済',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            )),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // 合計重量を巨大化
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                hasWeight ? WeightFormat.label(totalWeight) : '重量未入力',
                style: textTheme.displayMedium?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            // 内訳情報
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _SubInfoItem(
                  label: '数量',
                  value: '${gear.quantity} 個',
                  icon: Icons.shopping_bag_outlined,
                ),
                _SubInfoItem(
                  label: '1個あたり',
                  value: hasWeight
                      ? WeightFormat.gramsCompact(gear.weight!)
                      : '---',
                  icon: Icons.scale_outlined,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SubInfoItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SubInfoItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: colorScheme.onPrimaryContainer.withValues(alpha: 0.6)),
            const SizedBox(width: 4),
            Text(label,
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onPrimaryContainer.withValues(alpha: 0.6),
                )),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: textTheme.titleMedium?.copyWith(
            color: colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
