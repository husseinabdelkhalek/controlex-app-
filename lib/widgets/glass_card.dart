import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GlassCard extends StatefulWidget {
  final Widget child;
  final double? width;
  final double? height;
  final double borderRadius;
  final Color baseColor;
  final Color? borderColor;
  final bool isAnimated;

  const GlassCard({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.borderRadius = 24.0,
    this.baseColor = AppTheme.cardBaseColor,
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
          color: (widget.borderColor ?? Colors.white).withValues(alpha: 0.15), 
          width: 1.0
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            widget.baseColor.withValues(alpha: 0.15),
            widget.baseColor.withValues(alpha: 0.05),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: _isPressed ? 25 : 15,
            spreadRadius: _isPressed ? 4 : 2,
            offset: const Offset(0, 0),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
          child: Container(
             decoration: BoxDecoration(
               gradient: RadialGradient(
                 center: Alignment.topLeft,
                 radius: 1.5,
                 colors: [
                   Colors.white.withValues(alpha: 0.08),
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
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: card,
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

