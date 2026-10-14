import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';

import 'audio/neon_audio.dart';
import 'engine/hazards.dart';
import 'engine/neon_world.dart';
import 'engine/tuning.dart';
import 'progression/profile.dart';
import 'render/fx.dart';
import 'render/palette.dart';
import 'render/scene.dart';

class NeonRunConfig {
  const NeonRunConfig({
    required this.seed,
    required this.daily,
    required this.dimension,
    required this.skin,
    required this.trail,
    required this.settings,
    required this.previousBest,
  });

  final int seed;
  final bool daily;
  final String dimension;
  final String skin;
  final String trail;
  final NeonSettings settings;
  final int previousBest;
}

/// Low-frequency snapshot for the Flutter HUD (rebuilt only on change).
@immutable
class NeonHud {
  const NeonHud({
    this.score = 0,
    this.distance = 0,
    this.multiplier = 1,
    this.chain = 0,
    this.chainLeft = 0,
    this.shards = 0,
    this.dashCharge = 0,
    this.dashReady = false,
    this.dashing = false,
    this.tutorial = true,
    this.ready = false,
  });

  final int score;
  final int distance;
  final double multiplier;
  final int chain;
  final double chainLeft;
  final int shards;
  final double dashCharge;
  final bool dashReady;
  final bool dashing;

  /// Show the "tap to flip" hint (until the first flip).
  final bool tutorial;

  /// Showing the short "get ready" pause after resuming.
  final bool ready;

  @override
  bool operator ==(Object other) =>
      other is NeonHud &&
      other.score == score &&
      other.distance == distance &&
      other.multiplier == multiplier &&
      other.chain == chain &&
      other.chainLeft == chainLeft &&
      other.shards == shards &&
      other.dashCharge == dashCharge &&
      other.dashReady == dashReady &&
      other.dashing == dashing &&
      other.tutorial == tutorial &&
      other.ready == ready;

  @override
  int get hashCode =>
      Object.hash(score, distance, multiplier, chain, chainLeft, shards, dashCharge, dashReady, dashing, tutorial, ready);
}

enum ToastKind { banner, small, record }

class NeonToast {
  const NeonToast(this.text, {this.sub, this.kind = ToastKind.small, this.color = const Color(0xFFFFFFFF)});

  final String text;
  final String? sub;
  final ToastKind kind;
  final Color color;
}

/// The Flame shell around [NeonWorld]: steps the simulation, turns its
/// events into sound, haptics and particles, and draws the scene.
class NeonGame extends FlameGame {
  NeonGame(this.config, {required this.onGameOver}) : sim = NeonWorld(seed: config.seed, daily: config.daily) {
    _applyEffectsSettings();
  }

  NeonRunConfig config;
  final void Function(RunSummary run) onGameOver;

  NeonWorld sim;
  final NeonScene scene = NeonScene();
  final Particles particles = Particles(220);
  final Rings rings = Rings();
  final Floaters floaters = Floaters();
  final Shake shake = Shake();

  final ValueNotifier<NeonHud> hud = ValueNotifier(const NeonHud());
  final StreamController<NeonToast> _toasts = StreamController<NeonToast>.broadcast();
  Stream<NeonToast> get toasts => _toasts.stream;

  final List<double> _trailX = [];
  final List<double> _trailY = [];
  static const _trailLength = 26;

  double time = 0;
  double _flash = 0;
  Color _flashColor = const Color(0xFFFFFFFF);
  double _breakBlend = 0;
  BreakVariant? _variantShown;
  double _chaseFront = 0;
  double _dashGlow = 0;
  double _deathTimer = -1;
  bool _overSent = false;
  bool _recordAnnounced = false;
  double _grace = 0;
  bool _tutorial = true;

  NeonAudio get _audio => NeonAudio.instance;
  bool get _reduced => config.settings.reducedEffects;
  bool get isOver => _overSent;

  @override
  Color backgroundColor() => const Color(0xFF000000);

  void _applyEffectsSettings() {
    particles.budget = _reduced ? 0.35 : 1;
    shake.enabled = !_reduced;
  }

