import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../game/audio/game_audio.dart';
import '../../hole/hole_game.dart';
import '../../hole/logic/hole_world.dart';
import '../../hole/logic/size_scale.dart';
import '../progress/progress_cubit.dart';
import '../widgets/glow_button.dart';
import '../widgets/stardust_badge.dart';

const _purple = Color(0xFFB57CFF);
const _green = Color(0xFF5CFFB0);

/// What the HUD shows, refreshed ~10 times a second from the game.
class _HoleHud {
  const _HoleHud({
    this.radius = HoleWorld.startRadius,
    this.tier = 0,
    this.eaten = 0,
    this.starving = false,
    this.started = false,
  });

  final double radius;
  final int tier;
  final int eaten;
  final bool starving;
  final bool started;
}

class _Result {
  const _Result({
    required this.death,
    required this.maxRadius,
    required this.tier,
    required this.eaten,
    required this.stardust,
    required this.isNewBest,
  });

  final HoleDeath death;
  final double maxRadius;
  final int tier;
  final int eaten;
  final int stardust;
  final bool isNewBest;
}

/// "Black Hole: Eat the Universe" — a second endless game.
class HolePage extends StatefulWidget {
  const HolePage({super.key});

  @override
  State<HolePage> createState() => _HolePageState();
}

class _HolePageState extends State<HolePage> with WidgetsBindingObserver {
  late final HoleGame _game;
  final ValueNotifier<_HoleHud> _hud = ValueNotifier(const _HoleHud());
  final ValueNotifier<(Offset, Offset)?> _stick = ValueNotifier(null);
  int? _tierCard;
  Timer? _tierTimer;
  bool _paused = false;
  _Result? _result;

  ProgressCubit get _progress => context.read<ProgressCubit>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _game = HoleGame(onState: _onState, onTier: _onTier, onGameOver: _onGameOver);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tierTimer?.cancel();
    _hud.dispose();
    _stick.dispose();
    GameAudio.instance.setDucked(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _pause();
  }

  void _onState(HoleWorld w) {
    _hud.value = _HoleHud(
      radius: w.radius,
      tier: w.tier,
      eaten: w.eaten,
      starving: w.started && w.sinceLastMeal > 2.5 && !w.dead,
      started: w.started,
    );
  }

  void _onTier(int tier) {
    if (!mounted) return;
    _tierTimer?.cancel();
    setState(() => _tierCard = tier);
    _tierTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _tierCard = null);
    });
  }

  Future<void> _onGameOver(HoleWorld w) async {
    final stardust = w.eaten ~/ 10 + w.tier * 3;
    final isNewBest = await _progress.recordHoleRun(maxRadius: w.maxRadius, stardustEarned: stardust);
    if (!mounted) return;
    GameAudio.instance.setDucked(true);
    setState(() {
      _tierCard = null;
      _result = _Result(
        death: w.death ?? HoleDeath.evaporated,
        maxRadius: w.maxRadius,
        tier: tierOfRadius(w.maxRadius),
        eaten: w.eaten,
        stardust: stardust,
        isNewBest: isNewBest,
      );
    });
  }

  void _pause() {
    if (_paused || _result != null) return;
    _game.pauseEngine();
    _game.steer(Offset.zero);
    GameAudio.instance.setDucked(true);
    setState(() => _paused = true);
  }

  void _resume() {
    _game.resumeEngine();
    GameAudio.instance.setDucked(false);
    setState(() => _paused = false);
  }

  void _retry() {
    GameAudio.instance.setDucked(false);
    setState(() {
      _result = null;
      _tierCard = null;
    });
    _hud.value = const _HoleHud();
    _game.restart();
  }

  // Virtual joystick: drag from wherever you touch.
  void _panStart(DragStartDetails d) => _stick.value = (d.localPosition, d.localPosition);

  void _panUpdate(DragUpdateDetails d) {
    final s = _stick.value;
    if (s == null) return;
    _stick.value = (s.$1, d.localPosition);
    final delta = d.localPosition - s.$1;
    const full = 70.0; // pixels of drag for full speed
    final len = delta.distance;
    _game.steer(len < 4 ? Offset.zero : delta / full * (len > full ? full / len : 1));
  }

  void _panEnd([DragEndDetails? _]) {
    _stick.value = null;
    _game.steer(Offset.zero);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: _panStart,
              onPanUpdate: _panUpdate,
              onPanEnd: _panEnd,
              onPanCancel: _panEnd,
              child: RepaintBoundary(child: GameWidget(game: _game)),
            ),
          ),
          Positioned.fill(child: IgnorePointer(child: _Joystick(stick: _stick))),
          Positioned.fill(child: _Hud(hud: _hud, onPause: _pause)),
          if (_tierCard != null)
            Positioned.fill(child: IgnorePointer(child: _TierCard(key: ValueKey(_tierCard), tier: _tierCard!))),
          if (_paused)
            Positioned.fill(
              child: _Shell(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('PAUSED', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 6)),
                    const SizedBox(height: 24),
                    GlowButton(label: 'RESUME', icon: Icons.play_arrow_rounded, color: _purple, onPressed: _resume),
                    const SizedBox(height: 14),
                    GlowButton(label: 'HOME', filled: false, onPressed: () => context.pop()),
                  ],
                ),
              ),
            ),
          if (_result != null)
            Positioned.fill(child: _GameOver(result: _result!, onRetry: _retry, onHome: () => context.pop())),
        ],
      ),
    );
  }
}

class _Joystick extends StatelessWidget {
  const _Joystick({required this.stick});

  final ValueNotifier<(Offset, Offset)?> stick;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<(Offset, Offset)?>(
      valueListenable: stick,
      builder: (context, s, _) => CustomPaint(painter: _StickPainter(s)),
    );
  }
}

