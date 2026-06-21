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
    var list = List<Gear>.of(_allGear)
      ..sort((a, b) {
        final order = a.sortOrder.compareTo(b.sortOrder);
        return order != 0 ? order : a.name.compareTo(b.name);
      });

    final q = StringUtils.normalizeForSearch(_searchQuery);
    if (q.isNotEmpty) {
      return list.where((g) {
        final name = StringUtils.normalizeForSearch(g.name);
        final note = StringUtils.normalizeForSearch(g.note ?? '');
        final mfr = StringUtils.normalizeForSearch(g.manufacturer ?? '');
        return name.contains(q) || note.contains(q) || mfr.contains(q);
      }).toList();
    }

    return _buildHierarchy(list);
  }

  List<Gear> _buildHierarchy(List<Gear> flatList) {
    final result = <Gear>[];
    final childrenOf = <int, List<Gear>>{};
    final roots = <Gear>[];

    for (final g in flatList) {
      if (g.parentId == null) {
        roots.add(g);
      } else {
        childrenOf.putIfAbsent(g.parentId!, () => []).add(g);
      }
    }

    void addWithChildren(Gear parent) {
      result.add(parent);
      final children = childrenOf[parent.id];
      if (children == null) return;
      children.sort((a, b) {
        final order = a.sortOrder.compareTo(b.sortOrder);
        return order != 0 ? order : a.name.compareTo(b.name);
      });
      for (final child in children) {
        addWithChildren(child);
      }
    }

    for (final root in roots) {
      addWithChildren(root);
    }

    final addedIds = result.map((g) => g.id).toSet();
    for (final g in flatList) {
      if (!addedIds.contains(g.id)) {
        result.add(g);
      }
    }

    return result;
  }

  Future<void> _toggle(int gearId, bool value) async {
    try {
      await ref
          .read(packingProvider.notifier)
          .setIncludedForSet(widget.setId, gearId, value);

      // 再帰的な更新を反映するため最新のIDリストを再取得
      final included = await ref
          .read(packingProvider.notifier)
          .loadIncludedIds(widget.setId);
      if (mounted) {
        setState(() {
          _included = included;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存に失敗しました: $e')),
      );
    }
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
          Expanded(
            child: _displayGear.isEmpty
                ? const Center(child: Text('一致するギアがありません'))
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: _displayGear.length,
                    itemBuilder: (context, index) {
                      final gear = _displayGear[index];
                      final id = gear.id!;
                      final included = _included.contains(id);
                      return Material(
                        key: ValueKey('pack_sel_$id'),
                        color: Theme.of(context).colorScheme.surface,
                        child: GearInventoryListTile(
                          gear: gear,
                          reorderIndex: null,
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
