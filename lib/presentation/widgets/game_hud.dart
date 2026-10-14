import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme/app_theme.dart';
import '../../game/logic/cosmos.dart';
import '../progress/progress_cubit.dart';
import '../run/run_cubit.dart';
import 'defense_widgets.dart';
import 'stardust_badge.dart';

/// Score, combo, stardust and pause button drawn over the game.
/// Non-interactive parts are wrapped in IgnorePointer so taps reach the game.
class GameHud extends StatelessWidget {
  const GameHud({super.key, required this.onPause});

  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Stack(
          children: [
            IgnorePointer(
              child: Align(
                alignment: Alignment.topCenter,
                child: BlocBuilder<RunCubit, RunState>(
                  buildWhen: (a, b) => a.score != b.score || a.combo != b.combo,
                  builder: (context, s) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        transitionBuilder: (child, anim) =>
                            ScaleTransition(scale: Tween(begin: 1.4, end: 1.0).animate(anim), child: child),
                        child: Text(
                          '${s.score}',
                          key: ValueKey(s.score),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 56,
                            fontWeight: FontWeight.w900,
                            shadows: [Shadow(color: AppColors.accent.fade(0.7), blurRadius: 20)],
                          ),
                        ),
                      ),
                      AnimatedOpacity(
                        opacity: s.combo > 1 ? 1 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.gold.fade(0.15),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.gold.fade(0.6)),
                          ),
                          child: Text(
                            'COMBO ×${s.combo}',
                            style: const TextStyle(
                              color: AppColors.gold,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IgnorePointer(
              child: Align(
                alignment: Alignment.topLeft,
                child: BlocBuilder<RunCubit, RunState>(
                  buildWhen: (a, b) => a.stardust != b.stardust,
                  builder: (context, s) => StardustBadge(amount: s.stardust),
                ),
              ),
            ),
            IgnorePointer(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: BlocBuilder<RunCubit, RunState>(
                  buildWhen: (a, b) => a.travelIndex != b.travelIndex || a.defense != b.defense,
                  builder: (context, s) {
                    final d = s.defense;
                    return d != null ? DefenseStrip(defense: d) : _JourneyStrip(travelIndex: s.travelIndex);
                  },
                ),
              ),
            ),
            Align(
              alignment: Alignment.topRight,
              child: BlocBuilder<RunCubit, RunState>(
                buildWhen: (a, b) => a.status != b.status,
                builder: (context, s) => s.status == RunStatus.playing
                    ? IconButton(
                        onPressed: onPause,
                        icon: const Icon(Icons.pause_rounded, color: Colors.white70, size: 30),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom strip: live distance from the Sun (ticks up during flight) and
/// progress to the next real place — named only once you have found it.
class _JourneyStrip extends StatelessWidget {
  const _JourneyStrip({required this.travelIndex});

  final double travelIndex;

  @override
  Widget build(BuildContext context) {
    final index = travelIndex.floor();
    final Landmark? next = Cosmos.nextLandmark(index);
    final nextIndex = index ~/ hopsPerLandmark + 1;
    final known = context.read<ProgressCubit>().isDiscovered(nextIndex);
    final base = Cosmos.lastLandmarkBefore(index) * hopsPerLandmark;
    final progress = ((travelIndex - base) / hopsPerLandmark).clamp(0.0, 1.0).toDouble();
    const signal = Color(0xFF7CF5FF);
    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: Colors.black.fade(0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.fade(0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.wb_sunny_rounded, size: 14, color: AppColors.gold),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  Cosmos.distanceLabelAt(travelIndex),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Text(
                next == null
                    ? 'UNCHARTED'
                    : known
                        ? 'NEXT: ${next.name.toUpperCase()}'
                        : 'NEXT: ???',
                style: TextStyle(
                  color: known || next == null ? AppColors.accent : signal,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: next == null ? 1.0 : progress,
              minHeight: 5,
              backgroundColor: Colors.white.fade(0.1),
              valueColor: AlwaysStoppedAnimation(known || next == null ? AppColors.accent : signal),
            ),
          ),
        ],
      ),
    );
  }
}
