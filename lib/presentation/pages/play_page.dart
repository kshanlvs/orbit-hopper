import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/comet_skin.dart';
import '../../domain/entities/mission.dart';
import '../../game/audio/game_audio.dart';
import '../../game/logic/cosmos.dart';
import '../../game/logic/models.dart';
import '../../game/orbit_hopper_game.dart';
import '../progress/progress_cubit.dart';
import '../run/run_cubit.dart';
import '../widgets/discovery_card.dart';
import '../widgets/game_hud.dart';
import '../widgets/defense_widgets.dart';
import '../widgets/missions_view.dart';
import '../widgets/run_panels.dart';

class PlayPage extends StatefulWidget {
  const PlayPage({super.key, this.defenseMode = false});

  /// "Save Earth" mode instead of the open journey.
  final bool defenseMode;

  @override
  State<PlayPage> createState() => _PlayPageState();
}

class _PlayPageState extends State<PlayPage> with WidgetsBindingObserver {
  late final RunCubit _run;
  final math.Random _rng = math.Random();
  late final OrbitHopperGame _game;

  /// Shows the departure card only when the launch point changes.
  int? _lastDepartureShown;

  /// Missions active when this run started — only these can complete in it,
  /// so a freshly generated replacement can't finish instantly.
  List<Mission> _runMissions = const [];
  final Set<String> _doneThisRun = {};
  RunStats? _stats;
  int _newDiscoveries = 0;

  ProgressCubit get _progress => context.read<ProgressCubit>();

  /// Earth's index in the journey: every "Save Earth" run launches from it.
  static final int _earth = journey.indexWhere((l) => l.id == 'earth');

  DefenseConfig? _defenseConfig() =>
      widget.defenseMode ? DefenseConfig(level: _progress.state.defenseLevel) : null;

  int _startIndex() => widget.defenseMode ? _earth : _progress.launchIndex;

  DefenseSnapshot? _initialSnapshot(DefenseConfig? c) => c == null
      ? null
      : DefenseSnapshot(
          level: c.level,
          timeLeft: c.timeLimit,
          charge: 0,
          needed: c.chargeNeeded,
          killerActive: false,
          won: false,
          started: false,
        );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final start = _startIndex();
    final defense = _defenseConfig();
    _run = RunCubit()..restart(startLandmark: start, defense: _initialSnapshot(defense));
    _beginRunMissions();
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
      onStats: _handleStats,
      defense: defense,
      onDefense: _handleDefense,
      onDefenseWon: _handleDefenseWon,
    );
  }

  void _handleDefense(DefenseState d) {
    if (_run.isClosed) return;
    _run.defenseChanged(DefenseSnapshot(
      level: d.config.level,
      timeLeft: d.timeLeft,
      charge: d.charge,
      needed: d.config.chargeNeeded,
      killerActive: d.killer != null,
      won: d.won,
      started: d.timeLeft < d.config.timeLimit,
    ));
  }

  Future<void> _handleDefenseWon() async {
    final level = _run.state.defense?.level ?? 1;
    final reward = await _progress.defenseWon(level);
    if (!mounted || _run.isClosed) return;
    _game.pauseEngine();
    GameAudio.instance.setDucked(true);
    _run.won(reward: reward);
  }

  void _beginRunMissions() {
    _runMissions = List.of(_progress.state.missions);
    _doneThisRun.clear();
    _stats = null;
    _newDiscoveries = 0;
  }

  void _handleStats(RunStats stats) {
    _stats = stats;
    stats.newDiscoveries = _newDiscoveries;
    for (final m in _runMissions) {
      final key = m.encode();
      if (_doneThisRun.contains(key) || !m.isDoneBy(stats)) continue;
      _doneThisRun.add(key);
      _progress.completeMission(m);
      GameAudio.instance.play(Sfx.mission);
      if (!_run.isClosed) _run.missionCompleted(m);
    }
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
    if (widget.defenseMode) {
      _progress.discover(Cosmos.place(landmarkIndex).id); // Earth counts as found
      return; // the briefing card replaces the departure card
    }
    if (_lastDepartureShown == landmarkIndex || _run.isClosed) return;
    _lastDepartureShown = landmarkIndex;
    _run.departed(landmarkIndex);
  }

  Future<void> _handleDiscovery(int landmarkIndex) async {
    final landmark = Cosmos.place(landmarkIndex);
    final isNew = await _progress.discover(landmark.id);
    if (!mounted || _run.isClosed) return;
    if (isNew) {
      await _progress.claimMilestone(landmarkIndex);
      if (!mounted || _run.isClosed) return;
      _newDiscoveries++;
      final s = _stats;
      if (s != null) _handleStats(s);
    }
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
        DeathCause.asteroid => 'Asteroid impact',
        DeathCause.impact => 'Earth was hit',
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
    // Newly discovered places become the checkpoint automatically; in
    // "Save Earth" a win has already raised the threat level.
    final start = _startIndex();
    final defense = _defenseConfig();
    GameAudio.instance.setDucked(false);
    _run.restart(startLandmark: start, defense: _initialSnapshot(defense));
    _beginRunMissions();
    _game.restart(startLandmark: start, defense: defense);
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
            if (widget.defenseMode) const Positioned.fill(child: DefenseBriefing()),
            const Positioned.fill(child: DiscoveryOverlay()),
            const Positioned.fill(child: MissionToast()),
            Positioned.fill(
              child: BlocBuilder<RunCubit, RunState>(
                buildWhen: (a, b) => a.status != b.status,
                builder: (context, s) => switch (s.status) {
                  RunStatus.playing => const SizedBox.shrink(),
                  RunStatus.paused => PausePanel(onResume: _resume, onHome: _home),
                  RunStatus.over => s.victory
                      ? VictoryPanel(state: s, onNext: _retry, onHome: _home)
                      : GameOverPanel(state: s, onRetry: _retry, onHome: _home),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
