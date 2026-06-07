import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';

import '../data/camp_manufacturers.dart';
import '../models/gear.dart';
import '../providers/category_provider.dart';
import '../providers/database_providers.dart';
import '../providers/gear_provider.dart';
import '../services/amazon_search_service.dart';
import '../widgets/gear_list_tile.dart';
import '../widgets/manufacturer_picker_field.dart';

class _FormSnapshot {
  final String name;
  final String note;
  final String weightText;
  final int? categoryId;
  final int quantity;
  final String? imageFile;
  final String? manufacturer;
  final bool weightVerified;

  const _FormSnapshot({
    required this.name,
    required this.note,
    required this.weightText,
    required this.categoryId,
    required this.quantity,
    required this.imageFile,
    required this.manufacturer,
    required this.weightVerified,
  });

  @override
  bool operator ==(Object other) {
    return other is _FormSnapshot &&
        other.name == name &&
        other.note == note &&
        other.weightText == weightText &&
        other.categoryId == categoryId &&
        other.quantity == quantity &&
        other.imageFile == imageFile &&
        other.manufacturer == manufacturer &&
        other.weightVerified == weightVerified;
  }

  @override
  int get hashCode => Object.hash(
        name,
        note,
        weightText,
        categoryId,
        quantity,
        imageFile,
        manufacturer,
        weightVerified,
      );
}

class GearEditScreen extends ConsumerStatefulWidget {
  final Gear? existing;
  const GearEditScreen({super.key, this.existing});

  @override
  ConsumerState<GearEditScreen> createState() => _GearEditScreenState();
}

