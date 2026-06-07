import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:camp_inventory_app/main.dart';

void main() {
  testWidgets('アプリが起動する', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: CampInventoryApp()),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
