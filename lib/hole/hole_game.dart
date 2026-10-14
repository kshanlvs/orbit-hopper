import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_theme.dart';
import '../game/audio/game_audio.dart';
import '../game/logic/cosmos.dart';
import '../game/render/effects.dart';
import '../game/render/sprites.dart';
import 'logic/hole_world.dart';
import 'logic/size_scale.dart';

typedef HoleStateCallback = void Function(HoleWorld world);
typedef HoleTierCallback = void Function(int tier);
typedef HoleOverCallback = void Function(HoleWorld world);

/// Flame shell around [HoleWorld]: drag-to-steer, zooming camera, the black
/// hole with its glowing disk, and everything waiting to be eaten.
class HoleGame extends FlameGame {
  HoleGame({required this.onState, required this.onTier, required this.onGameOver, GameAudio? audio})
      : audio = audio ?? GameAudio.instance;

  final HoleStateCallback onState;
  final HoleTierCallback onTier;
  final HoleOverCallback onGameOver;
  final GameAudio audio;

  static const _food = Color(0xFF5CFFB0);
  static const _danger = AppColors.danger;

  HoleWorld? _world;
  final Effects _effects = Effects();
  final math.Random _rng = math.Random();
  double _time = 0;
  double _shake = 0;
  double _flash = 0;
  Color _flashColor = Colors.white;
  double _stateTimer = 0;
  double _eatSoundTimer = 0;
  double _deathTimer = 0;
  bool _overReported = false;
  double _gulp = 0; // hole "pulse" after eating

  // 2D parallax stars, batched.
  final List<Float32List> _starLayers = [];
  final List<double> _starParallax = const [0.15, 0.35, 0.7];
  Color _bgTop = const Color(0xFF05040C);
  Color _bgBottom = const Color(0xFF16101E);
  final Paint _bg = Paint();
  Color _bgShaderTop = Colors.transparent;
  Color _bgShaderBottom = Colors.transparent;

  final Paint _fill = Paint()..isAntiAlias = true;
  final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true;
  final Paint _points = Paint()
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;

  @override
  Color backgroundColor() => AppColors.background;

  HoleWorld? get sim => _world;

  /// Steering from the joystick: direction and strength (length 0..1).
  void steer(Offset s) => _world?.steer = s;

  void restart() {
    final w = _world;
    if (w == null) return;
    _world = HoleWorld(viewWidth: w.viewWidth, viewHeight: w.viewHeight);
    _effects.clear();
    _deathTimer = 0;
    _overReported = false;
    _shake = 0;
    _flash = 0;
    audio.setMood(Mood.deep);
    resumeEngine();
  }

  @override
  void update(double dt) {
    super.update(dt);
    final w = size.x;
    final h = size.y;
    if (w <= 0 || h <= 0) return;
    var world = _world;
    if (world == null || (!world.started && (world.viewWidth != w || world.viewHeight != h))) {
      world = HoleWorld(viewWidth: w, viewHeight: h);
      _world = world;
      _makeStars(w, h);
      audio.setMood(Mood.deep);
    }

    _time += dt;
    world.update(dt);
    _consume(world, w, h);
    _effects.update(dt);
    _shake = math.max(0.0, _shake - dt * 40);
    _flash = math.max(0.0, _flash - dt * 2.2);
    _gulp = math.max(0.0, _gulp - dt * 4);
    _eatSoundTimer -= dt;

    // Sky colour follows your size tier.
    final t = tierInfo(world.tier);
    final k = math.min(1.0, dt * 0.8);
    _bgTop = Color.lerp(_bgTop, Color(t.topArgb ?? 0xFF05040C), k)!;
    _bgBottom = Color.lerp(_bgBottom, Color(t.bottomArgb ?? 0xFF16101E), k)!;

    _stateTimer -= dt;
    if (_stateTimer <= 0) {
      _stateTimer = 0.1;
      onState(world);
    }

    if (world.dead) {
      _deathTimer += dt;
      if (_deathTimer > 1.4 && !_overReported) {
        _overReported = true;
        onState(world);
        onGameOver(world);
      }
    }
  }