class _GearEditScreenState extends ConsumerState<GearEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  int? _categoryId;
  int _quantity = 1;
  String? _imageFile;
  String? _manufacturer;
  bool _weightVerified = false;
  String? _fixedWeightText;
  bool _dirty = false;
  _FormSnapshot? _initialSnapshot;

  @override
  void initState() {
    super.initState();
    final g = widget.existing;
    if (g != null) {
      _nameCtrl.text = g.name;
      _noteCtrl.text = g.note ?? '';
      _weightCtrl.text = g.weight != null ? g.weight.toString() : '';
      _categoryId = g.categoryId;
      _quantity = g.quantity;
      _imageFile = g.imageFile;
      _manufacturer = g.manufacturer;
      _weightVerified = g.weightVerified;
      if (g.weightVerified && g.weight != null) {
        _fixedWeightText = g.weight.toString();
      }
    }
    _weightCtrl.addListener(_onWeightTextChanged);
    _nameCtrl.addListener(_updateDirty);
    _noteCtrl.addListener(_updateDirty);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialSnapshot = _captureSnapshot();
      _updateDirty();
    });
  }

  void _onWeightTextChanged() {
    if (_weightVerified && _weightCtrl.text.trim() != _fixedWeightText) {
      setState(() {
        _weightVerified = false;
        _fixedWeightText = null;
      });
    }
    _updateDirty();
  }

  _FormSnapshot _captureSnapshot() {
    return _FormSnapshot(
      name: _nameCtrl.text.trim(),
      note: _noteCtrl.text.trim(),
      weightText: _weightCtrl.text.trim(),
      categoryId: _categoryId,
      quantity: _quantity,
      imageFile: _imageFile,
      manufacturer: CampManufacturers.normalize(_manufacturer),
      weightVerified: _weightVerified,
    );
  }

  void _updateDirty() {
    if (!mounted) return;
    final initial = _initialSnapshot;
    final dirty = initial == null
        ? _isNewFormDirty()
        : _captureSnapshot() != initial;
    if (dirty != _dirty) {
      setState(() => _dirty = dirty);
    }
  }

  bool _isNewFormDirty() {
    return _nameCtrl.text.trim().isNotEmpty ||
        _noteCtrl.text.trim().isNotEmpty ||
        _weightCtrl.text.trim().isNotEmpty ||
        (_manufacturer != null && _manufacturer!.isNotEmpty) ||
        _imageFile != null ||
        _quantity != 1 ||
        _weightVerified;
  }

  void _setStateAndDirty(VoidCallback fn) {
    setState(fn);
    _updateDirty();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _noteCtrl.dispose();
    _weightCtrl.removeListener(_onWeightTextChanged);
    _weightCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage({required ImageSource source}) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source);
      if (picked == null) return;

      String finalPath = picked.path;

      // ライブラリからの選択時のみ調整を試みる
      if (source == ImageSource.gallery && mounted) {
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: picked.path,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: '編集',
              toolbarColor: Theme.of(context).colorScheme.surface,
              toolbarWidgetColor: Theme.of(context).colorScheme.onSurface,
              initAspectRatio: CropAspectRatioPreset.square,
              lockAspectRatio: false,
              aspectRatioPresets: [
                CropAspectRatioPreset.original,
                CropAspectRatioPreset.square,
                CropAspectRatioPreset.ratio3x2,
                CropAspectRatioPreset.ratio4x3,
                CropAspectRatioPreset.ratio16x9,
              ],
            ),
            IOSUiSettings(
              title: '編集',
              doneButtonTitle: '保存',
              cancelButtonTitle: 'キャンセル',
              aspectRatioPresets: [
                CropAspectRatioPreset.original,
                CropAspectRatioPreset.square,
                CropAspectRatioPreset.ratio3x2,
                CropAspectRatioPreset.ratio4x3,
                CropAspectRatioPreset.ratio16x9,
              ],
            ),
          ],
        );

        if (croppedFile != null) {
          finalPath = croppedFile.path;
        } else {
          // 編集をキャンセルした場合は処理を中断
          return;
        }
      }

      final fileName =
          await ref.read(imageStorageProvider).saveFromPath(finalPath);
      if (fileName != null) {
        _setStateAndDirty(() => _imageFile = fileName);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('写真を取り込みました'),
              backgroundColor: Theme.of(context).colorScheme.secondary,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error picking/editing image: $e');
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('エラー'),
            content: Text('写真の取り込みに失敗しました: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final categories = ref.read(categoryProvider);
    final category = categories.byId(_categoryId ?? -1);
    if (category == null) return;

    final gear = Gear(
      id: widget.existing?.id,
      name: _nameCtrl.text.trim(),
      categoryId: category.id!,
      categoryName: category.name,
      quantity: _quantity,
      weight: _weightCtrl.text.trim().isEmpty
          ? null
          : double.tryParse(_weightCtrl.text.trim()),
      imageFile: _imageFile,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      manufacturer: CampManufacturers.normalize(_manufacturer),
      weightVerified: _weightVerified && _parsedWeight != null,
    );

    final notifier = ref.read(gearProvider.notifier);
    if (widget.existing == null) {
      await notifier.add(gear);
    } else {
      await notifier.update(gear);
    }

    if (mounted) Navigator.pop(context);
  }

  Future<bool> _confirmDiscardChanges() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('変更を破棄しますか？'),
        content: const Text('保存していない変更は失われます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('編集を続ける'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('破棄する'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _openAmazonSearch() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('先にギア名を入力してください')),
      );
      return;
    }
    try {
      await AmazonSearchService.openProductSearch(
        productName: name,
        manufacturer: _manufacturer,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Amazonを開けませんでした: $e')),
      );
    }
  }

  double? get _parsedWeight {
    final t = _weightCtrl.text.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  void _toggleWeightFix() {
    if (_parsedWeight == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('先に重量 (g) を入力してください')),
      );
      return;
    }
    _setStateAndDirty(() {
      if (_weightVerified) {
        _weightVerified = false;
        _fixedWeightText = null;
      } else {
        _weightVerified = true;
        _fixedWeightText = _weightCtrl.text.trim();
      }
    });
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('削除しますか？'),
        content: const Text('このギアを削除します。'),
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
    if (ok == true && widget.existing?.id != null) {
      await ref.read(gearProvider.notifier).remove(widget.existing!.id!);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _scrollToSaveButton() async {
    await _scrollCtrl.animateTo(
      _scrollCtrl.position.maxScrollExtent,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final categories = ref.watch(categoryProvider);
    _categoryId ??=
        categories.items.isNotEmpty ? categories.items.first.id : null;

    final previewGear = widget.existing?.copyWith(imageFile: _imageFile) ??
        Gear(
          name: '',
          categoryId: 0,
          categoryName: '',
          quantity: 1,
          imageFile: _imageFile,
        );

    final saveLabel = isEdit ? '更新する' : '追加する';

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || !_dirty) return;
        if (await _confirmDiscardChanges() && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEdit ? 'ギア編集' : 'ギア追加'),
          actions: [
            if (isEdit)
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: _delete,
              ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.only(top: 4, bottom: 16),
                    children: [
                      ManufacturerPickerField(
                        value: _manufacturer,
                        onChanged: (v) =>
                            _setStateAndDirty(() => _manufacturer = v),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(labelText: 'ギア名'),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? '入力してください'
                            : null,
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonalIcon(
                          onPressed: _openAmazonSearch,
                          icon: const Icon(Icons.open_in_new, size: 18),
                          label: const Text('Amazonで商品情報を確認'),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Amazonの商品ページを開いて重量を確認します。メーカーを選ぶと検索精度が上がります。',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.65),
                                  ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        value: _categoryId,
                        items: categories.items
                            .map(
                              (c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(c.name),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            _setStateAndDirty(() => _categoryId = v),
                        decoration:
                            const InputDecoration(labelText: 'カテゴリ'),
                        validator: (v) => v == null ? '選択してください' : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text('数量'),
                          const SizedBox(width: 16),
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: _quantity > 1
                                ? () => _setStateAndDirty(() => _quantity--)
                                : null,
                          ),
                          Text(_quantity.toString()),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () =>
                                _setStateAndDirty(() => _quantity++),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _weightCtrl,
                              decoration: InputDecoration(
                                labelText: '重量 (g)',
                                hintText: '例: 500',
                                suffixIcon: _weightVerified
                                    ? const Icon(
                                        Icons.verified,
                                        color: Colors.green,
                                      )
                                    : null,
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return null;
                                }
                                if (double.tryParse(v.trim()) == null) {
                                  return '数値を入力してください';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: _toggleWeightFix,
                            style: FilledButton.styleFrom(
                              backgroundColor: _weightVerified
                                  ? Colors.green.shade700
                                  : null,
                              foregroundColor: _weightVerified
                                  ? Colors.white
                                  : null,
                            ),
                            child:
                                Text(_weightVerified ? 'FIX済' : 'FIX'),
                          ),
                        ],
                      ),
                      if (_weightVerified)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '重量は確認済みです（変更するとFIXが解除されます）',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.green.shade700,
                                    ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _noteCtrl,
                        decoration: const InputDecoration(labelText: 'メモ'),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _pickImage(source: ImageSource.gallery),
                              icon: const Icon(Icons.photo_library),
                              label: const Text('写真を選ぶ'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _pickImage(source: ImageSource.camera),
                              icon: const Icon(Icons.camera_alt),
                              label: const Text('写真を撮影'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_imageFile != null) ...[
                        GearImagePreview(gear: previewGear),
                        const SizedBox(height: 12),
                      ],
                      const SizedBox(height: 12),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: _dirty
                              ? Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary,
                                  width: 2,
                                )
                              : null,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _save,
                            child: Text(saveLabel),
                          ),
                        ),
                      ),
                      if (_dirty) const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ),
            if (_dirty)
              Material(
                elevation: 8,
                color: Theme.of(context).colorScheme.primaryContainer,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit_note,
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '未保存の変更があります',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _scrollToSaveButton,
                          child: const Text('保存へ'),
                        ),
                        FilledButton(
                          onPressed: _save,
                          child: Text(saveLabel),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
