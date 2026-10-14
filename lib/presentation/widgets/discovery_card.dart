import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme/app_theme.dart';
import '../../game/logic/cosmos.dart';
import '../progress/progress_cubit.dart';
import '../run/run_cubit.dart';
import 'body_icon.dart';

/// Shows a fact card whenever the player lands on a real place, then hides it.
/// Never blocks taps — the game keeps going underneath.
class DiscoveryOverlay extends StatefulWidget {
  const DiscoveryOverlay({super.key});

  @override
  State<DiscoveryOverlay> createState() => _DiscoveryOverlayState();
}

class _DiscoveryOverlayState extends State<DiscoveryOverlay> {
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RunCubit, RunState>(
      listenWhen: (a, b) => a.discovery?.id != b.discovery?.id,
      listener: (context, s) {
        final d = s.discovery;
        _timer?.cancel();
        if (d == null) return;
        _timer = Timer(const Duration(milliseconds: 6000), () {
          if (mounted) context.read<RunCubit>().dismissDiscovery(d.id);
        });
      },
      buildWhen: (a, b) => a.discovery?.id != b.discovery?.id,
      builder: (context, s) {
        final d = s.discovery;
        return IgnorePointer(
          child: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 112, left: 14, right: 14),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0, -0.25), end: Offset.zero).animate(anim),
                      child: child,
                    ),
                  ),
                  child: d == null ? const SizedBox.shrink() : _DiscoveryCard(key: ValueKey(d.id), discovery: d),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DiscoveryCard extends StatelessWidget {
  const _DiscoveryCard({super.key, required this.discovery});

  final Discovery discovery;

  @override
  Widget build(BuildContext context) {
    final k = discovery.landmarkIndex;
    final l = journey[k];
    final color = Color(l.look.primary);
    final progress = context.read<ProgressCubit>();
    final isStart = k == 0;
    final depart = discovery.isDeparture;
    final label = depart
        ? (isStart ? 'YOUR JOURNEY BEGINS' : 'DEPARTING FROM')
        : discovery.isNew
            ? 'NEW DISCOVERY  +${ProgressCubit.discoveryBonus} ✦'
            : 'YOU REACHED';
    final next = k + 1 < journey.length ? k + 1 : null;
    final nextKnown = next != null && progress.isDiscovered(next);

    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.fromLTRB(10, 12, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.fade(0.5)),
        boxShadow: [BoxShadow(color: color.fade(0.25), blurRadius: 24)],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BodyIcon(look: l.look, size: 64, seed: k),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: discovery.isNew && !depart ? AppColors.gold : AppColors.textDim,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(l.name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                Text(
                  isStart ? 'The center of our solar system' : '${l.distanceLabel} from the Sun',
                  style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
                ),
                if (!depart && l.region != null && !isStart) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Entering: ${l.region!.name}',
                    style: const TextStyle(
                        color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1),
                  ),
                ],
                if (!depart && discovery.isNew && Cosmos.isRankUp(k)) ...[
                  const SizedBox(height: 4),
                  Text(
                    'RANK UP: ${Cosmos.rankFor(k).toUpperCase()}',
                    style: const TextStyle(
                        color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                  ),
                ],
                if (!depart) ...[
                  const SizedBox(height: 6),
                  Text(
                    l.facts[discovery.factIndex % l.facts.length],
                    style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.35),
                  ),
                ],
                if (next != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    nextKnown ? 'NEXT: ${journey[next].name.toUpperCase()}' : 'INCOMING SIGNAL',
                    style: const TextStyle(
                      color: Color(0xFF7CF5FF),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                  if (!nextKnown) _Typewriter(text: '"${journey[next].teaser}"'),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Reveals a line letter by letter, like a transmission coming in.
class _Typewriter extends StatelessWidget {
  const _Typewriter({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 28 * text.length + 500),
      builder: (context, t, _) {
        // Short pause before the signal starts "arriving".
        final shown = (((t * (text.length + 18)) - 18).clamp(0, text.length)).toInt();
        return Text(
          text.substring(0, shown),
          style: const TextStyle(
            color: Color(0xFFB8F9FF),
            fontSize: 12.5,
            fontStyle: FontStyle.italic,
            height: 1.35,
          ),
        );
      },
    );
  }
}