  void _consume(HoleWorld world, double w, double h) {
    final c = Offset(w / 2, h / 2);
    for (final e in world.events) {
      final at = c + e.pos * world.scale;
      switch (e.type) {
        case HoleEventType.eat:
          _gulp = 1;
          if (_eatSoundTimer <= 0) {
            audio.play(Sfx.stardust);
            _eatSoundTimer = 0.07;
          }
          _effects.burst(c, Color(e.argb), count: 6, speed: 90, life: 0.35, size: 2);
          if (e.value % 25 == 0) {
            HapticFeedback.lightImpact();
            _effects.text('${e.value} EATEN', c + const Offset(0, -60), _food, size: 16);
          }
        case HoleEventType.hurt:
          HapticFeedback.heavyImpact();
          audio.play(Sfx.shieldBreak);
          _shake = 10;
          _flash = 0.5;
          _flashColor = _danger;
          _effects.burst(at, _danger, count: 24, speed: 220, life: 0.6);
          _effects.text('TOO BIG!', c + const Offset(0, -56), _danger, size: 20);
        case HoleEventType.tierUp:
          HapticFeedback.mediumImpact();
          audio.play(Sfx.reveal);
          _flash = 0.6;
          _flashColor = Colors.white;
          _effects.ring(c, Colors.white, maxRadius: 220, life: 1.0, width: 5);
          if (e.value >= 9) audio.setMood(Mood.cosmic);
          onTier(e.value);
        case HoleEventType.death:
          HapticFeedback.heavyImpact();
          audio.play(Sfx.death);
          _shake = 18;
          _flash = 0.8;
          _flashColor = e.value == HoleDeath.swallowed.index ? _danger : const Color(0xFFB57CFF);
          _effects.burst(c, const Color(0xFFB57CFF), count: 60, speed: 300, life: 1.2, size: 3);
      }
    }
    world.events.clear();
  }

  // ---------------------------------------------------------------- render

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final world = _world;
    if (world == null) return;
    final w = world.viewWidth;
    final h = world.viewHeight;

