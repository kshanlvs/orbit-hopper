import 'package:go_router/go_router.dart';

import '../../presentation/pages/home_page.dart';
import '../../presentation/pages/journey_page.dart';
import '../../presentation/pages/play_page.dart';
import '../../presentation/pages/skins_page.dart';

abstract final class AppRoutes {
  static const home = '/';
  static const play = '/play';
  static const skins = '/skins';
  static const journey = '/journey';
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.home,
  routes: [
    GoRoute(path: AppRoutes.home, builder: (context, state) => const HomePage()),
    GoRoute(path: AppRoutes.play, builder: (context, state) => const PlayPage()),
    GoRoute(path: AppRoutes.skins, builder: (context, state) => const SkinsPage()),
    GoRoute(path: AppRoutes.journey, builder: (context, state) => const JourneyPage()),
  ],
);
