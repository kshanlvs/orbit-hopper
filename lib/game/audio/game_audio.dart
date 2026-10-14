import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

import '../logic/cosmos.dart';

enum Sfx {
  launch('launch.wav', 0.5, 3),
  capture('capture.wav', 0.55, 3),
  stardust('stardust.wav', 0.4, 4),
  warning('warning.wav', 0.55, 2),
  death('death.wav', 0.85, 1),
  arrival('sector.wav', 0.55, 1),
  reveal('reveal.wav', 0.9, 1),
  ping('ping.wav', 0.5, 2),
  warp('warp.wav', 0.6, 1),
  wormhole('wormhole.wav', 0.75, 1),
  shield('shield.wav', 0.55, 1),
  shieldBreak('shield_break.wav', 0.7, 1),
  mission('mission.wav', 0.6, 1),
  uiTap('ui_tap.wav', 0.35, 2);

  const Sfx(this.file, this.volume, this.voices);

  final String file;
  final double volume;

  /// How many copies can overlap (e.g. three stardust pickups in a row).
  final int voices;
}

/// A few pre-loaded low-latency players for one sound, used round-robin.
/// Creating a player per sound (the old approach) is what made effects
/// arrive late and caused frame hitches.
class _Pool {
  _Pool(this._players);

  final List<AudioPlayer> _players;
  int _next = 0;

  static Future<_Pool> create(String asset, int voices, double volume) async {
    final players = await Future.wait(List.generate(voices, (_) async {
      final p = AudioPlayer();
      await p.setPlayerMode(PlayerMode.lowLatency);
      await p.setReleaseMode(ReleaseMode.stop);
      await p.setVolume(volume);
      await p.setSource(AssetSource(asset));
      return p;
    }));
    return _Pool(players);
  }

  void play() {
    final p = _players[_next];
    _next = (_next + 1) % _players.length;
    if (p.state == PlayerState.playing) {
      p.stop().then((_) => p.resume()).catchError((Object _) {});
    } else {
      p.resume().catchError((Object _) {});
    }
  }
}

/// All sound and music. Sound effects fire instantly from pools; music has
/// one track per mood (region) and crossfades as you travel. Every failure
/// is swallowed: missing audio must never crash or stall the game.
class GameAudio with WidgetsBindingObserver {
  GameAudio._();

  static final GameAudio instance = GameAudio._();

  static const _musicVolume = 0.45;
  static const _fadeSeconds = 2.6;

  final Map<String, _Pool> _pools = {};
  final List<AudioPlayer> _music = [AudioPlayer(), AudioPlayer()];
  final List<double> _vol = [0, 0];
  int _active = 0;
  Mood _mood = Mood.solar;
  bool _musicStarted = false;
  double _duck = 1;
  Timer? _fade;
  int _fadeToken = 0;

  bool _enabled = true;
  bool _ready = false;
  bool _observing = false;

  bool get enabled => _enabled;

  Future<void> init({required bool enabled, Mood mood = Mood.solar}) async {
    _enabled = enabled;
    _mood = mood;
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
    try {
      for (final m in _music) {
        await m.setReleaseMode(ReleaseMode.loop);
      }
      await Future.wait([
        for (final s in Sfx.values) _Pool.create('audio/${s.file}', s.voices, s.volume).then((p) => _pools[s.file] = p),
        for (var i = 1; i <= 5; i++)
          _Pool.create('audio/perfect_$i.wav', 2, 0.65).then((p) => _pools['perfect_$i.wav'] = p),
      ]);
      _ready = true;
    } catch (e) {
      debugPrint('GameAudio init failed: $e');
    }
  }

  void play(Sfx sfx) {
    if (_enabled && _ready) _pools[sfx.file]?.play();
  }

  /// Rising chime: combo 1..5 maps to five ascending notes.
  void perfect(int combo) {
    if (_enabled && _ready) _pools['perfect_${combo.clamp(1, 5)}.wav']?.play();
  }

  // ------------------------------------------------------------- music

  /// Starts music if it isn't running yet (safe to call often).
  Future<void> startMusic() async {
    if (!_enabled || _musicStarted) return;
    _musicStarted = true;
    await _crossfadeTo(_mood);
  }

  /// Switches the music to match a region. Crossfades smoothly.
  Future<void> setMood(Mood mood) async {
    if (mood == _mood && _musicStarted) return;
    _mood = mood;
    if (!_enabled) return;
    _musicStarted = true;
    await _crossfadeTo(mood);
  }

  /// Lowers the music (pause menu, game over) without stopping it.
  void setDucked(bool ducked) {
    _duck = ducked ? 0.35 : 1;
    if (_fade == null && _musicStarted) _setVol(_active, _target);
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    if (value) {
      _musicStarted = false;
      await startMusic();
    } else {
      _fade?.cancel();
      _fade = null;
      _musicStarted = false;
      for (var i = 0; i < 2; i++) {
        _vol[i] = 0;
        try {
          await _music[i].stop();
        } catch (_) {}
      }
    }
  }

  double get _target => _musicVolume * _duck;

  void _setVol(int i, double v) {
    _vol[i] = v;
    _music[i].setVolume(v).catchError((Object _) {});
  }

  Future<void> _crossfadeTo(Mood mood) async {
    final token = ++_fadeToken;
    _fade?.cancel();
    _fade = null;
    final outgoing = _active;
    final incoming = 1 - _active;
    _active = incoming;
    try {
      await _music[incoming].stop();
      _vol[incoming] = 0;
      await _music[incoming].setVolume(0);
      await _music[incoming].setSource(AssetSource('audio/music_${mood.name}.wav'));
      if (token != _fadeToken) return;
      await _music[incoming].resume();
    } catch (e) {
      debugPrint('GameAudio music failed: $e'); // e.g. web autoplay block
      _musicStarted = false;
      return;
    }
    if (token != _fadeToken) return;
    final outStart = _vol[outgoing];
    var t = 0.0;
    _fade = Timer.periodic(const Duration(milliseconds: 60), (timer) {
      t += 0.06 / _fadeSeconds;
      final k = t.clamp(0.0, 1.0).toDouble();
      _setVol(incoming, _target * k);
      if (outStart > 0) _setVol(outgoing, outStart * (1 - k));
      if (k >= 1) {
        timer.cancel();
        if (identical(_fade, timer)) _fade = null;
        _music[outgoing].stop().catchError((Object _) {});
        _vol[outgoing] = 0;
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_musicStarted) return;
    if (state == AppLifecycleState.resumed) {
      if (_enabled) _music[_active].resume().catchError((Object _) {});
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      for (final m in _music) {
        m.pause().catchError((Object _) {});
      }
    }
  }
}
