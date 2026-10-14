import 'package:flutter/material.dart';

import '../../game/logic/cosmos.dart';
import '../../game/render/sprites.dart';

/// A small animated celestial body, drawn with the same cached sprites as
/// the game. Locked bodies show as a dark silhouette with a "?".
class BodyIcon extends StatefulWidget {
  const BodyIcon({super.key, required this.look, this.size = 64, this.locked = false, this.seed = 0});

  final BodyLook look;
  final double size;
  final bool locked;
  final int seed;

  @override
  State<BodyIcon> createState() => _BodyIconState();
}

class _BodyIconState extends State<BodyIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(seconds: 1));
  final Stopwatch _clock = Stopwatch()..start();

  @override
  void initState() {
    super.initState();
    if (!widget.locked) _controller.repeat();
  }

  @override
  void didUpdateWidget(BodyIcon old) {
    super.didUpdateWidget(old);
    if (widget.locked) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: _BodyPainter(
              widget.look,
              widget.locked ? 0 : _clock.elapsedMilliseconds / 1000,
              widget.seed,
              widget.locked,
            ),
          ),
        ),
      ),
    );
  }
}

class _BodyPainter extends CustomPainter {
  _BodyPainter(this.look, this.time, this.seed, this.locked);

  final BodyLook look;
  final double time;
  final int seed;
  final bool locked;

  @override
  void paint(Canvas canvas, Size size) {
    // Rings and glows extend beyond the body, so keep the core small.
    final extra = switch (look.style) {
      BodyStyle.ringed || BodyStyle.blackHole => 0.22,
      BodyStyle.sun || BodyStyle.star => 0.2,
      BodyStyle.galaxy || BodyStyle.nebula => 0.27,
      _ => 0.32,
    };
    final c = size.center(Offset.zero);
    final r = size.shortestSide * extra;
    BodySprites.draw(canvas, c, r, look, time, seed: seed, revealed: locked ? 0 : 1);
    if (locked) {
      canvas.drawCircle(
        c,
        r + 2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0x667CF5FF),
      );
      TextSprites.draw(canvas, '?', c, fontSize: r * 0.9, color: const Color(0xFF7CF5FF), opacity: 0.7);
    }
  }

  @override
  bool shouldRepaint(_BodyPainter old) => old.time != time || old.look != look || old.locked != locked;
}
