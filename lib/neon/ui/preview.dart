import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../render/palette.dart';

/// A live mini-corridor: the chosen orb flips between floor and ceiling,
/// trailing the chosen trail, in the chosen dimension's colours.
class NeonPreview extends StatefulWidget {
  const NeonPreview({super.key, required this.dimension, required this.skin, required this.trail, this.animate = true});

  final String dimension;
  final String skin;
  final String trail;
  final bool animate;

  @override
  State<NeonPreview> createState() => _NeonPreviewState();
}

class _NeonPreviewState extends State<NeonPreview> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 6));

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _PreviewPainter(_c, NeonPalette.of(widget.dimension), SkinLook.of(widget.skin), widget.trail),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _PreviewPainter extends CustomPainter {
  _PreviewPainter(this.anim, this.pal, this.skin, this.trail) : super(repaint: anim);

  final Animation<double> anim;
  final NeonPalette pal;
  final SkinLook skin;
  final String trail;

  /// Orb height (0 top .. 1 bottom) at time t: rests, then flips.
  static double _y(double t) {
    final phase = t % 2.0;
    double ease(double k) => k * k;
    if (phase < 0.75) return 1;
    if (phase < 1.0) return 1 - ease((phase - 0.75) / 0.25);
    if (phase < 1.75) return 0;
    return ease((phase - 1.75) / 0.25);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final t = anim.value * 6;
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [pal.bgTop, pal.bgBottom],
        ).createShader(rect),
    );
    final top = h * 0.16, bot = h * 0.84;
    final grid = Paint()
      ..color = pal.grid.withAlpha(110)
      ..strokeWidth = 1;
    final step = h * 0.3;
    final off = (t * h * 0.6) % step;
    for (var x = -off; x < w; x += step) {
      canvas.drawLine(Offset(x, top), Offset(x, bot), grid);
    }
    final wall = Paint()
      ..color = pal.wall
      ..strokeWidth = 2.5;
    final halo = Paint()
      ..color = pal.wall.withAlpha(50)
      ..strokeWidth = 8;
    for (final y in [top, bot]) {
      canvas.drawLine(Offset(0, y), Offset(w, y), halo);
      canvas.drawLine(Offset(0, y), Offset(w, y), wall);
    }

    final r = (bot - top) * 0.075;
    final ox = w * 0.4;
    double yAt(double tt) => top + r + (_y(tt) * (bot - top - 2 * r));
    final glow = skin.glowAt(t);
    // Trail: past positions scroll left.
    final speed = (bot - top) * 1.3;
    const n = 22;
    final paint = Paint()..strokeCap = StrokeCap.round;
    for (var i = n; i >= 1; i--) {
      final dt = i * 0.018;
      final x = ox - dt * speed;
      final y = yAt(t - dt);
      final k = 1 - i / n;
      switch (trail) {
        case 'dots':
          if (i.isEven) canvas.drawCircle(Offset(x, y), r * 0.35 * (0.4 + k), paint..color = glow.withAlpha((200 * k).round()));
        case 'echo':
          if (i % 6 == 0) {
            canvas.drawCircle(
              Offset(x, y),
              r * (0.6 + 0.4 * k),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.5
                ..color = glow.withAlpha((160 * k).round()),
            );
          }
        case 'sparks':
          final jitter = math.sin(i * 12.9898 + t * 40) * r * 0.6;
          canvas.drawCircle(Offset(x, y + jitter), r * 0.18, paint..color = glow.withAlpha((230 * k).round()));
        case 'ribbon':
          final x2 = ox - (i - 1) * 0.018 * speed;
          final y2 = yAt(t - (i - 1) * 0.018);
          final path = Path()
            ..moveTo(x, y - r * 0.9 * k)
            ..lineTo(x2, y2 - r * 0.9 * k)
            ..lineTo(x2, y2 + r * 0.9 * k)
            ..lineTo(x, y + r * 0.9 * k)
            ..close();
          canvas.drawPath(path, Paint()..color = glow.withAlpha((130 * k).round()));
        default:
          final x2 = ox - (i - 1) * 0.018 * speed;
          final y2 = yAt(t - (i - 1) * 0.018);
          canvas.drawLine(
            Offset(x, y),
            Offset(x2, y2),
            paint
              ..color = glow.withAlpha((200 * k).round())
              ..strokeWidth = r * 1.3 * k + 1,
          );
      }
    }
    final c = Offset(ox, yAt(t));
    canvas.drawCircle(c, r * 3, Paint()..shader = RadialGradient(colors: [glow.withAlpha(150), glow.withAlpha(0)]).createShader(Rect.fromCircle(center: c, radius: r * 3)));
    if (skin.style == 'ghost') {
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = glow,
      );
    } else {
      canvas.drawCircle(c, r, Paint()..color = glow);
      canvas.drawCircle(c, r * 0.68, Paint()..color = skin.core);
    }
  }

  @override
  bool shouldRepaint(_PreviewPainter old) => old.pal != pal || old.skin != skin || old.trail != trail;
}
