/// Small deterministic random generator (xorshift32).
///
/// The same seed always produces the same corridor, on every device, so a
/// hard sequence can be reproduced for debugging and the daily challenge
/// is identical for everyone.
class NeonRng {
  NeonRng(int seed) : _s = _mix(seed);

  int _s;

  static int _mix(int seed) {
    var x = (seed ^ 0x9E3779B9) & 0xFFFFFFFF;
    x = ((x ^ (x >> 16)) * 0x45D9F3B) & 0xFFFFFFFF;
    x = ((x ^ (x >> 16)) * 0x45D9F3B) & 0xFFFFFFFF;
    x = (x ^ (x >> 16)) & 0xFFFFFFFF;
    return x == 0 ? 0x1234567 : x;
  }

  int nextU32() {
    var x = _s;
    x ^= (x << 13) & 0xFFFFFFFF;
    x ^= x >> 17;
    x ^= (x << 5) & 0xFFFFFFFF;
    _s = x & 0xFFFFFFFF;
    return _s;
  }

  /// Uniform in [0, 1).
  double next() => nextU32() / 4294967296.0;

  double range(double a, double b) => a + (b - a) * next();

  int nextInt(int n) => n <= 1 ? 0 : nextU32() % n;

  bool chance(double p) => next() < p;

  T pick<T>(List<T> items) => items[nextInt(items.length)];

  /// A child generator, so one subsystem's draws don't shift another's.
  NeonRng fork() => NeonRng(nextU32());
}
