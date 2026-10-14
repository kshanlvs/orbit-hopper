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
          final foundReal = [for (var k = 0; k < realPlaces; k++) cubit.isDiscovered(k)].where((d) => d).length;
          final uncharted = cubit.unchartedFound;
          final launch = cubit.launchIndex;
          // Real places, every uncharted world found so far, and one more mystery.
          final count = realPlaces + uncharted + 1;
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            itemCount: count + 1,
            itemBuilder: (context, i) {
              if (i == 0) return _Header(found: foundReal, uncharted: uncharted);
              final k = i - 1;
              return _Stop(
                index: k,
                discovered: cubit.isDiscovered(k),
                isLast: k == count - 1,
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
  const _Header({required this.found, required this.uncharted});

  final int found;
  final int uncharted;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ProgressCubit>();
    final fragments = cubit.fragmentsDecoded;
    final (chapter, left) = Cosmos.nextChapter(cubit.furthestDiscovered);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$found / $realPlaces real places discovered',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          if (uncharted > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '+ $uncharted uncharted world${uncharted == 1 ? '' : 's'} beyond the edge',
                style: const TextStyle(color: Color(0xFF7CF5FF), fontWeight: FontWeight.w700),
              ),
            ),
          const SizedBox(height: 6),
          const Text(
            'Real places in their true order outward from the Sun. Land on one to unlock it '
            'and earn +${ProgressCubit.discoveryBonus} stardust. Every place you discover becomes a '
            'launch point. Past the edge of the universe, new worlds never stop appearing.',
            style: TextStyle(color: AppColors.textDim, height: 1.4),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: found / realPlaces,
              minHeight: 6,
              backgroundColor: Colors.white.fade(0.08),
              color: AppColors.gold,
            ),
          ),
          const SizedBox(height: 14),
          _InfoTile(
            icon: Icons.flag_rounded,
            color: const Color(0xFF5CFFB0),
            title: 'NEXT MILESTONE: ${chapter.title.toUpperCase()}',
            body: '$left place${left == 1 ? '' : 's'} to go  ·  reward +${chapter.reward} ✦',
          ),
          const SizedBox(height: 10),
          _SignalTile(fragments: fragments),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.color, required this.title, required this.body});

  final IconData icon;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.fade(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.fade(0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.5)),
                const SizedBox(height: 2),
                Text(body, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "The Signal": story progress and every transmission unlocked so far.
class _SignalTile extends StatefulWidget {
  const _SignalTile({required this.fragments});

  final int fragments;

  @override
  State<_SignalTile> createState() => _SignalTileState();
}

class _SignalTileState extends State<_SignalTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ProgressCubit>();
    const gold = Color(0xFFFFD166);
    final unlocked = [
      for (final e in transmissions.entries)
        if (cubit.isDiscovered(Cosmos.indexOfId(e.key)) || e.key == 'sun') e.value,
    ];
    final contact = cubit.isDiscovered(realPlaces);
    return GestureDetector(
      onTap: () => setState(() => _open = !_open),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: gold.fade(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: gold.fade(0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.settings_input_antenna_rounded, color: gold, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    contact
                        ? 'THE SIGNAL · FIRST CONTACT MADE'
                        : 'THE SIGNAL · ${widget.fragments}/$signalFragments DECODED',
                    style: const TextStyle(color: gold, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.5),
                  ),
                ),
                Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: Colors.white54),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: widget.fragments / signalFragments,
                minHeight: 5,
                backgroundColor: Colors.white.fade(0.08),
                color: gold,
              ),
            ),
            if (!_open)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Someone out there is calling. Tap to read the transmissions.',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ),
            if (_open)
              for (final t in unlocked)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.from,
                          style: const TextStyle(
                              color: gold, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                      const SizedBox(height: 2),
                      Text(t.text,
                          style: const TextStyle(
                              color: Color(0xFFFFE6A8), fontStyle: FontStyle.italic, height: 1.4, fontSize: 13)),
                    ],
                  ),
                ),
          ],
        ),
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
    final l = Cosmos.place(widget.index);
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
                          widget.index == 0
                              ? 'Where every journey starts'
                              : l.real
                                  ? '${l.distanceLabel} from the Sun'
                                  : 'Uncharted · beyond the edge',
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
