import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/gear_provider.dart';
import '../providers/manufacturer_provider.dart';
import 'reorderable_list_widgets.dart';

/// メーカー選択（検索付きボトムシート・カスタム追加対応）
class ManufacturerPickerField extends ConsumerStatefulWidget {
  final String? value;
  final ValueChanged<String?> onChanged;

  const ManufacturerPickerField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  ConsumerState<ManufacturerPickerField> createState() =>
      _ManufacturerPickerFieldState();
}

class _ManufacturerPickerFieldState
    extends ConsumerState<ManufacturerPickerField> {
  late final TextEditingController _displayCtrl;

  @override
  void initState() {
    super.initState();
    _displayCtrl = TextEditingController(text: _labelText(widget.value));
    ref.read(manufacturerProvider.notifier).load();
  }

  @override
  void didUpdateWidget(ManufacturerPickerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _displayCtrl.text = _labelText(widget.value);
    }
  }

  @override
  void dispose() {
    _displayCtrl.dispose();
    super.dispose();
  }

  String _labelText(String? value) {
    if (value == null || value.isEmpty) return '';
    return value;
  }

  Future<void> _openPicker() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ManufacturerPickerSheet(initial: widget.value),
    );
    if (selected != null) {
      final v = selected.isEmpty ? null : selected;
      widget.onChanged(v);
      _displayCtrl.text = _labelText(v);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      readOnly: true,
      onTap: _openPicker,
      controller: _displayCtrl,
      decoration: const InputDecoration(
        labelText: 'メーカー',
        hintText: 'タップして選択',
        suffixIcon: Icon(Icons.arrow_drop_down),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      ),
    );
  }
}

class _ManufacturerPickerSheet extends ConsumerStatefulWidget {
  final String? initial;
  const _ManufacturerPickerSheet({this.initial});

  @override
  ConsumerState<_ManufacturerPickerSheet> createState() =>
      _ManufacturerPickerSheetState();
}

class _ManufacturerPickerSheetState
    extends ConsumerState<_ManufacturerPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(manufacturerProvider.notifier).load(),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _addManufacturer() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('メーカーを追加'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'メーカー名'),
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
      await ref.read(manufacturerProvider.notifier).addCustom(ctrl.text);
      if (mounted) {
        Navigator.pop(context, ctrl.text.trim());
      }
    }
    ctrl.dispose();
  }

  Future<void> _renameManufacturer(String name) async {
    final ctrl = TextEditingController(text: name);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('メーカー名を変更'),
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
    final next = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true || next.isEmpty || next == name) return;

    final success =
        await ref.read(manufacturerProvider.notifier).rename(name, next);
    await ref.read(gearProvider.notifier).load();
    if (!mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('メーカー名を変更できませんでした')),
      );
    } else if (widget.initial == name) {
      Navigator.pop(context, next);
    }
  }

  Future<void> _deleteManufacturer(String name) async {
    final count = await ref.read(manufacturerProvider.notifier).countGear(name);
    if (!mounted) return;

    final message = count > 0
        ? '「$name」を削除しますか？\n$count 件のギアからメーカー指定が外れます。'
        : '「$name」を削除しますか？';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('メーカーを削除'),
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
    if (ok != true) return;

    final success = await ref.read(manufacturerProvider.notifier).remove(name);
    await ref.read(gearProvider.notifier).load();
    if (!mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('メーカーを削除できませんでした')),
      );
    } else if (widget.initial == name) {
      Navigator.pop(context, '');
    }
  }

  Future<void> _reorderManufacturers(int oldIndex, int newIndex) async {
    final notifier = ref.read(manufacturerProvider.notifier);
    final list = await notifier.managedManufacturers();
    final moved = list.removeAt(oldIndex);
    list.insert(newIndex, moved);
    await notifier.reorder(list);
  }

  Future<void> _handleManufacturerAction(String action, String name) async {
    switch (action) {
      case 'edit':
        await _renameManufacturer(name);
      case 'delete':
        await _deleteManufacturer(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final manufacturers = ref.watch(manufacturerProvider);
    final notifier = ref.read(manufacturerProvider.notifier);
    final filtered = notifier.search(_query);
    final canReorder = _query.trim().isEmpty;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (context, scrollController) {
          return Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: const InputDecoration(
                          hintText: 'メーカー名で検索',
                          prefixIcon: Icon(Icons.search),
                          isDense: true,
                        ),
                        onChanged: (q) => setState(() => _query = q),
                      ),
                    ),
                    IconButton(
                      tooltip: 'メーカーを追加',
                      onPressed: _addManufacturer,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ),
              ListTile(
                title: const Text('未選択'),
                trailing: widget.initial == null || widget.initial!.isEmpty
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(context, ''),
              ),
              const Divider(height: 1),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          '該当なし。「＋」でメーカーを追加できます',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      )
                    : canReorder
                        ? ReorderableListView.builder(
                            scrollController: scrollController,
                            itemCount: manufacturers.length,
                            onReorderItem: _reorderManufacturers,
                            itemBuilder: (context, index) {
                              final name = manufacturers[index];
                              return _ManufacturerListTile(
                                key: ValueKey('manufacturer_$name'),
                                name: name,
                                selected: widget.initial == name,
                                reorderIndex: index,
                                onSelect: () => Navigator.pop(context, name),
                                onAction: (action) =>
                                    _handleManufacturerAction(action, name),
                              );
                            },
                          )
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final name = filtered[index];
                              return _ManufacturerListTile(
                                name: name,
                                selected: widget.initial == name,
                                onSelect: () => Navigator.pop(context, name),
                                onAction: (action) =>
                                    _handleManufacturerAction(action, name),
                              );
                            },
                          ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ManufacturerListTile extends StatelessWidget {
  final String name;
  final bool selected;
  final int? reorderIndex;
  final VoidCallback onSelect;
  final ValueChanged<String> onAction;

  const _ManufacturerListTile({
    super.key,
    required this.name,
    required this.selected,
    this.reorderIndex,
    required this.onSelect,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: ListTile(
        leading: reorderIndex == null ? null : DragHandle(index: reorderIndex!),
        title: Text(name),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) const Icon(Icons.check),
            IconButton(
              tooltip: '編集',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => onAction('edit'),
            ),
            IconButton(
              tooltip: '削除',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => onAction('delete'),
            ),
          ],
        ),
        onTap: onSelect,
      ),
    );
  }
}
