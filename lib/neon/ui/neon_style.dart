import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio/neon_audio.dart';

abstract final class NeonColors {
  static const bg = Color(0xFF06030E);
  static const panel = Color(0xFF0F0A22);
  static const cyan = Color(0xFF00E5FF);
  static const violet = Color(0xFF8A5CFF);
  static const magenta = Color(0xFFFF3DCB);
  static const gold = Color(0xFFFFC94D);
  static const text = Color(0xFFEDEBFF);
  static const dim = Color(0xFF8D88B5);
}

abstract final class NeonText {
  static TextStyle glow(double size, Color color, {FontWeight weight = FontWeight.w800, double spacing = 2}) =>
      TextStyle(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: spacing,
        shadows: [
          Shadow(color: color.withAlpha(200), blurRadius: size * 0.5),
          Shadow(color: color.withAlpha(110), blurRadius: size * 1.2),
        ],
      );

  static TextStyle body(double size, {Color color = NeonColors.text, FontWeight weight = FontWeight.w600}) =>
      TextStyle(fontSize: size, color: color, fontWeight: weight, letterSpacing: 0.4, height: 1.25);

  static const label = TextStyle(
    fontSize: 11,
    color: NeonColors.dim,
    fontWeight: FontWeight.w700,
    letterSpacing: 2,
  );
}

ThemeData neonTheme() => ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: NeonColors.bg,
      colorScheme: const ColorScheme.dark(
        primary: NeonColors.cyan,
        secondary: NeonColors.magenta,
        surface: NeonColors.panel,
      ),
      switchTheme: SwitchThemeData(
        thumbColor:
            WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? NeonColors.cyan : NeonColors.dim),
        trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? NeonColors.cyan.withAlpha(90) : const Color(0xFF231C40)),
      ),
      useMaterial3: true,
    );

/// A glowing outlined panel.
class NeonPanel extends StatelessWidget {
  const NeonPanel(
      {super.key,
      required this.child,
      this.color = NeonColors.violet,
      this.padding = const EdgeInsets.all(14),
      this.glow = 0.35});

  final Widget child;
  final Color color;
  final EdgeInsets padding;
  final double glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: NeonColors.panel.withAlpha(225),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(170), width: 1.4),
        boxShadow: [BoxShadow(color: color.withAlpha((120 * glow).round()), blurRadius: 18)],
      ),
      child: child,
    );
  }
}

/// A neon button with a press animation, sound and haptic tick.
class NeonButton extends StatefulWidget {
  const NeonButton({
    super.key,
    required this.label,
    required this.onTap,
    this.color = NeonColors.cyan,
    this.icon,
    this.big = false,
    this.filled = false,
    this.width,
  });

  final String label;
  final VoidCallback? onTap;
  final Color color;
  final IconData? icon;
  final bool big;
  final bool filled;
  final double? width;

  @override
  State<NeonButton> createState() => _NeonButtonState();
}

class _NeonButtonState extends State<NeonButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final c = enabled ? widget.color : NeonColors.dim;
    final h = widget.big ? 60.0 : 46.0;
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTap: enabled
            ? () {
                NeonAudio.instance.play(NeonSfx.ui);
                NeonAudio.instance.tapHaptic();
                widget.onTap!();
              }
            : null,
        child: AnimatedScale(
          scale: _down ? 0.95 : 1,
          duration: const Duration(milliseconds: 90),
          child: Container(
            height: h,
            width: widget.width,
            padding: EdgeInsets.symmetric(horizontal: widget.big ? 28 : 18),
            decoration: BoxDecoration(
              color: widget.filled ? c.withAlpha(_down ? 120 : 70) : NeonColors.panel.withAlpha(200),
              borderRadius: BorderRadius.circular(h / 2),
              border: Border.all(color: c, width: widget.big ? 2.2 : 1.6),
              boxShadow: [
                BoxShadow(color: c.withAlpha(enabled ? (_down ? 170 : 100) : 0), blurRadius: widget.big ? 24 : 14)
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, color: c, size: widget.big ? 26 : 20),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: NeonText.glow(widget.big ? 22 : 15, enabled ? NeonColors.text : NeonColors.dim, spacing: 3),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small round icon button (pause, back).
class NeonIconButton extends StatelessWidget {
  const NeonIconButton(
      {super.key, required this.icon, required this.onTap, this.color = NeonColors.cyan, this.size = 44, this.tooltip});

  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final double size;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          NeonAudio.instance.play(NeonSfx.ui);
          NeonAudio.instance.tapHaptic();
          onTap();
        },
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: NeonColors.panel.withAlpha(200),
            border: Border.all(color: color.withAlpha(200), width: 1.5),
            boxShadow: [BoxShadow(color: color.withAlpha(80), blurRadius: 10)],
          ),
          child: Icon(icon, color: color, size: size * 0.5),
        ),
      ),
    );
  }
}

