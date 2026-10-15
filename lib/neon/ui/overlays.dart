import 'package:flutter/material.dart';

import '../engine/neon_world.dart';
import '../progression/profile.dart';
import '../progression/rules.dart';
import 'neon_style.dart';

class NeonGameOver extends StatelessWidget {
  const NeonGameOver({
    super.key,
    required this.run,
    required this.reward,
    required this.best,
    required this.onRetry,
    required this.onMenu,
    this.dailyTarget,
  });

  final RunSummary run;
  final RunReward? reward;
  final int best;
  final VoidCallback onRetry;
  final VoidCallback onMenu;
  final int? dailyTarget;

  @override
  Widget build(BuildContext context) {
    final r = reward;
    final record = r?.newRecord ?? false;
    return ColoredBox(
      color: const Color(0xCC03010A),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.85, end: 1),
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutBack,
                builder: (context, k, child) => Transform.scale(scale: k, child: child),
                child: NeonPanel(
                  color: record ? NeonColors.gold : NeonColors.magenta,
                  glow: 0.6,
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 6,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(run.cause.isEmpty ? 'RUN OVER' : run.cause,
                                style: NeonText.glow(14, NeonColors.magenta, spacing: 4)),
                            const SizedBox(height: 4),
                            const Text('SCORE', style: NeonText.label),
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: run.score.toDouble()),
                              duration: const Duration(milliseconds: 900),
                              curve: Curves.easeOutCubic,
                              builder: (context, v, _) => FittedBox(
                                child:
                                    Text(formatInt(v.round()), style: NeonText.glow(46, NeonColors.text, spacing: 2)),
                              ),
                            ),
                            if (record)
                              const _RecordBadge()
                            else
                              Text('BEST  ${formatInt(best)}', style: NeonText.body(13, color: NeonColors.gold)),
                            if (dailyTarget != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                r?.dailyCompleted ?? false
                                    ? 'DAILY COMPLETE!'
                                    : (run.score >= dailyTarget!
                                        ? 'Daily target reached'
                                        : 'Daily target ${formatInt(dailyTarget!)}'),
                                style: NeonText.body(12, color: NeonColors.gold),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 18,
                              runSpacing: 6,
                              children: [
                                _Stat('DISTANCE', '${formatInt(run.distance)} m'),
                                _Stat('ENERGY', r == null ? '…' : '+${formatInt(r.energy)}'),
                                _Stat('BEST MULTI', 'x${run.bestMultiplier.toStringAsFixed(1)}'),
                                _Stat('NEAR MISSES', '${run.nearMisses}'),
                                _Stat('SHARDS', '${run.shards}'),
                                if (run.escapes > 0) _Stat('ESCAPES', '${run.escapes}'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 5,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            NeonButton(
                                label: 'RETRY', icon: Icons.replay_rounded, big: true, filled: true, onTap: onRetry),
                            const SizedBox(height: 10),
                            NeonButton(
                                label: 'MENU', icon: Icons.home_rounded, color: NeonColors.violet, onTap: onMenu),
                            const SizedBox(height: 10),
                            if (r != null) ..._unlocks(r),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _unlocks(RunReward r) {
    final items = <(IconData, String, Color)>[
      for (final d in r.dimensions) (Icons.blur_on_rounded, 'Dimension unlocked: ${d.name}', NeonColors.cyan),
      for (final a in r.achievements) (Icons.emoji_events_rounded, '${a.title}  +${a.reward}', NeonColors.gold),
      for (final t in r.tiers) (Icons.trending_up_rounded, 'Best ${formatInt(t)} reached', NeonColors.violet),
      if (r.dailyCompleted) (Icons.calendar_today_rounded, 'Daily challenge complete', NeonColors.gold),
    ];
    return [
      for (final (icon, text, color) in items.take(3))
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                  child:
                      Text(text, style: NeonText.body(12, color: color), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      if (items.length > 3) Text('+${items.length - 3} more in Goals', style: NeonText.body(11, color: NeonColors.dim)),
    ];
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: NeonText.label.copyWith(fontSize: 10)),
        Text(value, style: NeonText.body(15, weight: FontWeight.w800)),
      ],
    );
  }
}

class _RecordBadge extends StatefulWidget {
  const _RecordBadge();

  @override
  State<_RecordBadge> createState() => _RecordBadgeState();
}

class _RecordBadgeState extends State<_RecordBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(begin: 0.96, end: 1.06).animate(_c),
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: NeonColors.gold, size: 20),
          const SizedBox(width: 4),
          Text('NEW RECORD', style: NeonText.glow(18, NeonColors.gold, spacing: 3)),
          const SizedBox(width: 4),
          const Icon(Icons.star_rounded, color: NeonColors.gold, size: 20),
        ],
      ),
    );
  }
}

/// Pause menu with the most-used switches right there.
class NeonPauseMenu extends StatelessWidget {
  const NeonPauseMenu({
    super.key,
    required this.settings,
    required this.onResume,
    required this.onRestart,
    required this.onQuit,
    required this.onSettings,
  });

  final NeonSettings settings;
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onQuit;
  final ValueChanged<NeonSettings> onSettings;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xCC03010A),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: NeonPanel(
              color: NeonColors.cyan,
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('PAUSED', style: NeonText.glow(30, NeonColors.cyan, spacing: 6)),
                        const SizedBox(height: 14),
                        NeonButton(
                            label: 'RESUME', icon: Icons.play_arrow_rounded, big: true, filled: true, onTap: onResume),
                        const SizedBox(height: 10),
                        NeonButton(
                            label: 'RESTART', icon: Icons.replay_rounded, color: NeonColors.violet, onTap: onRestart),
                        const SizedBox(height: 10),
                        NeonButton(label: 'QUIT', icon: Icons.home_rounded, color: NeonColors.magenta, onTap: onQuit),
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Toggle('Music', settings.music, (v) => onSettings(settings.copyWith(music: v))),
                        _Toggle('Sound effects', settings.sfx, (v) => onSettings(settings.copyWith(sfx: v))),
                        _Toggle('Haptics', settings.haptics, (v) => onSettings(settings.copyWith(haptics: v))),
                        _Toggle('Reduced effects', settings.reducedEffects,
                            (v) => onSettings(settings.copyWith(reducedEffects: v))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle(this.label, this.value, this.onChanged);

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: NeonText.body(14))),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}
