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

typedef DragHandleBuilder = Widget Function(BuildContext context, Widget handle);

/// 一覧の leading（格納用ハンドル・サムネイル）
class GearListRowLeading extends StatelessWidget {
  final Gear gear;
  final int? reorderIndex;
  final DragHandleBuilder? dragHandleBuilder;

  const GearListRowLeading({
    super.key,
    required this.gear,
    this.reorderIndex,
    this.dragHandleBuilder,
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
                child: dragHandleBuilder != null
                    ? dragHandleBuilder!(context, DragHandle(index: reorderIndex!))
                    : DragHandle(index: reorderIndex!),
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
  final bool isGroupStart;
  final bool isGroupEnd;
  final double? groupTotalWeight;

  const GearInventoryListTile({
    super.key,
    required this.gear,
    this.reorderIndex,
    this.leading,
    this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.isGroupStart = false,
    this.isGroupEnd = false,
    this.groupTotalWeight,
  });

  @override
  Widget build(BuildContext context) {
    final isChild = gear.parentId != null;
    final colorScheme = Theme.of(context).colorScheme;

    final mfr = gear.manufacturer;
    final prefix = mfr != null && mfr.isNotEmpty ? '$mfr · ' : '';
    final label = '$prefix${gear.categoryName}';
    final weightText = gear.weight == null
        ? null
        : WeightFormat.gramsCompact(gear.weight! * gear.quantity);
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).textTheme.bodySmall?.color,
        );

    final showGroupTotal = groupTotalWeight != null &&
        groupTotalWeight! > (gear.weight ?? 0) * gear.quantity;

    final effectiveTitle = Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 20,
            child: AppMarqueeText(
              text: gear.name,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ),
        if (showGroupTotal) ...[
          const SizedBox(width: 8),
          Text(
            WeightFormat.gramsCompact(groupTotalWeight!),
            style: style?.copyWith(
              color: colorScheme.primary,
            ),
          ),
          // 下段のFIXアイコン(dotSize) + 間隔(6) 分のスペースを空けて桁を揃える
          const SizedBox(width: GearListTileLayout.dotSize + 6),
        ],
      ],
    );

    final effectiveSubtitle = Row(
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
        if (weightText != null) ...[
          const SizedBox(width: 8),
          Text(
            weightText,
            style: style,
          ),
          const SizedBox(width: 6),
          WeightStatusDot(gear: gear),
        ],
      ],
    );

    final effectiveLeading =
        leading ?? GearListRowLeading(gear: gear, reorderIndex: reorderIndex);

    final leadingWidth = GearListTileLayout.leadingWidth(
      withDrag: (reorderIndex != null || leading != null),
      isChild: isChild,
    );

    final indent = GearListTileLayout.listContentPadding.left +
        leadingWidth +
        GearListTileLayout.titleGap;

    final divider = Divider(
      height: 1,
      thickness: 1,
      indent: indent,
      color: colorScheme.primary.withValues(alpha: 0.12),
    );

    Widget tile = ListTile(
      contentPadding: GearListTileLayout.listContentPadding,
      horizontalTitleGap: GearListTileLayout.titleGap,
      minLeadingWidth: leadingWidth,
      leading: effectiveLeading,
      title: title ?? effectiveTitle,
      subtitle: subtitle ?? effectiveSubtitle,
      trailing: trailing,
      onTap: onTap,
    );

    if (isGroupStart || isGroupEnd || isChild) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isGroupStart) divider,
          tile,
          if (isGroupEnd) divider,
        ],
      );
    }

    return tile;
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
  final double? groupTotalWeight;

  const GearWeightSubtitle({
    super.key,
    required this.gear,
    this.groupTotalWeight,
  });

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

    final showGroupTotal = groupTotalWeight != null &&
        groupTotalWeight! > (gear.weight ?? 0) * gear.quantity;

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
        if (weight != null || showGroupTotal) ...[
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showGroupTotal)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    WeightFormat.gramsCompact(groupTotalWeight!),
                    style: style?.copyWith(
                      fontSize: (style.fontSize ?? 12) + 1,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              if (weight != null)
                Text(
                  weight,
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  textAlign: TextAlign.right,
                  style: style,
                ),
            ],
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
