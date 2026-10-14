import 'dart:ui';

import 'package:flutter/painting.dart' show HSVColor;

import '../engine/hazards.dart';

/// Colours for one visual dimension.
///
/// Hazard colour meaning never changes: [dash] (magenta) hazards can be
/// Pulse-Dashed through; [solid] ones never can. Dashable shapes also carry
/// an inner outline, so the difference does not rely on colour alone.
class NeonPalette {
  const NeonPalette({
    required this.bgTop,
    required this.bgBottom,
    required this.grid,
    required this.wall,
    required this.solid,
    required this.accent,
    required this.shard,
    this.dash = const Color(0xFFFF3DCB),
    this.risk = const Color(0xFFFFC94D),
  });

  final Color bgTop, bgBottom, grid, wall, solid, accent, shard, dash, risk;

  static NeonPalette lerp(NeonPalette a, NeonPalette b, double t) {
    Color l(Color x, Color y) => Color.lerp(x, y, t)!;
    return NeonPalette(
      bgTop: l(a.bgTop, b.bgTop),
      bgBottom: l(a.bgBottom, b.bgBottom),
      grid: l(a.grid, b.grid),
      wall: l(a.wall, b.wall),
      solid: l(a.solid, b.solid),
      accent: l(a.accent, b.accent),
      shard: l(a.shard, b.shard),
      dash: l(a.dash, b.dash),
      risk: l(a.risk, b.risk),
    );
  }

  static Color _hue(Color c, double degrees) {
    final h = HSVColor.fromColor(c);
    return h.withHue((h.hue + degrees) % 360).toColor();
  }

  /// The palette a Reality Break shifts to. [t] is time, for PRISM's
  /// slow colour cycling.
  NeonPalette shifted(BreakVariant v, double t) => switch (v) {
        BreakVariant.prism => NeonPalette(
            bgTop: bgTop,
            bgBottom: _hue(bgBottom, t * 40),
            grid: _hue(grid, t * 60),
            wall: _hue(wall, t * 60),
            solid: _hue(solid, t * 60 + 40),
            accent: _hue(accent, t * 60 + 120),
            shard: shard,
          ),
        BreakVariant.flux => NeonPalette(
            bgTop: Color.lerp(bgTop, const Color(0xFF12001F), 0.6)!,
            bgBottom: Color.lerp(bgBottom, const Color(0xFF2A0045), 0.6)!,
            grid: accent,
            wall: accent,
            solid: solid,
            accent: wall,
            shard: shard,
          ),
        BreakVariant.twist => NeonPalette(
            bgTop: bgTop,
            bgBottom: Color.lerp(bgBottom, const Color(0xFF250018), 0.5)!,
            grid: Color.lerp(grid, dash, 0.4)!,
            wall: Color.lerp(wall, dash, 0.45)!,
            solid: solid,
            accent: wall,
            shard: shard,
          ),
        BreakVariant.squeeze => NeonPalette(
            bgTop: Color.lerp(bgTop, const Color(0xFF1A0E00), 0.5)!,
            bgBottom: Color.lerp(bgBottom, const Color(0xFF2A1400), 0.5)!,
            grid: Color.lerp(grid, const Color(0xFF6B4300), 0.6)!,
            wall: const Color(0xFFFFB43B),
            solid: solid,
            accent: accent,
            shard: shard,
          ),
      };

  static const core = NeonPalette(
    bgTop: Color(0xFF06030E),
    bgBottom: Color(0xFF0E0624),
    grid: Color(0xFF2B1B66),
    wall: Color(0xFF00E5FF),
    solid: Color(0xFF00E5FF),
    accent: Color(0xFF8A5CFF),
    shard: Color(0xFF8CFBFF),
  );

  static const byDimension = <String, NeonPalette>{
    'core': core,
    'sunset': NeonPalette(
      bgTop: Color(0xFF12041C),
      bgBottom: Color(0xFF35103A),
      grid: Color(0xFF7A2A5C),
      wall: Color(0xFFFF9A3C),
      solid: Color(0xFFFFD060),
      accent: Color(0xFFFF4F9A),
      shard: Color(0xFFFFE6A0),
    ),
    'toxic': NeonPalette(
      bgTop: Color(0xFF010804),
      bgBottom: Color(0xFF05180C),
      grid: Color(0xFF115A30),
      wall: Color(0xFF39FF6A),
      solid: Color(0xFFC6FF3B),
      accent: Color(0xFF00FFC6),
      shard: Color(0xFFE8FF8A),
    ),
    'ice': NeonPalette(
      bgTop: Color(0xFF030913),
      bgBottom: Color(0xFF0B1B36),
      grid: Color(0xFF22588C),
      wall: Color(0xFFC8F2FF),
      solid: Color(0xFF6FD3FF),
      accent: Color(0xFFA0A8FF),
      shard: Color(0xFFFFFFFF),
    ),
    'inferno': NeonPalette(
      bgTop: Color(0xFF0E0201),
      bgBottom: Color(0xFF2A0904),
      grid: Color(0xFF6A1A08),
      wall: Color(0xFFFF5A1F),
      solid: Color(0xFFFFB020),
      accent: Color(0xFFFF2D55),
      shard: Color(0xFFFFE36E),
    ),
    'void': NeonPalette(
      bgTop: Color(0xFF000000),
      bgBottom: Color(0xFF060606),
      grid: Color(0xFF1C1C1C),
      wall: Color(0xFFFFFFFF),
      solid: Color(0xFFE6E6E6),
      accent: Color(0xFF8C8C8C),
      shard: Color(0xFFFFFFFF),
    ),
  };

  static NeonPalette of(String dimension) => byDimension[dimension] ?? core;
}

/// How an orb skin looks. Cosmetic only.
class SkinLook {
  const SkinLook(this.core, this.glow, this.style);

  final Color core;
  final Color glow;
  final String style;

  static const byId = <String, SkinLook>{
    'pulse': SkinLook(Color(0xFFFFFFFF), Color(0xFF00E5FF), 'pulse'),
    'nova': SkinLook(Color(0xFFFFF4C2), Color(0xFFFFB84D), 'nova'),
    'plasma': SkinLook(Color(0xFFF2DDFF), Color(0xFFB04DFF), 'plasma'),
    'venom': SkinLook(Color(0xFFEAFFD6), Color(0xFF5CFF3A), 'venom'),
    'ghost': SkinLook(Color(0x00FFFFFF), Color(0xFFBFD8FF), 'ghost'),
    'prism': SkinLook(Color(0xFFFFFFFF), Color(0xFFFF6AD5), 'prism'),
  };

  static SkinLook of(String id) => byId[id] ?? byId['pulse']!;

  /// Glow colour now (Prism cycles through the spectrum).
  Color glowAt(double t) {
    if (style != 'prism') return glow;
    return HSVColor.fromAHSV(1, (t * 90) % 360, 0.75, 1).toColor();
  }
}
