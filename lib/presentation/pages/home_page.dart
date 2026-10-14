import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/comet_skin.dart';
import '../../domain/entities/player_progress.dart';
import '../../game/audio/game_audio.dart';
import '../../game/logic/cosmos.dart';
import '../../game/render/sprites.dart';
import '../../game/render/starfield.dart';
import '../progress/progress_cubit.dart';
import '../widgets/glow_button.dart';
import '../widgets/missions_view.dart';
import '../widgets/stardust_badge.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
  final Stopwatch _clock = Stopwatch()..start();
  Starfield? _stars;
  Size? _starsSize;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          if (_starsSize != size) {
            _stars = Starfield(width: size.width, height: size.height, seed: 7);
            _starsSize = size;
          }
          return Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => CustomPaint(
                    painter: _BackdropPainter(_stars!, _clock.elapsedMilliseconds / 1000),
                  ),
                ),
              ),
              SafeArea(
                child: BlocBuilder<ProgressCubit, PlayerProgress>(
                  builder: (context, progress) => _content(context, progress, compact: size.height < 760),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _content(BuildContext context, PlayerProgress progress, {required bool compact}) {
    final skin = CometSkins.byId(progress.selectedSkinId);
    final cubit = context.read<ProgressCubit>();
    final launch = cubit.launchIndex;
    // The journey never ends, so there is always a next unknown place.
    var unknown = launch + 1;
    while (cubit.isDiscovered(unknown)) {
      unknown++;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      cubit.rank.toUpperCase(),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'BEST ${progress.bestScore}  ·  🌍 ${progress.discoveredIds.where((id) => !id.startsWith('beyond_')).length}/$realPlaces',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textDim,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StardustBadge(amount: progress.stardust),
                  IconButton(
                    tooltip: progress.soundOn ? 'Mute' : 'Sound on',
                    onPressed: () => context.read<ProgressCubit>().toggleSound(),
                    icon: Icon(
                      progress.soundOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                      color: progress.soundOn ? Colors.white70 : AppColors.textDim,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(flex: 2),
          const _Title(),
          if (!compact) ...[
            const SizedBox(height: 10),
            const Text(
              'Fly from the Sun to the edge of the universe.\nLand on real planets, stars and galaxies.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textDim, height: 1.5),
            ),
          ],
          const Spacer(),
          SizedBox(
            height: compact ? 116 : 160,
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => CustomPaint(
                  size: Size(double.infinity, compact ? 116 : 160),
                  painter: _HeroPainter(
                    _clock.elapsedMilliseconds / 1000,
                    Color(skin.argb),
                    skin.rainbow,
                    Cosmos.place(launch).look,
                    launch,
                  ),
                ),
              ),
            ),
          ),
          Text(
            launch == 0 ? 'ORBITING THE SUN' : 'ORBITING ${Cosmos.place(launch).name.toUpperCase()}',
            style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2.5),
          ),
          ...[
            const SizedBox(height: 10),
            Text(
              'INCOMING SIGNAL',
              style: const TextStyle(
                  color: Color(0xFF7CF5FF), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2.5),
            ),
            const SizedBox(height: 3),
            Text(
              '"${Cosmos.place(unknown).teaser}"',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFB8F9FF), fontStyle: FontStyle.italic, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Builder(builder: (context) {
              final (chapter, left) = Cosmos.nextChapter(cubit.furthestDiscovered);
              return Text(
                '📡 SIGNAL ${cubit.fragmentsDecoded}/$signalFragments  ·  🏁 ${chapter.title} ($left to go)',
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white60, fontSize: 11.5, fontWeight: FontWeight.w700),
              );
            }),
          ],
          const Spacer(),
          GlowButton(
            label: launch == 0 ? 'PLAY' : 'CONTINUE',
            icon: Icons.play_arrow_rounded,
            width: 290,
            onPressed: () => context.push(AppRoutes.play),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: 290,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _ModeTile(
                  title: 'SAVE EARTH',
                  subtitle: 'THREAT LV ${progress.defenseLevel}',
                  icon: Icons.public_rounded,
                  color: AppColors.danger,
                  pulse: true,
                  onTap: () => context.push(AppRoutes.defense),
                ),
                _ModeTile(
                  title: 'NEON SHIFT',
                  subtitle: 'NEW ARCADE GAME',
                  icon: Icons.bolt_rounded,
                  color: const Color(0xFFFF3DCB),
                  badge: 'NEW',
                  onTap: () => context.push(AppRoutes.neon),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: 290,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GlowButton(
                  label: 'STAR MAP',
                  filled: false,
                  width: 140,
                  onPressed: () => context.push(AppRoutes.journey),
                ),
                GlowButton(
                  label: 'COMETS',
                  filled: false,
                  color: AppColors.gold,
                  width: 140,
                  onPressed: () => context.push(AppRoutes.skins),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _MissionsChip(progress: progress),
          const Spacer(),
        ],
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: Colors.white,
      fontSize: 52,
      fontWeight: FontWeight.w900,
      letterSpacing: 6,
      height: 1,
    );
    return ShaderMask(
      shaderCallback: (rect) => const LinearGradient(
        colors: [AppColors.accent, Color(0xFFC77DFF), Color(0xFFFF6B9D)],
      ).createShader(rect),
      child: const Column(
        children: [
          Text('ORBIT', style: style),
          Text('HOPPER', style: style),
        ],
      ),
    );
  }
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter(this.stars, this.time);

  final Starfield stars;
  final double time;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, size.height),
          const [Color(0xFF060A1C), Color(0xFF1A0B3A)],
        ),
    );
    stars.render(canvas, -time * 30, time);
  }

  @override
  bool shouldRepaint(_BackdropPainter old) => old.time != time;
}

