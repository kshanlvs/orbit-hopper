import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'challenges_page.dart';
import 'lab_page.dart';
import 'menu_page.dart';
import 'neon_scope.dart';
import 'play_page.dart';
import 'settings_page.dart';

abstract final class NeonRoutes {
  static const menu = '/neon';
  static const play = '/neon/play';
  static const daily = '/neon/play?daily=1';
  static const lab = '/neon/lab';
  static const challenges = '/neon/challenges';
  static const settings = '/neon/settings';
}

/// All Neon Shift screens under one shell, so they share the profile and
/// orientation. [exitTo] is where the menu's back button goes (null = no
/// back button, for the standalone app).
RouteBase neonShellRoute({String? exitTo, VoidCallback? onEnter, VoidCallback? onLeave, bool restorePortrait = false}) {
  return ShellRoute(
    builder: (context, state, child) => NeonScope(
      onEnter: onEnter,
      onLeave: onLeave,
      restorePortrait: restorePortrait,
      child: child,
    ),
    routes: [
      GoRoute(
        path: NeonRoutes.menu,
        builder: (context, state) => NeonMenuPage(exitTo: exitTo),
        routes: [
          GoRoute(
            path: 'play',
            builder: (context, state) => NeonPlayPage(daily: state.uri.queryParameters['daily'] == '1'),
          ),
          GoRoute(path: 'lab', builder: (context, state) => const NeonLabPage()),
          GoRoute(path: 'challenges', builder: (context, state) => const NeonChallengesPage()),
          GoRoute(path: 'settings', builder: (context, state) => const NeonSettingsPage()),
        ],
      ),
    ],
  );
}
