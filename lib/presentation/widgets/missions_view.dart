import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/mission.dart';
import '../../domain/entities/player_progress.dart';
import '../progress/progress_cubit.dart';
import '../run/run_cubit.dart';

/// A list of missions; ones in [done] show a green check.
class MissionsList extends StatelessWidget {
  const MissionsList({super.key, required this.missions, this.done = const <Mission>[], this.title = 'MISSIONS'});

  final List<Mission> missions;
  final List<Mission> done;
  final String title;

  @override
  Widget build(BuildContext context) {
    final doneKeys = {for (final m in done) m.encode()};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: const TextStyle(color: AppColors.textDim, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2.5),
        ),
        const SizedBox(height: 8),
        for (final m in missions) _MissionRow(mission: m, done: doneKeys.contains(m.encode())),
      ],
    );
  }
}

class _MissionRow extends StatelessWidget {
  const _MissionRow({required this.mission, required this.done});

  final Mission mission;
  final bool done;

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF5CFFB0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 18,
            color: done ? green : Colors.white38,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              mission.description,
              style: TextStyle(
                color: done ? green : Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                decoration: done ? TextDecoration.lineThrough : null,
                decorationColor: green,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '+${mission.reward} ✦',
            style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w800, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

/// Opens the active missions as a bottom sheet (from the home screen).
void showMissionsSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.panel,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => BlocProvider.value(
      value: context.read<ProgressCubit>(),
      child: BlocBuilder<ProgressCubit, PlayerProgress>(
        builder: (context, p) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MissionsList(missions: p.missions, title: 'ACTIVE MISSIONS'),
                const SizedBox(height: 6),
                Text(
                  'Complete a mission during any run to earn its stardust. '
                  'A new, harder one takes its place.  ·  ${p.missionsCompleted} completed so far',
                  style: const TextStyle(color: AppColors.textDim, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// In-game toast that pops up whenever a mission completes.
class MissionToast extends StatefulWidget {
  const MissionToast({super.key});

  @override
  State<MissionToast> createState() => _MissionToastState();
}

class _MissionToastState extends State<MissionToast> {
  Mission? _showing;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<RunCubit, RunState>(
      listenWhen: (a, b) => b.missionsDone.length > a.missionsDone.length,
      listener: (context, s) {
        _timer?.cancel();
        setState(() => _showing = s.missionsDone.last);
        _timer = Timer(const Duration(milliseconds: 3200), () {
          if (mounted) setState(() => _showing = null);
        });
      },
      child: IgnorePointer(
        child: SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 96, left: 16, right: 16),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: Tween(begin: 0.8, end: 1.0).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutBack)),
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: _showing == null
                    ? const SizedBox.shrink()
                    : Container(
                        key: ValueKey(_showing!.encode()),
                        constraints: const BoxConstraints(maxWidth: 400),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.panel,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF5CFFB0).fade(0.6)),
                          boxShadow: [BoxShadow(color: const Color(0xFF5CFFB0).fade(0.25), blurRadius: 20)],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF5CFFB0), size: 22),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'MISSION COMPLETE',
                                    style: TextStyle(
                                      color: Color(0xFF5CFFB0),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                  Text(
                                    _showing!.description,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '+${_showing!.reward} ✦',
                              style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900),
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
}
