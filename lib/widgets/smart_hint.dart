import 'package:flutter/material.dart';

class SmartHint extends StatefulWidget {
  final bool condition;
  final Widget child;
  final String? message;
  final bool isCircular;

  const SmartHint({
    super.key,
    required this.condition,
    required this.child,
    this.message,
    this.isCircular = false,
  });

  @override
  State<SmartHint> createState() => _SmartHintState();
}

class _SmartHintState extends State<SmartHint> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _glowAnimation = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    if (widget.condition) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant SmartHint oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.condition && !oldWidget.condition) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.condition && oldWidget.condition) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.condition) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // Glowing effect behind the child
            Container(
              decoration: BoxDecoration(
                shape: widget.isCircular ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: widget.isCircular ? null : BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00F1FF).withOpacity(_glowAnimation.value * 0.6),
                    blurRadius: 20 * _glowAnimation.value,
                    spreadRadius: 5 * _glowAnimation.value,
                  ),
                  BoxShadow(
                    color: const Color(0xFFB026FF).withOpacity(_glowAnimation.value * 0.4),
                    blurRadius: 30 * _glowAnimation.value,
                    spreadRadius: -5,
                  ),
                ],
              ),
              child: widget.child,
            ),
            
            // Optional Tooltip floating above
            if (widget.message != null)
              Positioned(
                top: -45,
                child: Opacity(
                  opacity: _glowAnimation.value,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF00F1FF).withOpacity(0.5)),
                    ),
                    child: Text(
                      widget.message!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
      child: widget.child,
    );
  }
}
