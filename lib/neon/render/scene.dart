import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../engine/hazards.dart';
import '../engine/neon_world.dart';
import '../engine/tuning.dart';
import 'fx.dart';
import 'palette.dart';

/// Everything the scene needs for one frame.
class SceneFrame {
  SceneFrame({
    required this.world,
    required this.palette,
    required this.skin,
    required this.trail,
    required this.trailX,
    required this.trailY,
    required this.time,
    required this.renderS,
    required this.orbY,
    required this.particles,
    required this.rings,
    required this.floaters,
    required this.reduced,
    required this.highContrast,
    required this.chaseFront,
    required this.dashGlow,
  });

  final NeonWorld world;
  final NeonPalette palette;
  final SkinLook skin;
  final String trail;
  final List<double> trailX, trailY;
  final double time;
  final double renderS;
  final double orbY;
  final Particles particles;
  final Rings rings;
  final Floaters floaters;
  final bool reduced;
  final bool highContrast;

  /// 0 = no energy wave, 1 = right behind the orb.
  final double chaseFront;
  final double dashGlow;
}

/// Draws the corridor, hazards, shards, orb and effects with stroked
/// "neon tube" lines (several widths and alphas — no blur filters, which
/// are too slow per frame on mid-range phones).
class NeonScene {
  final Paint _fill = Paint()..isAntiAlias = true;
  final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;
  final Paint _sprite = Paint()..filterQuality = FilterQuality.low;
  final Path _path = Path();
  final Path _path2 = Path();
  ui.Image? _glow;
  final Map<String, TextPainter> _labels = {};

  double w = 0, h = 0, unit = 1, top = 0, orbX = 0, s = 0;

  double sx(double x) => orbX + (x - s) * unit;
  double sy(double y) => top + y * unit;

  /// Corridor layout: 74% of the height, but never so tall that less than
  /// 2.1 units of corridor are visible ahead of the orb.
  void layout(Size size) {
    w = size.width;
    h = size.height;
    orbX = w * 0.22;
    unit = math.min(h * 0.74, (w - orbX) / 2.1);
    top = (h - unit) / 2 + h * 0.01;
  }

