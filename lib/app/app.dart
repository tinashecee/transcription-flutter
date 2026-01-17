import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme/app_theme.dart';
import '../presentation/widgets/app_shortcuts.dart';

class TranscriberApp extends ConsumerWidget {
  const TranscriberApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return AppShortcuts(
      child: MaterialApp.router(
        title: 'Testimony Transcriber',
        theme: AppTheme.light,
        routerConfig: router,
      ),
    );
  }
}
