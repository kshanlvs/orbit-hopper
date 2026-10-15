import 'package:go_router/go_router.dart';

import '../../game/audio/game_audio.dart';
import '../../neon/ui/neon_routes.dart';
import '../../presentation/pages/home_page.dart';
import '../../presentation/pages/journey_page.dart';
import '../../presentation/pages/play_page.dart';
import '../../presentation/pages/skins_page.dart';

abstract final class AppRoutes {
  static const home = '/';
  static const play = '/play';
  static const defense = '/play?mode=defense';
  static const neon = NeonRoutes.menu;
  static const skins = '/skins';
  static const journey = '/journey';
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.home,
  routes: [
    GoRoute(path: AppRoutes.home, builder: (context, state) => const HomePage()),
    GoRoute(
      path: AppRoutes.play,
      builder: (context, state) => PlayPage(defenseMode: state.uri.queryParameters['mode'] == 'defense'),
    ),
    GoRoute(path: AppRoutes.skins, builder: (context, state) => const SkinsPage()),
    GoRoute(path: AppRoutes.journey, builder: (context, state) => const JourneyPage()),
    neonShellRoute(
      exitTo: AppRoutes.home,
      restorePortrait: true,
      onEnter: () => GameAudio.instance.setSuspended(true),
      onLeave: () => GameAudio.instance.setSuspended(false),
    ),
  ],
);
