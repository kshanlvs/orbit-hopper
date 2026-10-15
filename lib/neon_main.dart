import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'neon/ui/neon_routes.dart';
import 'neon/ui/neon_style.dart';

/// Neon Shift on its own:  flutter run -t lib/neon_main.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NeonShiftApp());
}

final GoRouter _router = GoRouter(
  initialLocation: NeonRoutes.menu,
  routes: [neonShellRoute()],
);

class NeonShiftApp extends StatelessWidget {
  const NeonShiftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Neon Shift',
      debugShowCheckedModeBanner: false,
      theme: neonTheme(),
      routerConfig: _router,
    );
  }
}
