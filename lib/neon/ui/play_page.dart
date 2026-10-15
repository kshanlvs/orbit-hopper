import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../audio/neon_audio.dart';
import '../engine/neon_world.dart';
import '../neon_game.dart';
import '../progression/neon_cubit.dart';
import '../progression/profile.dart';
import '../progression/rules.dart';
import 'hud.dart';
import 'overlays.dart';

class NeonPlayPage extends StatefulWidget {
  const NeonPlayPage({super.key, this.daily = false});

  final bool daily;

  @override
  State<NeonPlayPage> createState() => _NeonPlayPageState();
}

class _NeonPlayPageState extends State<NeonPlayPage> with WidgetsBindingObserver {
  late final NeonCubit _cubit = context.read<NeonCubit>();
  late NeonGame _game;
  final FocusNode _focus = FocusNode();
  final math.Random _seeds = math.Random();

  RunSummary? _result;
  RunReward? _reward;
  bool _paused = false;

  int get _seed => widget.daily ? _cubit.today.seed : _seeds.nextInt(0x7FFFFFFF);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final p = _cubit.state;
    _game = NeonGame(
      NeonRunConfig(
        seed: _seed,
        daily: widget.daily,
        dimension: p.dimension,
        skin: p.skin,
        trail: p.trail,
        settings: p.settings,
        previousBest: p.best,
      ),
      onGameOver: _onGameOver,
    );
    NeonAudio.instance.setDucked(false);
    NeonAudio.instance.music(NeonTrack.run);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focus.dispose();
    NeonAudio.instance.setDucked(false);
    NeonAudio.instance.music(NeonTrack.menu);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      if (_result == null && _cubit.state.settings.pauseOnFocusLoss) {
        _pause();
      } else if (!_paused) {
        _game.pauseGame(); // never simulate while the app is in the background
      }
    } else if (state == AppLifecycleState.resumed && !_paused && _result == null) {
      _game.resumeGame();
    }
  }

  Future<void> _onGameOver(RunSummary run) async {
    NeonAudio.instance.setDucked(true);
    setState(() {
      _result = run;
      _reward = null;
    });
    final reward = await _cubit.recordRun(run);
    if (!mounted) return;
    _game.setPreviousBest(_cubit.state.best);
    setState(() => _reward = reward);
  }

  void _retry() {
    _game.restart(_seed);
    NeonAudio.instance.setDucked(false);
    setState(() {
      _result = null;
      _reward = null;
      _paused = false;
    });
    _focus.requestFocus();
  }

  void _pause() {
    if (_paused || _result != null || !_game.sim.alive) return;
    _game.pauseGame();
    NeonAudio.instance.setDucked(true);
    setState(() => _paused = true);
  }

  void _resume() {
    if (!_paused) return;
    NeonAudio.instance.setDucked(false);
    setState(() => _paused = false);
    _game.resumeGame();
    _focus.requestFocus();
  }

  void _quit() => context.pop();

  Future<void> _settings(NeonSettings s) async {
    await _cubit.settings(s);
    await NeonAudio.instance.apply(sfx: s.sfx, music: s.music, haptics: s.haptics);
    _game.updateSettings(s);
    if (mounted) setState(() {});
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.space || k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.arrowDown) {
      if (_result != null) {
        _retry();
      } else if (!_paused) {
        _game.flip();
      }
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.keyD || k == LogicalKeyboardKey.arrowRight || k == LogicalKeyboardKey.shiftLeft) {
      _game.dash();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.escape || k == LogicalKeyboardKey.keyP) {
      _paused ? _resume() : _pause();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return PopScope(
      canPop: _paused || result != null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _pause();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Focus(
          focusNode: _focus,
          autofocus: true,
          onKeyEvent: _onKey,
          child: Stack(
            children: [
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (_) {
                    if (!_paused && _result == null) _game.flip();
                  },
                  child: GameWidget(game: _game),
                ),
              ),
              Positioned.fill(child: SafeArea(child: NeonHudView(game: _game, onPause: _pause))),
              Positioned.fill(child: NeonToastLayer(toasts: _game.toasts)),
              if (_paused)
                Positioned.fill(
                  child: NeonPauseMenu(
                    settings: _cubit.state.settings,
                    onResume: _resume,
                    onRestart: _retry,
                    onQuit: _quit,
                    onSettings: _settings,
                  ),
                ),
              if (result != null)
                Positioned.fill(
                  child: NeonGameOver(
                    run: result,
                    reward: _reward,
                    best: _cubit.state.best,
                    dailyTarget: widget.daily ? _cubit.today.target : null,
                    onRetry: _retry,
                    onMenu: _quit,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
