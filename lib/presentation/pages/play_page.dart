import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/comet_skin.dart';
import '../../game/audio/game_audio.dart';
import '../../game/logic/cosmos.dart';
import '../../game/logic/models.dart';
import '../../game/orbit_hopper_game.dart';
import '../progress/progress_cubit.dart';
import '../run/run_cubit.dart';
import '../widgets/discovery_card.dart';
import '../widgets/game_hud.dart';
import '../widgets/run_panels.dart';

class PlayPage extends StatefulWidget {
  const PlayPage({super.key});

  @override
  State<PlayPage> createState() => _PlayPageState();
}

class _PlayPageState extends State<PlayPage> with WidgetsBindingObserver {
  late final RunCubit _run;
  final math.Random _rng = math.Random();
  late final OrbitHopperGame _game;

  /// Shows the departure card only when the launch point changes.
  int? _lastDepartureShown;

  ProgressCubit get _progress => context.read<ProgressCubit>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final start = _progress.launchIndex;
    _run = RunCubit()..restart(startLandmark: start);
    final skin = CometSkins.byId(_progress.state.selectedSkinId);
    _game = OrbitHopperGame(
      skin: skin,
      startLandmark: start,
      isDiscovered: (k) => _progress.isDiscovered(k),
      onScoreChanged: _run.scoreChanged,
      onStardustChanged: _run.stardustChanged,
      onJourney: _run.journeyChanged,
      onTravel: _run.travelChanged,
      onDiscovery: _handleDiscovery,
      onDepart: _handleDepart,
      onGameOver: _handleGameOver,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    GameAudio.instance.setDucked(false);
    _run.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _pause();
  }

  void _handleDepart(int landmarkIndex) {
    if (landmarkIndex == 0) _progress.discover(journey[0].id); // counts the Sun
    if (_lastDepartureShown == landmarkIndex || _run.isClosed) return;
    _lastDepartureShown = landmarkIndex;
    _run.departed(landmarkIndex);
  }

  Future<void> _handleDiscovery(int landmarkIndex) async {
    final landmark = journey[landmarkIndex];
    final isNew = await _progress.discover(landmark.id);
    if (!mounted || _run.isClosed) return;
    _run.discovered(
      landmarkIndex: landmarkIndex,
      isNew: isNew,
      // First visit shows the first fact; later visits show a random one.
      factIndex: isNew ? 0 : _rng.nextInt(landmark.facts.length),
    );
  }

  Future<void> _handleGameOver(int score, int stardust, int bestIndex, DeathCause cause) async {
    final progress = _progress;
    final earned = stardust + score ~/ 4;
    final isNewBest = await progress.recordRun(score: score, stardustEarned: earned);
    if (!mounted || _run.isClosed) return;
    GameAudio.instance.setDucked(true);
    _run.finish(
      isNewBest: isNewBest,
      earnedStardust: earned,
      bestScore: progress.state.bestScore,
      deathReason: switch (cause) {
        DeathCause.moon => 'Moon strike',
        DeathCause.collapse => 'Planet collapsed',
        DeathCause.lost => 'Lost in space',
      },
    );
  }

  void _pause() {
    if (_run.state.status != RunStatus.playing) return;
    _game.pauseEngine();
    GameAudio.instance.setDucked(true);
    _run.pause();
  }

  void _resume() {
    _game.resumeEngine();
    GameAudio.instance.setDucked(false);
    _run.resume();
  }

  void _retry() {
    // Newly discovered places become the checkpoint automatically.
    final start = _progress.launchIndex;
    GameAudio.instance.setDucked(false);
    _run.restart(startLandmark: start);
    _game.restart(startLandmark: start);
  }

  void _home() => context.pop();

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _run,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (_) => _game.tap(),
                child: RepaintBoundary(child: GameWidget(game: _game)),
              ),
            ),
            Positioned.fill(child: RepaintBoundary(child: GameHud(onPause: _pause))),
            const Positioned.fill(child: DiscoveryOverlay()),
            Positioned.fill(
              child: BlocBuilder<RunCubit, RunState>(
                buildWhen: (a, b) => a.status != b.status,
                builder: (context, s) => switch (s.status) {
                  RunStatus.playing => const SizedBox.shrink(),
                  RunStatus.paused => PausePanel(onResume: _resume, onHome: _home),
                  RunStatus.over => GameOverPanel(state: s, onRetry: _retry, onHome: _home),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