class _StickPainter extends CustomPainter {
  _StickPainter(this.s);

  final (Offset, Offset)? s;

  @override
  void paint(Canvas canvas, Size size) {
    final v = s;
    if (v == null) return;
    final (origin, now) = v;
    var d = now - origin;
    if (d.distance > 70) d = d / d.distance * 70;
    canvas.drawCircle(
        origin,
        70,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Colors.white.fade(0.15));
    canvas.drawCircle(origin + d, 22, Paint()..color = _purple.fade(0.3));
  }

  @override
  bool shouldRepaint(_StickPainter old) => old.s != s;
}

class _Hud extends StatelessWidget {
  const _Hud({required this.hud, required this.onPause});

  final ValueNotifier<_HoleHud> hud;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: ValueListenableBuilder<_HoleHud>(
          valueListenable: hud,
          builder: (context, h, _) {
            final next = tierName(h.tier + 1);
            return Stack(
              children: [
                IgnorePointer(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          formatLength(h.radius * 2),
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            shadows: [Shadow(color: _purple.fade(0.8), blurRadius: 18)],
                          ),
                        ),
                        Text(
                          comparisonFor(h.radius * 2),
                          style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 240,
                          padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
                          decoration: BoxDecoration(
                            color: Colors.black.fade(0.35),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.fade(0.08)),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'EATING: ${tierName(h.tier).toUpperCase()}',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: _green, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                              ),
                              const SizedBox(height: 5),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: tierProgress(h.radius),
                                  minHeight: 4,
                                  backgroundColor: Colors.white.fade(0.1),
                                  color: _purple,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'NEXT: ${next.toUpperCase()}',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 1.5),
                              ),
                            ],
                          ),
                        ),
                        if (h.starving) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'EVAPORATING — EAT SOMETHING!',
                            style: TextStyle(color: _purple, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                IgnorePointer(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      '${h.eaten}\nEATEN',
                      style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w900, fontSize: 12),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    onPressed: onPause,
                    icon: const Icon(Icons.pause_rounded, color: Colors.white70, size: 30),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// "You grew!" card with a true fact about the things you can now eat.
class _TierCard extends StatelessWidget {
  const _TierCard({super.key, required this.tier});

  final int tier;

  @override
  Widget build(BuildContext context) {
    final info = tierInfo(tier);
    return SafeArea(
      child: Align(
        alignment: const Alignment(0, 0.55),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutBack,
          builder: (context, t, child) => Opacity(
            opacity: t.clamp(0.0, 1.0).toDouble(),
            child: Transform.scale(scale: 0.85 + 0.15 * t, child: child),
          ),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 18),
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: AppColors.panel,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _purple.fade(0.6)),
              boxShadow: [BoxShadow(color: _purple.fade(0.3), blurRadius: 24)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'YOU GREW!  NOW YOU CAN EAT',
                  style: TextStyle(color: _green, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2),
                ),
                const SizedBox(height: 2),
                Text(tierName(tier), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                if (!info.real || tier >= sizeTiers.length)
                  const Text(
                    'IMAGINATION',
                    style: TextStyle(color: _purple, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 2),
                  ),
                Text(
                  tier >= sizeTiers.length
                      ? 'Universe after universe, each one bigger than the last. How far can you go?'
                      : info.fact,
                  style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Shell extends StatelessWidget {
  const _Shell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.fade(0.55),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 26),
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
            decoration: BoxDecoration(
              color: AppColors.panel,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: _purple.fade(0.3)),
              boxShadow: [BoxShadow(color: _purple.fade(0.15), blurRadius: 40)],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _GameOver extends StatelessWidget {
  const _GameOver({required this.result, required this.onRetry, required this.onHome});

  final _Result result;
  final VoidCallback onRetry;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final best = context.read<ProgressCubit>().state.holeBestRadius;
    final evaporated = result.death == HoleDeath.evaporated;
    return _Shell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            evaporated ? 'EVAPORATED' : 'SWALLOWED',
            style: TextStyle(
              color: evaporated ? _purple : AppColors.danger,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            formatLength(result.maxRadius * 2),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              shadows: [Shadow(color: _purple.fade(0.7), blurRadius: 22)],
            ),
          ),
          Text(
            comparisonFor(result.maxRadius * 2),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (result.isNewBest)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(14)),
              child: const Text(
                'BIGGEST EVER!',
                style: TextStyle(color: AppColors.background, fontWeight: FontWeight.w900, letterSpacing: 3),
              ),
            )
          else
            Text(
              'BEST  ${formatLength(best * 2)}',
              style: const TextStyle(color: AppColors.textDim, letterSpacing: 2, fontWeight: FontWeight.w700),
            ),
          const SizedBox(height: 14),
          Text(
            'Reached: ${tierName(result.tier)}  ·  ${result.eaten} things eaten',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _purple.fade(0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _purple.fade(0.3)),
            ),
            child: Text(
              evaporated
                  ? 'Real science: Stephen Hawking predicted that black holes slowly evaporate, and the '
                      'smaller they are, the faster they fade. Keep eating to stay ahead!'
                  : 'You touched something more than twice your size. Red rings mean danger; '
                      'pulsing red means it can swallow you.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4),
            ),
          ),
          const SizedBox(height: 14),
          StardustBadge(amount: result.stardust, prefix: '+'),
          const SizedBox(height: 22),
          GlowButton(label: 'TRY AGAIN', icon: Icons.replay_rounded, color: _purple, onPressed: onRetry),
          const SizedBox(height: 14),
          GlowButton(label: 'HOME', filled: false, onPressed: onHome),
        ],
      ),
    );
  }
}
