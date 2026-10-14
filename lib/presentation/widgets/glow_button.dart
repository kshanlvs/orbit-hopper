import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../game/audio/game_audio.dart';

/// Neon pill button with a press-down scale animation.
class GlowButton extends StatefulWidget {
  const GlowButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = AppColors.accent,
    this.filled = true,
    this.width = 240,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final Color color;
  final bool filled;
  final double width;

  @override
  State<GlowButton> createState() => _GlowButtonState();
}

class _GlowButtonState extends State<GlowButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final fg = widget.filled ? AppColors.background : widget.color;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: () {
        GameAudio.instance.play(Sfx.uiTap);
        // On web, browsers only allow audio after a user gesture.
        GameAudio.instance.startMusic();
        widget.onPressed();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1,
        duration: const Duration(milliseconds: 90),
        child: Container(
          width: widget.width,
          height: 58,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            color: widget.filled ? widget.color : Colors.transparent,
            border: Border.all(color: widget.color.fade(widget.filled ? 1 : 0.7), width: 2),
            boxShadow: [
              BoxShadow(
                color: widget.color.fade(widget.filled ? 0.55 : 0.2),
                blurRadius: 24,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, color: fg, size: 24),
                const SizedBox(width: 10),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  color: fg,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
