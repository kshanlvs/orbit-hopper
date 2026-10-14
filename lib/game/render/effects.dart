import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'sprites.dart';

class _Particle {
  _Particle(this.position, this.velocity, this.life, this.size, this.color) : maxLife = life;

  Offset position;
  Offset velocity;
  double life;
  final double maxLife;
  final double size;
  final Color color;
}

class _Ring {
  _Ring(this.center, this.maxRadius, this.life, this.color, this.width) : maxLife = life;

  final Offset center;
  final double maxRadius;
  double life;
  final double maxLife;
  final Color color;
  final double width;
}

class _FloatText {
  _FloatText(this.text, this.position, this.color, this.size, this.life) : maxLife = life;

  final String text;
  Offset position;
  final Color color;
  final double size;
  double life;
  final double maxLife;
}

/// Particles, shockwave rings and floating score text, all in world space.
class Effects {
  static const int _maxParticles = 320;

  final math.Random _rng = math.Random();
  final List<_Particle> _particles = [];
  final List<_Ring> _rings = [];
  final List<_FloatText> _texts = [];
  final Paint _paint = Paint()..isAntiAlias = true;
  final Paint _ringPaint = Paint()
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true;

  void burst(
    Offset at,
    Color color, {
    int count = 16,
    double speed = 180,
    double life = 0.6,
    double size = 2.6,
  }) {
    for (var i = 0; i < count; i++) {
      final a = _rng.nextDouble() * math.pi * 2;
      final s = speed * (0.35 + _rng.nextDouble() * 0.65);
      _particles.add(_Particle(
        at,
        Offset(math.cos(a), math.sin(a)) * s,
        life * (0.6 + _rng.nextDouble() * 0.4),
        size * (0.6 + _rng.nextDouble() * 0.8),
        color,
      ));
    }
    if (_particles.length > _maxParticles) {
      _particles.removeRange(0, _particles.length - _maxParticles);
    }
  }

  void ring(Offset at, Color color, {double maxRadius = 60, double life = 0.5, double width = 3}) {
    _rings.add(_Ring(at, maxRadius, life, color, width));
  }

  void text(String text, Offset at, Color color, {double size = 18, double life = 0.9}) {
    _texts.add(_FloatText(text, at, color, size, life));
  }

  /// Continuous sparks behind the comet.
  void spark(Offset at, Color color) {
    final a = _rng.nextDouble() * math.pi * 2;
    _particles.add(_Particle(at, Offset(math.cos(a), math.sin(a)) * 25, 0.4, 1.4, color));
  }

  void update(double dt) {
    final drag = math.max(0.0, 1 - 2.4 * dt);
    for (final p in _particles) {
      p.position += p.velocity * dt;
      p.velocity = p.velocity * drag;
      p.life -= dt;
    }
    _particles.removeWhere((p) => p.life <= 0);

    for (final r in _rings) {
      r.life -= dt;
    }
    _rings.removeWhere((r) => r.life <= 0);

    for (final t in _texts) {
      t.life -= dt;
      t.position = t.position.translate(0, -38 * dt);
    }
    _texts.removeWhere((t) => t.life <= 0);
  }

  void render(Canvas canvas) {
    for (final p in _particles) {
      final k = p.life / p.maxLife;
      _paint.color = p.color.fade(k);
      canvas.drawCircle(p.position, p.size * (0.4 + 0.6 * k), _paint);
    }

    for (final r in _rings) {
      final progress = 1 - r.life / r.maxLife;
      final eased = 1 - math.pow(1 - progress, 3).toDouble();
      _ringPaint
        ..color = r.color.fade(1 - progress)
        ..strokeWidth = r.width * (1 - progress) + 0.5;
      canvas.drawCircle(r.center, r.maxRadius * eased, _ringPaint);
    }

    for (final t in _texts) {
      final k = t.life / t.maxLife;
      final age = t.maxLife - t.life;
      final pop = age < 0.12 ? 0.6 + 0.4 * (age / 0.12) : 1.0;
      TextSprites.draw(
        canvas,
        t.text,
        t.position,
        fontSize: t.size,
        color: t.color,
        letterSpacing: 1.5,
        opacity: math.min(1.0, k * 1.6),
        scale: pop,
        glow: true,
        weight: FontWeight.w900,
      );
    }
  }

  void clear() {
    _particles.clear();
    _rings.clear();
    _texts.clear();
  }
}
