import 'package:flutter/material.dart';

/// 格納解除の確認ダイアログを表示する関数
Future<bool> showConfirmUnnestDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('格納解除の確認'),
      content: const Text('格納解除しますか？'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('キャンセル'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('格納解除'),
        ),
      ],
    ),
  );
  return result ?? false;
}
