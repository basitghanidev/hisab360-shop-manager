import 'package:flutter/material.dart';

class AnimatedSyncIcon extends StatefulWidget {
  final VoidCallback onPressed;
  final Color? color;
  const AnimatedSyncIcon({super.key, required this.onPressed, this.color});

  @override
  State<AnimatedSyncIcon> createState() => _AnimatedSyncIconState();
}

class _AnimatedSyncIconState extends State<AnimatedSyncIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handlePress() {
    if (_controller.isAnimating) return;
    _controller.forward(from: 0);
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: IconButton(
        icon: Icon(Icons.sync, color: widget.color),
        onPressed: _handlePress,
      ),
    );
  }
}
