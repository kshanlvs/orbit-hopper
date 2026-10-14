import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme/app_theme.dart';
import '../run/run_cubit.dart';

const _red = Color(0xFFFF4D6D);
const _orange = Color(0xFFFF8A3D);

/// Mission briefing shown before the first launch in "Save Earth" mode.
class DefenseBriefing extends StatelessWidget {
  const DefenseBriefing({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RunCubit, RunState>(
      buildWhen: (a, b) => a.defense?.started != b.defense?.started || a.status != b.status,
      builder: (context, s) {
        final d = s.defense;
        final show = d != null && !d.started && s.status == RunStatus.playing;
        return IgnorePointer(
          child: AnimatedOpacity(
            opacity: show ? 1 : 0,
            duration: const Duration(milliseconds: 300),
            child: SafeArea(
              child: Align(
                alignment: const Alignment(0, -0.55),
                child: d == null
                    ? const SizedBox.shrink()
                    : Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        constraints: const BoxConstraints(maxWidth: 420),
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                        decoration: BoxDecoration(
                          color: AppColors.panel,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _red.fade(0.6)),
                          boxShadow: [BoxShadow(color: _red.fade(0.25), blurRadius: 28)],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, color: _red, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'THREAT LEVEL ${d.level}',
                                  style: const TextStyle(
                                    color: _red,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2.5,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Asteroid on collision course with Earth!',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '1.  Hop between planets to build charge (PERFECT = double).\n'
                              '2.  At full charge (${d.needed}), the asteroid appears.\n'
                              '3.  Ram it before the timer hits zero!',
                              style: const TextStyle(color: Colors.white70, height: 1.5, fontSize: 13.5),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'IMPACT IN ${_clock(d.timeLeft)}  ·  TAP TO LAUNCH',
                              style: const TextStyle(
                                color: _orange,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Bottom HUD in "Save Earth" mode: countdown + charge bar.
class DefenseStrip extends StatelessWidget {
  const DefenseStrip({super.key, required this.defense});

  final DefenseSnapshot defense;

  @override
  Widget build(BuildContext context) {
    final d = defense;
    final urgent = d.timeLeft < 10 && !d.won;
    final status = d.won
        ? 'ASTEROID DEFLECTED!'
        : d.killerActive
            ? 'INTERCEPT THE ASTEROID!'
            : 'CHARGE ${d.charge}/${d.needed}';
    final color = d.won
        ? AppColors.gold
        : d.killerActive
            ? _orange
            : AppColors.accent;
    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: Colors.black.fade(0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: (urgent ? _red : Colors.white).fade(urgent ? 0.7 : 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.public_rounded, size: 16, color: urgent ? _red : const Color(0xFF2E7BFF)),
              const SizedBox(width: 6),
              Text(
                d.won ? 'EARTH IS SAFE' : 'IMPACT IN ${_clock(d.timeLeft)}',
                style: TextStyle(
                  color: d.won ? AppColors.gold : (urgent ? _red : Colors.white),
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 1.2,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const Spacer(),
              Text(
                status,
                style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.5),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: d.needed == 0 ? 1.0 : (d.charge / d.needed).clamp(0.0, 1.0).toDouble(),
              minHeight: 6,
              backgroundColor: Colors.white.fade(0.1),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}

String _clock(double seconds) {
  final s = seconds.ceil().clamp(0, 5999);
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}
