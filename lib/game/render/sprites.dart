import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../logic/cosmos.dart';
import 'body_renderer.dart';

/// Pixel density used for every cached sprite (capped to save memory).
double _spriteRatio() {
  final views = WidgetsBinding.instance.platformDispatcher.views;
  final dpr = views.isEmpty ? 2.0 : views.first.devicePixelRatio;
  return dpr.clamp(1.0, 2.5).toDouble();
}

/// Small LRU cache of GPU images; evicted images are disposed.
class _ImageCache<K> {
  _ImageCache(this.capacity);

  final int capacity;
  final LinkedHashMap<K, ui.Image> _map = LinkedHashMap<K, ui.Image>();

  ui.Image putIfAbsent(K key, ui.Image Function() create) {
    final hit = _map.remove(key);
    if (hit != null) {
      _map[key] = hit; // move to most-recent
      return hit;
    }
    final img = create();
    _map[key] = img;
    while (_map.length > capacity) {
      final oldest = _map.keys.first;
      _map.remove(oldest)?.dispose();
    }
    return img;
  }
}

ui.Image _record(double logicalW, double logicalH, double ratio, void Function(Canvas c) draw) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(ratio);
  draw(canvas);
  final picture = recorder.endRecording();
  final img = picture.toImageSync(
    math.max(1, (logicalW * ratio).ceil()),
    math.max(1, (logicalH * ratio).ceil()),
  );
  picture.dispose();
  return img;
}

final Paint _imagePaint = Paint()
  ..filterQuality = FilterQuality.low
  ..isAntiAlias = true;

/// Draws [img] centred on [center] at [logicalSize], with [opacity] and an
/// optional [colorFilter]. Uses one shared Paint: zero allocations per frame.
void drawSprite(
  Canvas canvas,
  ui.Image img,
  Offset center,
  Size logicalSize, {
  double opacity = 1,
  double scale = 1,
  double rotation = 0,
  ColorFilter? colorFilter,
}) {
  if (opacity <= 0.005) return;
  _imagePaint
    ..color = Colors.white.fade(opacity)
    ..colorFilter = colorFilter;
  final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
  final w = logicalSize.width * scale;
  final h = logicalSize.height * scale;
  if (rotation == 0) {
    canvas.drawImageRect(img, src, Rect.fromCenter(center: center, width: w, height: h), _imagePaint);
  } else {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.drawImageRect(img, src, Rect.fromCenter(center: Offset.zero, width: w, height: h), _imagePaint);
    canvas.restore();
  }
  _imagePaint.colorFilter = null;
}

/// Planets, stars and galaxies pre-rendered once, then drawn as images.
/// This replaces dozens of vector draw calls per body per frame.
abstract final class BodySprites {
  static final _ImageCache<int> _cache = _ImageCache<int>(56);

  /// Dim teal "hologram" for objects not yet discovered: hides the true
  /// colours but keeps the shape visible (a fully dark silhouette made glowy
  /// objects like nebulae and star clusters vanish against the sky).
  static const ColorFilter silhouette = ColorFilter.matrix(<double>[
    0.03, 0.06, 0.012, 0, 6, //
    0.13, 0.26, 0.05, 0, 10, //
    0.17, 0.33, 0.06, 0, 22, //
    0, 0, 0, 1, 0,
  ]);

  static int _key(BodyLook look, double r, int seed) => Object.hash(
        look.style,
        look.primary,
        look.secondary,
        look.tilt,
        look.spot,
        r,
        seed % 3,
      );

  static ui.Image _image(BodyLook look, double r, int seed) {
    final ext = BodyRenderer.extent(look.style);
    final size = r * ext * 2;
    return _cache.putIfAbsent(_key(look, r, seed), () {
      return _record(size, size, _spriteRatio(), (c) {
        BodyRenderer.draw(c, Offset(size / 2, size / 2), r, look, 0, seed: seed % 3);
      });
    });
  }

