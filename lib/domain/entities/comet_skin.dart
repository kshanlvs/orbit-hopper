class CometSkin {
  const CometSkin({
    required this.id,
    required this.name,
    required this.argb,
    required this.cost,
    this.rainbow = false,
  });

  final String id;
  final String name;

  /// Comet colour as 0xAARRGGBB (kept as int so the domain layer stays UI-free).
  final int argb;
  final int cost;

  /// Rainbow skins cycle their hue over time.
  final bool rainbow;
}

abstract final class CometSkins {
  static const all = <CometSkin>[
    CometSkin(id: 'ice', name: 'Ice Comet', argb: 0xFF5CE1FF, cost: 0),
    CometSkin(id: 'solar', name: 'Solar Flare', argb: 0xFFFF9F43, cost: 60),
    CometSkin(id: 'venom', name: 'Venom', argb: 0xFF7CFF6B, cost: 150),
    CometSkin(id: 'nebula', name: 'Nebula', argb: 0xFFC77DFF, cost: 300),
    CometSkin(id: 'ruby', name: 'Ruby Core', argb: 0xFFFF4D6D, cost: 500),
    CometSkin(id: 'gold', name: 'Golden Tail', argb: 0xFFFFD166, cost: 800),
    CometSkin(id: 'prism', name: 'Prism', argb: 0xFFFFFFFF, cost: 1500, rainbow: true),
  ];

  static CometSkin byId(String id) =>
      all.firstWhere((s) => s.id == id, orElse: () => all.first);
}