  /// Settings can change from the pause menu.
  void updateSettings(NeonSettings s) {
    config = NeonRunConfig(
      seed: config.seed,
      daily: config.daily,
      dimension: config.dimension,
      skin: config.skin,
      trail: config.trail,
      settings: s,
      previousBest: config.previousBest,
    );
    _applyEffectsSettings();
  }

  // ------------------------------------------------------------- input

  void flip() {
    if (!sim.alive || _grace > 0 || paused) return;
    sim.flip();
  }

  void dash() {
    if (_grace > 0 || paused) return;
    sim.dash();
  }

  /// A fresh run. Normal runs get a new seed each time; the daily keeps its.
  void restart(int seed) {
    sim = NeonWorld(seed: seed, daily: config.daily);
    config = NeonRunConfig(
      seed: seed,
      daily: config.daily,
      dimension: config.dimension,
      skin: config.skin,
      trail: config.trail,
      settings: config.settings,
      previousBest: math.max(config.previousBest, 0),
    );
    particles.clear();
    rings.clear();
    floaters.clear();
    _trailX.clear();
    _trailY.clear();
    _flash = 0;
    _breakBlend = 0;
    _variantShown = null;
    _chaseFront = 0;
    _dashGlow = 0;
    _deathTimer = -1;
    _overSent = false;
    _recordAnnounced = false;
    _grace = 0;
    _tutorial = true;
    hud.value = const NeonHud();
    _hudTimer = 0;
    if (paused) resumeEngine();
  }

  /// Raise the record bar after a run so the next one celebrates properly.
  void setPreviousBest(int best) {
    config = NeonRunConfig(
      seed: config.seed,
      daily: config.daily,
      dimension: config.dimension,
      skin: config.skin,
      trail: config.trail,
      settings: config.settings,
      previousBest: best,
    );
  }

  void pauseGame() {
    if (!paused) pauseEngine();
  }

  void resumeGame() {
    if (!paused) return;
    _grace = sim.alive && sim.s > 0 ? 0.7 : 0;
    resumeEngine();
  }

  // ------------------------------------------------------------- update

  @override
  void update(double dt) {
    super.update(dt);
    time += dt;
    if (_grace > 0) {
      _grace -= dt;
    } else {
      sim.update(dt);
      _events();
      if (sim.alive) {
        _trailX.add(sim.s);
        _trailY.add(sim.orb.y);
        if (_trailX.length > _trailLength) {
          _trailX.removeAt(0);
          _trailY.removeAt(0);
        }
        if (config.trail == 'sparks') {
          particles.spray(sim.s - Tune.orbRadius, sim.orb.y, -1, 0, SkinLook.of(config.skin).glowAt(time), 1,
              spread: 1.2, speed: 0.6, size: 0.008, life: 0.35);
        }
      }
    }

    particles.update(dt);
    rings.update(dt);
    floaters.update(dt);
    shake.update(dt);
    if (_flash > 0) _flash = math.max(0, _flash - dt * 2.5);
    _dashGlow += ((sim.dashing ? 1.0 : 0.0) - _dashGlow) * math.min(1, dt * 10);

    final inBreak = sim.activeBreak != null;
    if (inBreak) _variantShown = sim.activeBreak;
    _breakBlend += ((inBreak ? 1.0 : 0.0) - _breakBlend) * math.min(1, dt * 2.2);

    final chaseTarget = sim.chaseActive
        ? 0.3 + 0.7 * ((sim.s - sim.chaseStartedAt) / (Tune.chaseLength + 4)).clamp(0.0, 1.0)
        : 0.0;
    _chaseFront += (chaseTarget - _chaseFront) * math.min(1, dt * (sim.chaseActive ? 1.5 : 3.5));
    if (!sim.chaseActive && _chaseFront < 0.01) _chaseFront = 0;

    if (_deathTimer >= 0) {
      _deathTimer += dt;
      if (_deathTimer > 0.85 && !_overSent) {
        _overSent = true;
        onGameOver(sim.summary());
      }
    }
    _hudTimer -= dt;
    if (_hudTimer <= 0) {
      _hudTimer = 1 / 20; // the HUD redraws at most 20 times a second
      _pushHud();
    }
  }

  double _hudTimer = 0;

