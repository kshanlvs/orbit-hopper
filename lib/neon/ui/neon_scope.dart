import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../audio/neon_audio.dart';
import '../progression/neon_cubit.dart';
import 'neon_style.dart';

/// Wraps every Neon Shift screen: loads the profile, switches to
/// landscape, owns the audio, and restores everything when you leave.
class NeonScope extends StatefulWidget {
  const NeonScope({
    super.key,
    required this.child,
    this.onEnter,
    this.onLeave,
    this.restorePortrait = false,
  });

  final Widget child;

  /// Hooks for a host app (Orbit Hopper silences its own music here).
  final VoidCallback? onEnter;
  final VoidCallback? onLeave;
  final bool restorePortrait;

  @override
  State<NeonScope> createState() => _NeonScopeState();
}

class _NeonScopeState extends State<NeonScope> {
  NeonCubit? _cubit;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    widget.onEnter?.call();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final cubit = NeonCubit(SharedPrefsNeonRepository(prefs));
    await cubit.load();
    final s = cubit.state.settings;
    // Sounds load in the background; the menu appears immediately.
    NeonAudio.instance
        .init(sfx: s.sfx, music: s.music, haptics: s.haptics)
        .then((_) => NeonAudio.instance.music(NeonTrack.menu));
    if (!mounted) {
      await cubit.close();
      return;
    }
    setState(() => _cubit = cubit);
  }

  @override
  void dispose() {
    _cubit?.close();
    NeonAudio.instance.stopMusic();
    if (widget.restorePortrait) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
    widget.onLeave?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = _cubit;
    return Theme(
      data: neonTheme(),
      child: cubit == null
          ? const ColoredBox(
              color: NeonColors.bg,
              child: Center(child: CircularProgressIndicator(color: NeonColors.cyan)),
            )
          : BlocProvider.value(value: cubit, child: widget.child),
    );
  }
}
