import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../neon_game.dart';
import 'neon_style.dart';

/// The in-run HUD. It lives in the bands above and below the corridor and
/// only the pause and dash buttons take touches — every other tap flips.
class NeonHudView extends StatelessWidget {
  const NeonHudView({super.key, required this.game, required this.onPause});

  final NeonGame game;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<NeonHud>(
      valueListenable: game.hud,
      builder: (context, h, _) {
        return Stack(
          children: [
            // Top band.
            Positioned(
              left: 12,
              top: 6,
              child: Row(
                children: [
                  NeonIconButton(icon: Icons.pause_rounded, tooltip: 'Pause', size: 38, onTap: onPause),
                  const SizedBox(width: 10),
                  IgnorePointer(child: Text('${h.distance} m', style: NeonText.glow(14, NeonColors.dim, spacing: 1))),
                ],
              ),
            ),
            Positioned(
              top: 4,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(formatInt(h.score), style: NeonText.glow(26, NeonColors.text, spacing: 1)),
                    const SizedBox(width: 10),
                    _Multiplier(multiplier: h.multiplier, left: h.chainLeft, chain: h.chain),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 14,
              top: 10,
              child: IgnorePointer(child: EnergyChip(amount: h.shards, size: 16)),
            ),
            // Bottom-left, behind the orb, where nothing is coming at you.
            Positioned(
              left: 14,
              bottom: 10,
              child: _DashButton(
                charge: h.dashCharge,
                ready: h.dashReady,
                active: h.dashing,
                onTap: game.dash,
              ),
            ),
            if (h.tutorial) const Positioned.fill(child: IgnorePointer(child: _TapHint())),
            if (h.ready)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(child: Text('READY', style: NeonText.glow(40, NeonColors.cyan, spacing: 8))),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Multiplier extends StatelessWidget {
  const _Multiplier({required this.multiplier, required this.left, required this.chain});

  final double multiplier;
  final double left;
  final int chain;

  @override
  Widget build(BuildContext context) {
    final hot = chain >= 10;
    final color = chain == 0 ? NeonColors.dim : (hot ? NeonColors.magenta : NeonColors.violet);
    return AnimatedScale(
      scale: chain == 0 ? 0.9 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('x${multiplier.toStringAsFixed(1)}', style: NeonText.glow(17, color, spacing: 1)),
          const SizedBox(height: 2),
          Container(
            width: 46,
            height: 4,
            decoration: BoxDecoration(color: const Color(0xFF231C40), borderRadius: BorderRadius.circular(2)),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: left,
              child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashButton extends StatelessWidget {
  const _DashButton({required this.charge, required this.ready, required this.active, required this.onTap});

  final double charge;
  final bool ready;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const size = 62.0;
    final color = ready || active ? NeonColors.magenta : NeonColors.dim;
    return Semantics(
      button: true,
      label: ready ? 'Pulse Dash ready' : 'Pulse Dash charging',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => onTap(),
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _RingPainter(active ? 1 : charge, color, ready),
            child: Center(child: Icon(Icons.bolt_rounded, color: color, size: 30)),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.color, this.ready);

  final double value;
  final Color color;
  final bool ready;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 4;
    canvas.drawCircle(c, r + 3, Paint()..color = NeonColors.panel.withAlpha(210));
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = const Color(0xFF231C40),
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
    if (ready) {
      canvas.drawCircle(
        c,
        r + 4,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color.withAlpha(120),
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.value != value || o.color != color || o.ready != ready;
}

class _TapHint extends StatefulWidget {
  const _TapHint();

  @override
  State<_TapHint> createState() => _TapHintState();
}

class _TapHintState extends State<_TapHint> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: const Alignment(0.25, 0),
      child: FadeTransition(
        opacity: Tween(begin: 0.45, end: 1.0).animate(_c),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.swap_vert_rounded, color: NeonColors.cyan, size: 38),
            const SizedBox(height: 6),
            Text('TAP ANYWHERE TO FLIP GRAVITY', style: NeonText.glow(16, NeonColors.text, spacing: 3)),
          ],
        ),
      ),
    );
  }
}

/// Banners and small notices pushed by the game.
class NeonToastLayer extends StatefulWidget {
  const NeonToastLayer({super.key, required this.toasts});

  final Stream<NeonToast> toasts;

  @override
  State<NeonToastLayer> createState() => _NeonToastLayerState();
}

class _NeonToastLayerState extends State<NeonToastLayer> {
  StreamSubscription<NeonToast>? _sub;
  NeonToast? _banner;
  NeonToast? _small;
  int _bannerId = 0, _smallId = 0;

  @override
  void initState() {
    super.initState();
    _sub = widget.toasts.listen(_show);
  }

  @override
  void didUpdateWidget(NeonToastLayer old) {
    super.didUpdateWidget(old);
    if (old.toasts != widget.toasts) {
      _sub?.cancel();
      _sub = widget.toasts.listen(_show);
    }
  }

  void _show(NeonToast t) {
    if (!mounted) return;
    if (t.kind == ToastKind.small) {
      final id = ++_smallId;
      setState(() => _small = t);
      Future.delayed(const Duration(milliseconds: 1800), () {
        if (mounted && id == _smallId) setState(() => _small = null);
      });
    } else {
      final id = ++_bannerId;
      setState(() => _banner = t);
      Future.delayed(const Duration(milliseconds: 1700), () {
        if (mounted && id == _bannerId) setState(() => _banner = null);
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = _banner, s = _small;
    return IgnorePointer(
      child: Stack(
        children: [
          Align(
            alignment: const Alignment(0.2, -0.45),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, a) => ScaleTransition(
                scale: Tween(begin: 1.25, end: 1.0).animate(a),
                child: FadeTransition(opacity: a, child: child),
              ),
              child: b == null
                  ? const SizedBox.shrink()
                  : Column(
                      key: ValueKey(_bannerId),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(b.text, style: NeonText.glow(b.kind == ToastKind.record ? 34 : 30, b.color, spacing: 6)),
                        if (b.sub != null) Text(b.sub!, style: NeonText.glow(16, NeonColors.text, spacing: 3)),
                      ],
                    ),
            ),
          ),
          Align(
            alignment: const Alignment(0.3, 0.95),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: s == null
                  ? const SizedBox.shrink()
                  : Container(
                      key: ValueKey(_smallId),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: NeonColors.panel.withAlpha(200),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: s.color.withAlpha(160)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(s.text, style: NeonText.glow(13, s.color, spacing: 2)),
                          if (s.sub != null) Text(s.sub!, style: NeonText.body(11, color: NeonColors.dim)),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
