// lib/app.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router.dart';
import 'core/services/supabase_client.dart';
import 'core/theme/app_theme.dart';
import 'config/env.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  late final Future<void> _init;

  @override
  void initState() {
    super.initState();
    _init = AppSupabase.init();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _init,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return MaterialApp(
            title: Env.appName,
            home: const Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }
        if (snapshot.hasError) {
          return MaterialApp(
            title: Env.appName,
            home: Scaffold(body: Center(child: Text('Startup error: ${snapshot.error}'))),
          );
        }
        final router = AppRouter.create(ref);
        return MaterialApp.router(
          title: Env.appName,
          theme: AppTheme.light(context),
          darkTheme: AppTheme.dark(context),
          themeMode: ThemeMode.system,
          routerConfig: router,
          debugShowCheckedModeBanner: Env.isDev,
        );
      },
    );
  }
}