  void _pushHud() {
    double q(double v, double step) => (v / step).round() * step;
    final score = sim.score;
    hud.value = NeonHud(
      score: score.points,
      distance: sim.s.floor(),
      multiplier: score.multiplier,
      chain: score.chain,
      chainLeft: q(score.chainLeft, 0.02),
      shards: sim.stats.shards,
      dashCharge: q(sim.dashCharge, 0.05),
      dashReady: sim.dashReady,
      dashing: sim.dashing,
      tutorial: _tutorial && sim.alive,
      ready: _grace > 0,
    );
  }

  void _toast(NeonToast t) {
    if (!_toasts.isClosed) _toasts.add(t);
  }

  void _events() {
    if (sim.events.isEmpty) return;
    final pal = _palette();
    final skin = SkinLook.of(config.skin);
    for (final e in sim.events) {
      switch (e.type) {
        case NeonEventType.flip:
          _tutorial = false;
          _audio.play(NeonSfx.flip);
          _audio.tapHaptic();
          rings.add(e.x, e.y, skin.glowAt(time), radius: 0.16, life: 0.22);
          particles.spray(e.x, e.y, 0, -e.value.toDouble(), skin.glowAt(time), 4, speed: 0.9, life: 0.25);
        case NeonEventType.land:
          particles.spray(e.x, e.y + e.value * Tune.orbRadius, -1, -e.value * 0.6, pal.wall, 3,
              speed: 0.7, size: 0.007, life: 0.25);
        case NeonEventType.shard:
          _audio.play(NeonSfx.shard);
          particles.burst(e.x, e.y, e.label == 'risk' ? pal.risk : pal.shard, 7, speed: 0.8, size: 0.009, life: 0.35);
        case NeonEventType.setComplete:
          _audio.chain(sim.score.chain);
          floaters.add(e.x, e.y - 0.12, 'PERFECT +${e.value}', pal.shard, size: 13);
          rings.add(e.x, e.y, pal.shard, radius: 0.3);
        case NeonEventType.nearMiss:
          _audio.play(NeonSfx.nearMiss);
          _audio.chain(sim.score.chain);
          _audio.lightHaptic();
          floaters.add(e.x, e.y - 0.12, 'NEAR MISS +${e.value}', pal.accent, size: 13);
          particles.burst(e.x, e.y, pal.accent, 10, speed: 1.4, size: 0.008, life: 0.3);
          if (sim.score.chain % 5 == 0 && !_reduced) sim.hitStop = 0.05;
        case NeonEventType.chainBroken:
          _audio.play(NeonSfx.chainBreak);
          floaters.add(e.x, e.y - 0.14, 'CHAIN LOST', const Color(0xFF9A9AB0), size: 11);
        case NeonEventType.dashReady:
          _audio.play(NeonSfx.dashReady);
          _audio.mediumHaptic();
          _toast(NeonToast('PULSE DASH READY', sub: 'Tap ⚡ to phase through magenta', color: pal.dash));
        case NeonEventType.dashStart:
          _audio.play(NeonSfx.dash);
          _audio.heavyHaptic();
          shake.kick(4);
          rings.add(e.x, e.y, pal.dash, radius: 0.45, life: 0.4);
          particles.spray(e.x, e.y, -1, 0, pal.dash, 18, spread: 0.9, speed: 2, life: 0.4);
        case NeonEventType.dashPierce:
          _audio.play(NeonSfx.pierce);
          _audio.mediumHaptic();
          shake.kick(5);
          particles.burst(e.x + 0.05, e.y, pal.dash, 22, speed: 2.2, size: 0.01, life: 0.45);
        case NeonEventType.dashEnd:
          break;
        case NeonEventType.breakWarn:
          _audio.play(NeonSfx.breakWarn);
          _toast(NeonToast('REALITY BREAK', sub: e.label, kind: ToastKind.banner, color: pal.accent));
        case NeonEventType.breakStart:
          _audio.play(NeonSfx.breakStart);
          _audio.heavyHaptic();
          shake.kick(6);
          if (!_reduced) {
            _flash = 0.55;
            _flashColor = pal.accent;
          }
        case NeonEventType.breakEnd:
          _toast(NeonToast('REALITY RESTORED', color: pal.wall));
        case NeonEventType.chaseWarn:
          _audio.play(NeonSfx.chaseWarn);
          _toast(NeonToast('ENERGY WAVE', sub: 'Outrun it!', kind: ToastKind.banner, color: pal.dash));
        case NeonEventType.chaseStart:
          _audio.heavyHaptic();
          shake.kick(3);
        case NeonEventType.escape:
          _audio.play(NeonSfx.escape);
          _audio.mediumHaptic();
          _toast(NeonToast('ESCAPED', sub: '+${e.value}', kind: ToastKind.banner, color: pal.shard));
          rings.add(e.x, e.y, pal.shard, radius: 0.7, life: 0.6);
        case NeonEventType.riskClear:
          floaters.add(e.x, e.y + 0.14, 'RISK TAKEN', pal.risk, size: 13);
        case NeonEventType.milestone:
          _audio.play(NeonSfx.milestone);
          floaters.add(e.x + 0.4, 0.5, '${e.value} m', pal.wall, size: 18);
        case NeonEventType.death:
          _audio.play(NeonSfx.death);
          _audio.heavyHaptic();
          shake.kick(10);
          particles.burst(e.x, e.y, skin.glowAt(time), 50, speed: 2.4, size: 0.014, life: 0.9);
          particles.burst(e.x, e.y, const Color(0xFFFFFFFF), 16, speed: 1.2, size: 0.01, life: 0.6);
          rings.add(e.x, e.y, skin.glowAt(time), radius: 0.8, life: 0.5);
          if (!_reduced) {
            _flash = 0.35;
            _flashColor = const Color(0xFFFFFFFF);
          }
          _deathTimer = 0;
      }
    }
    sim.events.clear();

    final best = config.previousBest;
    if (!_recordAnnounced && best > 0 && sim.alive && sim.score.points > best) {
      _recordAnnounced = true;
      _audio.play(NeonSfx.record);
      _toast(NeonToast('NEW RECORD', kind: ToastKind.record, color: pal.risk));
      particles.burst(sim.s + 0.5, 0.5, pal.risk, 30, speed: 1.8, life: 0.8);
    }
  }

