import 'package:flutter/material.dart';

/// Motion Design System Widgets for BizManager.
/// Adds smooth numerical value animations and subtle pulsing status badges.

/// Animates numerical values smoothly (e.g. Total Sale Rs. 0 -> Rs. 12,500).
class AnimatedCountText extends StatelessWidget {
  final double value;
  final String prefix;
  final String suffix;
  final TextStyle? style;
  final Duration duration;
  final int fractionDigits;

  const AnimatedCountText({
    super.key,
    required this.value,
    this.prefix = '',
    this.suffix = '',
    this.style,
    this.duration = const Duration(milliseconds: 600),
    this.fractionDigits = 0,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) {
        final formatted = animatedValue.toStringAsFixed(fractionDigits);
        return Text(
          '$prefix$formatted$suffix',
          style: style,
        );
      },
    );
  }
}

/// Subtle pulsing animation for warnings (e.g., Low Stock alerts, Unpaid due badges).
class PulsingBadge extends StatefulWidget {
  final Widget child;
  final bool isPulsing;
  final Duration duration;

  const PulsingBadge({
    super.key,
    required this.child,
    this.isPulsing = true,
    this.duration = const Duration(milliseconds: 1200),
  });

  @override
  State<PulsingBadge> createState() => _PulsingBadgeState();
}

class _PulsingBadgeState extends State<PulsingBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.isPulsing) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant PulsingBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPulsing && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isPulsing && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isPulsing) return widget.child;
    return ScaleTransition(
      scale: _scaleAnimation,
      child: widget.child,
    );
  }
}
