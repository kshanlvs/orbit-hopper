import 'package:orbit_hopper/neon/engine/hazards.dart';
import 'package:orbit_hopper/neon/engine/neon_world.dart';
import 'package:orbit_hopper/neon/engine/tuning.dart';
import 'package:orbit_hopper/neon/engine/validator.dart';

/// Plays a world perfectly-enough: whenever it enters a chunk it plans a
/// proven route from its exact state and follows it.
class NeonBot {
  NeonBot(this.world);

  final NeonWorld world;
  Chunk? _planned;
  Set<int> _flips = {};
  int _step = 0;
  int replans = 0;
  int failedPlans = 0;

  void tick() {
    final c = world.current;
    if (!identical(c, _planned)) {
      _planned = c;
      _step = 0;
      var p = RouteValidator.plan(c, world.orb.copy(), world.s, minGap: 0.12);
      p ??= RouteValidator.plan(c, world.orb.copy(), world.s, minGap: 0.02);
      if (p == null) failedPlans++;
      _flips = p?.flips.toSet() ?? {};
      replans++;
    }
    if (_flips.contains(_step)) world.flip();
    _step++;
    world.update(Tune.dt);
  }
}
