import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/app_theme_provider.dart';
import 'providers/bootstrap_provider.dart';
import 'screens/gear_list_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: CampInventoryApp()));
}

class CampInventoryApp extends ConsumerWidget {
  const CampInventoryApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(bootstrapProvider);
    final colorTheme = ref.watch(appThemeProvider);

    return MaterialApp(
      title: 'GEAR BASE',
      theme: AppTheme.build(colorTheme),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ja', 'JP'),
      ],
      locale: const Locale('ja', 'JP'),
      home: bootstrap.when(
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Scaffold(
          body: Center(child: Text('起動エラー: $e')),
        ),
        data: (_) => const GearListScreen(),
      ),
    );
  }
}
