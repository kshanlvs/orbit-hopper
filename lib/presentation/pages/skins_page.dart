import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/comet_skin.dart';
import '../../domain/entities/player_progress.dart';
import '../progress/progress_cubit.dart';
import '../widgets/stardust_badge.dart';

class SkinsPage extends StatelessWidget {
  const SkinsPage({super.key});

  Future<void> _onTap(BuildContext context, CometSkin skin) async {
    final cubit = context.read<ProgressCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final owned = cubit.owns(skin);
    final need = skin.cost - cubit.state.stardust;
    final ok = await cubit.purchase(skin);
    messenger.hideCurrentSnackBar();
    if (!ok) {
      messenger.showSnackBar(SnackBar(content: Text('You need $need more stardust')));
    } else if (!owned) {
      messenger.showSnackBar(SnackBar(content: Text('${skin.name} unlocked!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('COMETS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 4)),
        actions: [
          BlocBuilder<ProgressCubit, PlayerProgress>(
            builder: (context, p) => Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(child: StardustBadge(amount: p.stardust)),
            ),
          ),
        ],
      ),
      body: BlocBuilder<ProgressCubit, PlayerProgress>(
        builder: (context, progress) => GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 0.85,
          ),
          itemCount: CometSkins.all.length,
          itemBuilder: (context, i) {
            final skin = CometSkins.all[i];
            return _SkinCard(
              skin: skin,
              owned: progress.unlockedSkinIds.contains(skin.id),
              selected: progress.selectedSkinId == skin.id,
              affordable: progress.stardust >= skin.cost,
              onTap: () => _onTap(context, skin),
            );
          },
        ),
      ),
    );
  }
}

class _SkinCard extends StatelessWidget {
  const _SkinCard({
    required this.skin,
    required this.owned,
    required this.selected,
    required this.affordable,
    required this.onTap,
  });

  final CometSkin skin;
  final bool owned;
  final bool selected;
  final bool affordable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(skin.argb);
    final gradientColors = skin.rainbow
        ? const [Color(0xFFFF4D6D), Color(0xFFFFD166), Color(0xFF7CFF6B), Color(0xFF5CE1FF), Color(0xFFC77DFF)]
        : [color, color.fade(0.4)];

    final String status;
    final Color statusColor;
    if (selected) {
      status = 'EQUIPPED';
      statusColor = AppColors.accent;
    } else if (owned) {
      status = 'TAP TO EQUIP';
      statusColor = Colors.white70;
    } else {
      status = '${skin.cost}';
      statusColor = affordable ? AppColors.gold : AppColors.textDim;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? AppColors.accent : Colors.white.fade(0.08),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected ? [BoxShadow(color: AppColors.accent.fade(0.3), blurRadius: 20)] : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(
              opacity: owned ? 1 : 0.55,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(colors: [...gradientColors, gradientColors.first]),
                  boxShadow: [BoxShadow(color: color.fade(0.6), blurRadius: 24)],
                ),
                child: Center(
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(skin.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!owned) ...[
                  Icon(Icons.lock_rounded, size: 14, color: statusColor),
                  const SizedBox(width: 4),
                ],
                Text(
                  status,
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.w800, letterSpacing: 1.5),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
