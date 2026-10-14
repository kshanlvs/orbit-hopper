import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_theme.dart';
import '../domain/entities/comet_skin.dart';
import 'audio/game_audio.dart';
import 'logic/cosmos.dart';
import 'logic/game_world.dart';
import 'logic/models.dart';
import 'render/body_renderer.dart';
import 'render/effects.dart';
import 'render/space_backdrop.dart';
import 'render/sprites.dart';
import 'render/starfield.dart';

typedef ScoreCallback = void Function(int score, int combo);
typedef StardustCallback = void Function(int stardust);
typedef JourneyCallback = void Function(int bestIndex);
typedef TravelCallback = void Function(double travelIndex);
typedef LandmarkCallback = void Function(int landmarkIndex);
typedef GameOverCallback = void Function(int score, int stardust, int bestIndex, DeathCause cause);
typedef StatsCallback = void Function(RunStats stats);
typedef DefenseCallback = void Function(DefenseState state);

/// Flame shell around [GameWorld]: drives the loop, draws the cosmos,
/// adds juice (particles, slow motion, warp streaks, sound) and reports to the UI.
class OrbitHopperGame extends FlameGame {
  OrbitHopperGame({
    required this.skin,
    required this.startLandmark,
    required this.isDiscovered,
    required this.onScoreChanged,
    required this.onStardustChanged,
    required this.onJourney,
    required this.onTravel,
    required this.onDiscovery,
    required this.onDepart,
    required this.onGameOver,
    required this.onStats,
    this.defense,
    this.onDefense,
    this.onDefenseWon,
    GameAudio? audio,
  }) : audio = audio ?? GameAudio.instance;

  final GameAudio audio;
  final CometSkin skin;
  int startLandmark;

  /// True if the player has landed on this real place in any earlier run.
  final bool Function(int landmarkIndex) isDiscovered;
  final ScoreCallback onScoreChanged;
  final StardustCallback onStardustChanged;
  final JourneyCallback onJourney;
  final TravelCallback onTravel;
  final LandmarkCallback onDiscovery;
  final LandmarkCallback onDepart;
  final GameOverCallback onGameOver;

  /// Fired whenever run stats change (for missions).
  final StatsCallback onStats;

  /// "Save Earth" mode (null = normal journey).
  DefenseConfig? defense;
  final DefenseCallback? onDefense;
  final VoidCallback? onDefenseWon;
  double _wonTimer = -1;
  double _alarmTimer = 0;
  static const _killerLook = BodyLook(BodyStyle.cratered, 0xFF8C4A36, 0xFF3A1A12);

  static const _goldColor = AppColors.gold;
  static const _dangerColor = AppColors.danger;
  static const _signalColor = Color(0xFF7CF5FF);
  static const _wormholeColor = Color(0xFFB57CFF);
  static const _shieldColor = Color(0xFF5CFFB0);

  GameWorld? _sim;
  Starfield? _stars;
  SpaceBackdrop? _backdrop;
  final Effects _effects = Effects();
  final List<Offset> _trail = [];
  final math.Random _rng = math.Random();

  double _time = 0;
  double _shake = 0;
  double _flash = 0;
  Color _flashColor = _goldColor;
  double _deathTimer = 0;
  bool _overReported = false;

  // Cinematic state
  double _timeScale = 1;
  double _slowTimer = 0;
  double _slowFactor = 1;
  double _zoom = 1;
  double _starSpeed = 0;
  double _prevCamera = 0;
  double _travelTimer = 0;
  double _pingTimer = 0;

  /// Landmark index -> time its reveal animation started (this run).
  final Map<int, double> _reveals = {};

  // Banner
  double _bannerTime = 0;
  String _bannerTitle = '';
  String _bannerName = '';

  // Signal (undiscovered landmark ahead)
  Planet? _signal;
  bool _signalOnScreen = false;

  final Paint _fill = Paint()..isAntiAlias = true;
  final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true;
  final Paint _line = Paint()
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;
  final Path _starPath = _unitStar();
  final Path _arrowPath = Path()
    ..moveTo(0, -9)
    ..lineTo(8, 5)
    ..lineTo(-8, 5)
    ..close();

  @override
  Color backgroundColor() => AppColors.background;

  // ---------------------------------------------------------------- input

  void tap() {
    final sim = _sim;
    if (sim == null || paused) return;
    sim.launch();
  }

