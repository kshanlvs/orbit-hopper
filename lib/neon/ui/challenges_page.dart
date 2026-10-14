import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../progression/catalog.dart';
import '../progression/neon_cubit.dart';
import '../progression/profile.dart';
import 'neon_routes.dart';
import 'neon_style.dart';

/// Daily seeded challenge, personal-best milestones and achievements.
class NeonChallengesPage extends StatelessWidget {
  const NeonChallengesPage({super.key});

  static const _skillChallenges = {'no_dash_3000', 'chain_x10', 'risk_taker', 'escape_chase'};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<NeonCubit, NeonProfile>(
        builder: (context, p) {
          final cubit = context.read<NeonCubit>();
          final daily = cubit.today;
          final done = cubit.dailyDoneToday;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 8,
                    child: ListView(
                      children: [
                        Row(
                          children: [
                            NeonIconButton(
                                icon: Icons.arrow_back_rounded, tooltip: 'Back', size: 40, onTap: () => context.pop()),
                            const SizedBox(width: 12),
                            Text('GOALS', style: NeonText.glow(20, NeonColors.gold, spacing: 4)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        NeonPanel(
                          color: NeonColors.gold,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('DAILY CHALLENGE · ${daily.date}',
                                  style: NeonText.glow(13, NeonColors.gold, spacing: 2)),
                              const SizedBox(height: 6),
                              Text(
                                'Everyone gets the same corridor today. Score ${formatInt(daily.target)} '
                                'for +${NeonCatalog.dailyReward} energy.',
                                style: NeonText.body(13),
                              ),
                              const SizedBox(height: 8),
                              _Bar(
                                  value: daily.target == 0 ? 0 : cubit.dailyBestToday / daily.target,
                                  color: NeonColors.gold),
                              const SizedBox(height: 4),
                              Text(
                                done
                                    ? 'Completed  ·  best ${formatInt(cubit.dailyBestToday)}'
                                    : 'Best today: ${formatInt(cubit.dailyBestToday)}',
                                style: NeonText.body(12, color: done ? NeonColors.cyan : NeonColors.dim),
                              ),
                              const SizedBox(height: 10),
                              NeonButton(
                                label: done ? 'PLAY AGAIN' : 'PLAY DAILY',
                                icon: Icons.play_arrow_rounded,
                                color: NeonColors.gold,
                                filled: !done,
                                onTap: () => context.push(NeonRoutes.daily),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        NeonPanel(
                          color: NeonColors.violet,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('PERSONAL BEST', style: NeonText.glow(13, NeonColors.violet, spacing: 2)),
                              const SizedBox(height: 8),
                              for (var i = 0; i < NeonCatalog.bestTiers.length; i++)
                                _TierRow(
                                  tier: NeonCatalog.bestTiers[i],
                                  reward: NeonCatalog.bestTierRewards[i],
                                  best: p.best,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 10,
                    child: NeonPanel(
                      color: NeonColors.cyan,
                      child: ListView(
                        children: [
                          Text('SKILL CHALLENGES', style: NeonText.glow(13, NeonColors.magenta, spacing: 2)),
                          const SizedBox(height: 6),
                          for (final a in NeonCatalog.achievements.where((a) => _skillChallenges.contains(a.id)))
                            _AchievementRow(a: a, done: p.achievements.contains(a.id)),
                          const SizedBox(height: 12),
                          Text(
                            'ACHIEVEMENTS  ${p.achievements.length}/${NeonCatalog.achievements.length}',
                            style: NeonText.glow(13, NeonColors.cyan, spacing: 2),
                          ),
                          const SizedBox(height: 6),
                          for (final a in NeonCatalog.achievements.where((a) => !_skillChallenges.contains(a.id)))
                            _AchievementRow(a: a, done: p.achievements.contains(a.id)),
                          const SizedBox(height: 10),
                          Text(
                            'Lifetime: ${formatInt(p.lifetimeDistance)} m  ·  ${formatInt(p.runs)} runs',
                            style: NeonText.body(12, color: NeonColors.dim),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 6,
      decoration: BoxDecoration(color: const Color(0xFF231C40), borderRadius: BorderRadius.circular(3)),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: value.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            boxShadow: [BoxShadow(color: color.withAlpha(120), blurRadius: 6)],
          ),
        ),
      ),
    );
  }
}

class _TierRow extends StatelessWidget {
  const _TierRow({required this.tier, required this.reward, required this.best});

  final int tier;
  final int reward;
  final int best;

  @override
  Widget build(BuildContext context) {
    final done = best >= tier;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
              color: done ? NeonColors.cyan : NeonColors.dim, size: 18),
          const SizedBox(width: 8),
          SizedBox(width: 64, child: Text(formatInt(tier), style: NeonText.body(13, weight: FontWeight.w800))),
          Expanded(child: _Bar(value: best / tier, color: done ? NeonColors.cyan : NeonColors.violet)),
          const SizedBox(width: 8),
          _Energy(reward),
        ],
      ),
    );
  }
}

class _AchievementRow extends StatelessWidget {
  const _AchievementRow({required this.a, required this.done});

  final Achievement a;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            done ? Icons.emoji_events_rounded : Icons.lock_outline_rounded,
            color: done ? NeonColors.gold : NeonColors.dim,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.title,
                    style: NeonText.body(14, weight: FontWeight.w800, color: done ? NeonColors.text : NeonColors.dim)),
                Text(a.description, style: NeonText.body(12, color: NeonColors.dim)),
              ],
            ),
          ),
          done ? Text('DONE', style: NeonText.body(12, color: NeonColors.cyan)) : _Energy(a.reward),
        ],
      ),
    );
  }
}

class _Energy extends StatelessWidget {
  const _Energy(this.amount);

  final int amount;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.diamond, color: NeonColors.dim, size: 12),
        const SizedBox(width: 3),
        Text('$amount', style: NeonText.body(12, color: NeonColors.dim)),
      ],
    );
  }
}
