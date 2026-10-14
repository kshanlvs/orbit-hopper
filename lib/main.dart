import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/repositories/shared_prefs_progress_repository.dart';
import 'game/audio/game_audio.dart';
import 'game/logic/cosmos.dart';
import 'presentation/progress/progress_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  final prefs = await SharedPreferences.getInstance();
  final progressCubit = ProgressCubit(SharedPrefsProgressRepository(prefs));
  await progressCubit.load();

  // Load sounds in the background so the app opens instantly.
  final launchIndex = Cosmos.indexOfId(progressCubit.state.launchFromId);
  GameAudio.instance
      .init(
        enabled: progressCubit.state.soundOn,
        mood: Cosmos.regionAt(launchIndex * hopsPerLandmark).mood,
      )
      .then((_) => GameAudio.instance.startMusic());

  runApp(OrbitHopperApp(progressCubit: progressCubit));
}
