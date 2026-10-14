import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../logic/cosmos.dart';
import 'sprites.dart';

/// Far-away scenery that changes with the region: the Sun's warm glow,
/// the band of the Milky Way, distant galaxies. Each layer is rendered once
/// into an image and cross-faded, so it costs almost nothing per frame.
class SpaceBackdrop {
  SpaceBackdrop({required this.width, required this.height});

  final double width;
  final double height;

  ui.Image? _band;
  ui.Image? _galaxies;

  Color _top = const Color(0xFF000000);
  Color _bottom = const Color(0xFF000000);
  Color _shaderTop = const Color(0x00000000);
  Color _shaderBottom = const Color(0x00000000);
  final Paint _bg = Paint();
  final Map<Backdrop, double> _alpha = {for (final b in Backdrop.values) b: 0.0};
  double _sunFade = 1;

  void snapTo(Region region) {
    _top = Color(region.topArgb);
    _bottom = Color(region.bottomArgb);
    for (final b in Backdrop.values) {
      _alpha[b] = b == region.backdrop ? 1.0 : 0.0;
    }
  }

  void update(double dt, Region region, int bestIndex) {
    final k = math.min(1.0, dt * 0.8);
    _top = Color.lerp(_top, Color(region.topArgb), k)!;
    _bottom = Color.lerp(_bottom, Color(region.bottomArgb), k)!;
    for (final b in Backdrop.values) {
      final target = b == region.backdrop ? 1.0 : 0.0;
      _alpha[b] = _alpha[b]! + (target - _alpha[b]!) * k;
    }
    _sunFade = (1 - bestIndex / 30).clamp(0.15, 1.0).toDouble();
  }

  void render(Canvas canvas, double time, double cameraY) {
    final rect = Rect.fromLTWH(0, 0, width, height);
    // Rebuild the gradient only when the colours actually change.
    if (_top != _shaderTop || _bottom != _shaderBottom) {
      _bg.shader = ui.Gradient.linear(Offset.zero, Offset(0, height), [_top, _bottom]);
      _shaderTop = _top;
      _shaderBottom = _bottom;
    }
    canvas.drawRect(rect, _bg);

    final sun = _alpha[Backdrop.sunGlow]! * _sunFade;
    if (sun > 0.01) {
      GlowSprites.draw(canvas, Offset(width / 2, height * 1.12), height * 0.95, const Color(0xFFFFA040),
          opacity: 0.5 * sun);
    }

    final band = _alpha[Backdrop.milkyBand]!;
    if (band > 0.01) {
      final img = _band ??= _renderBand();
      drawSprite(canvas, img, Offset(width / 2, height / 2), Size(width, height), opacity: band);
    }

    final gal = _alpha[Backdrop.galaxies]!;
    if (gal > 0.01) {
      final img = _galaxies ??= _renderGalaxies();
      final y = (-cameraY * 0.03) % height;
      drawSprite(canvas, img, Offset(width / 2, y - height / 2), Size(width, height), opacity: gal);
      drawSprite(canvas, img, Offset(width / 2, y + height / 2), Size(width, height), opacity: gal);
    }
  }

  ui.Image _renderBand() => _bake((canvas) {
        final rng = math.Random(11);
        canvas.save();
        canvas.translate(width / 2, height * 0.45);
        canvas.rotate(-0.55);
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: width * 3, height: height * 0.42),
          Paint()
            ..shader = ui.Gradient.linear(
              Offset(0, -height * 0.21),
              Offset(0, height * 0.21),
              [
                Colors.transparent,
                const Color(0xFFB9A6FF).fade(0.16),
                const Color(0xFFFFF0D6).fade(0.24),
                const Color(0xFFB9A6FF).fade(0.16),
                Colors.transparent,
              ],
              [0.0, 0.3, 0.5, 0.7, 1.0],
            ),
        );
        final p = Paint();
        for (var i = 0; i < 260; i++) {
          final g = (rng.nextDouble() + rng.nextDouble() + rng.nextDouble() - 1.5) / 1.5;
          p.color = Colors.white.fade(0.2 + rng.nextDouble() * 0.5);
          canvas.drawCircle(
            Offset((rng.nextDouble() * 2 - 1) * width * 1.4, g * height * 0.16),
            i % 7 == 0 ? 1.4 : 0.8,
            p,
          );
        }
        canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: width * 2.6, height: height * 0.05),
          Paint()
            ..shader = ui.Gradient.linear(
              Offset(0, -height * 0.025),
              Offset(0, height * 0.025),
              [Colors.transparent, Colors.black.fade(0.4), Colors.transparent],
            ),
        );
        canvas.restore();
      });

  ui.Image _renderGalaxies() => _bake((canvas) {
        final rng = math.Random(23);
        const tints = [Color(0xFFB5C8FF), Color(0xFFFFDFA8), Color(0xFFE0B5FF), Color(0xFFA8FFE6)];
        for (var i = 0; i < 9; i++) {
          final c = Offset(rng.nextDouble() * width, rng.nextDouble() * height);
          final size = 8 + rng.nextDouble() * 20;
          final tint = tints[rng.nextInt(tints.length)];
          canvas.save();
          canvas.translate(c.dx, c.dy);
          canvas.rotate(rng.nextDouble() * math.pi);
          canvas.scale(1, 0.35);
          canvas.drawCircle(
            Offset.zero,
            size * 1.2,
            Paint()
              ..shader = ui.Gradient.radial(Offset.zero, size * 1.2, [tint.fade(0.45), tint.fade(0)]),
          );
          canvas.restore();
          canvas.drawCircle(c, 1.3, Paint()..color = Colors.white.fade(0.7));
        }
      });

  ui.Image _bake(void Function(Canvas c) draw) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    draw(canvas);
    final pic = recorder.endRecording();
    final img = pic.toImageSync(math.max(1, width.ceil()), math.max(1, height.ceil()));
    pic.dispose();
    return img;
  }

  void dispose() {
    _band?.dispose();
    _galaxies?.dispose();
  }
}
