import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

enum NeonSfx {
  flip('flip.wav', 0.45, 4),
  shard('shard.wav', 0.42, 4),
  nearMiss('near_miss.wav', 0.6, 2),
  dashReady('dash_ready.wav', 0.55, 1),
  dash('dash.wav', 0.7, 1),
  pierce('pierce.wav', 0.6, 3),
  breakWarn('break_warn.wav', 0.55, 1),
  breakStart('break_start.wav', 0.75, 1),
  chaseWarn('chase_warn.wav', 0.6, 1),
  escape('escape.wav', 0.75, 1),
  chainBreak('chain_break.wav', 0.4, 1),
  milestone('milestone.wav', 0.5, 1),
  death('death.wav', 0.85, 1),
  record('record.wav', 0.85, 1),
  ui('ui.wav', 0.35, 2);

  const NeonSfx(this.file, this.volume, this.voices);

  final String file;
  final double volume;
  final int voices;
}

enum NeonTrack {
  menu('neon_menu.wav'),
  run('neon_run.wav');

  const NeonTrack(this.file);
  final String file;
}

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

  Future<void> dispose() async {
    for (final p in _players) {
      try {
        await p.dispose();
      } catch (_) {}
    }
  }
}

/// Neon Shift's sound: low-latency effect pools, a crossfading music pair,
/// separate music/effects switches, and haptics. Every failure is
/// swallowed — missing or blocked audio must never stall the game.
class NeonAudio with WidgetsBindingObserver {
  NeonAudio._();

  static final NeonAudio instance = NeonAudio._();

  static const _musicVolume = 0.5;

  final Map<String, _Pool> _pools = {};
  final List<AudioPlayer> _music = [];
  final List<double> _vol = [0, 0];
  int _active = 0;
  NeonTrack? _track;
  double _duck = 1;
  Timer? _fade;
  int _token = 0;

  bool sfxOn = true;
  bool musicOn = true;
  bool hapticsOn = true;

  bool _ready = false;
  Future<void>? _loading;
  bool _observing = false;
  bool _paused = false;

  /// Tests set this: no players are created and nothing touches plugins.
  static bool silent = false;

  Future<void> init({required bool sfx, required bool music, required bool haptics}) {
    sfxOn = sfx;
    musicOn = music;
    hapticsOn = haptics && !silent;
    if (silent) return Future<void>.value();
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
    return _loading ??= _load();
  }

  Future<void> _load() async {
    try {
      if (_music.isEmpty) {
        _music.addAll([AudioPlayer(), AudioPlayer()]);
        for (final m in _music) {
          await m.setReleaseMode(ReleaseMode.loop);
        }
      }
      await Future.wait([
        for (final s in NeonSfx.values)
          _Pool.create('audio/neon/${s.file}', s.voices, s.volume).then((p) => _pools[s.file] = p),
        for (var i = 1; i <= 5; i++)
          _Pool.create('audio/neon/chain_$i.wav', 2, 0.55).then((p) => _pools['chain_$i'] = p),
      ]);
      _ready = true;
    } catch (e) {
      debugPrint('NeonAudio init failed: $e');
    }
  }

  void play(NeonSfx s) {
    if (sfxOn && _ready) _pools[s.file]?.play();
  }

  /// Rising five-note chime as the chain grows.
  void chain(int n) {
    if (sfxOn && _ready && n > 0) _pools['chain_${((n - 1) % 5) + 1}']?.play();
  }

  // --------------------------------------------------------------- haptics

  void tapHaptic() {
    if (hapticsOn) HapticFeedback.selectionClick();
  }

  void lightHaptic() {
    if (hapticsOn) HapticFeedback.lightImpact();
  }

  void mediumHaptic() {
    if (hapticsOn) HapticFeedback.mediumImpact();
  }

  void heavyHaptic() {
    if (hapticsOn) HapticFeedback.heavyImpact();
  }

  // ----------------------------------------------------------------- music

  Future<void> music(NeonTrack track) async {
    if (_track == track && _vol[_active] > 0) return;
    _track = track;
    if (!musicOn || _music.isEmpty) return;
    await _crossfadeTo(track);
  }

  void setDucked(bool ducked) {
    _duck = ducked ? 0.3 : 1;
    if (_fade == null && _music.isNotEmpty && _vol[_active] > 0) _setVol(_active, _target);
  }

  Future<void> apply({required bool sfx, required bool music, required bool haptics}) async {
    sfxOn = sfx;
    hapticsOn = haptics && !silent;
    if (music == musicOn) return;
    musicOn = music;
    if (music) {
      final t = _track;
      if (t != null) await _crossfadeTo(t);
    } else {
      await stopMusic(keepTrack: true);
    }
  }

  Future<void> stopMusic({bool keepTrack = false}) async {
    _token++;
    _fade?.cancel();
    _fade = null;
    if (!keepTrack) _track = null;
    for (var i = 0; i < _music.length; i++) {
      _vol[i] = 0;
      try {
        await _music[i].stop();
      } catch (_) {}
    }
  }

  double get _target => _musicVolume * _duck;

  void _setVol(int i, double v) {
    _vol[i] = v;
    _music[i].setVolume(v).catchError((Object _) {});
  }

  Future<void> _crossfadeTo(NeonTrack track) async {
    await (_loading ?? Future<void>.value());
    if (_music.isEmpty) return;
    final token = ++_token;
    _fade?.cancel();
    _fade = null;
    final outgoing = _active;
    final incoming = 1 - _active;
    _active = incoming;
    try {
      await _music[incoming].stop();
      _vol[incoming] = 0;
      await _music[incoming].setVolume(0);
      await _music[incoming].setSource(AssetSource('audio/neon/${track.file}'));
      if (token != _token) return;
      if (!_paused) await _music[incoming].resume();
    } catch (e) {
      debugPrint('NeonAudio music failed: $e');
      return;
    }
    final outStart = _vol[outgoing];
    var t = 0.0;
    _fade = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (token != _token) {
        timer.cancel();
        return;
      }
      t += 0.05 / 1.2;
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
    if (_music.isEmpty) return;
    if (state == AppLifecycleState.resumed) {
      _paused = false;
      if (musicOn && _track != null && _vol[_active] > 0) {
        _music[_active].resume().catchError((Object _) {});
      }
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _paused = true;
      for (final m in _music) {
        m.pause().catchError((Object _) {});
      }
    }
  }
}
