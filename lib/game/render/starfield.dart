import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class _Group {
  _Group(this.parallax, this.size, this.alpha, this.phase, int capacity)
      : xs = Float32List(capacity),
        ys = Float32List(capacity),
        buffer = Float32List(capacity * 4);

  final double parallax;
  final double size;
  final double alpha;
  final double phase;
  final Float32List xs;
  final Float32List ys;
  final Float32List buffer;
  int count = 0;
}

/// Parallax star layers drawn with a handful of batched draw calls.
/// When the camera moves fast the stars stretch into warp streaks —
/// that's what makes the climb feel like travelling.
class Starfield {
  Starfield({required this.width, required this.height, int count = 150, int? seed}) {
    final rng = math.Random(seed);
    // 4 depth layers x 3 twinkle phases. The last layer is close "space dust".
    const parallax = [0.1, 0.25, 0.5, 1.25];
    const sizes = [1.1, 1.6, 2.3, 1.4];
    const alphas = [0.45, 0.6, 0.8, 0.22];
    const shares = [0.4, 0.3, 0.2, 0.1];
    for (var layer = 0; layer < 4; layer++) {
      final n = (count * shares[layer]).round();
      for (var ph = 0; ph < 3; ph++) {
        final g = _Group(parallax[layer], sizes[layer], alphas[layer], ph * 2.1, n);
        for (var i = 0; i < n ~/ 3 + 1 && g.count < n; i++) {
          g.xs[g.count] = rng.nextDouble() * width;
          g.ys[g.count] = rng.nextDouble() * height;
          g.count++;
        }
        _groups.add(g);
      }
    }
  }

  final double width;
  final double height;
  final List<_Group> _groups = [];
  final Paint _paint = Paint()
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;

  /// [cameraSpeed] is how fast the camera moves up, in px/s (positive = up).
  void render(Canvas canvas, double cameraY, double time, {double cameraSpeed = 0}) {
    for (final g in _groups) {
      final twinkle = 0.65 + 0.35 * math.sin(time * 1.8 + g.phase);
      final streak = (cameraSpeed * g.parallax * 0.07).clamp(0.0, 70.0).toDouble();
      final lines = streak > 1.5;
      final buf = g.buffer;
      final shift = -cameraY * g.parallax;
      var j = 0;
      for (var i = 0; i < g.count; i++) {
        final y = (g.ys[i] + shift) % height;
        final x = g.xs[i];
        if (lines) {
          buf[j++] = x;
          buf[j++] = y;
          buf[j++] = x;
          buf[j++] = y - streak;
        } else {
          buf[j++] = x;
          buf[j++] = y;
        }
      }
      _paint
        ..color = Colors.white.fade(g.alpha * (lines ? 0.85 : twinkle))
        ..strokeWidth = lines ? g.size * 0.8 : g.size * 2;
      canvas.drawRawPoints(
        lines ? ui.PointMode.lines : ui.PointMode.points,
        Float32List.sublistView(buf, 0, j),
        _paint,
      );
    }
  }
}
