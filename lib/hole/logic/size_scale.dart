import 'dart:math' as math;

import '../../game/logic/cosmos.dart';

/// One stage of growth: from this radius (in metres) the black hole is big
/// enough to start eating these things.
class SizeTier {
  const SizeTier(this.name, this.minRadius, this.looks, this.fact, {this.real = true, this.topArgb, this.bottomArgb});

  final String name;

  /// Radius in metres at which this tier begins.
  final double minRadius;

  /// How objects of this size are drawn.
  final List<BodyLook> looks;

  /// A true fact about things of this size (story text when [real] is false).
  final String fact;
  final bool real;
  final int? topArgb;
  final int? bottomArgb;
}

const _dust = BodyLook(BodyStyle.rocky, 0xFF9C8F80, 0xFF4E463E);
const _greyRock = BodyLook(BodyStyle.cratered, 0xFF9A9A9E, 0xFF5E5E66);
const _brownRock = BodyLook(BodyStyle.rocky, 0xFF9C7A5B, 0xFF5A4232);
const _satellite = BodyLook(BodyStyle.probe, 0xFFD8D8D8, 0xFF5CE1FF);
const _goldSat = BodyLook(BodyStyle.probe, 0xFFFFD166, 0xFFD8D8D8);
const _ice = BodyLook(BodyStyle.icy, 0xFFD6ECF5, 0xFF8FB8CC);
const _comet = BodyLook(BodyStyle.cloud, 0xFFCFE9FF, 0xFF7FA7C9);
const _moonGrey = BodyLook(BodyStyle.cratered, 0xFFC9C6C0, 0xFF7A7670);
const _moonIce = BodyLook(BodyStyle.icy, 0xFFF0E2C8, 0xFFB07A55);
const _earthLike = BodyLook(BodyStyle.earth, 0xFF2E7BFF, 0xFF3FBF6A);
const _marsLike = BodyLook(BodyStyle.mars, 0xFFD9653B, 0xFF8C3A1E);
const _venusLike = BodyLook(BodyStyle.venus, 0xFFF1D79A, 0xFFC9A061);
const _jupiterLike = BodyLook(BodyStyle.banded, 0xFFE3B98A, 0xFFA8693F, spot: true);
const _saturnLike = BodyLook(BodyStyle.ringed, 0xFFE9D3A0, 0xFFB89A62, tilt: 0.35);
const _neptuneLike = BodyLook(BodyStyle.banded, 0xFF3D63E0, 0xFF223A99);
const _sunLike = BodyLook(BodyStyle.sun, 0xFFFFC23D, 0xFFFF7A1A);
const _blueStar = BodyLook(BodyStyle.star, 0xFFBFD6FF, 0xFFFFFFFF);
const _redDwarf = BodyLook(BodyStyle.star, 0xFFFF6A4D, 0xFFFFB199);
const _redGiant = BodyLook(BodyStyle.star, 0xFFFF5A2E, 0xFFFFA070);
const _nebulaPink = BodyLook(BodyStyle.nebula, 0xFFFF6FB5, 0xFF5C7CFF);
const _nebulaTeal = BodyLook(BodyStyle.nebula, 0xFF4FE3C1, 0xFF3A7BFF);
const _openCluster = BodyLook(BodyStyle.cluster, 0xFF8FB8FF, 0xFFE0ECFF);
const _globular = BodyLook(BodyStyle.cluster, 0xFFFFE2A0, 0xFFFFC870, spot: true);
const _spiral = BodyLook(BodyStyle.galaxy, 0xFFB5C8FF, 0xFFFFDFA8, tilt: 0.4);
const _goldGalaxy = BodyLook(BodyStyle.galaxy, 0xFFFFD9A0, 0xFFFFF4DD, tilt: 0.2);
const _galaxyCluster = BodyLook(BodyStyle.cluster, 0xFFFFD9A0, 0xFFB5C8FF, spot: true);
const _web = BodyLook(BodyStyle.nebula, 0xFFC77DFF, 0xFF5CE1FF);
const _universe = BodyLook(BodyStyle.cmb, 0xFFFF9966, 0xFF4D7CFF);