  void restart({required int startLandmark, DefenseConfig? defense}) {
    this.startLandmark = startLandmark;
    this.defense = defense;
    _wonTimer = -1;
    final sim = _sim;
    if (sim == null) return;
    _sim = GameWorld(width: sim.width, height: sim.height, startLandmark: startLandmark, defense: defense);
    _backdrop?.snapTo(_sim!.region);
    _effects.clear();
    _trail.clear();
    _reveals.clear();
    _shake = 0;
    _flash = 0;
    _deathTimer = 0;
    _bannerTime = 0;
    _timeScale = 1;
    _slowTimer = 0;
    _zoom = 1;
    _overReported = false;
    _prevCamera = _sim!.cameraY;
    onScoreChanged(0, 0);
    onStardustChanged(0);
    onJourney(_sim!.bestIndex);
    onTravel(_sim!.bestIndex.toDouble());
    audio.setMood(defense != null ? Mood.deep : _sim!.region.mood);
    resumeEngine();
  }

  // ---------------------------------------------------------------- loop

  @override
  void update(double dt) {
    super.update(dt);
    final w = size.x;
    final h = size.y;
    if (w <= 0 || h <= 0) return;

    var sim = _sim;
    if (sim == null || (!sim.started && (sim.width != w || sim.height != h))) {
      sim = GameWorld(width: w, height: h, startLandmark: startLandmark, defense: defense);
      _sim = sim;
      _stars = Starfield(width: w, height: h);
      _backdrop?.dispose();
      _backdrop = SpaceBackdrop(width: w, height: h)..snapTo(sim.region);
      _trail.clear();
      _prevCamera = sim.cameraY;
      audio.setMood(defense != null ? Mood.deep : sim.region.mood);
    }

    // Slow motion for dramatic moments, easing back to normal speed.
    if (_slowTimer > 0) {
      _slowTimer -= dt;
      _timeScale += (_slowFactor - _timeScale) * math.min(1.0, dt * 12);
    } else {
      _timeScale += (1 - _timeScale) * math.min(1.0, dt * 2.5);
    }
    final sdt = dt * _timeScale;

    _time += dt;
    sim.update(sdt);
    _consumeEvents(sim);
    _effects.update(sdt);
    _backdrop?.update(dt, sim.region, sim.bestIndex);

    // Camera speed -> warp streaks. Deeper space feels faster.
    final camSpeed = dt > 0 ? (_prevCamera - sim.cameraY) / dt : 0.0;
    _prevCamera = sim.cameraY;
    final flying = sim.comet.mode == CometMode.flying;
    final cometUp = flying ? math.max(0.0, -sim.comet.velocity.dy) * 0.5 : 0.0;
    final warp = 1 + Cosmos.lastLandmarkBefore(sim.bestIndex) * 0.07;
    final targetSpeed = (math.max(0.0, camSpeed) + cometUp) * warp;
    _starSpeed += (targetSpeed - _starSpeed) * math.min(1.0, dt * 6);

    // Pull the camera back slightly in flight: a sense of speed and space.
    final zoomTarget = flying ? 0.93 : 1.0;
    _zoom += (zoomTarget - _zoom) * math.min(1.0, dt * 2.2);

    _shake = math.max(0.0, _shake - dt * 40);
    _flash = math.max(0.0, _flash - dt * 2.2);
    _bannerTime = math.max(0.0, _bannerTime - dt);

    _updateSignal(sim, dt);

    if (!sim.isDead) {
      _trail.add(sim.comet.position);
      if (_trail.length > 26) _trail.removeAt(0);
      if (flying) _effects.spark(sim.comet.position, _cometColor(0));
    } else {
      if (_trail.isNotEmpty) _trail.removeAt(0);
      _deathTimer += dt;
      if (_deathTimer > 1.2 && !_overReported) {
        _overReported = true;
        onGameOver(sim.score, sim.stardustCollected, sim.bestIndex, sim.deathCause ?? DeathCause.lost);
      }
    }

    _travelTimer -= dt;
    if (_travelTimer <= 0) {
      _travelTimer = 0.1;
      onTravel(sim.travelIndex);
      final ds = sim.defense;
      if (ds != null) onDefense?.call(ds);
    }

    // Save Earth: alarms in the last seconds, victory hand-off.
    final d = sim.defense;
    if (d != null) {
      if (d.active && sim.started && d.timeLeft < 10) {
        _alarmTimer -= dt;
        if (_alarmTimer <= 0) {
          _alarmTimer = 1.0;
          audio.play(Sfx.alarm);
          _flash = math.max(_flash, 0.25);
          _flashColor = _dangerColor;
        }
      }
      if (_wonTimer >= 0) {
        _wonTimer += dt;
        if (_wonTimer > 2.6) {
          _wonTimer = -1;
          onDefense?.call(d);
          onDefenseWon?.call();
        }
      }
    }
  }