  NeonPalette _palette() {
    final base = NeonPalette.of(config.dimension);
    final v = _variantShown;
    if (v == null || _breakBlend < 0.005) return base;
    return NeonPalette.lerp(base, base.shifted(v, time), _breakBlend);
  }

  // ------------------------------------------------------------- render

  @override
  void render(Canvas canvas) {
    final sz = Size(size.x, size.y);
    scene.layout(sz);
    final renderS = sim.alive ? sim.s + sim.alpha * sim.speed * Tune.dt : sim.s;

    canvas.save();
    final o = shake.offset;
    canvas.translate(o.dx, o.dy);
    if (!_reduced && _variantShown != null && _breakBlend > 0.01) {
      final cx = sz.width / 2, cy = sz.height / 2;
      if (_variantShown == BreakVariant.twist) {
        canvas.translate(cx, cy);
        canvas.rotate(_breakBlend * math.sin(time * 0.8) * 0.045);
        canvas.translate(-cx, -cy);
      } else if (_variantShown == BreakVariant.flux) {
        final k = 1 + _breakBlend * 0.035 * math.sin(time * 1.6);
        canvas.translate(cx, cy);
        canvas.scale(k, k);
        canvas.translate(-cx, -cy);
      }
    }
    scene.render(
      canvas,
      SceneFrame(
        world: sim,
        palette: _palette(),
        skin: SkinLook.of(config.skin),
        trail: config.trail,
        trailX: _trailX,
        trailY: _trailY,
        time: time,
        renderS: renderS,
        orbY: sim.orb.y,
        particles: particles,
        rings: rings,
        floaters: floaters,
        reduced: _reduced,
        highContrast: config.settings.highContrast,
        chaseFront: _chaseFront,
        dashGlow: _dashGlow,
      ),
    );
    canvas.restore();

    if (_flash > 0) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, sz.width, sz.height),
        Paint()..color = _flashColor.withAlpha((90 * _flash).round()),
      );
    }
    super.render(canvas);
  }

  @override
  void onRemove() {
    _toasts.close();
    super.onRemove();
  }
}
