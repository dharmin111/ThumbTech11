// presentation/AdminScreen/widgets/hover_scale.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Builder receives (context, isHovering, isPressed) so the caller can
/// change shadow depth, colors, or icon transforms based on hover state.
typedef HoverBuilder = Widget Function(
    BuildContext context,
    bool isHovering,
    bool isPressed,
    );

/// Wrap any card/button with this to get a smooth, web-friendly
/// hover-lift + press-down animation using MouseRegion + AnimatedScale.
class HoverScale extends StatefulWidget {
  final HoverBuilder builder;
  final VoidCallback? onTap;
  final double hoverScale;
  final double pressScale;
  final Duration duration;

  const HoverScale({
    super.key,
    required this.builder,
    this.onTap,
    this.hoverScale = 1.03,
    this.pressScale = 0.97,
    this.duration = const Duration(milliseconds: 220),
  });

  @override
  State<HoverScale> createState() => _HoverScaleState();
}

class _HoverScaleState extends State<HoverScale> {
  bool _hovering = false;
  bool _pressed = false;

  void _setHover(bool value) {
    if (_hovering == value) return;
    setState(() => _hovering = value);
  }

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final double scale =
    _pressed ? widget.pressScale : (_hovering ? widget.hoverScale : 1.0);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _setHover(true),
      onExit: (_) {
        _setHover(false);
        _setPressed(false);
      },
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap == null
            ? null
            : () {
          HapticFeedback.lightImpact();
          widget.onTap!.call();
        },
        child: AnimatedScale(
          scale: scale,
          duration: widget.duration,
          curve: Curves.easeOutCubic,
          child: AnimatedSlide(
            offset: _hovering ? const Offset(0, -0.02) : Offset.zero,
            duration: widget.duration,
            curve: Curves.easeOutCubic,
            child: widget.builder(context, _hovering, _pressed),
          ),
        ),
      ),
    );
  }
}