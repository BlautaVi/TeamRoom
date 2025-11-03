import 'package:flutter/material.dart';

class AnimatedTapWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const AnimatedTapWrapper({
    super.key,
    required this.child,
    this.onTap,
  });

  @override
  State<AnimatedTapWrapper> createState() => _AnimatedTapWrapperState();
}

class _AnimatedTapWrapperState extends State<AnimatedTapWrapper> {
  bool _isPressed = false;

  void _onTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    widget.onTap?.call();
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}