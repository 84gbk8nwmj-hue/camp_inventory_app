import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_theme_provider.dart';
import '../providers/confirm_unnest_provider.dart';
import '../theme/app_color_theme.dart';
import 'privacy_policy_screen.dart';

class ThemeSettingsScreen extends ConsumerWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(appThemeProvider);
    final confirmUnnest = ref.watch(confirmUnnestProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
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
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('格納解除時に確認する'),
            subtitle: const Text('左スワイプで格納解除する際に確認ダイアログを表示します'),
            value: confirmUnnest,
            onChanged: (value) async {
              await ref
                  .read(confirmUnnestProvider.notifier)
                  .setConfirmUnnest(value);
            },
          ),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
          ListTile(
            title: const Text('プライバシーポリシー'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const PrivacyPolicyScreen(),
                ),
              );
            },
          ),
          ListTile(
            title: const Text('オープンソースライセンス'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showLicensePage(
                context: context,
                applicationName: 'キャンプ持ち出しリスト',
                applicationVersion: '1.0.0',
              );
            },
          ),
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
