import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../audio/neon_audio.dart';
import '../progression/catalog.dart';
import '../progression/neon_cubit.dart';
import '../progression/profile.dart';
import 'neon_routes.dart';
import 'neon_style.dart';

class NeonMenuPage extends StatelessWidget {
  const NeonMenuPage({super.key, this.exitTo});

  final String? exitTo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<NeonCubit, NeonProfile>(
        builder: (context, p) {
          final cubit = context.read<NeonCubit>();
          final daily = cubit.today;
          return NeonBackdrop(
            reduced: p.settings.reducedEffects,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 11,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (exitTo != null)
                            NeonIconButton(
                              icon: Icons.arrow_back_rounded,
                              tooltip: 'Back',
                              size: 40,
                              onTap: () => context.go(exitTo!),
                            )
                          else
                            const SizedBox(height: 40),
                          const Spacer(),
                          _Logo(reduced: p.settings.reducedEffects),
                          const SizedBox(height: 6),
                          Text(
                            'One tap. Flip gravity. Survive the shift.',
                            style: NeonText.body(14, color: NeonColors.dim),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Spacer(),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                NeonButton(
                                  label: 'PLAY',
                                  icon: Icons.play_arrow_rounded,
                                  big: true,
                                  filled: true,
                                  onTap: () => context.push(NeonRoutes.play),
                                ),
                                const SizedBox(width: 22),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('BEST', style: NeonText.label),
                                    Text(formatInt(p.best), style: NeonText.glow(24, NeonColors.gold, spacing: 1)),
                                  ],
                                ),
                                const SizedBox(width: 22),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('ENERGY', style: NeonText.label),
                                    EnergyChip(amount: p.energy, size: 20),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 8,
                      child: Center(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _DailyCard(
                                target: daily.target,
                                best: cubit.dailyBestToday,
                                done: cubit.dailyDoneToday,
                                onPlay: () => context.push(NeonRoutes.daily),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _Tile(
                                      icon: Icons.auto_awesome,
                                      label: 'LAB',
                                      color: NeonColors.magenta,
                                      onTap: () => context.push(NeonRoutes.lab),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _Tile(
                                      icon: Icons.emoji_events_rounded,
                                      label: 'GOALS',
                                      color: NeonColors.gold,
                                      badge: '${p.achievements.length}/${NeonCatalog.achievements.length}',
                                      onTap: () => context.push(NeonRoutes.challenges),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _Tile(
                                      icon: Icons.tune_rounded,
                                      label: 'SETTINGS',
                                      color: NeonColors.cyan,
                                      onTap: () => context.push(NeonRoutes.settings),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Dimension: ${NeonCatalog.dimension(p.dimension).name}   ·   Runs: ${formatInt(p.runs)}',
                                textAlign: TextAlign.center,
                                style: NeonText.body(12, color: NeonColors.dim),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// "NEON" flickers like a tube sign; "SHIFT" flips upside down now and
/// then — the whole game in one logo.
class _Logo extends StatefulWidget {
  const _Logo({required this.reduced});

  final bool reduced;

  @override
  State<_Logo> createState() => _LogoState();
}

class _LogoState extends State<_Logo> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final size = math.min(64.0, box.maxWidth / 6.2);
      return AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          var flicker = 1.0;
          if (!widget.reduced && ((t > 0.12 && t < 0.14) || (t > 0.17 && t < 0.18))) flicker = 0.35;
          // Flip "SHIFT" between t=0.55 and 0.75.
          var scaleY = 1.0;
          if (t > 0.55 && t < 0.75) scaleY = math.cos((t - 0.55) / 0.2 * math.pi * 2);
          if (widget.reduced) scaleY = 1;
          return FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Opacity(opacity: flicker, child: Text('NEON', style: NeonText.glow(size, NeonColors.cyan, spacing: 6))),
                SizedBox(width: size * 0.3),
                Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.diagonal3Values(1, scaleY.abs() < 0.08 ? (scaleY >= 0 ? 0.08 : -0.08) : scaleY, 1),
                  child: Text('SHIFT', style: NeonText.glow(size, NeonColors.magenta, spacing: 6)),
                ),
              ],
            ),
          );
        },
      );
    });
  }
}

class _DailyCard extends StatelessWidget {
  const _DailyCard({required this.target, required this.best, required this.done, required this.onPlay});

  final int target;
  final int best;
  final bool done;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return NeonPanel(
      color: NeonColors.gold,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, color: NeonColors.gold, size: 16),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'DAILY CHALLENGE',
                        style: NeonText.glow(13, NeonColors.gold, spacing: 2),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Same corridor for everyone today.', style: NeonText.body(12, color: NeonColors.dim), maxLines: 2),
                const SizedBox(height: 4),
                Text(
                  done
                      ? 'Completed · best ${formatInt(best)}'
                      : 'Score ${formatInt(target)}  ·  +${NeonCatalog.dailyReward} energy',
                  style: NeonText.body(13, color: done ? NeonColors.cyan : NeonColors.text),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          NeonButton(label: done ? 'AGAIN' : 'GO', color: NeonColors.gold, onTap: onPlay),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.label, required this.color, required this.onTap, this.badge});

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          NeonAudio.instance.play(NeonSfx.ui);
          NeonAudio.instance.tapHaptic();
          onTap();
        },
        child: NeonPanel(
          color: color,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 6),
              FittedBox(child: Text(label, style: NeonText.glow(13, NeonColors.text, spacing: 2))),
              if (badge != null) ...[
                const SizedBox(height: 2),
                Text(badge!, style: NeonText.body(11, color: NeonColors.dim)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
