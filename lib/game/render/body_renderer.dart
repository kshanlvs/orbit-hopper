import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../logic/cosmos.dart';

/// Draws every kind of celestial body procedurally (no image assets).
/// Shared by the game and by the Star Map screen.
abstract final class BodyRenderer {
  static final Paint _p = Paint()..isAntiAlias = true;
  static final Paint _s = Paint()
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true;
  static final Paint _blur = Paint()..isAntiAlias = true;

  static void draw(Canvas canvas, Offset c, double r, BodyLook look, double time, {int seed = 0}) {
    final primary = Color(look.primary);
    final secondary = Color(look.secondary);
    final rng = math.Random(seed * 7919 + look.style.index);
    switch (look.style) {
      case BodyStyle.sun:
        _sun(canvas, c, r, primary, secondary, time);
      case BodyStyle.rocky:
        _sphereBase(canvas, c, r, primary, secondary);
        _clipped(canvas, c, r, () {
          for (var i = 0; i < 6; i++) {
            _p.color = secondary.fade(0.35);
            final o = _randIn(rng, r * 0.8);
            canvas.drawOval(Rect.fromCenter(center: c + o, width: r * (0.4 + rng.nextDouble() * 0.5), height: r * (0.25 + rng.nextDouble() * 0.3)), _p);
          }
        });
        _shade(canvas, c, r);
      case BodyStyle.cratered:
        _sphereBase(canvas, c, r, primary, secondary);
        _clipped(canvas, c, r, () => _craters(canvas, c, r, rng, secondary, 7));
        _shade(canvas, c, r);
      case BodyStyle.venus:
        _glow(canvas, c, r * 1.35, primary, 0.35, r * 0.4);
        _sphereBase(canvas, c, r, primary, secondary);
        _clipped(canvas, c, r, () {
          for (var i = -3; i <= 3; i++) {
            final path = Path();
            final y = c.dy + i * r * 0.3;
            path.moveTo(c.dx - r, y);
            for (var x = -r; x <= r; x += r / 6) {
              path.lineTo(c.dx + x, y + math.sin(x / r * 4 + i + time * 0.3) * r * 0.08);
            }
            _s
              ..color = secondary.fade(0.3)
              ..strokeWidth = r * 0.14;
            canvas.drawPath(path, _s);
          }
        });
        _shade(canvas, c, r);
      case BodyStyle.earth:
        _glow(canvas, c, r * 1.3, const Color(0xFF6FB6FF), 0.45, r * 0.35);
        _sphereBase(canvas, c, r, primary, const Color(0xFF123A8C));
        _clipped(canvas, c, r, () {
          final drift = (time * 4) % (r * 2);
          for (var i = 0; i < 5; i++) {
            final o = _randIn(rng, r * 0.75);
            _p.color = secondary;
            canvas.save();
            canvas.translate(c.dx + _wrap(o.dx + drift, r), c.dy + o.dy);
            canvas.rotate(rng.nextDouble() * math.pi);
            canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: r * (0.5 + rng.nextDouble() * 0.5), height: r * (0.3 + rng.nextDouble() * 0.3)), _p);
            canvas.restore();
          }
          for (var i = 0; i < 4; i++) {
            final o = _randIn(rng, r * 0.85);
            _p.color = Colors.white.fade(0.55);
            canvas.drawOval(Rect.fromCenter(center: Offset(c.dx + _wrap(o.dx + drift * 1.6, r), c.dy + o.dy), width: r * 0.7, height: r * 0.12), _p);
          }
          _p.color = Colors.white.fade(0.8);
          canvas.drawOval(Rect.fromCenter(center: c + Offset(0, -r * 0.92), width: r * 0.9, height: r * 0.22), _p);
        });
        _shade(canvas, c, r);
      case BodyStyle.mars:
        _sphereBase(canvas, c, r, primary, secondary);
        _clipped(canvas, c, r, () {
          for (var i = 0; i < 5; i++) {
            _p.color = secondary.fade(0.45);
            final o = _randIn(rng, r * 0.7);
            canvas.drawOval(Rect.fromCenter(center: c + o, width: r * 0.6, height: r * 0.3), _p);
          }
          _p.color = Colors.white.fade(0.85);
          canvas.drawOval(Rect.fromCenter(center: c + Offset(0, -r * 0.9), width: r * 0.7, height: r * 0.25), _p);
          canvas.drawOval(Rect.fromCenter(center: c + Offset(0, r * 0.93), width: r * 0.5, height: r * 0.18), _p);
        });
        _shade(canvas, c, r);
      case BodyStyle.banded:
        _sphereBase(canvas, c, r, primary, secondary);
        _clipped(canvas, c, r, () => _bands(canvas, c, r, primary, secondary, rng, look.spot, time));
        _shade(canvas, c, r);
      case BodyStyle.ringed:
        _ring(canvas, c, r, primary, secondary, look.tilt, back: true);
        _sphereBase(canvas, c, r, primary, secondary);
        _clipped(canvas, c, r, () => _bands(canvas, c, r, primary, secondary, rng, false, time, soft: true));
        _shade(canvas, c, r);
        _ring(canvas, c, r, primary, secondary, look.tilt, back: false);
      case BodyStyle.icy:
        _glow(canvas, c, r * 1.25, primary, 0.25, r * 0.3);
        _sphereBase(canvas, c, r, primary, secondary);
        _clipped(canvas, c, r, () {
          for (var i = 0; i < 5; i++) {
            _s
              ..color = secondary.fade(0.4)
              ..strokeWidth = 1.2;
            final o = _randIn(rng, r * 0.6);
            canvas.drawArc(Rect.fromCircle(center: c + o, radius: r * (0.4 + rng.nextDouble() * 0.6)), rng.nextDouble() * 6, 1.4, false, _s);
          }
          _p.color = Colors.white.fade(0.35);
          canvas.drawOval(Rect.fromCenter(center: c + Offset(r * 0.15, r * 0.2), width: r * 0.8, height: r * 0.6), _p);
        });
        _shade(canvas, c, r);
      case BodyStyle.probe:
        _probe(canvas, c, r, primary, secondary, time);
      case BodyStyle.cloud:
        _glow(canvas, c, r * 1.3, primary, 0.35, r * 0.5);
        for (var i = 0; i < 46; i++) {
          final o = _randIn(rng, r * 1.25);
          final tw = 0.5 + 0.5 * math.sin(time * 2 + i);
          _p.color = primary.fade(0.35 + 0.5 * tw);
          canvas.drawCircle(c + o, 0.8 + rng.nextDouble() * 1.8, _p);
        }
        _glow(canvas, c, r * 0.35, Colors.white, 0.8, r * 0.2);
        _p.color = secondary;
        canvas.drawCircle(c, r * 0.18, _p);
      case BodyStyle.star:
        _star(canvas, c, r, primary, secondary, time, seed);
      case BodyStyle.nebula:
        _nebula(canvas, c, r, primary, secondary, rng, time);
      case BodyStyle.blackHole:
        _blackHole(canvas, c, r, primary, secondary, look.tilt, time);
      case BodyStyle.galaxy:
        _galaxy(canvas, c, r, primary, secondary, look.tilt, rng, time);
      case BodyStyle.cmb:
        _sphereBase(canvas, c, r, primary, secondary);
        _clipped(canvas, c, r, () {
          for (var i = 0; i < 40; i++) {
            _p.color = (i.isEven ? primary : secondary).fade(0.55);
            canvas.drawCircle(c + _randIn(rng, r), r * (0.08 + rng.nextDouble() * 0.18), _p);
          }
        });
        _shade(canvas, c, r);
    }
  }

  /// Colour used for glows/particles around a body.
  static Color glowColor(BodyLook look) => Color(look.primary);

  /// How far (in body radii) anything of this style is drawn from its centre.
  static double extent(BodyStyle style) => switch (style) {
        BodyStyle.sun => 2.8,
        BodyStyle.star => 2.7,
        BodyStyle.ringed => 2.3,
        BodyStyle.blackHole => 2.2,
        BodyStyle.nebula => 1.95,
        BodyStyle.galaxy => 1.75,
        BodyStyle.earth || BodyStyle.venus || BodyStyle.cloud => 1.6,
        _ => 1.5,
      };

  // ------------------------------------------------------------ building blocks

  static void _sphereBase(Canvas canvas, Offset c, double r, Color primary, Color secondary) {
    _p.shader = ui.Gradient.radial(
      c + Offset(-r * 0.35, -r * 0.35),
      r * 1.6,
      [Color.lerp(primary, Colors.white, 0.35)!, primary, secondary],
      [0.0, 0.5, 1.0],
    );
    canvas.drawCircle(c, r, _p);
    _p.shader = null;
  }

  static void _shade(Canvas canvas, Offset c, double r) {
    _p.shader = ui.Gradient.radial(
      c + Offset(-r * 0.4, -r * 0.4),
      r * 2.0,
      [Colors.transparent, Colors.black.fade(0.65)],
      [0.45, 1.0],
    );
    canvas.drawCircle(c, r, _p);
    _p.shader = null;
  }

  /// Soft glow as a radial gradient (bounded and much cheaper than a blur).
  static void _glow(Canvas canvas, Offset c, double radius, Color color, double alpha, double blur) {
    final core = (1 - blur / math.max(radius, 1.0)).clamp(0.0, 0.85).toDouble();
    _blur.shader = ui.Gradient.radial(
      c,
      radius * 1.15,
      [color.fade(alpha), color.fade(alpha * 0.55), color.fade(0)],
      [0.0, core, 1.0],
    );
    canvas.drawCircle(c, radius * 1.15, _blur);
    _blur.shader = null;
  }

  static void _clipped(Canvas canvas, Offset c, double r, void Function() draw) {
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));
    draw();
    canvas.restore();
  }

  static Offset _randIn(math.Random rng, double radius) {
    final a = rng.nextDouble() * math.pi * 2;
    final d = math.sqrt(rng.nextDouble()) * radius;
    return Offset(math.cos(a) * d, math.sin(a) * d);
  }

  static double _wrap(double x, double r) => ((x + r) % (2 * r)) - r;

  static void _craters(Canvas canvas, Offset c, double r, math.Random rng, Color dark, int n) {
    for (var i = 0; i < n; i++) {
      final o = _randIn(rng, r * 0.85);
      final cr = r * (0.08 + rng.nextDouble() * 0.16);
      _p.color = dark.fade(0.6);
      canvas.drawCircle(c + o, cr, _p);
      _s
        ..color = Colors.white.fade(0.18)
        ..strokeWidth = 1;
      canvas.drawArc(Rect.fromCircle(center: c + o, radius: cr), math.pi * 0.9, math.pi * 0.9, false, _s);
    }
  }

  static void _bands(Canvas canvas, Offset c, double r, Color primary, Color secondary, math.Random rng,
      bool spot, double time,
      {bool soft = false}) {
    var y = -r;
    var i = 0;
    while (y < r) {
      final h = r * (0.12 + rng.nextDouble() * 0.16);
      _p.color = (i.isEven ? secondary : Color.lerp(primary, Colors.white, 0.25)!).fade(soft ? 0.25 : 0.55);
      final path = Path()..moveTo(c.dx - r, c.dy + y);
      for (var x = -r; x <= r; x += r / 5) {
        path.lineTo(c.dx + x, c.dy + y + math.sin(x / r * 3 + i + time * 0.4) * h * 0.15);
      }
      path
        ..lineTo(c.dx + r, c.dy + y + h)
        ..lineTo(c.dx - r, c.dy + y + h)
        ..close();
      canvas.drawPath(path, _p);
      y += h;
      i++;
    }
    if (spot) {
      final hsv = HSVColor.fromColor(primary);
      final cool = hsv.hue > 180 && hsv.hue < 270;
      _p.color = cool ? const Color(0xFF15215E) : const Color(0xFFC4502C);
      final sx = _wrap(r * 0.3 + time * 6, r);
      canvas.drawOval(Rect.fromCenter(center: c + Offset(sx, r * 0.3), width: r * 0.42, height: r * 0.24), _p);
    }
  }

  static void _ring(Canvas canvas, Offset c, double r, Color primary, Color secondary, double tilt,
      {required bool back}) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(tilt);
    final outer = Rect.fromCenter(center: Offset.zero, width: r * 4.2, height: r * 1.1);
    final inner = Rect.fromCenter(center: Offset.zero, width: r * 3.3, height: r * 0.85);
    final start = back ? math.pi : 0.0;
    _s
      ..color = Color.lerp(primary, Colors.white, 0.3)!.fade(back ? 0.45 : 0.8)
      ..strokeWidth = r * 0.22;
    canvas.drawArc(outer, start, math.pi, false, _s);
    _s
      ..color = secondary.fade(back ? 0.35 : 0.65)
      ..strokeWidth = r * 0.14;
    canvas.drawArc(inner, start, math.pi, false, _s);
    canvas.restore();
  }

  static void _sun(Canvas canvas, Offset c, double r, Color primary, Color secondary, double time) {
    _glow(canvas, c, r * 2.4, secondary, 0.35, r * 0.9);
    _glow(canvas, c, r * 1.6, primary, 0.55, r * 0.5);
    // Corona rays
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(time * 0.08);
    for (var i = 0; i < 14; i++) {
      final a = i / 14 * math.pi * 2;
      final len = r * (1.45 + 0.18 * math.sin(time * 2 + i * 1.7));
      final path = Path()
        ..moveTo(math.cos(a - 0.09) * r, math.sin(a - 0.09) * r)
        ..lineTo(math.cos(a) * len, math.sin(a) * len)
        ..lineTo(math.cos(a + 0.09) * r, math.sin(a + 0.09) * r)
        ..close();
      _p.color = primary.fade(0.35);
      canvas.drawPath(path, _p);
    }
    canvas.restore();
    _p.shader = ui.Gradient.radial(c, r, [const Color(0xFFFFFBE6), primary, secondary], [0.0, 0.6, 1.0]);
    canvas.drawCircle(c, r, _p);
    _p.shader = null;
    // Boiling surface
    final rng = math.Random(3);
    _clipped(canvas, c, r, () {
      for (var i = 0; i < 18; i++) {
        final o = _randIn(rng, r * 0.9);
        final k = 0.5 + 0.5 * math.sin(time * 3 + i * 2.1);
        _p.color = Colors.white.fade(0.12 * k);
        canvas.drawCircle(c + o, r * 0.14, _p);
      }
    });
  }

  static void _star(Canvas canvas, Offset c, double r, Color primary, Color secondary, double time, int seed) {
    final tw = 1 + 0.06 * math.sin(time * 5 + seed);
    _glow(canvas, c, r * 2.0 * tw, primary, 0.35, r * 0.8);
    _glow(canvas, c, r * 1.3, primary, 0.6, r * 0.35);
    _s
      ..color = secondary.fade(0.55)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final spike = r * 2.6 * tw;
    canvas.drawLine(c + Offset(-spike, 0), c + Offset(spike, 0), _s);
    canvas.drawLine(c + Offset(0, -spike), c + Offset(0, spike), _s);
    _s.strokeWidth = 1;
    final d = spike * 0.45;
    canvas.drawLine(c + Offset(-d, -d), c + Offset(d, d), _s);
    canvas.drawLine(c + Offset(-d, d), c + Offset(d, -d), _s);
    _s.strokeCap = StrokeCap.butt;
    _p.shader = ui.Gradient.radial(c, r, [Colors.white, secondary, primary], [0.0, 0.45, 1.0]);
    canvas.drawCircle(c, r, _p);
    _p.shader = null;
  }

  static void _nebula(Canvas canvas, Offset c, double r, Color primary, Color secondary, math.Random rng, double time) {
    for (var i = 0; i < 9; i++) {
      final o = _randIn(rng, r * 0.8);
      final pulse = 1 + 0.06 * math.sin(time * 1.2 + i);
      _glow(canvas, c + o, r * (0.45 + rng.nextDouble() * 0.45) * pulse, i.isEven ? primary : secondary, 0.38, r * 0.35);
    }
    for (var i = 0; i < 16; i++) {
      final o = _randIn(rng, r * 0.9);
      _p.color = Colors.white.fade(0.4 + 0.4 * (0.5 + 0.5 * math.sin(time * 3 + i)));
      canvas.drawCircle(c + o, 0.8 + rng.nextDouble() * 1.4, _p);
    }
    _glow(canvas, c, r * 0.3, Colors.white, 0.9, r * 0.15);
    _p.color = Colors.white;
    canvas.drawCircle(c, r * 0.12, _p);
  }

  static void _blackHole(Canvas canvas, Offset c, double r, Color primary, Color secondary, double tilt, double time) {
    void disk(bool back) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(tilt);
      final rect = Rect.fromCenter(center: Offset.zero, width: r * 3.6, height: r * 0.9);
      final start = back ? math.pi : 0.0;
      _s
        ..color = primary.fade(back ? 0.14 : 0.22)
        ..strokeWidth = r * 0.6;
      canvas.drawArc(rect, start, math.pi, false, _s);
      _s
        ..color = primary.fade(back ? 0.22 : 0.35)
        ..strokeWidth = r * 0.38;
      canvas.drawArc(rect, start, math.pi, false, _s);
      _s
        ..color = Color.lerp(primary, secondary, 0.5 + 0.5 * math.sin(time * 4))!.fade(back ? 0.6 : 0.95)
        ..strokeWidth = r * 0.22;
      canvas.drawArc(rect, start, math.pi, false, _s);
      canvas.restore();
    }

    _glow(canvas, c, r * 1.6, primary, 0.3, r * 0.6);
    disk(true);
    _p.color = Colors.black;
    canvas.drawCircle(c, r * 0.8, _p);
    _s
      ..color = secondary.fade(0.9)
      ..strokeWidth = 2;
    canvas.drawCircle(c, r * 0.82, _s);
    // Light bent over the top of the hole
    _s
      ..color = primary.fade(0.6)
      ..strokeWidth = r * 0.12;
    canvas.drawArc(Rect.fromCircle(center: c, radius: r * 0.98), math.pi * 1.1, math.pi * 0.8, false, _s);
    disk(false);
  }

  static void _galaxy(Canvas canvas, Offset c, double r, Color primary, Color secondary, double tilt,
      math.Random rng, double time) {
    _glow(canvas, c, r * 1.2, primary, 0.25, r * 0.6);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(tilt);
    canvas.scale(1, 0.62);
    canvas.rotate(time * 0.12);
    for (var arm = 0; arm < 2; arm++) {
      for (var i = 0; i < 70; i++) {
        final t = i / 70;
        final theta = t * math.pi * 3 + arm * math.pi;
        final rr = r * 1.35 * t + r * 0.08;
        final jitter = _randIn(rng, r * 0.12 * (0.4 + t));
        final pos = Offset(math.cos(theta) * rr, math.sin(theta) * rr) + jitter;
        _p.color = Color.lerp(secondary, primary, t)!.fade(0.9 - 0.6 * t);
        canvas.drawCircle(pos, 0.7 + rng.nextDouble() * 1.6 * (1 - t * 0.5), _p);
      }
    }
    canvas.restore();
    _glow(canvas, c, r * 0.4, secondary, 0.9, r * 0.25);
    _p.color = Colors.white;
    canvas.drawCircle(c, r * 0.1, _p);
  }

  static void _probe(Canvas canvas, Offset c, double r, Color primary, Color secondary, double time) {
    final pulse = 0.5 + 0.5 * math.sin(time * 3);
    _s
      ..color = secondary.fade(0.25 + 0.4 * pulse)
      ..strokeWidth = 2;
    canvas.drawCircle(c, r * (0.95 + 0.1 * pulse), _s);
    _glow(canvas, c, r * 0.8, secondary, 0.25, r * 0.4);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-0.5 + math.sin(time * 0.5) * 0.1);
    _s
      ..color = primary.fade(0.9)
      ..strokeWidth = 1.6;
    // booms
    canvas.drawLine(Offset(-r * 0.15, 0), Offset(-r * 0.95, r * 0.2), _s);
    canvas.drawLine(Offset(r * 0.15, 0), Offset(r * 0.85, -r * 0.35), _s);
    canvas.drawLine(Offset.zero, Offset(0, r * 0.9), _s);
    // dish
    _p.color = primary;
    canvas.drawOval(Rect.fromCenter(center: Offset(0, -r * 0.18), width: r * 0.95, height: r * 0.42), _p);
    _p.color = Color.lerp(primary, Colors.black, 0.35)!;
    canvas.drawOval(Rect.fromCenter(center: Offset(0, -r * 0.2), width: r * 0.7, height: r * 0.26), _p);
    // bus
    _p.color = secondary;
    canvas.drawRect(Rect.fromCenter(center: Offset(0, r * 0.12), width: r * 0.32, height: r * 0.22), _p);
    canvas.restore();
  }
}
