import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// Fixed-size particle pool in world units (no per-frame allocation).
class Particles {
  Particles(this.capacity)
      : _x = List.filled(capacity, 0),
        _y = List.filled(capacity, 0),
        _vx = List.filled(capacity, 0),
        _vy = List.filled(capacity, 0),
        _life = List.filled(capacity, 0),
        _max = List.filled(capacity, 1),
        _size = List.filled(capacity, 0),
        _color = List.filled(capacity, const Color(0xFFFFFFFF));

  final int capacity;
  final List<double> _x, _y, _vx, _vy, _life, _max, _size;
  final List<Color> _color;
  final math.Random _rng = math.Random(3);
  int _next = 0;

  /// Lower in reduced-effects mode.
  double budget = 1;

  void burst(double x, double y, Color color, int count, {double speed = 1.2, double size = 0.012, double life = 0.5}) {
    final n = (count * budget).round();
    for (var i = 0; i < n; i++) {
      final a = _rng.nextDouble() * math.pi * 2;
      final v = speed * (0.3 + _rng.nextDouble() * 0.7);
      _spawn(x, y, math.cos(a) * v, math.sin(a) * v, color, size * (0.6 + _rng.nextDouble() * 0.8),
          life * (0.6 + _rng.nextDouble() * 0.6));
    }
  }

  /// A spray mostly in one direction (dust off a wall, dash sparks).
  void spray(double x, double y, double dirX, double dirY, Color color, int count,
      {double spread = 0.8, double speed = 1, double size = 0.01, double life = 0.4}) {
    final n = (count * budget).round();
    final base = math.atan2(dirY, dirX);
    for (var i = 0; i < n; i++) {
      final a = base + (_rng.nextDouble() - 0.5) * spread;
      final v = speed * (0.4 + _rng.nextDouble() * 0.6);
      _spawn(x, y, math.cos(a) * v, math.sin(a) * v, color, size * (0.6 + _rng.nextDouble() * 0.8),
          life * (0.6 + _rng.nextDouble() * 0.6));
    }
  }

  void _spawn(double x, double y, double vx, double vy, Color c, double size, double life) {
    final i = _next;
    _next = (_next + 1) % capacity;
    _x[i] = x;
    _y[i] = y;
    _vx[i] = vx;
    _vy[i] = vy;
    _color[i] = c;
    _size[i] = size;
    _life[i] = life;
    _max[i] = life;
  }

  void update(double dt) {
    final drag = math.pow(0.08, dt).toDouble();
    for (var i = 0; i < capacity; i++) {
      if (_life[i] <= 0) continue;
      _life[i] -= dt;
      _x[i] += _vx[i] * dt;
      _y[i] += _vy[i] * dt;
      _vx[i] *= drag;
      _vy[i] *= drag;
    }
  }

  void render(Canvas canvas, Paint paint, double Function(double) sx, double Function(double) sy, double unit) {
    for (var i = 0; i < capacity; i++) {
      final l = _life[i];
      if (l <= 0) continue;
      final k = (l / _max[i]).clamp(0.0, 1.0);
      paint.color = _color[i].withAlpha((255 * k).round());
      canvas.drawCircle(Offset(sx(_x[i]), sy(_y[i])), _size[i] * unit * (0.5 + 0.5 * k), paint);
    }
  }

  void clear() {
    for (var i = 0; i < capacity; i++) {
      _life[i] = 0;
    }
  }
}

class _Ring {
  double x = 0, y = 0, life = 0, max = 1, radius = 0.2;
  Color color = const Color(0xFFFFFFFF);
}

/// Expanding shockwave rings.
class Rings {
  final List<_Ring> _rings = List.generate(10, (_) => _Ring());
  int _next = 0;

  void add(double x, double y, Color color, {double radius = 0.25, double life = 0.35}) {
    final r = _rings[_next];
    _next = (_next + 1) % _rings.length;
    r
      ..x = x
      ..y = y
      ..color = color
      ..radius = radius
      ..life = life
      ..max = life;
  }

  void update(double dt) {
    for (final r in _rings) {
      if (r.life > 0) r.life -= dt;
    }
  }

  void render(Canvas canvas, Paint paint, double Function(double) sx, double Function(double) sy, double unit) {
    paint.style = PaintingStyle.stroke;
    for (final r in _rings) {
      if (r.life <= 0) continue;
      final k = 1 - r.life / r.max;
      paint
        ..color = r.color.withAlpha((200 * (1 - k)).round())
        ..strokeWidth = unit * 0.012 * (1 - k) + 1;
      canvas.drawCircle(Offset(sx(r.x), sy(r.y)), r.radius * unit * (0.2 + k), paint);
    }
    paint.style = PaintingStyle.fill;
  }

  void clear() {
    for (final r in _rings) {
      r.life = 0;
    }
  }
}

class _Floater {
  double x = 0, y = 0, life = 0;
  String text = '';
  Color color = const Color(0xFFFFFFFF);
  double size = 14;
}

/// Little "+25 NEAR MISS" labels that drift up from where they happened.
/// Text layouts are cached, so repeated labels cost nothing.
class Floaters {
  final List<_Floater> _items = List.generate(8, (_) => _Floater());
  final Map<String, TextPainter> _cache = {};
  int _next = 0;

  void add(double x, double y, String text, Color color, {double size = 14}) {
    final f = _items[_next];
    _next = (_next + 1) % _items.length;
    f
      ..x = x
      ..y = y
      ..text = text
      ..color = color
      ..size = size
      ..life = 0.9;
  }

  void update(double dt) {
    for (final f in _items) {
      if (f.life > 0) {
        f.life -= dt;
        f.y -= dt * 0.25;
      }
    }
  }

  TextPainter _painter(String text, Color color, double size) {
    final key = '$text|${color.toARGB32()}|$size';
    final hit = _cache[key];
    if (hit != null) return hit;
    if (_cache.length > 40) _cache.clear();
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          shadows: [Shadow(color: color.withAlpha(180), blurRadius: 8)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    return _cache[key] = tp;
  }

  void render(Canvas canvas, double Function(double) sx, double Function(double) sy) {
    for (final f in _items) {
      if (f.life <= 0) continue;
      final tp = _painter(f.text, f.color, f.size);
      final a = (f.life / 0.3).clamp(0.0, 1.0);
      final o = Offset(sx(f.x) - tp.width / 2, sy(f.y) - tp.height / 2);
      if (a >= 1) {
        tp.paint(canvas, o);
      } else {
        canvas.saveLayer(
          Rect.fromLTWH(o.dx - 10, o.dy - 10, tp.width + 20, tp.height + 20),
          Paint()..color = Color.fromARGB((255 * a).round(), 255, 255, 255),
        );
        tp.paint(canvas, o);
        canvas.restore();
      }
    }
  }

  void clear() {
    for (final f in _items) {
      f.life = 0;
    }
  }
}

/// Decaying screen shake.
class Shake {
  double _t = 0, _power = 0;
  final math.Random _rng = math.Random(9);
  bool enabled = true;

  void kick(double power) {
    if (!enabled) return;
    _power = math.max(_power, power);
    _t = 0.25;
  }

  void update(double dt) {
    if (_t > 0) {
      _t -= dt;
      if (_t <= 0) _power = 0;
    }
  }

  Offset get offset {
    if (_t <= 0) return Offset.zero;
    final k = _power * (_t / 0.25);
    return Offset((_rng.nextDouble() - 0.5) * 2 * k, (_rng.nextDouble() - 0.5) * 2 * k);
  }
}
