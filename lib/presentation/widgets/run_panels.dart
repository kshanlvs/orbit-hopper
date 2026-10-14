import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme/app_theme.dart';
import '../../game/logic/cosmos.dart';
import '../progress/progress_cubit.dart';
import '../run/run_cubit.dart';
import 'glow_button.dart';
import 'missions_view.dart';
import 'stardust_badge.dart';

class _PanelShell extends StatelessWidget {
  const _PanelShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.fade(0.55),
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutBack,
          builder: (context, t, child) => Opacity(
            opacity: t.clamp(0.0, 1.0).toDouble(),
            child: Transform.scale(scale: 0.85 + 0.15 * t, child: child),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 28),
            padding: const EdgeInsets.fromLTRB(24, 30, 24, 26),
            decoration: BoxDecoration(
              color: AppColors.panel,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.accent.fade(0.25)),
              boxShadow: [BoxShadow(color: AppColors.accent.fade(0.15), blurRadius: 40)],
            ),
            child: child,
          ),
          ),
        ),
      ),
    );
  }
}

class PausePanel extends StatelessWidget {
  const PausePanel({super.key, required this.onResume, required this.onHome});

  final VoidCallback onResume;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    return _PanelShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'PAUSED',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 6),
          ),
          const SizedBox(height: 20),
          Builder(
            builder: (context) => MissionsList(missions: context.read<ProgressCubit>().state.missions),
          ),
          const SizedBox(height: 16),
          GlowButton(label: 'RESUME', icon: Icons.play_arrow_rounded, onPressed: onResume),
          const SizedBox(height: 14),
          GlowButton(label: 'HOME', filled: false, onPressed: onHome),
        ],
      ),
    );
  }
}

class GameOverPanel extends StatelessWidget {
  const GameOverPanel({
    super.key,
    required this.state,
    required this.onRetry,
    required this.onHome,
  });

  final RunState state;
  final VoidCallback onRetry;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    return _PanelShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            state.deathReason.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.danger,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${state.score}',
            style: TextStyle(
              fontSize: 76,
              fontWeight: FontWeight.w900,
              height: 1,
              shadows: [Shadow(color: AppColors.accent.fade(0.7), blurRadius: 24)],
            ),
          ),
          const SizedBox(height: 8),
          if (state.isNewBest)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: AppColors.gold.fade(0.6), blurRadius: 18)],
              ),
              child: const Text(
                'NEW BEST!',
                style: TextStyle(
                  color: AppColors.background,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
              ),
            )
          else
            Text(
              'BEST  ${state.bestScore}',
              style: const TextStyle(color: AppColors.textDim, letterSpacing: 3, fontWeight: FontWeight.w700),
            ),
          const SizedBox(height: 16),
          Text(
            _reachedLabel(state.bestIndex),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 2),
          ),
          const SizedBox(height: 2),
          Text(
            Cosmos.distanceLabelAt(state.bestIndex),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700),
          ),
          _SoClose(bestIndex: state.bestIndex),
          const SizedBox(height: 14),
          if (state.missionsDone.isNotEmpty) ...[
            MissionsList(missions: state.missionsDone, done: state.missionsDone, title: 'MISSIONS COMPLETED'),
            const SizedBox(height: 6),
          ] else ...[
            Builder(
              builder: (context) => MissionsList(
                missions: context.read<ProgressCubit>().state.missions,
                title: 'YOUR MISSIONS',
              ),
            ),
            const SizedBox(height: 6),
          ],
          StardustBadge(amount: state.earnedStardust, prefix: '+'),
          const SizedBox(height: 24),
          Builder(builder: (context) {
            final from = context.read<ProgressCubit>().launchIndex;
            return GlowButton(
              label: from == 0 ? 'RETRY' : 'FROM ${journey[from].name.toUpperCase()}',
              icon: Icons.replay_rounded,
              width: 270,
              onPressed: onRetry,
            );
          }),
          const SizedBox(height: 14),
          GlowButton(label: 'HOME', filled: false, onPressed: onHome),
        ],
      ),
    );
  }
}

/// "You were 2 hops from something unknown…" — the reason to try again.
class _SoClose extends StatelessWidget {
  const _SoClose({required this.bestIndex});

  final int bestIndex;

  @override
  Widget build(BuildContext context) {
    final next = Cosmos.nextLandmark(bestIndex);
    if (next == null) return const SizedBox(height: 4);
    final k = journey.indexOf(next);
    final known = context.read<ProgressCubit>().isDiscovered(k);
    final hops = k * hopsPerLandmark - bestIndex;
    const signal = Color(0xFF7CF5FF);
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: signal.fade(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: signal.fade(0.3)),
      ),
      child: Column(
        children: [
          Text(
            known
                ? '${hops == 1 ? '1 hop' : '$hops hops'} from ${next.name}'
                : 'Only ${hops == 1 ? '1 hop' : '$hops hops'} from an unknown object',
            textAlign: TextAlign.center,
            style: const TextStyle(color: signal, fontWeight: FontWeight.w800, fontSize: 13),
          ),
          if (!known) ...[
            const SizedBox(height: 4),
            Text(
              '"${next.teaser}"',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic, fontSize: 12.5),
            ),
          ],
        ],
      ),
    );
  }
}

String _reachedLabel(int bestIndex) {
  if (bestIndex == 0) return 'STILL AT THE SUN';
  final last = journey[Cosmos.lastLandmarkBefore(bestIndex)].name.toUpperCase();
  return Cosmos.landmarkAt(bestIndex) != null ? 'REACHED $last' : 'BEYOND $last';
}