  /// Finds the nearest undiscovered real place ahead and sends sonar pings.
  void _updateSignal(GameWorld sim, double dt) {
    Planet? found;
    for (final p in sim.planets) {
      final k = p.landmark;
      if (k == null || p.index <= sim.bestIndex) continue;
      if (_isUnknown(k)) found = p;
      break;
    }
    _signal = found;
    if (found == null || sim.isDead) {
      _signalOnScreen = false;
      return;
    }
    final screenY = found.center.dy - sim.cameraY;
    _signalOnScreen = screenY > -found.radius && screenY < sim.height + found.radius;
    final near = screenY > -sim.height * 1.4;
    _pingTimer -= dt;
    if (near && _pingTimer <= 0) {
      audio.play(Sfx.ping);
      _pingTimer = _signalOnScreen ? 1.9 : 3.4;
      if (_signalOnScreen) {
        _effects.ring(found.center, _signalColor, maxRadius: found.radius * 3, life: 1.4, width: 2);
      }
    }
  }

  bool _isUnknown(int landmark) => landmark != 0 && !isDiscovered(landmark) && !_reveals.containsKey(landmark);

  void _slowMo(double factor, double seconds) {
    _slowFactor = factor;
    _slowTimer = seconds;
  }

  void _consumeEvents(GameWorld sim) {
    final hasDiscovery = sim.events.any((x) => x.type == WorldEventType.discovery);
    var statsChanged = false;
    for (final e in sim.events) {
      switch (e.type) {
        case WorldEventType.capture || WorldEventType.stardust || WorldEventType.wormhole ||
              WorldEventType.shieldBreak:
          statsChanged = true;
        default:
          break;
      }
    }
    for (final e in sim.events) {
      switch (e.type) {
        case WorldEventType.launch:
          HapticFeedback.selectionClick();
          audio.play(Sfx.launch);
          _effects.burst(e.position, _cometColor(0), count: 10, speed: 140, life: 0.35);
        case WorldEventType.capture:
          HapticFeedback.lightImpact();
          // Perfect and discovery landings have their own bigger sounds.
          final special = hasDiscovery || sim.events.any((x) => x.type == WorldEventType.perfect);
          if (!special) audio.play(Sfx.capture);
          final captureColor = Color(e.argb);
          _effects.ring(e.position, captureColor, maxRadius: 46, life: 0.45);
          _effects.burst(e.position, captureColor, count: 12, speed: 160, life: 0.5);
          if (e.value > 0) {
            _effects.text('+${e.value}', e.position + const Offset(0, -22), Colors.white);
            onScoreChanged(sim.score, sim.combo);
            onJourney(sim.bestIndex);
          }
        case WorldEventType.perfect:
          HapticFeedback.mediumImpact();
          if (!hasDiscovery) audio.perfect(e.value);
          _flash = math.max(_flash, 0.3);
          _flashColor = _goldColor;
          _shake = math.max(_shake, 3.0);
          _effects.ring(e.position, _goldColor, maxRadius: 90, life: 0.6, width: 4);
          _effects.text(
            e.value > 1 ? 'PERFECT ×${e.value}' : 'PERFECT',
            e.position + const Offset(0, -52),
            _goldColor,
            size: 22,
            life: 1.1,
          );
        case WorldEventType.stardust:
          audio.play(Sfx.stardust);
          _effects.burst(e.position, _goldColor, count: 8, speed: 120, life: 0.4, size: 2);
          onStardustChanged(sim.stardustCollected);
        case WorldEventType.warning:
          HapticFeedback.lightImpact();
          audio.play(Sfx.warning);
          _effects.ring(e.position, _dangerColor, maxRadius: 70, life: 0.5);
        case WorldEventType.region:
          audio.setMood(sim.region.mood);
          // Landing on a landmark shows the region in its fact card instead.
          if (hasDiscovery) break;
          audio.play(Sfx.warp);
          _bannerTitle = 'NOW ENTERING';
          _bannerName = sim.region.name.toUpperCase();
          _bannerTime = 3.4;
          _flash = 0.35;
          _flashColor = _signalColor;
        case WorldEventType.discovery:
          final k = e.value;
          final firstTime = _isUnknown(k);
          final color = Color(e.argb);
          if (firstTime) {
            // The big reveal: slow motion, flash, shockwaves.
            _reveals[k] = _time;
            HapticFeedback.heavyImpact();
            audio.play(Sfx.reveal);
            _slowMo(0.25, 0.9);
            _flash = 0.8;
            _flashColor = Colors.white;
            _shake = math.max(_shake, 6.0);
            _effects.ring(e.position, Colors.white, maxRadius: 220, life: 1.3, width: 6);
            _effects.ring(e.position, color, maxRadius: 150, life: 1.0, width: 4);
            _effects.burst(e.position, color, count: 50, speed: 240, life: 1.2, size: 3);
          } else {
            HapticFeedback.mediumImpact();
            audio.play(Sfx.arrival);
            _slowMo(0.6, 0.35);
            _flash = math.max(_flash, 0.3);
            _flashColor = color;
            _effects.ring(e.position, color, maxRadius: 140, life: 0.9, width: 4);
          }
          onDiscovery(k);
        case WorldEventType.depart:
          onDepart(e.value);
        case WorldEventType.wormhole:
          HapticFeedback.heavyImpact();
          audio.play(Sfx.wormhole);
          _flash = 0.7;
          _flashColor = _wormholeColor;
          _starSpeed = 5000; // instant hyperspace streaks
          _effects.ring(e.position, _wormholeColor, maxRadius: 120, life: 0.7, width: 5);
          _effects.burst(e.position, _wormholeColor, count: 30, speed: 260, life: 0.7);
          final arrive = sim.comet.position;
          _effects.ring(arrive, _wormholeColor, maxRadius: 90, life: 0.8, width: 4);
          _effects.text('WARP +${e.value} HOPS', arrive + const Offset(0, -70), _wormholeColor, size: 22, life: 1.3);
        case WorldEventType.shieldGet:
          HapticFeedback.mediumImpact();
          audio.play(Sfx.shield);
          _effects.ring(e.position, _shieldColor, maxRadius: 60, life: 0.5, width: 3);
          _effects.text('SHIELD', e.position + const Offset(0, -30), _shieldColor, size: 18);
        case WorldEventType.killerSpawn:
          HapticFeedback.heavyImpact();
          audio.play(Sfx.alarm);
          _bannerTitle = 'FULLY CHARGED';
          _bannerName = 'INTERCEPT THE ASTEROID!';
          _bannerTime = 3.0;
          _flash = 0.4;
          _flashColor = _dangerColor;
        case WorldEventType.deflect:
          HapticFeedback.heavyImpact();
          audio.play(Sfx.victory);
          _slowMo(0.2, 1.4);
          _shake = 22;
          _flash = 1.0;
          _flashColor = Colors.white;
          _wonTimer = 0;
          _effects.burst(e.position, const Color(0xFFFF8A3D), count: 90, speed: 420, life: 1.6, size: 4);
          _effects.burst(e.position, Colors.white, count: 40, speed: 300, life: 1.0, size: 2.5);
          _effects.ring(e.position, Colors.white, maxRadius: 260, life: 1.4, width: 7);
          _effects.ring(e.position, const Color(0xFFFF8A3D), maxRadius: 180, life: 1.1, width: 5);
          _effects.text('DEFLECTED!', e.position + const Offset(0, -60), AppColors.gold, size: 30, life: 2.0);
          _bannerTitle = 'MISSION SUCCESS';
          _bannerName = 'EARTH IS SAFE';
          _bannerTime = 3.2;
        case WorldEventType.shieldBreak:
          HapticFeedback.heavyImpact();
          audio.play(Sfx.shieldBreak);
          _shake = math.max(_shake, 8.0);
          _slowMo(0.4, 0.3);
          _effects.burst(sim.comet.position, _shieldColor, count: 36, speed: 280, life: 0.8, size: 2.6);
          _effects.ring(sim.comet.position, _shieldColor, maxRadius: 70, life: 0.5, width: 4);
          _effects.text('SAVED!', sim.comet.position + const Offset(0, -34), _shieldColor, size: 20);
        case WorldEventType.death:
          HapticFeedback.heavyImpact();
          audio.play(Sfx.death);
          _slowMo(0.35, 0.45);
          _shake = 16;
          final deathColor = _cometColor(0);
          _effects.burst(e.position, deathColor, count: 50, speed: 340, life: 1.1, size: 3.2);
          _effects.burst(e.position, Colors.white, count: 14, speed: 200, life: 0.6, size: 2);
          _effects.ring(e.position, deathColor, maxRadius: 140, life: 0.8, width: 5);
          if (e.value == DeathCause.impact.index) {
            _flash = 1.0;
            _flashColor = _dangerColor;
            _shake = 26;
            _bannerTitle = 'IMPACT';
            _bannerName = 'EARTH WAS HIT';
            _bannerTime = 3.2;
          }
          if (e.value == DeathCause.collapse.index) {
            final planet = sim.comet.planet;
            if (planet != null) {
              _effects.burst(planet.center, Color(e.argb), count: 40, speed: 260, life: 1.2, size: 4);
            }
          }
      }
    }
    sim.events.clear();
    if (statsChanged) onStats(sim.stats);
  }

