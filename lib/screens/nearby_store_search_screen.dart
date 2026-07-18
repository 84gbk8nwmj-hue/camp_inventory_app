import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NearbyStoreSearchScreen extends ConsumerWidget {
  const NearbyStoreSearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('近くのお店検索'),
      ),
      body: const Center(
        child: Text('お店検索結果がここに表示されます'),
      ),
    );
  }
}