  ui.Image _glowImage() {
    final cached = _glow;
    if (cached != null) return cached;
    const size = 128.0;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        const Offset(size / 2, size / 2),
        size / 2,
        [const Color(0xFFFFFFFF), const Color(0x66FFFFFF), const Color(0x00FFFFFF)],
        [0, 0.3, 1],
      );
    c.drawCircle(const Offset(size / 2, size / 2), size / 2, paint);
    return _glow = rec.endRecording().toImageSync(size.toInt(), size.toInt());
  }

  void _glowAt(Canvas canvas, double x, double y, double radius, Color color) {
    final img = _glowImage();
    _sprite.colorFilter = ColorFilter.mode(color, BlendMode.modulate);
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Rect.fromCircle(center: Offset(x, y), radius: radius),
      _sprite,
    );
  }

  /// A neon tube: soft halo, colour body, hot white core.
  void _tube(Canvas canvas, Path p, Color color, double width, {bool reduced = false, int alpha = 255}) {
    if (!reduced) {
      _stroke
        ..color = color.withAlpha((28 * alpha / 255).round())
        ..strokeWidth = width * 5;
      canvas.drawPath(p, _stroke);
    }
    _stroke
      ..color = color.withAlpha((90 * alpha / 255).round())
      ..strokeWidth = width * 2.4;
    canvas.drawPath(p, _stroke);
    _stroke
      ..color = color.withAlpha(alpha)
      ..strokeWidth = width;
    canvas.drawPath(p, _stroke);
    _stroke
      ..color = const Color(0xFFFFFFFF).withAlpha((170 * alpha / 255).round())
      ..strokeWidth = math.max(0.8, width * 0.35);
    canvas.drawPath(p, _stroke);
  }

  TextPainter _label(String text, Color color, double size) {
    final key = '$text|${color.toARGB32()}|${size.round()}';
    return _labels[key] ??= (TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w800, letterSpacing: 2),
      ),
      textDirection: TextDirection.ltr,
    )..layout());
  }

  // ------------------------------------------------------------- render

  void render(Canvas canvas, SceneFrame f) {
    s = f.renderS;
    final pal = f.palette;
    final lw = math.max(1.5, unit * 0.008) * (f.highContrast ? 1.6 : 1);

    _background(canvas, f, pal);
    final x0 = s - orbX / unit - 0.1;
    final x1 = s + (w - orbX) / unit + 0.1;

    for (final c in f.world.chunks) {
      if (c.x1 < x0 || c.x0 > x1) continue;
      _riskZone(canvas, c, pal);
    }
    _walls(canvas, f, pal, x0, x1, lw);
    for (final c in f.world.chunks) {
      if (c.x1 < x0 || c.x0 > x1) continue;
      for (final p in c.platforms) {
        _platform(canvas, p, pal, lw, f.reduced);
      }
      for (final hz in c.hazards) {
        if (hz.right < x0 || hz.left > x1) continue;
        _hazard(canvas, hz, pal, lw, f);
      }
      _shards(canvas, c, pal, f);
    }

    _trail(canvas, f, pal);
    if (f.world.alive) _orb(canvas, f);
    f.rings.render(canvas, _fill, sx, sy, unit);
    _fill.style = PaintingStyle.fill;
    f.particles.render(canvas, _fill, sx, sy, unit);
    f.floaters.render(canvas, sx, sy);
    if (f.chaseFront > 0) _chaseWave(canvas, f, pal);
  }

  void _background(Canvas canvas, SceneFrame f, NeonPalette pal) {
    final full = Rect.fromLTWH(-40, -40, w + 80, h + 80);
    _fill
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFFFFFFF) // a shader still uses the paint's alpha
      ..shader = ui.Gradient.linear(Offset(0, 0), Offset(0, h), [pal.bgTop, pal.bgBottom]);
    canvas.drawRect(full, _fill);
    _fill.shader = null;
    if (f.highContrast) return;

    final ct = sy(0), cb = sy(1);
    // Perspective rays to a vanishing point far ahead: depth.
    final vx = w * 1.25, vy = (ct + cb) / 2;
    _stroke
      ..strokeWidth = 1
      ..color = pal.grid.withAlpha(60);
    for (var i = 0; i <= 8; i++) {
      final y = ct + (cb - ct) * i / 8;
      canvas.drawLine(Offset(-20, y), Offset(vx, vy + (y - vy) * 0.15), _stroke);
    }
    // Scrolling vertical grid, with FLUX making it ripple.
    final flux = f.world.activeBreak == BreakVariant.flux;
    const spacing = 0.4;
    const parallax = 0.55;
    final first = ((s * parallax - orbX / unit) / spacing).floor() - 1;
    final last = ((s * parallax + (w - orbX) / unit) / spacing).ceil() + 1;
    _stroke.color = pal.grid.withAlpha(90);
    for (var k = first; k <= last; k++) {
      final x = orbX + (k * spacing - s * parallax) * unit;
      if (flux && !f.reduced) {
        _path.reset();
        for (var j = 0; j <= 10; j++) {
          final y = ct + (cb - ct) * j / 10;
          final dx = math.sin(j * 0.9 + f.time * 3 + k) * unit * 0.03;
          if (j == 0) {
            _path.moveTo(x + dx, y);
          } else {
            _path.lineTo(x + dx, y);
          }
        }
        canvas.drawPath(_path, _stroke);
      } else {
        canvas.drawLine(Offset(x, ct), Offset(x, cb), _stroke);
      }
    }
    // Slow parallax diamonds deep in the background.
    if (!f.reduced) {
      _stroke
        ..color = pal.accent.withAlpha(26)
        ..strokeWidth = 2;
      const dsp = 1.7;
      const dpar = 0.22;
      final d0 = ((s * dpar - orbX / unit) / dsp).floor() - 1;
      final d1 = ((s * dpar + (w - orbX) / unit) / dsp).ceil() + 1;
      for (var k = d0; k <= d1; k++) {
        final cx = orbX + (k * dsp - s * dpar) * unit;
        final cy = vy + math.sin(k * 1.7) * unit * 0.12;
        final r = unit * (0.32 + 0.1 * math.sin(k * 2.3));
        _path
          ..reset()
          ..moveTo(cx, cy - r)
          ..lineTo(cx + r, cy)
          ..lineTo(cx, cy + r)
          ..lineTo(cx - r, cy)
          ..close();
        canvas.drawPath(_path, _stroke);
      }
    }
  }

  void _walls(Canvas canvas, SceneFrame f, NeonPalette pal, double x0, double x1, double lw) {
    final world = f.world;
    const step = 0.06;
    _path.reset();
    _path2.reset();
    var first = true;
    for (var x = x0; x <= x1 + step; x += step) {
      final c = world.chunkAt(x);
      final tx = sx(x), ty = sy(c.top(x)), by = sy(c.bot(x));
      if (first) {
        _path.moveTo(tx, ty);
        _path2.moveTo(tx, by);
        first = false;
      } else {
        _path.lineTo(tx, ty);
        _path2.lineTo(tx, by);
      }
    }
    // Solid bands beyond the walls keep the HUD readable.
    final band = Color.lerp(pal.bgTop, const Color(0xFF000000), 0.35)!;
    final upper = Path.from(_path)
      ..lineTo(sx(x1 + step), -40)
      ..lineTo(sx(x0), -40)
      ..close();
    final lower = Path.from(_path2)
      ..lineTo(sx(x1 + step), h + 40)
      ..lineTo(sx(x0), h + 40)
      ..close();
    _fill
      ..style = PaintingStyle.fill
      ..color = band;
    canvas.drawPath(upper, _fill);
    canvas.drawPath(lower, _fill);
    _fill.color = pal.wall.withAlpha(14);
    canvas.drawPath(upper, _fill);
    canvas.drawPath(lower, _fill);

    _tube(canvas, _path, pal.wall, lw, reduced: f.reduced);
    _tube(canvas, _path2, pal.wall, lw, reduced: f.reduced);

    // Speed ticks running along both walls.
    _stroke
      ..color = pal.wall.withAlpha(110)
      ..strokeWidth = math.max(1, lw * 0.6);
    const tick = 0.3;
    for (var k = (x0 / tick).floor(); k <= (x1 / tick).ceil(); k++) {
      final x = k * tick;
      final c = world.chunkAt(x);
      final px = sx(x);
      final ty = sy(c.top(x)), by = sy(c.bot(x));
      canvas.drawLine(Offset(px, ty - unit * 0.012), Offset(px - unit * 0.03, ty - unit * 0.04), _stroke);
      canvas.drawLine(Offset(px, by + unit * 0.012), Offset(px - unit * 0.03, by + unit * 0.04), _stroke);
    }
  }

  void _riskZone(Canvas canvas, Chunk c, NeonPalette pal) {
    final riskTop = c.riskTop;
    if (riskTop == null) return;
    final mid = (c.top(c.riskX0) + c.bot(c.riskX0)) / 2;
    final y0 = riskTop ? c.top(c.riskX0) : mid;
    final y1 = riskTop ? mid : c.bot(c.riskX0);
    _fill
      ..style = PaintingStyle.fill
      ..color = pal.risk.withAlpha(18);
    canvas.drawRect(Rect.fromLTRB(sx(c.riskX0), sy(y0), sx(c.riskX1), sy(y1)), _fill);
    final risk = _label('RISK ×2', pal.risk, math.max(10, unit * 0.045));
    final safe = _label('SAFE', pal.wall.withAlpha(170), math.max(10, unit * 0.04));
    final lx = sx(c.riskX0) - unit * 0.42;
    final riskY = sy((y0 + y1) / 2);
    final safeY = sy(riskTop ? (mid + c.bot(c.riskX0)) / 2 : (c.top(c.riskX0) + mid) / 2);
    risk.paint(canvas, Offset(lx - risk.width / 2, riskY - risk.height / 2));
    safe.paint(canvas, Offset(lx - safe.width / 2, safeY - safe.height / 2));
  }

  void _platform(Canvas canvas, Platform p, NeonPalette pal, double lw, bool reduced) {
    final r = Rect.fromLTRB(sx(p.x0), sy(p.y0), sx(p.x1), sy(p.y1));
    _fill
      ..style = PaintingStyle.fill
      ..color = pal.accent.withAlpha(70);
    canvas.drawRect(r, _fill);
    _path
      ..reset()
      ..addRect(r);
    _tube(canvas, _path, pal.accent, lw * 0.8, reduced: reduced);
  }

  void _hazard(Canvas canvas, Hazard hz, NeonPalette pal, double lw, SceneFrame f) {
    final color = hz.dashable ? pal.dash : pal.solid;
    final alpha = hz.pierced ? 60 : 255;
    final reduced = f.reduced;
    switch (hz) {
      case final Spike sp:
        _path
          ..reset()
          ..moveTo(sx(sp.x), sy(sp.baseY))
          ..lineTo(sx(sp.x + sp.width / 2), sy(sp.apexY))
          ..lineTo(sx(sp.x + sp.width), sy(sp.baseY))
          ..close();
        _filled(canvas, _path, color, alpha);
        _tube(canvas, _path, color, lw, reduced: reduced, alpha: alpha);
        _innerMark(canvas, sp.x + sp.width / 2, (sp.baseY * 2 + sp.apexY) / 3, sp.width * 0.16, color, alpha);
      case final Block bk:
        _path
          ..reset()
          ..addRect(Rect.fromLTRB(sx(bk.x0), sy(bk.y0), sx(bk.x1), sy(bk.y1)));
        _filled(canvas, _path, color, alpha);
        _tube(canvas, _path, color, lw, reduced: reduced, alpha: alpha);
        _innerMark(canvas, (bk.x0 + bk.x1) / 2, (bk.y0 + bk.y1) / 2, 0.03, color, alpha);
      case final Laser lz:
        _laser(canvas, lz, color, lw, f);
      case final Mover mv:
        final (a, b) = mv.span(s);
        // Rail showing the full travel: readable before it moves.
        _stroke
          ..color = color.withAlpha(40)
          ..strokeWidth = math.max(1, lw * 0.6);
        final cx = sx((mv.x0 + mv.x1) / 2);
        final (r0, r1) = switch (mv.mode) {
          MoverMode.float => (mv.center - mv.amplitude - mv.halfHeight, mv.center + mv.amplitude + mv.halfHeight),
          MoverMode.pistonFloor => (mv.wallY - mv.maxLength, mv.wallY),
          MoverMode.pistonCeiling => (mv.wallY, mv.wallY + mv.maxLength),
        };
        canvas.drawLine(Offset(cx, sy(r0)), Offset(cx, sy(r1)), _stroke);
        _path
          ..reset()
          ..addRect(Rect.fromLTRB(sx(mv.x0), sy(a), sx(mv.x1), sy(b)));
        _filled(canvas, _path, color, alpha);
        _tube(canvas, _path, color, lw, reduced: reduced, alpha: alpha);
        _innerMark(canvas, (mv.x0 + mv.x1) / 2, (a + b) / 2, 0.03, color, alpha);
      case final Rotor ro:
        final (ax, ay, bx, by) = ro.ends(s);
        _stroke
          ..color = color.withAlpha(30)
          ..strokeWidth = 1.5;
        canvas.drawCircle(Offset(sx(ro.cx), sy(ro.cy)), ro.halfLength * unit, _stroke);
        _path
          ..reset()
          ..moveTo(sx(ax), sy(ay))
          ..lineTo(sx(bx), sy(by));
        _tube(canvas, _path, color, ro.thickness * unit * 1.6, reduced: reduced);
        _fill
          ..style = PaintingStyle.fill
          ..color = const Color(0xFFFFFFFF);
        canvas.drawCircle(Offset(sx(ro.cx), sy(ro.cy)), ro.thickness * unit * 1.2, _fill);
      case final Nose no:
        _path
          ..reset()
          ..moveTo(sx(no.x - Nose.length), sy(no.y))
          ..lineTo(sx(no.x + 0.01), sy(no.y - no.halfHeight))
          ..lineTo(sx(no.x + 0.01), sy(no.y + no.halfHeight))
          ..close();
        _filled(canvas, _path, color, alpha);
        _tube(canvas, _path, color, lw, reduced: reduced);
    }
  }

  void _filled(Canvas canvas, Path p, Color color, int alpha) {
    _fill
      ..style = PaintingStyle.fill
      ..color = color.withAlpha((50 * alpha / 255).round());
    canvas.drawPath(p, _fill);
  }

  /// The small hollow diamond on dashable hazards (a shape cue, not just
  /// colour, for colour-blind players).
  void _innerMark(Canvas canvas, double x, double y, double r, Color color, int alpha) {
    final cx = sx(x), cy = sy(y), rr = r * unit;
    _path2
      ..reset()
      ..moveTo(cx, cy - rr)
      ..lineTo(cx + rr, cy)
      ..lineTo(cx, cy + rr)
      ..lineTo(cx - rr, cy)
      ..close();
    _stroke
      ..color = const Color(0xFFFFFFFF).withAlpha((200 * alpha / 255).round())
      ..strokeWidth = math.max(1, unit * 0.005);
    canvas.drawPath(_path2, _stroke);
  }

  void _laser(Canvas canvas, Laser l, Color color, double lw, SceneFrame f) {
    final x = sx(l.x);
    final y0 = sy(l.y0), y1 = sy(l.y1);
    // Emitters.
    _fill
      ..style = PaintingStyle.fill
      ..color = color;
    final ew = unit * 0.05, eh = unit * 0.022;
    canvas.drawRect(Rect.fromCenter(center: Offset(x, y0 + eh / 2), width: ew, height: eh), _fill);
    canvas.drawRect(Rect.fromCenter(center: Offset(x, y1 - eh / 2), width: ew, height: eh), _fill);
    if (l.active(s)) {
      _path
        ..reset()
        ..moveTo(x, y0)
        ..lineTo(x, y1);
      _tube(canvas, _path, color, Laser.halfWidth * unit * 1.4, reduced: f.reduced);
      return;
    }
    final warn = l.warning(s);
    if (warn > 0) {
      final flicker = f.reduced ? 1.0 : (0.6 + 0.4 * math.sin(f.time * 60));
      _stroke
        ..color = color.withAlpha((40 + 170 * warn * flicker).round())
        ..strokeWidth = math.max(1, lw * 0.6);
      canvas.drawLine(Offset(x, y0), Offset(x, y1), _stroke);
    } else {
      _stroke
        ..color = color.withAlpha(36)
        ..strokeWidth = 1;
      final dash = unit * 0.03;
      for (var y = y0; y < y1; y += dash * 2) {
        canvas.drawLine(Offset(x, y), Offset(x, math.min(y1, y + dash)), _stroke);
      }
    }
  }

  void _shards(Canvas canvas, Chunk c, NeonPalette pal, SceneFrame f) {
    final r = unit * 0.03;
    for (final sh in c.shards) {
      if (sh.collected) continue;
      final x = sx(sh.x), y = sy(sh.y);
      if (x < -r * 4 || x > w + r * 4) continue;
      final color = sh.risk ? pal.risk : pal.shard;
      if (!f.reduced) _glowAt(canvas, x, y, r * 3.2, color.withAlpha(120));
      final spin = math.cos(f.time * 4 + sh.x * 3).abs() * 0.7 + 0.3;
      _path
        ..reset()
        ..moveTo(x, y - r)
        ..lineTo(x + r * spin, y)
        ..lineTo(x, y + r)
        ..lineTo(x - r * spin, y)
        ..close();
      _fill
        ..style = PaintingStyle.fill
        ..color = color;
      canvas.drawPath(_path, _fill);
      _stroke
        ..color = const Color(0xFFFFFFFF)
        ..strokeWidth = 1;
      canvas.drawPath(_path, _stroke);
    }
  }

  void _trail(Canvas canvas, SceneFrame f, NeonPalette pal) {
    final n = f.trailX.length;
    if (n < 2) return;
    final color = f.world.dashing ? pal.dash : f.skin.glowAt(f.time);
    final r = Tune.orbRadius * unit;
    switch (f.trail) {
      case 'dots':
        _fill.style = PaintingStyle.fill;
        for (var i = 0; i < n; i += 2) {
          final k = i / n;
          _fill.color = color.withAlpha((200 * k).round());
          canvas.drawCircle(Offset(sx(f.trailX[i]), sy(f.trailY[i])), r * 0.35 * (0.4 + k), _fill);
        }
      case 'ribbon':
        _fill.style = PaintingStyle.fill;
        for (var i = 1; i < n; i++) {
          final k = i / n;
          final hw0 = r * 0.9 * ((i - 1) / n), hw1 = r * 0.9 * k;
          final ax = sx(f.trailX[i - 1]), ay = sy(f.trailY[i - 1]);
          final bx = sx(f.trailX[i]), by = sy(f.trailY[i]);
          _path
            ..reset()
            ..moveTo(ax, ay - hw0)
            ..lineTo(bx, by - hw1)
            ..lineTo(bx, by + hw1)
            ..lineTo(ax, ay + hw0)
            ..close();
          _fill.color = color.withAlpha((120 * k).round());
          canvas.drawPath(_path, _fill);
        }
      case 'echo':
        _stroke.strokeWidth = 1.5;
        for (var i = n - 6; i >= 0; i -= 6) {
          final k = i / n;
          _stroke.color = color.withAlpha((150 * k).round());
          canvas.drawCircle(Offset(sx(f.trailX[i]), sy(f.trailY[i])), r * (0.6 + 0.4 * k), _stroke);
        }
      default: // streak (and sparks, which adds particles on top)
        for (var i = 1; i < n; i++) {
          final k = i / n;
          _stroke
            ..color = color.withAlpha((200 * k).round())
            ..strokeWidth = r * 1.3 * k + 1;
          canvas.drawLine(
            Offset(sx(f.trailX[i - 1]), sy(f.trailY[i - 1])),
            Offset(sx(f.trailX[i]), sy(f.trailY[i])),
            _stroke,
          );
        }
    }
  }

  void _orb(Canvas canvas, SceneFrame f) {
    final world = f.world;
    final x = orbX, y = sy(f.orbY);
    final r = Tune.orbRadius * unit;
    final skin = f.skin;
    final glow = world.dashing ? const Color(0xFFFF3DCB) : skin.glowAt(f.time);
    final t = f.time;

    // Squash & stretch with vertical speed.
    final stretch = (world.orb.vy.abs() / Tune.maxFall).clamp(0.0, 1.0);
    canvas.save();
    canvas.translate(x, y);
    canvas.scale(1 - 0.14 * stretch, 1 + 0.24 * stretch);

    final pulse = 1 + 0.06 * math.sin(t * 7);
    _glowAt(canvas, 0, 0, r * (f.reduced ? 2.6 : 3.6) * pulse * (1 + f.dashGlow * 0.6), glow.withAlpha(170));

    _stroke
      ..strokeWidth = math.max(1.5, r * 0.14)
      ..color = glow.withAlpha(220);
    switch (skin.style) {
      case 'nova':
        for (var k = 0; k < 4; k++) {
          final a = t * 2 + k * math.pi / 2;
          canvas.drawLine(Offset(math.cos(a) * r * 1.1, math.sin(a) * r * 1.1),
              Offset(math.cos(a) * r * 1.9, math.sin(a) * r * 1.9), _stroke);
        }
      case 'plasma':
        final rect = Rect.fromCircle(center: Offset.zero, radius: r * 1.5);
        canvas.drawArc(rect, t * 5, 1.2, false, _stroke);
        canvas.drawArc(rect, t * 5 + math.pi, 1.2, false, _stroke);
      case 'venom':
        _fill
          ..style = PaintingStyle.fill
          ..color = glow;
        for (var k = 0; k < 6; k++) {
          final a = t * 0.8 + k * math.pi / 3;
          final ca = math.cos(a), sa = math.sin(a);
          _path
            ..reset()
            ..moveTo(ca * r * 1.6, sa * r * 1.6)
            ..lineTo(math.cos(a + 0.3) * r * 0.95, math.sin(a + 0.3) * r * 0.95)
            ..lineTo(math.cos(a - 0.3) * r * 0.95, math.sin(a - 0.3) * r * 0.95)
            ..close();
          canvas.drawPath(_path, _fill);
        }
      case 'ghost':
        canvas.drawCircle(Offset.zero, r * 1.0, _stroke);
        _stroke.color = glow.withAlpha(70);
        canvas.drawCircle(Offset.zero, r * 0.55, _stroke);
      default: // pulse, prism
        _stroke.color = glow.withAlpha(140);
        canvas.drawCircle(Offset.zero, r * (1.3 + 0.18 * math.sin(t * 6)), _stroke);
    }

    if (skin.style != 'ghost') {
      _fill
        ..style = PaintingStyle.fill
        ..color = glow;
      canvas.drawCircle(Offset.zero, r, _fill);
      _fill.color = skin.core;
      canvas.drawCircle(Offset.zero, r * 0.68, _fill);
    }
    canvas.restore();
  }

  void _chaseWave(Canvas canvas, SceneFrame f, NeonPalette pal) {
    final k = f.chaseFront.clamp(0.0, 1.0);
    // The wave lives in the space behind the orb and creeps toward it.
    final front = orbX * (0.08 + 0.62 * k) + math.sin(f.time * 6) * unit * 0.02;
    final color = pal.dash;
    _fill
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFFFFFFF)
      ..shader = ui.Gradient.linear(
        Offset(front - unit * 0.9, 0),
        Offset(front, 0),
        [color.withAlpha(0), color.withAlpha((110 * k).round() + 40)],
      );
    canvas.drawRect(Rect.fromLTRB(-40, sy(0) - unit * 0.05, front, sy(1) + unit * 0.05), _fill);
    _fill.shader = null;
    _path.reset();
    for (var j = 0; j <= 24; j++) {
      final yy = sy(0) + unit * j / 24;
      final xx = front + math.sin(j * 1.9 + f.time * (f.reduced ? 4 : 18)) * unit * 0.02;
      if (j == 0) {
        _path.moveTo(xx, yy);
      } else {
        _path.lineTo(xx, yy);
      }
    }
    _tube(canvas, _path, color, math.max(2, unit * 0.01), reduced: f.reduced);
  }
}