  // ---------------------------------------------------------------- render

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final sim = _sim;
    if (sim == null) return;
    final w = sim.width;
    final h = sim.height;

    _backdrop?.render(canvas, _time, sim.cameraY);
    _stars?.render(canvas, sim.cameraY, _time, cameraSpeed: _starSpeed);

    canvas.save();
    // Zoom around a point in the lower-middle of the screen.
    final pivot = Offset(w / 2, h * 0.6);
    canvas.translate(pivot.dx, pivot.dy);
    canvas.scale(_zoom);
    canvas.translate(-pivot.dx, -pivot.dy);
    final shake = _shake > 0
        ? Offset((_rng.nextDouble() - 0.5) * _shake, (_rng.nextDouble() - 0.5) * _shake)
        : Offset.zero;
    canvas.translate(shake.dx, shake.dy - sim.cameraY);

    final top = sim.cameraY - 280;
    final bottom = sim.cameraY + h + 280;
    for (final p in sim.planets) {
      if (p.center.dy < top || p.center.dy > bottom) continue;
      _drawPlanet(canvas, p, sim);
    }
    for (final s in sim.stardust) {
      if (s.collected || s.position.dy < top || s.position.dy > bottom) continue;
      _drawStardust(canvas, s);
    }
    for (final wh in sim.wormholes) {
      if (wh.position.dy < top || wh.position.dy > bottom) continue;
      _drawWormhole(canvas, wh, sim);
    }
    for (final s in sim.shields) {
      if (s.collected || s.position.dy < top || s.position.dy > bottom) continue;
      _drawShieldPickup(canvas, s);
    }
    final killer = sim.defense?.killer;
    if (killer != null) _drawKiller(canvas, killer);
    for (final a in sim.asteroids) {
      if (a.position.dy < top || a.position.dy > bottom) continue;
      GlowSprites.draw(canvas, a.position, a.radius * 2.4, _dangerColor, opacity: 0.35);
      BodySprites.draw(canvas, a.position, a.radius, asteroidLook, _time, seed: a.seed);
    }
    _drawGuide(canvas, sim);
    _drawTrail(canvas);
    if (!sim.isDead) _drawComet(canvas, sim);
    _effects.render(canvas);
    canvas.restore();

