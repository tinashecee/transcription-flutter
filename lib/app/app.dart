import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

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
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: router,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          FlutterQuillLocalizations.delegate,
        ],
        supportedLocales: FlutterQuillLocalizations.supportedLocales,
      ),
    );
  }
}