/// Planet with a comet orbiting it — the menu's living logo.
class _HeroPainter extends CustomPainter {
  _HeroPainter(this.time, this.color, this.rainbow, this.look, this.seed);

  final double time;
  final Color color;
  final bool rainbow;
  final BodyLook look;
  final int seed;

  Color _cometColor(double offset) => rainbow
      ? HSVColor.fromAHSV(1, (time * 140 + offset * 220) % 360, 0.65, 1).toColor()
      : color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.height * 0.21;
    final orbit = size.height * 0.41;

    canvas.drawCircle(
      c,
      orbit,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = AppColors.accent.fade(0.25),
    );
    BodySprites.draw(canvas, c, r, look, time, seed: seed);

    final angle = time * 2.6;
    final trail = Paint()..strokeCap = StrokeCap.round;
    const steps = 18;
    for (var i = steps; i > 0; i--) {
      final a1 = angle - i * 0.045;
      final a0 = a1 - 0.045;
      final k = 1 - i / steps;
      trail
        ..color = _cometColor(1 - k).fade(k * 0.85)
        ..strokeWidth = 14 * k;
      canvas.drawLine(
        c + Offset(math.cos(a0), math.sin(a0)) * orbit,
        c + Offset(math.cos(a1), math.sin(a1)) * orbit,
        trail,
      );
    }
    final pos = c + Offset(math.cos(angle), math.sin(angle)) * orbit;
    final cometColor = _cometColor(0);
    GlowSprites.draw(canvas, pos, 22, cometColor, opacity: 0.85);
    canvas.drawCircle(pos, 7, Paint()..color = cometColor);
    canvas.drawCircle(pos, 3.5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_HeroPainter old) => old.time != time || old.color != color;
}

/// Compact "3 missions · up to +150 ✦" entry that opens the missions sheet.
class _MissionsChip extends StatelessWidget {
  const _MissionsChip({required this.progress});

  final PlayerProgress progress;

  @override
  Widget build(BuildContext context) {
    final total = progress.missions.fold<int>(0, (sum, m) => sum + m.reward);
    return GestureDetector(
      onTap: () => showMissionsSheet(context),
      child: Container(
        width: 290,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: const Color(0xFF5CFFB0).fade(0.07),
          border: Border.all(color: const Color(0xFF5CFFB0).fade(0.45)),
        ),
        child: Row(
          children: [
            const Icon(Icons.flag_rounded, color: Color(0xFF5CFFB0), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${progress.missions.length} MISSIONS',
                style: const TextStyle(
                  color: Color(0xFF5CFFB0),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  fontSize: 13,
                ),
              ),
            ),
            Text(
              '+$total ✦',
              style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w800),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}

/// A compact game-mode button: title, subtitle and an optional badge.
class _ModeTile extends StatefulWidget {
  const _ModeTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.badge,
    this.pulse = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? badge;
  final bool pulse;

  @override
  State<_ModeTile> createState() => _ModeTileState();
}

class _ModeTileState extends State<_ModeTile> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.color;
    return GestureDetector(
      onTap: () {
        GameAudio.instance.play(Sfx.uiTap);
        widget.onTap();
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, child) => Container(
              width: 140,
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: c.fade(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: c.fade(0.75), width: 1.6),
                boxShadow: [
                  BoxShadow(color: c.fade(widget.pulse ? 0.15 + 0.25 * _pulse.value : 0.2), blurRadius: 18),
                ],
              ),
              child: child,
            ),
            child: Row(
              children: [
                Icon(widget.icon, color: c, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(color: c, fontWeight: FontWeight.w900, fontSize: 13.5, letterSpacing: 1),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 9.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (widget.badge != null)
            Positioned(
              right: -4,
              top: -9,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(9)),
                child: Text(
                  widget.badge!,
                  style: const TextStyle(
                      color: AppColors.background, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 1),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