    _drawSignalHud(canvas, sim, w, h);
    _drawKillerMarker(canvas, sim, w, h);
    _drawDangerVignette(canvas, sim, w, h);
    if (_flash > 0) {
      _fill.color = _flashColor.fade(math.min(1.0, _flash) * 0.35);
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h), _fill);
    }
    if (_bannerTime > 0) _drawBanner(canvas, w, h);
    if (!sim.started) _drawTapHint(canvas, sim, w, h);
  }

  void _drawPlanet(Canvas canvas, Planet p, GameWorld sim) {
    final isCurrent = identical(sim.comet.planet, p) && !sim.isDead;
    if (p.collapsed) return;

    final left = p.stabilityLeft;
    final critical = isCurrent && p.stability.isFinite && left < 0.3;
    final wobble = critical ? math.sin(_time * 45) * 2.2 * (1 - left / 0.3) : 0.0;
    final c = p.center + Offset(wobble, 0);
    final glow = BodyRenderer.glowColor(p.look);
    final k = p.landmark;
    final unknown = k != null && _isUnknown(k);

    // Reveal progress: 0 = silhouette, 1 = fully visible.
    var revealed = 1.0;
    if (unknown) {
      revealed = 0;
    } else if (k != null && _reveals.containsKey(k)) {
      revealed = ((_time - _reveals[k]!) / 1.4).clamp(0.0, 1.0).toDouble();
    }

    // Orbit path
    _stroke
      ..color = (unknown ? _signalColor : glow).fade(isCurrent ? 0.35 : 0.14)
      ..strokeWidth = 1.2;
    canvas.drawCircle(p.center, p.orbitRadius, _stroke);

    // Moon ring + moons
    if (p.moons.isNotEmpty) {
      _stroke
        ..color = _dangerColor.fade(0.12)
        ..strokeWidth = 1;
      canvas.drawCircle(p.center, p.moonRingRadius, _stroke);
      for (final m in p.moons) {
        final mp = p.moonPosition(m);
        GlowSprites.draw(canvas, mp, m.radius * 2.4, _dangerColor, opacity: 0.6);
        _fill.color = const Color(0xFFB8BED6);
        canvas.drawCircle(mp, m.radius, _fill);
        _fill.color = const Color(0xFF6E7590);
        canvas.drawCircle(mp + Offset(m.radius * 0.3, m.radius * 0.25), m.radius * 0.35, _fill);
      }
    }

    if (critical) {
      GlowSprites.draw(canvas, c, p.radius * 1.9, _dangerColor, opacity: 0.4 + 0.4 * math.sin(_time * 18).abs());
    }

    BodySprites.draw(canvas, c, p.radius, p.look, _time, seed: p.index, revealed: revealed);

    if (unknown) {
      // Pulsing rim on the dark silhouette — something is there…
      final pulse = 0.5 + 0.5 * math.sin(_time * 3);
      _stroke
        ..color = _signalColor.fade(0.25 + 0.35 * pulse)
        ..strokeWidth = 1.6;
      canvas.drawCircle(c, p.radius + 2, _stroke);
      TextSprites.draw(canvas, '?', c, fontSize: p.radius * 0.9, color: _signalColor, opacity: 0.35 + 0.3 * pulse);
    }

    // Stability arc
    if (p.stability.isFinite && (isCurrent || p.timeHeld > 0)) {
      _stroke
        ..color = Color.lerp(_dangerColor, const Color(0xFF5CFFB0), left)!
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: p.radius + 7),
        -math.pi / 2,
        math.pi * 2 * left,
        false,
        _stroke,
      );
      _stroke.strokeCap = StrokeCap.butt;
    }

    // Labels under real places
    if (k != null) {
      final l = Cosmos.place(k);
      final y1 = p.center + Offset(0, p.orbitRadius + 16);
      final y2 = p.center + Offset(0, p.orbitRadius + 32);
      if (unknown) {
        TextSprites.draw(canvas, 'UNKNOWN OBJECT', y1,
            fontSize: 12, color: _signalColor, letterSpacing: 3, opacity: 0.9);
        TextSprites.draw(canvas, '? ? ?', y2, fontSize: 10, color: _signalColor, letterSpacing: 2, opacity: 0.6);
      } else {
        TextSprites.draw(canvas, l.name.toUpperCase(), y1,
            fontSize: 12, color: Colors.white, letterSpacing: 3, opacity: 0.85 * revealed);
        TextSprites.draw(canvas, l.distanceLabel, y2,
            fontSize: 10, color: glow, letterSpacing: 1.5, opacity: 0.75 * revealed);
      }
    }
  }

  /// "Unknown object" HUD: an arrow at the top edge while it is still above
  /// the screen, a pulsing alert once it is in view.
  void _drawSignalHud(Canvas canvas, GameWorld sim, double w, double h) {
    final s = _signal;
    if (s == null || sim.isDead) return;
    final pulse = 0.5 + 0.5 * math.sin(_time * 4);
    final hops = s.index - sim.bestIndex;
    if (_signalOnScreen) {
      TextSprites.draw(canvas, '●  UNKNOWN OBJECT DETECTED', Offset(w / 2, 128),
          fontSize: 12, color: _signalColor, letterSpacing: 3, opacity: 0.45 + 0.5 * pulse, glow: true);
      return;
    }
    final screenY = s.center.dy - sim.cameraY;
    if (screenY > -h * 1.6) {
      final x = s.center.dx.clamp(30.0, w - 30.0).toDouble();
      canvas.save();
      canvas.translate(x, 112);
      _fill.color = _signalColor.fade(0.5 + 0.5 * pulse);
      canvas.drawPath(_arrowPath, _fill);
      canvas.restore();
      final label = hops <= 1 ? 'SIGNAL · NEXT HOP' : 'SIGNAL · $hops HOPS';
      TextSprites.draw(canvas, label, Offset(x.clamp(80.0, w - 80.0).toDouble(), 132),
          fontSize: 10, color: _signalColor, letterSpacing: 2.5, opacity: 0.55 + 0.4 * pulse);
    }
  }

  void _drawStardust(Canvas canvas, Stardust s) {
    final pulse = 0.75 + 0.25 * math.sin(_time * 6 + s.phase);
    GlowSprites.draw(canvas, s.position, 13 * pulse, _goldColor, opacity: 0.7);
    canvas.save();
    canvas.translate(s.position.dx, s.position.dy);
    canvas.rotate(_time * 1.8 + s.phase);
    canvas.scale(6.5 * pulse);
    _fill.color = _goldColor;
    canvas.drawPath(_starPath, _fill);
    canvas.restore();
  }

  /// Dotted aim line for the first jumps of a run — teaches the mechanic.
  void _drawGuide(Canvas canvas, GameWorld sim) {
    if (sim.hopsThisRun >= 2 || sim.comet.mode != CometMode.orbiting) return;
    final dir = sim.launchDirection;
    final alpha = sim.started ? 0.35 : 0.6;
    for (var i = 1; i <= 12; i++) {
      final pos = sim.comet.position + dir * (i * 16.0);
      _fill.color = Colors.white.fade(alpha * (1 - i / 13));
      canvas.drawCircle(pos, 1.8, _fill);
    }
  }

  void _drawTrail(Canvas canvas) {
    final n = _trail.length;
    for (var i = 1; i < n; i++) {
      final k = i / n;
      _line
        ..color = _cometColor(1 - k).fade(k * 0.85)
        ..strokeWidth = GameWorld.cometRadius * 2 * k;
      canvas.drawLine(_trail[i - 1], _trail[i], _line);
    }
  }

  void _drawComet(Canvas canvas, GameWorld sim) {
    final pos = sim.comet.position;
    // Blink while invulnerable after a shield breaks.
    if (sim.invulnerable > 0 && (_time * 14).floor().isEven) return;
    final color = _cometColor(0);
    GlowSprites.draw(canvas, pos, 22, color, opacity: 0.85);
    _fill.color = color;
    canvas.drawCircle(pos, GameWorld.cometRadius, _fill);
    _fill.color = Colors.white;
    canvas.drawCircle(pos, GameWorld.cometRadius * 0.5, _fill);
    if (sim.shield) {
      final pulse = 0.5 + 0.5 * math.sin(_time * 5);
      GlowSprites.draw(canvas, pos, 20, _shieldColor, opacity: 0.25);
      _stroke
        ..color = _shieldColor.fade(0.55 + 0.35 * pulse)
        ..strokeWidth = 2;
      canvas.drawCircle(pos, 14 + pulse, _stroke);
    }
  }

  /// The giant asteroid: fiery trail pointing back toward Earth.
  void _drawKiller(Canvas canvas, KillerAsteroid k) {
    const r = KillerAsteroid.radius;
    final c = k.position;
    for (var i = 5; i >= 1; i--) {
      final t = i / 5;
      GlowSprites.draw(canvas, c + Offset(0, r * 1.4 * t), r * (1.4 - 0.12 * i),
          Color.lerp(const Color(0xFFFFD166), _dangerColor, t)!, opacity: 0.55 - 0.08 * i);
    }
    final pulse = 0.5 + 0.5 * math.sin(_time * 6);
    GlowSprites.draw(canvas, c, r * 2.2, _dangerColor, opacity: 0.45 + 0.25 * pulse);
    BodySprites.draw(canvas, c, r, _killerLook, _time, seed: 7);
    _stroke
      ..color = AppColors.gold.fade(0.5 + 0.4 * pulse)
      ..strokeWidth = 2;
    canvas.drawCircle(c, r + 8 + 3 * pulse, _stroke);
    TextSprites.draw(canvas, 'RAM IT!', c + const Offset(0, -r - 20),
        fontSize: 13, color: AppColors.gold, letterSpacing: 3, opacity: 0.6 + 0.4 * pulse, glow: true);
  }

  void _drawKillerMarker(Canvas canvas, GameWorld sim, double w, double h) {
    final k = sim.defense?.killer;
    if (k == null) return;
    final screenY = k.position.dy - sim.cameraY;
    if (screenY > 0) return;
    final pulse = 0.5 + 0.5 * math.sin(_time * 6);
    final x = k.position.dx.clamp(30.0, w - 30.0).toDouble();
    canvas.save();
    canvas.translate(x, 112);
    _fill.color = _dangerColor.fade(0.6 + 0.4 * pulse);
    canvas.drawPath(_arrowPath, _fill);
    canvas.restore();
    TextSprites.draw(canvas, 'TARGET AHEAD', Offset(x.clamp(80.0, w - 80.0).toDouble(), 132),
        fontSize: 10, color: _dangerColor, letterSpacing: 2.5, opacity: 0.7 + 0.3 * pulse);
  }

  /// Swirling portal: spinning arcs around a dark core.
  void _drawWormhole(Canvas canvas, Wormhole w, GameWorld sim) {
    final c = w.position;
    const r = Wormhole.radius;
    final fade = w.used ? 0.3 : 1.0;
    GlowSprites.draw(canvas, c, r * 2.6, _wormholeColor, opacity: 0.55 * fade);
    _stroke.strokeCap = StrokeCap.round;
    for (var i = 0; i < 4; i++) {
      final rr = r * (0.45 + i * 0.2);
      final spin = _time * (2.6 - i * 0.4) + w.phase + i;
      _stroke
        ..color = Color.lerp(_signalColor, _wormholeColor, i / 3)!.fade((0.9 - i * 0.15) * fade)
        ..strokeWidth = 3 - i * 0.5;
      canvas.drawArc(Rect.fromCircle(center: c, radius: rr), spin, math.pi * 1.2, false, _stroke);
    }
    _stroke.strokeCap = StrokeCap.butt;
    _fill.color = Colors.black.fade(0.85 * fade);
    canvas.drawCircle(c, r * 0.32, _fill);
    if (!w.used) {
      final hops = w.targetIndex - sim.bestIndex;
      if (hops > 1) {
        TextSprites.draw(canvas, 'WARP +$hops', c + const Offset(0, r + 14),
            fontSize: 10, color: _wormholeColor, letterSpacing: 2, opacity: 0.85);
      }
    }
  }

  void _drawShieldPickup(Canvas canvas, ShieldPickup s) {
    final bob = math.sin(_time * 3 + s.position.dx) * 3;
    final c = s.position + Offset(0, bob);
    final pulse = 0.5 + 0.5 * math.sin(_time * 4);
    GlowSprites.draw(canvas, c, 22, _shieldColor, opacity: 0.5 + 0.2 * pulse);
    _stroke
      ..color = _shieldColor
      ..strokeWidth = 2.2;
    canvas.drawCircle(c, 10, _stroke);
    _fill.color = _shieldColor.fade(0.35);
    canvas.drawCircle(c, 10, _fill);
    _fill.color = Colors.white.fade(0.8);
    canvas.drawCircle(c + const Offset(-3, -3), 2.5, _fill);
  }

  void _drawDangerVignette(Canvas canvas, GameWorld sim, double w, double h) {
    final p = sim.comet.planet;
    if (p == null || sim.isDead || !p.stability.isFinite) return;
    final left = p.stabilityLeft;
    if (left >= 0.3) return;
    final strength = (1 - left / 0.3) * (0.6 + 0.4 * math.sin(_time * 14).abs());
    _fill.shader = ui.Gradient.radial(
      Offset(w / 2, h / 2),
      math.max(w, h) * 0.75,
      [Colors.transparent, _dangerColor.fade(0.35 * strength)],
      [0.55, 1.0],
    );
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), _fill);
    _fill.shader = null;
  }

  void _drawBanner(Canvas canvas, double w, double h) {
    final t = _bannerTime;
    final alpha = t > 3.0 ? (3.4 - t) / 0.4 : (t < 0.6 ? t / 0.6 : 1.0);
    TextSprites.draw(canvas, _bannerTitle, Offset(w / 2, h * 0.3),
        fontSize: 13, color: Colors.white, letterSpacing: 6, opacity: alpha * 0.7);
    TextSprites.draw(canvas, _bannerName, Offset(w / 2, h * 0.3 + 28),
        fontSize: 24, color: AppColors.accent, letterSpacing: 3, opacity: alpha, glow: true);
  }

  void _drawTapHint(Canvas canvas, GameWorld sim, double w, double h) {
    final a = 0.45 + 0.55 * (0.5 + 0.5 * math.sin(_time * 4));
    TextSprites.draw(canvas, 'TAP TO LAUNCH', Offset(w / 2, h * 0.5),
        fontSize: 16, color: Colors.white, letterSpacing: 5, opacity: a, glow: true);
    final sub = sim.startLandmark == 0
        ? 'Fly from the Sun to the edge of the universe'
        : 'Departing ${Cosmos.place(sim.startLandmark).name}';
    TextSprites.draw(canvas, sub, Offset(w / 2, h * 0.5 + 26),
        fontSize: 12, color: AppColors.textDim, opacity: 0.9, weight: FontWeight.w600);
  }

  // ---------------------------------------------------------------- colour

  Color _cometColor(double offset) {
    if (skin.rainbow) {
      return HSVColor.fromAHSV(1, (_time * 140 + offset * 220) % 360, 0.65, 1).toColor();
    }
    return Color(skin.argb);
  }

  static Path _unitStar() => Path()
    ..moveTo(0, -1)
    ..lineTo(0.3, -0.3)
    ..lineTo(1, 0)
    ..lineTo(0.3, 0.3)
    ..lineTo(0, 1)
    ..lineTo(-0.3, 0.3)
    ..lineTo(-1, 0)
    ..lineTo(-0.3, -0.3)
    ..close();

  @override
  void onRemove() {
    _backdrop?.dispose();
    super.onRemove();
  }
}
