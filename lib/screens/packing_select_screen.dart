import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/gear.dart';
import '../providers/gear_provider.dart';
import '../providers/packing_provider.dart';
import '../utils/string_utils.dart';
import '../utils/weight_format.dart';
import '../widgets/gear_list_tile.dart';

class PackingSelectScreen extends ConsumerStatefulWidget {
  final int setId;
  const PackingSelectScreen({super.key, required this.setId});

  @override
  ConsumerState<PackingSelectScreen> createState() =>
      _PackingSelectScreenState();
}

class _PackingSelectScreenState extends ConsumerState<PackingSelectScreen> {
  bool _loading = true;
  Set<int> _included = {};
  List<Gear> _allGear = [];
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final packing = ref.read(packingProvider.notifier);
    final gear = ref.read(gearProvider);
    final included = await packing.loadIncludedIds(widget.setId);
    await packing.selectSet(widget.setId);
    if (!mounted) return;
    setState(() {
      _included = included;
      _allGear = List.of(gear.items);
      _loading = false;
    });
  }

  List<Gear> get _displayGear {
    final q = StringUtils.normalizeForSearch(_searchQuery);
    if (q.isEmpty) return _allGear;
    return _allGear.where((g) {
      final name = StringUtils.normalizeForSearch(g.name);
      final note = StringUtils.normalizeForSearch(g.note ?? '');
      final mfr = StringUtils.normalizeForSearch(g.manufacturer ?? '');
      return name.contains(q) || note.contains(q) || mfr.contains(q);
    }).toList();
  }

  Future<void> _toggle(int gearId, bool value) async {
    setState(() {
      if (value) {
        _included.add(gearId);
      } else {
        _included.remove(gearId);
      }
    });
    try {
      await ref
          .read(packingProvider.notifier)
          .setIncludedForSet(widget.setId, gearId, value);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (value) {
          _included.remove(gearId);
        } else {
          _included.add(gearId);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存に失敗しました: $e')),
      );
    }
  }

  Future<void> _onReorderItem(int oldIndex, int newIndex) async {
    if (_searchQuery.trim().isNotEmpty) return; // 検索中は並び替え不可

    final list = List<Gear>.of(_allGear);
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    setState(() => _allGear = list);
    final ids = list.map((g) => g.id!).toList();
    await ref.read(gearProvider.notifier).reorderItems(ids);
  }

  int get _selectedCount =>
      _allGear.where((g) => _included.contains(g.id)).length;

  double get _selectedWeight {
    return _allGear
        .where((g) => _included.contains(g.id))
        .fold(0.0, (sum, g) => sum + gearLineWeight(g));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final weightLabel = WeightFormat.label(_selectedWeight);

    return Scaffold(
      appBar: AppBar(
        title: const Text('持ち出しギアを選ぶ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '再読み込み',
            onPressed: () {
              setState(() => _loading = true);
              _load();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'ギア名・メーカー・メモで検索',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Text(
              '選択 $_selectedCount 点　持ち出し重量 $weightLabel',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _searchQuery.trim().isNotEmpty
                    ? '検索中は並び替えできません'
                    : '≡ をドラッグして並び替え',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _searchQuery.trim().isNotEmpty
                          ? Theme.of(context).colorScheme.error
                          : null,
                    ),
              ),
            ),
          ),
          Expanded(
            child: _displayGear.isEmpty
                ? const Center(child: Text('一致するギアがありません'))
                : ReorderableListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: _displayGear.length,
                    onReorderItem: _onReorderItem,
                    buildDefaultDragHandles: _searchQuery.trim().isEmpty,
                    itemBuilder: (context, index) {
                      final gear = _displayGear[index];
                      final id = gear.id!;
                      final included = _included.contains(id);
                      return Material(
                        key: ValueKey('pack_sel_$id'),
                        color: Theme.of(context).colorScheme.surface,
                        child: GearInventoryListTile(
                          gear: gear,
                          reorderIndex: _searchQuery.trim().isEmpty ? index : null,
                          trailing: Checkbox(
                            value: included,
                            onChanged: (v) {
                              if (v != null) _toggle(id, v);
                            },
                          ),
                          onTap: () => _toggle(id, !included),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