/// Energy amount with the shard icon.
class EnergyChip extends StatelessWidget {
  const EnergyChip({super.key, required this.amount, this.size = 16});

  final int amount;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.diamond, color: NeonColors.cyan, size: size + 2),
        const SizedBox(width: 6),
        Text(formatInt(amount), style: NeonText.glow(size, NeonColors.text, spacing: 1)),
      ],
    );
  }
}

String formatInt(int v) {
  final s = v.abs().toString();
  final b = StringBuffer(v < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

/// Animated synthwave backdrop for the menus.
class NeonBackdrop extends StatefulWidget {
  const NeonBackdrop({super.key, required this.child, this.reduced = false});

  final Widget child;
  final bool reduced;

  @override
  State<NeonBackdrop> createState() => _NeonBackdropState();
}

class _NeonBackdropState extends State<NeonBackdrop> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: CustomPaint(painter: _BackdropPainter(_c, widget.reduced)),
        ),
        widget.child,
      ],
    );
  }
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter(this.anim, this.reduced) : super(repaint: reduced ? null : anim);

  final Animation<double> anim;
  final bool reduced;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF06030E), Color(0xFF130833), Color(0xFF06030E)],
          stops: [0, 0.62, 1],
        ).createShader(rect),
    );
    final horizon = h * 0.62;
    // Sun.
    final sunC = Offset(w * 0.72, horizon - h * 0.05);
    canvas.drawCircle(
      sunC,
      h * 0.26,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFF3DCB), Color(0xFF8A5CFF)],
        ).createShader(Rect.fromCircle(center: sunC, radius: h * 0.26))
        ..color = const Color(0x33FFFFFF),
    );
    final bandPaint = Paint()..color = const Color(0xFF06030E);
    for (var i = 0; i < 5; i++) {
      final y = sunC.dy + h * 0.03 * i + h * 0.02;
      canvas.drawRect(Rect.fromLTWH(sunC.dx - h * 0.3, y, h * 0.6, h * 0.008 * (i + 1)), bandPaint);
    }
    canvas.drawRect(Rect.fromLTWH(0, horizon, w, h - horizon), Paint()..color = const Color(0xFF06030E));

    // Perspective floor grid, scrolling toward the viewer.
    final grid = Paint()
      ..color = const Color(0xFF8A5CFF).withAlpha(120)
      ..strokeWidth = 1.2;
    final vp = Offset(w * 0.5, horizon);
    for (var i = -14; i <= 14; i++) {
      canvas.drawLine(vp, Offset(w * 0.5 + i * w * 0.12, h + 10), grid);
    }
    final t = reduced ? 0.0 : (anim.value * 20) % 1;
    for (var i = 0; i < 10; i++) {
      final k = (i + t) / 10;
      final y = horizon + (h - horizon) * math.pow(k, 2.2);
      grid.color = const Color(0xFF00E5FF).withAlpha((40 + 120 * k).round());
      canvas.drawLine(Offset(0, y), Offset(w, y), grid);
    }
    canvas.drawLine(
      Offset(0, horizon),
      Offset(w, horizon),
      Paint()
        ..color = const Color(0xFFFF3DCB)
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_BackdropPainter old) => old.reduced != reduced;
}
