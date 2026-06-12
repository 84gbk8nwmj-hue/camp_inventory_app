import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/gear.dart';
import '../providers/database_providers.dart';
import '../utils/weight_format.dart';
import 'reorderable_list_widgets.dart';

enum GearWeightStatus {
  missing,
  unverified,
  verified,
}

GearWeightStatus gearWeightStatus(Gear gear) {
  if (gear.weight == null) return GearWeightStatus.missing;
  if (gear.weightVerified) return GearWeightStatus.verified;
  return GearWeightStatus.unverified;
}

/// ギア一覧行のレイアウト定数（≡ / サムネ / テキスト間隔）
class GearListTileLayout {
  GearListTileLayout._();

  static const double gap = 8;
  static const double thumbSize = 56;
  static const double dotSize = 8;
  static const double dragWidth = 22;
  static const double titleGap = 12;
  static const double indentSize = 14;

  static const EdgeInsets listContentPadding = EdgeInsets.fromLTRB(8, 4, 8, 4);

  static double leadingWidth({required bool withDrag, bool isChild = false}) {
    var w = thumbSize;
    if (withDrag) w += dragWidth + gap;
    if (isChild) w += indentSize;
    return w;
  }
}

/// 重量ステータス（赤=未入力 / 黄=未FIX / 緑=FIX済）
class WeightStatusDot extends StatelessWidget {
  final Gear gear;
  const WeightStatusDot({super.key, required this.gear});

  @override
  Widget build(BuildContext context) {
    final color = switch (gearWeightStatus(gear)) {
      GearWeightStatus.missing => Colors.red.shade600,
      GearWeightStatus.unverified => Colors.amber.shade700,
      GearWeightStatus.verified => Colors.green.shade600,
    };

    return Tooltip(
      message: switch (gearWeightStatus(gear)) {
        GearWeightStatus.missing => '重量未入力',
        GearWeightStatus.unverified => '重量入力済み（未FIX）',
        GearWeightStatus.verified => '重量FIX済み',
      },
      child: Container(
        width: GearListTileLayout.dotSize,
        height: GearListTileLayout.dotSize,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(context).colorScheme.surface,
            width: 1,
          ),
        ),
      ),
    );
  }
}

/// 一覧の leading（格納用ハンドル・サムネイル）
class GearListRowLeading extends StatelessWidget {
  final Gear gear;
  final int? reorderIndex;

  const GearListRowLeading({
    super.key,
    required this.gear,
    this.reorderIndex,
  });

  @override
  Widget build(BuildContext context) {
    final withDrag = reorderIndex != null;
    final isChild = gear.parentId != null;
    return SizedBox(
      width: GearListTileLayout.leadingWidth(withDrag: withDrag, isChild: isChild),
      child: Row(
        children: [
          if (isChild) const SizedBox(width: GearListTileLayout.indentSize),
          if (withDrag) ...[
            SizedBox(
              width: GearListTileLayout.dragWidth,
              child: Center(
                child: DragHandle(index: reorderIndex!),
              ),
            ),
            const SizedBox(width: GearListTileLayout.gap),
          ],
          SizedBox(
            width: GearListTileLayout.thumbSize,
            height: GearListTileLayout.thumbSize,
            child: GearListTileLeading(gear: gear),
          ),
        ],
      ),
    );
  }
}

class GearListTileLeading extends ConsumerWidget {
  final Gear gear;
  const GearListTileLeading({super.key, required this.gear});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = ref.read(imageStorageProvider).resolveFile(gear.imageFile);
    if (file != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          file,
          width: GearListTileLayout.thumbSize,
          height: GearListTileLayout.thumbSize,
          fit: BoxFit.cover,
          cacheWidth: 112,
        ),
      );
    }
    return CircleAvatar(
      radius: GearListTileLayout.thumbSize / 2,
      child: Text(gear.quantity.toString()),
    );
  }
}

/// ギア在庫一覧用 ListTile
class GearInventoryListTile extends StatelessWidget {
  final Gear gear;
  final int? reorderIndex;
  final Widget? leading;
  final Widget? title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const GearInventoryListTile({
    super.key,
    required this.gear,
    this.reorderIndex,
    this.leading,
    this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveLeading = leading ?? GearListRowLeading(gear: gear, reorderIndex: reorderIndex);
    final isChild = gear.parentId != null;

    return ListTile(
      contentPadding: GearListTileLayout.listContentPadding,
      horizontalTitleGap: GearListTileLayout.titleGap,
      minLeadingWidth: GearListTileLayout.leadingWidth(
        withDrag: (reorderIndex != null || leading != null),
        isChild: isChild,
      ),
      leading: effectiveLeading,
      title: title ??
          SizedBox(
            height: 20,
            child: AppMarqueeText(
              text: gear.name,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
      subtitle: subtitle ?? GearWeightSubtitle(gear: gear),
      trailing: trailing,
      onTap: onTap,
    );
  }
}

/// スライド可能なテキスト用ウィジェット（はみ出す場合に手動でスクロール可能）
class AppMarqueeText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const AppMarqueeText({super.key, required this.text, this.style});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Text(
        text,
        style: style,
        maxLines: 1,
      ),
    );
  }
}

class GearWeightSubtitle extends StatelessWidget {
  final Gear gear;

  const GearWeightSubtitle({super.key, required this.gear});

  @override
  Widget build(BuildContext context) {
    final mfr = gear.manufacturer;
    final prefix = mfr != null && mfr.isNotEmpty ? '$mfr · ' : '';
    final label = '$prefix${gear.categoryName}';
    final weight = gear.weight == null
        ? null
        : WeightFormat.gramsCompact(gear.weight! * gear.quantity);
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).textTheme.bodySmall?.color,
        );

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 18,
            child: AppMarqueeText(
              text: label,
              style: style,
            ),
          ),
        ),
        if (weight != null) ...[
          const SizedBox(width: 8),
          Text(
            weight,
            maxLines: 1,
            overflow: TextOverflow.visible,
            textAlign: TextAlign.right,
            style: style,
          ),
          const SizedBox(width: 6),
          WeightStatusDot(gear: gear),
        ],
      ],
    );
  }
}

String gearWeightSubtitle(Gear gear) {
  final weightText = gear.weight != null
      ? '　${WeightFormat.gramsCompact(gear.weight! * gear.quantity)}'
      : '';
  final mfr = gear.manufacturer;
  final prefix = mfr != null && mfr.isNotEmpty ? '$mfr · ' : '';
  return '$prefix${gear.categoryName}$weightText';
}

class GearImagePreview extends ConsumerWidget {
  final Gear gear;
  final double? height;
  final double aspectRatio;

  const GearImagePreview({
    super.key,
    required this.gear,
    this.height,
    this.aspectRatio = 1.0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = ref.read(imageStorageProvider).resolveFile(gear.imageFile);
    if (file == null) return const SizedBox.shrink();

    final image = Image.file(
      file,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: height != null
          ? SizedBox(
              height: height,
              width: double.infinity,
              child: image,
            )
          : AspectRatio(
              aspectRatio: aspectRatio,
              child: image,
            ),
    );
  }
}