/// Real sizes, smallest to largest. Radii are in metres.
const sizeTiers = <SizeTier>[
  SizeTier('Space dust', 0, [_dust, _greyRock], 'Earth sweeps up many tonnes of space dust every single day.',
      topArgb: 0xFF05040C, bottomArgb: 0xFF16101E),
  SizeTier('Pebbles', 0.005, [_greyRock, _brownRock],
      'Most shooting stars are just dust and pebbles burning up high in our air.',
      topArgb: 0xFF06050E, bottomArgb: 0xFF1A1222),
  SizeTier('Meteoroids', 0.3, [_brownRock, _greyRock],
      'A meteoroid that survives the fall and lands on the ground is called a meteorite.',
      topArgb: 0xFF070612, bottomArgb: 0xFF1E1428),
  SizeTier('Satellites', 3, [_satellite, _goldSat, _greyRock],
      'Thousands of working satellites circle Earth today, for GPS, TV, weather and the internet.',
      topArgb: 0xFF040A16, bottomArgb: 0xFF0C2240),
  SizeTier('Asteroids', 200, [_greyRock, _brownRock, _ice],
      'The asteroid that ended the age of the dinosaurs was about 10 km wide.',
      topArgb: 0xFF0B0907, bottomArgb: 0xFF22180F),
  SizeTier('Comets', 20000, [_comet, _ice, _greyRock], "A comet's tail always points away from the Sun.",
      topArgb: 0xFF04060D, bottomArgb: 0xFF0B1424),
  SizeTier('Moons', 800000, [_moonGrey, _moonIce, _ice],
      "Ganymede, one of Jupiter's moons, is bigger than the planet Mercury.",
      topArgb: 0xFF050812, bottomArgb: 0xFF0E1C33),
  SizeTier('Planets', 3e6, [_earthLike, _marsLike, _venusLike], 'About 1.3 million Earths would fit inside the Sun.',
      topArgb: 0xFF060A1C, bottomArgb: 0xFF0B2240),
  SizeTier('Giant planets', 3e7, [_jupiterLike, _saturnLike, _neptuneLike],
      'Jupiter is so big that all the other planets could fit inside it.',
      topArgb: 0xFF0D0705, bottomArgb: 0xFF2A1308),
  SizeTier('Stars', 3e8, [_sunLike, _redDwarf, _blueStar],
      'Our Sun is a fairly ordinary star. Most stars are smaller, cooler red dwarfs.',
      topArgb: 0xFF140B04, bottomArgb: 0xFF3A2008),
  SizeTier('Giant stars', 3e10, [_redGiant, _blueStar],
      "Some giant stars are so big that, placed where the Sun is, they would swallow Jupiter's orbit.",
      topArgb: 0xFF180516, bottomArgb: 0xFF420D36),
  SizeTier('Nebulae & star clusters', 3e15, [_nebulaPink, _nebulaTeal, _openCluster, _globular],
      'Nebulae are vast clouds of gas and dust where new stars are born.',
      topArgb: 0xFF120420, bottomArgb: 0xFF2E0B3A),
  SizeTier('Galaxies', 3e19, [_spiral, _goldGalaxy],
      'The observable universe holds hundreds of billions of galaxies.',
      topArgb: 0xFF02020A, bottomArgb: 0xFF0C0E26),
  SizeTier('Galaxy clusters', 3e22, [_galaxyCluster, _goldGalaxy],
      'Galaxy clusters are the biggest things in the universe held together by gravity.',
      topArgb: 0xFF03020C, bottomArgb: 0xFF120C2A),
  SizeTier('The cosmic web', 3e24, [_web, _galaxyCluster],
      'Galaxies are strung along giant threads called the cosmic web, with huge empty voids in between.',
      topArgb: 0xFF05020E, bottomArgb: 0xFF1A0830),
  SizeTier('Other universes', 3e26, [_universe, _web],
      'Nobody knows what lies beyond the observable universe. From here on, it is pure imagination!',
      real: false, topArgb: 0xFF0A0410, bottomArgb: 0xFF1E0A24),
];

