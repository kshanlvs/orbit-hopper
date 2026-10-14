import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/player_progress.dart';
import '../../game/logic/cosmos.dart';
import '../progress/progress_cubit.dart';
import '../widgets/body_icon.dart';

/// The Star Map: every real place on the journey, in true order from the Sun.
/// Places you have landed on reveal their name and facts.
class JourneyPage extends StatelessWidget {
  const JourneyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('STAR MAP', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 4)),
      ),
      body: BlocBuilder<ProgressCubit, PlayerProgress>(
        builder: (context, progress) {
          final cubit = context.read<ProgressCubit>();
          final found = [for (var k = 0; k < journey.length; k++) cubit.isDiscovered(k)].where((d) => d).length;
          final launch = cubit.launchIndex;
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            itemCount: journey.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) return _Header(found: found);
              final k = i - 1;
              return _Stop(
                index: k,
                discovered: cubit.isDiscovered(k),
                isLast: k == journey.length - 1,
                isLaunchPoint: k == launch,
                onLaunchHere: () => cubit.setLaunchFrom(k),
              );
            },
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.found});

  final int found;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$found / ${journey.length} discovered',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Real places in their true order outward from the Sun. Land on one to unlock it '
            'and earn +${ProgressCubit.discoveryBonus} stardust. Every place you discover becomes a '
            'launch point, so your journey can always continue.',
            style: TextStyle(color: AppColors.textDim, height: 1.4),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: found / journey.length,
              minHeight: 6,
              backgroundColor: Colors.white.fade(0.08),
              color: AppColors.gold,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stop extends StatefulWidget {
  const _Stop({
    required this.index,
    required this.discovered,
    required this.isLast,
    required this.isLaunchPoint,
    required this.onLaunchHere,
  });

  final int index;
  final bool discovered;
  final bool isLast;
  final bool isLaunchPoint;
  final VoidCallback onLaunchHere;

  @override
  State<_Stop> createState() => _StopState();
}

class _StopState extends State<_Stop> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final l = journey[widget.index];
    final color = Color(l.look.primary);
    final region = l.region;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (region != null)
          Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8, top: widget.index == 0 ? 0 : 10),
            child: Text(
              region.name.toUpperCase(),
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.5,
              ),
            ),
          ),
        Stack(
          children: [
            // Timeline rail linking this stop to the next
            if (!widget.isLast)
              Positioned(
                left: 35,
                top: 60,
                bottom: 0,
                child: Container(width: 2, color: Colors.white.fade(0.1)),
              ),
            Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BodyIcon(look: l.look, size: 72, locked: !widget.discovered, seed: widget.index),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.discovered ? () => setState(() => _open = !_open) : null,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 14, bottom: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.discovered ? l.name : '???',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: widget.discovered ? Colors.white : AppColors.textDim,
                                ),
                              ),
                            ),
                            if (widget.discovered)
                              Icon(
                                _open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                                color: Colors.white54,
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.index == 0 ? 'Where every journey starts' : '${l.distanceLabel} from the Sun',
                          style: TextStyle(
                            color: widget.discovered ? color : AppColors.textDim.fade(0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (!widget.discovered)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '"${l.teaser}"',
                              style: const TextStyle(
                                color: Color(0xFFB8F9FF),
                                fontSize: 12.5,
                                fontStyle: FontStyle.italic,
                                height: 1.35,
                              ),
                            ),
                          ),
                        if (widget.discovered)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: widget.isLaunchPoint
                                ? const _Chip(label: 'LAUNCH POINT', icon: Icons.rocket_launch_rounded, active: true)
                                : GestureDetector(
                                    onTap: widget.onLaunchHere,
                                    child: const _Chip(label: 'LAUNCH FROM HERE', icon: Icons.rocket_launch_outlined),
                                  ),
                          ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                          child: _open && widget.discovered
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      for (final fact in l.facts)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 6),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('•  ', style: TextStyle(color: color)),
                                              Expanded(
                                                child: Text(
                                                  fact,
                                                  style: const TextStyle(color: Colors.white70, height: 1.4),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                )
                              : const SizedBox(width: double.infinity),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            ),
          ],
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.icon, this.active = false});

  final String label;
  final IconData icon;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.gold : AppColors.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.fade(active ? 0.15 : 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.fade(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
        ],
      ),
    );
  }
}
