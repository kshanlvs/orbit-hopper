import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../progression/catalog.dart';
import '../progression/neon_cubit.dart';
import '../progression/profile.dart';
import '../progression/rules.dart';
import '../render/palette.dart';
import 'neon_style.dart';
import 'preview.dart';

enum _Tab { dimensions, orbs, trails }

/// Dimension Lab: worlds unlock with your best score; orbs and trails are
/// bought with energy earned in runs. All cosmetic.
class NeonLabPage extends StatefulWidget {
  const NeonLabPage({super.key});

  @override
  State<NeonLabPage> createState() => _NeonLabPageState();
}

class _NeonLabPageState extends State<NeonLabPage> {
  _Tab _tab = _Tab.dimensions;
  String? _dimension, _skin, _trail;
  String? _message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<NeonCubit, NeonProfile>(
        builder: (context, p) {
          final dim = _dimension ?? p.dimension;
          final skin = _skin ?? p.skin;
          final trail = _trail ?? p.trail;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 9,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            NeonIconButton(
                                icon: Icons.arrow_back_rounded, tooltip: 'Back', size: 40, onTap: () => context.pop()),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'DIMENSION LAB',
                                style: NeonText.glow(20, NeonColors.magenta, spacing: 4),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            EnergyChip(amount: p.energy, size: 17),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: NeonPreview(
                            key: ValueKey('$dim/$skin/$trail/${p.settings.reducedEffects}'),
                            dimension: _tab == _Tab.dimensions ? dim : p.dimension,
                            skin: _tab == _Tab.orbs ? skin : p.skin,
                            trail: _tab == _Tab.trails ? trail : p.trail,
                            animate: !p.settings.reducedEffects,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _actionBar(context, p, dim, skin, trail),
                        if (_message != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(_message!, style: NeonText.body(12, color: NeonColors.gold)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 10,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            for (final t in _Tab.values)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 3),
                                  child: _TabChip(
                                    label: switch (t) {
                                      _Tab.dimensions => 'WORLDS',
                                      _Tab.orbs => 'ORBS',
                                      _Tab.trails => 'TRAILS',
                                    },
                                    selected: _tab == t,
                                    onTap: () => setState(() {
                                      _tab = t;
                                      _message = null;
                                    }),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Expanded(child: _grid(p, dim, skin, trail)),
                      ],
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

  Widget _grid(NeonProfile p, String dim, String skin, String trail) {
    final items = <_Item>[
      if (_tab == _Tab.dimensions)
        for (final d in NeonCatalog.dimensions)
          _Item(
            id: d.id,
            name: d.name,
            color: NeonPalette.of(d.id).wall,
            second: NeonPalette.of(d.id).bgBottom,
            status: p.dimension == d.id
                ? 'ACTIVE'
                : (NeonRules.dimensionUnlocked(p, d) ? 'UNLOCKED' : 'BEST ${formatInt(d.unlockScore)}'),
            locked: !NeonRules.dimensionUnlocked(p, d),
            selected: dim == d.id,
          ),
      if (_tab == _Tab.orbs)
        for (final s in NeonCatalog.skins)
          _Item(
            id: s.id,
            name: s.name,
            color: SkinLook.of(s.id).glow,
            second: SkinLook.of(s.id).core,
            status: p.skin == s.id ? 'EQUIPPED' : (p.ownedSkins.contains(s.id) ? 'OWNED' : '${formatInt(s.price)} ENERGY'),
            locked: !p.ownedSkins.contains(s.id),
            selected: skin == s.id,
          ),
      if (_tab == _Tab.trails)
        for (final t in NeonCatalog.trails)
          _Item(
            id: t.id,
            name: t.name,
            color: SkinLook.of(p.skin).glow,
            second: NeonColors.panel,
            status: p.trail == t.id ? 'EQUIPPED' : (p.ownedTrails.contains(t.id) ? 'OWNED' : '${formatInt(t.price)} ENERGY'),
            locked: !p.ownedTrails.contains(t.id),
            selected: trail == t.id,
          ),
    ];
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 150,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.15,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final it = items[i];
        return _ItemCard(
          item: it,
          onTap: () => setState(() {
            _message = null;
            switch (_tab) {
              case _Tab.dimensions:
                _dimension = it.id;
              case _Tab.orbs:
                _skin = it.id;
              case _Tab.trails:
                _trail = it.id;
            }
          }),
        );
      },
    );
  }

  Widget _actionBar(BuildContext context, NeonProfile p, String dim, String skin, String trail) {
    final cubit = context.read<NeonCubit>();
    String title;
    String label;
    VoidCallback? action;
    switch (_tab) {
      case _Tab.dimensions:
        final d = NeonCatalog.dimension(dim);
        title = '${d.name} — ${d.tagline}';
        if (p.dimension == d.id) {
          label = 'ACTIVE';
        } else if (NeonRules.dimensionUnlocked(p, d)) {
          label = 'ENTER';
          action = () => _run(cubit.dimension(d.id), 'Entered ${d.name}.');
        } else {
          label = 'SCORE ${formatInt(d.unlockScore)} TO UNLOCK';
        }
      case _Tab.orbs:
        final s = NeonCatalog.skin(skin);
        title = '${s.name} orb';
        if (p.skin == s.id) {
          label = 'EQUIPPED';
        } else if (p.ownedSkins.contains(s.id)) {
          label = 'EQUIP';
          action = () => _run(cubit.skin(s.id), '${s.name} equipped.');
        } else if (p.energy >= s.price) {
          label = 'BUY · ${formatInt(s.price)}';
          action = () => _run(cubit.skin(s.id), '${s.name} unlocked!');
        } else {
          label = 'NEED ${formatInt(s.price - p.energy)} MORE';
        }
      case _Tab.trails:
        final t = NeonCatalog.trail(trail);
        title = '${t.name} trail';
        if (p.trail == t.id) {
          label = 'EQUIPPED';
        } else if (p.ownedTrails.contains(t.id)) {
          label = 'EQUIP';
          action = () => _run(cubit.trail(t.id), '${t.name} equipped.');
        } else if (p.energy >= t.price) {
          label = 'BUY · ${formatInt(t.price)}';
          action = () => _run(cubit.trail(t.id), '${t.name} unlocked!');
        } else {
          label = 'NEED ${formatInt(t.price - p.energy)} MORE';
        }
    }
    return Row(
      children: [
        Expanded(child: Text(title, style: NeonText.body(13), maxLines: 2, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 10),
        Flexible(
          child: NeonButton(
            label: label,
            icon: label.startsWith('BUY') || label.startsWith('NEED') ? Icons.diamond : null,
            color: action == null ? NeonColors.dim : NeonColors.magenta,
            filled: action != null,
            onTap: action,
          ),
        ),
      ],
    );
  }

  Future<void> _run(Future<PurchaseResult> f, String ok) async {
    final r = await f;
    if (!mounted) return;
    setState(() {
      _message = switch (r) {
        PurchaseResult.bought || PurchaseResult.equipped => ok,
        PurchaseResult.tooExpensive => 'Not enough energy yet — play a run!',
        PurchaseResult.unknown => null,
      };
    });
  }
}

class _Item {
  const _Item({
    required this.id,
    required this.name,
    required this.color,
    required this.second,
    required this.status,
    required this.locked,
    required this.selected,
  });

  final String id, name, status;
  final Color color, second;
  final bool locked, selected;
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, required this.onTap});

  final _Item item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = item.selected ? NeonColors.magenta : (item.locked ? const Color(0xFF3A3360) : NeonColors.violet);
    return Semantics(
      button: true,
      label: '${item.name}, ${item.status}',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: NeonColors.panel,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c, width: item.selected ? 2 : 1.2),
            boxShadow: [if (item.selected) BoxShadow(color: c.withAlpha(110), blurRadius: 14)],
          ),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [item.second, item.color]),
                          boxShadow: [BoxShadow(color: item.color.withAlpha(item.locked ? 40 : 150), blurRadius: 14)],
                        ),
                      ),
                      if (item.locked) const Icon(Icons.lock_rounded, color: Colors.white70, size: 18),
                    ],
                  ),
                ),
              ),
              Text(item.name,
                  style: NeonText.body(13, weight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(item.status, style: NeonText.body(11, color: NeonColors.dim), maxLines: 1),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = selected ? NeonColors.cyan : NeonColors.dim;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: selected ? NeonColors.cyan.withAlpha(40) : Colors.transparent,
          border: Border.all(color: c.withAlpha(selected ? 255 : 120)),
        ),
        child: Text(label, style: NeonText.glow(13, selected ? NeonColors.text : NeonColors.dim, spacing: 2)),
      ),
    );
  }
}