/// Each "Other universes" stage after the last tier is this many times bigger.
const double _beyondStep = 100;

/// Tier index for a radius. Past the last tier it keeps counting forever:
/// every [_beyondStep]× growth is a new "universe" stage.
int tierOfRadius(double r) {
  for (var i = sizeTiers.length - 1; i >= 0; i--) {
    if (r >= sizeTiers[i].minRadius) {
      if (i < sizeTiers.length - 1) return i;
      final extra = math.log(r / sizeTiers[i].minRadius) / math.log(_beyondStep);
      return i + extra.floor();
    }
  }
  return 0;
}

/// Radius at which tier [i] begins (works beyond the list too).
double tierStart(int i) {
  if (i < sizeTiers.length) return sizeTiers[i].minRadius;
  final last = sizeTiers.last.minRadius;
  return last * math.pow(_beyondStep, i - sizeTiers.length + 1).toDouble();
}

SizeTier tierInfo(int i) => sizeTiers[math.min(i, sizeTiers.length - 1)];

String tierName(int i) =>
    i < sizeTiers.length ? sizeTiers[i].name : 'Universe ${i - sizeTiers.length + 2}';

/// 0..1 progress from the start of the current tier to the next one, on a log scale.
double tierProgress(double r) {
  final t = tierOfRadius(r);
  final a = math.max(tierStart(t), 1e-4);
  final b = tierStart(t + 1);
  return ((math.log(r) - math.log(a)) / (math.log(b) - math.log(a))).clamp(0.0, 1.0).toDouble();
}

/// Things of real, known size (diameters in metres), to compare against.
const _comparisons = <(double, String)>[
  (0.002, 'a grain of sand'),
  (0.02, 'a marble'),
  (0.22, 'a football'),
  (1.8, 'a person'),
  (30, 'a blue whale'),
  (110, 'a football field'),
  (330, 'the Eiffel Tower'),
  (8849, 'Mount Everest'),
  (100000, 'the edge of space above Earth (100 km)'),
  (3.474e6, 'the Moon'),
  (1.2742e7, 'Earth'),
  (1.3982e8, 'Jupiter'),
  (1.3927e9, 'the Sun'),
  (2.99e11, "Earth's orbit around the Sun"),
  (1.0e12, 'the giant star Betelgeuse'),
  (9.0e12, "Neptune's orbit"),
  (9.46e15, 'a light-year'),
  (9.5e20, 'the Milky Way'),
  (9.5e22, 'our Local Group of galaxies'),
  (8.8e26, 'the observable universe'),
];

/// "Bigger than Mount Everest" for a black hole of this diameter.
String comparisonFor(double diameter) {
  String? best;
  for (final (size, name) in _comparisons) {
    if (diameter >= size) best = name;
  }
  return best == null ? 'Smaller than a grain of sand' : 'Bigger than $best';
}

/// Human-friendly length: 3.2 mm, 45 cm, 120 m, 8,849 km, 2.1 light-years…
String formatLength(double m) {
  const ly = 9.4607e15;
  if (m < 0.01) return '${(m * 1000).toStringAsFixed(1)} mm';
  if (m < 1) return '${(m * 100).toStringAsFixed(1)} cm';
  if (m < 1000) return '${m.toStringAsFixed(m < 10 ? 1 : 0)} m';
  final km = m / 1000;
  if (km < 1e6) return '${_group(km.round())} km';
  if (km < 1e9) return '${(km / 1e6).toStringAsFixed(1)} million km';
  if (m < 0.1 * ly) return '${(km / 1e9).toStringAsFixed(1)} billion km';
  final l = m / ly;
  if (l < 1000) return '${l.toStringAsFixed(l < 10 ? 1 : 0)} light-years';
  if (l < 1e6) return '${_group(l.round())} light-years';
  if (l < 1e9) return '${(l / 1e6).toStringAsFixed(1)} million light-years';
  if (l < 1e12) return '${(l / 1e9).toStringAsFixed(1)} billion light-years';
  return '${(l / 1e12).toStringAsFixed(1)} trillion light-years';
}

String _group(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}
