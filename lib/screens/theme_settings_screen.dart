import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_theme_provider.dart';
import '../theme/app_color_theme.dart';

class ThemeSettingsScreen extends ConsumerWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(appThemeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('背景テーマ')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '背景色のテーマを選べます。アイコンや文字色もテーマに合わせて変わります。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          ...AppColorTheme.values.map((theme) {
            final selected = theme == current;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: _ThemePreviewSwatch(theme: theme),
                title: Text(theme.labelJa),
                subtitle: Text(theme.labelEn),
                trailing: selected
                    ? Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () async {
                  await ref.read(appThemeProvider.notifier).setTheme(theme);
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ThemePreviewSwatch extends StatelessWidget {
  final AppColorTheme theme;
  const _ThemePreviewSwatch({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.accent.withValues(alpha: 0.5),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                color: theme.scaffold,
              ),
            ),
            Expanded(
              flex: 1,
              child: Container(
                width: double.infinity,
                color: theme.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
