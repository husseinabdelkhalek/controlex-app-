import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GlassCard extends StatefulWidget {
  final Widget child;
  final double? width;
  final double? height;
  final double borderRadius;
  final Color? baseColor;
  final Color? borderColor;
  final bool isAnimated;

  GlassCard({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.borderRadius = 24.0,
    this.baseColor,
    this.borderColor,
    this.isAnimated = true,
  });

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    Widget card = Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.all(
          color: widget.borderColor ?? AppTheme.glassBorder, 
          width: 1.0,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            (widget.baseColor ?? AppTheme.cardBaseColor).withValues(alpha: 0.85),
            (widget.baseColor ?? AppTheme.cardBaseColor).withValues(alpha: 0.65),
          ],
        ),
        boxShadow: [
          // Ambient shadow
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, 5),
          ),
          // Neon Glow Effect on Press/Hover
          if (_isPressed)
            BoxShadow(
              color: AppTheme.violetGlow,
              blurRadius: 20,
              spreadRadius: 2,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24.0, sigmaY: 24.0),
          child: Container(
             decoration: BoxDecoration(
               gradient: RadialGradient(
                 center: Alignment.topLeft,
                 radius: 1.5,
                 colors: [
                   Colors.white.withValues(alpha: 0.1),
                   Colors.transparent,
                 ],
               ),
             ),
             child: widget.child,
          ),
        ),
      ),
    );

    Widget interactiveCard = Listener(
      onPointerDown: (_) => setState(() => _isPressed = true),
      onPointerUp: (_) => setState(() => _isPressed = false),
      onPointerCancel: (_) => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _isPressed ? -2 : 0, 0), // Elevate on press (resembles hover effect translate3d(0,-2px,0))
        child: AnimatedScale(
          scale: _isPressed ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: card,
        ),
      ),
    );

    if (widget.isAnimated) {
      return TweenAnimationBuilder(
        duration: const Duration(milliseconds: 400),
        tween: Tween<double>(begin: 0.90, end: 1.0),
        curve: Curves.easeOutCubic,
        builder: (context, scale, child) {
          return Transform.scale(
            scale: scale,
            child: child,
          );
        },
        child: interactiveCard,
      );
    }
    
    return interactiveCard;
  }
}