  /// Draws a body with cheap animation (spin, twinkle, pulse) on top of the
  /// cached image. [revealed] 0 = silhouette, 1 = full colour.
  static void draw(
    Canvas canvas,
    Offset c,
    double radius,
    BodyLook look,
    double time, {
    int seed = 0,
    double revealed = 1,
    double opacity = 1,
    double? cacheRadius,
  }) {
    // Quantise for cache hits. Callers whose sizes change every frame (the
    // zooming black hole game) pass a fixed [cacheRadius] and get scaled.
    final r = cacheRadius ?? (radius / 2).roundToDouble() * 2;
    final img = _image(look, r, seed);
    final size = r * BodyRenderer.extent(look.style) * 2;
    final logical = Size(size, size);

    var scale = radius / r;
    var rotation = 0.0;
    switch (look.style) {
      case BodyStyle.sun:
        rotation = time * 0.06;
        scale *= 1 + 0.015 * math.sin(time * 1.7);
      case BodyStyle.star || BodyStyle.cluster:
        scale *= 1 + 0.035 * math.sin(time * 4.5 + seed);
      case BodyStyle.nebula || BodyStyle.blackHole || BodyStyle.cloud:
        scale *= 1 + 0.025 * math.sin(time * 1.3 + seed);
      case BodyStyle.galaxy:
        rotation = math.sin(time * 0.2 + seed) * 0.05;
      default:
        break;
    }

    if (revealed < 1) {
      drawSprite(canvas, img, c, logical,
          opacity: opacity * (1 - revealed), scale: scale, rotation: rotation, colorFilter: silhouette);
    }
    if (revealed > 0) {
      drawSprite(canvas, img, c, logical, opacity: opacity * revealed, scale: scale, rotation: rotation);
    }
  }
}

/// Soft round glows: one white image, tinted per draw with a colour filter,
/// so even a rainbow comet never creates new images.
abstract final class GlowSprites {
  static const double _size = 64;
  static ui.Image? _white;

  static void draw(Canvas canvas, Offset center, double radius, Color color, {double opacity = 1}) {
    final img = _white ??= _record(_size, _size, 1, (c) {
      const mid = Offset(_size / 2, _size / 2);
      c.drawCircle(
        mid,
        _size / 2,
        Paint()
          ..shader = ui.Gradient.radial(
            mid,
            _size / 2,
            [Colors.white, Colors.white.fade(0.45), Colors.white.fade(0)],
            [0.0, 0.35, 1.0],
          ),
      );
    });
    drawSprite(canvas, img, center, Size(radius * 2, radius * 2),
        opacity: opacity, colorFilter: ColorFilter.mode(color, BlendMode.modulate));
  }
}

class TextSprite {
  TextSprite(this.image, this.size);

  final ui.Image image;
  final Size size;
}

/// Text rendered once into an image. Drawing text this way costs one
/// image blit per frame instead of a full text layout.
abstract final class TextSprites {
  static final _ImageCache<int> _cache = _ImageCache<int>(80);
  static final Map<int, Size> _sizes = {};

  static TextSprite get(
    String text, {
    required double fontSize,
    required Color color,
    double letterSpacing = 1,
    FontWeight weight = FontWeight.w800,
    bool glow = false,
  }) {
    final key = Object.hash(text, fontSize, color.toARGB32(), letterSpacing, weight, glow);
    final img = _cache.putIfAbsent(key, () {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: weight,
            letterSpacing: letterSpacing,
            shadows: [
              Shadow(color: Colors.black.fade(0.85), blurRadius: 6),
              if (glow) Shadow(color: color.fade(0.7), blurRadius: 14),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: fontSize * 40);
      const pad = 16.0;
      final size = Size(painter.width + pad * 2, painter.height + pad * 2);
      _sizes[key] = size;
      return _record(size.width, size.height, _spriteRatio(), (c) => painter.paint(c, const Offset(pad, pad)));
    });
    return TextSprite(img, _sizes[key]!);
  }

  static void draw(
    Canvas canvas,
    String text,
    Offset center, {
    required double fontSize,
    required Color color,
    double letterSpacing = 1,
    double opacity = 1,
    double scale = 1,
    bool glow = false,
    FontWeight weight = FontWeight.w800,
  }) {
    final s = get(text, fontSize: fontSize, color: color, letterSpacing: letterSpacing, glow: glow, weight: weight);
    drawSprite(canvas, s.image, center, s.size, opacity: opacity, scale: scale);
  }
}