    if (_bgTop != _bgShaderTop || _bgBottom != _bgShaderBottom) {
      _bg.shader = ui.Gradient.linear(Offset.zero, Offset(0, h), [_bgTop, _bgBottom]);
      _bgShaderTop = _bgTop;
      _bgShaderBottom = _bgBottom;
    }
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), _bg);
    _drawStars(canvas, world, w, h);

    canvas.save();
    if (_shake > 0) {
      canvas.translate((_rng.nextDouble() - 0.5) * _shake, (_rng.nextDouble() - 0.5) * _shake);
    }
    final c = Offset(w / 2, h / 2);
    final s = world.scale;
    final holeR = world.radius * s;

    // Gravity reach (faint).
    _stroke
      ..color = const Color(0xFFB57CFF).fade(0.07)
      ..strokeWidth = 1;
    canvas.drawCircle(c, holeR * 3.2, _stroke);

    for (final t in world.things) {
      final p = c + t.pos * s;
      final r = t.radius * s;
      if (r < 0.6 || p.dx < -r * 3 || p.dy < -r * 3 || p.dx > w + r * 3 || p.dy > h + r * 3) continue;
      final danger = world.dangerOf(t);
      if (danger > 0) {
        final pulse = danger == 2 ? 0.5 + 0.5 * math.sin(_time * 8) : 0.5;
        GlowSprites.draw(canvas, p, r * 1.9, _danger, opacity: 0.25 + 0.25 * pulse);
      }
      BodySprites.draw(canvas, p, r, t.look, _time, seed: t.seed % 3, cacheRadius: 40);
      if (danger > 0) {
        _stroke
          ..color = _danger.fade(danger == 2 ? 0.55 + 0.4 * math.sin(_time * 8).abs() : 0.6)
          ..strokeWidth = danger == 2 ? 2.4 : 1.6;
        canvas.drawCircle(p, r + 3, _stroke);
      } else if (r > 3) {
        _stroke
          ..color = _food.fade(0.35)
          ..strokeWidth = 1;
        canvas.drawCircle(p, r + 2, _stroke);
      }
    }

    if (!world.dead || _deathTimer < 0.25) _drawHole(canvas, world, c, holeR);
    _effects.render(canvas);
    canvas.restore();

    if (_flash > 0) {
      _fill.color = _flashColor.fade(math.min(1.0, _flash) * 0.3);
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h), _fill);
    }
    _drawEvaporationVignette(canvas, world, w, h);
    if (!world.started) _drawIntro(canvas, w, h);
  }

  void _drawHole(Canvas canvas, HoleWorld world, Offset c, double r) {
    if (world.invulnerable > 0 && (_time * 12).floor().isEven) return;
    final gulp = 1 + 0.12 * _gulp;
    final rr = r * gulp;
    // Accretion glow
    GlowSprites.draw(canvas, c, rr * 2.6, const Color(0xFFFF8A3D), opacity: 0.35);
    GlowSprites.draw(canvas, c, rr * 1.8, const Color(0xFFB57CFF), opacity: 0.55);
    // Spinning disk arcs
    _stroke.strokeCap = StrokeCap.round;
    for (var i = 0; i < 4; i++) {
      final ring = rr * (1.25 + i * 0.16);
      _stroke
        ..color = Color.lerp(const Color(0xFFFFD166), const Color(0xFFB57CFF), i / 3)!.fade(0.75 - i * 0.12)
        ..strokeWidth = math.max(1.2, rr * (0.16 - i * 0.025));
      canvas.drawArc(Rect.fromCircle(center: c, radius: ring), _time * (2.4 - i * 0.35) + i * 1.3, math.pi * 1.1,
          false, _stroke);
    }
    _stroke.strokeCap = StrokeCap.butt;
    // Event horizon
    _fill.color = Colors.black;
    canvas.drawCircle(c, rr, _fill);
    _stroke
      ..color = Colors.white.fade(0.8)
      ..strokeWidth = 1.4;
    canvas.drawCircle(c, rr * 1.03, _stroke);
  }

  /// Red edges when you have not eaten for a while and are evaporating.
  void _drawEvaporationVignette(Canvas canvas, HoleWorld world, double w, double h) {
    if (!world.started || world.dead || world.sinceLastMeal < 2.5) return;
    final k = ((world.sinceLastMeal - 2.5) / 3).clamp(0.0, 1.0).toDouble();
    final pulse = 0.6 + 0.4 * math.sin(_time * 6).abs();
    _fill.shader = ui.Gradient.radial(
      Offset(w / 2, h / 2),
      math.max(w, h) * 0.75,
      [Colors.transparent, const Color(0xFFB57CFF).fade(0.32 * k * pulse)],
      [0.55, 1.0],
    );
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), _fill);
    _fill.shader = null;
  }

  void _drawIntro(Canvas canvas, double w, double h) {
    final a = 0.5 + 0.5 * (0.5 + 0.5 * math.sin(_time * 4));
    TextSprites.draw(canvas, 'DRAG TO MOVE', Offset(w / 2, h * 0.68),
        fontSize: 16, color: Colors.white, letterSpacing: 5, opacity: a, glow: true);
    TextSprites.draw(canvas, 'Eat smaller things  ·  avoid bigger ones', Offset(w / 2, h * 0.68 + 26),
        fontSize: 12.5, color: AppColors.textDim, weight: FontWeight.w600);
    TextSprites.draw(canvas, 'You are evaporating — keep eating!', Offset(w / 2, h * 0.68 + 46),
        fontSize: 12.5, color: const Color(0xFFB57CFF), weight: FontWeight.w700);
  }

  // ---------------------------------------------------------------- stars

  void _makeStars(double w, double h) {
    _starLayers.clear();
    final rng = math.Random(9);
    for (var l = 0; l < 3; l++) {
      final n = [70, 45, 25][l];
      final list = Float32List(n * 2);
      for (var i = 0; i < n; i++) {
        list[i * 2] = rng.nextDouble() * w;
        list[i * 2 + 1] = rng.nextDouble() * h;
      }
      _starLayers.add(list);
    }
  }

  final Float32List _starBuf = Float32List(140);

  void _drawStars(Canvas canvas, HoleWorld world, double w, double h) {
    for (var l = 0; l < _starLayers.length; l++) {
      final src = _starLayers[l];
      final par = _starParallax[l];
      final ox = -world.cameraTravel.dx * par;
      final oy = -world.cameraTravel.dy * par;
      final n = src.length;
      for (var i = 0; i < n; i += 2) {
        _starBuf[i] = (src[i] + ox) % w;
        _starBuf[i + 1] = (src[i + 1] + oy) % h;
      }
      _points
        ..color = Colors.white.fade(0.35 + l * 0.2)
        ..strokeWidth = 1.6 + l * 0.8;
      canvas.drawRawPoints(ui.PointMode.points, Float32List.sublistView(_starBuf, 0, n), _points);
    }
  }
}
