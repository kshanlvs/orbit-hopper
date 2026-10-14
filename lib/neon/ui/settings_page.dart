import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../audio/neon_audio.dart';
import '../progression/neon_cubit.dart';
import '../progression/profile.dart';
import 'neon_style.dart';

class NeonSettingsPage extends StatelessWidget {
  const NeonSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<NeonCubit, NeonProfile>(
        builder: (context, p) {
          final s = p.settings;
          Future<void> set(NeonSettings next) async {
            await context.read<NeonCubit>().settings(next);
            await NeonAudio.instance.apply(sfx: next.sfx, music: next.music, haptics: next.haptics);
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      NeonIconButton(icon: Icons.arrow_back_rounded, tooltip: 'Back', size: 40, onTap: () => context.pop()),
                      const SizedBox(width: 12),
                      Text('SETTINGS', style: NeonText.glow(20, NeonColors.cyan, spacing: 4)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: NeonPanel(
                            child: ListView(
                              children: [
                                Text('AUDIO & FEEL', style: NeonText.glow(13, NeonColors.violet, spacing: 2)),
                                _Row('Music', 'Synthwave soundtrack', s.music, (v) => set(s.copyWith(music: v))),
                                _Row('Sound effects', 'Flips, shards, near misses', s.sfx, (v) => set(s.copyWith(sfx: v))),
                                _Row('Haptics', 'Vibration on flips and impacts', s.haptics, (v) => set(s.copyWith(haptics: v))),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: NeonPanel(
                            child: ListView(
                              children: [
                                Text('COMFORT & ACCESSIBILITY', style: NeonText.glow(13, NeonColors.violet, spacing: 2)),
                                _Row(
                                  'Reduced effects',
                                  'No shake, flashes or camera twist; fewer particles',
                                  s.reducedEffects,
                                  (v) => set(s.copyWith(reducedEffects: v)),
                                ),
                                _Row(
                                  'High contrast',
                                  'Thicker hazard outlines, plain background',
                                  s.highContrast,
                                  (v) => set(s.copyWith(highContrast: v)),
                                ),
                                _Row(
                                  'Pause when leaving the app',
                                  'Auto-pause on calls and notifications',
                                  s.pauseOnFocusLoss,
                                  (v) => set(s.copyWith(pauseOnFocusLoss: v)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Controls: tap anywhere to flip gravity · ⚡ button to Pulse Dash · keyboard: Space flips, D dashes, P pauses',
                    textAlign: TextAlign.center,
                    style: NeonText.body(11, color: NeonColors.dim),
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

class _Row extends StatelessWidget {
  const _Row(this.title, this.subtitle, this.value, this.onChanged);

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: NeonText.body(14, weight: FontWeight.w800)),
                Text(subtitle, style: NeonText.body(12, color: NeonColors.dim)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
