import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GlowingButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final double? width;
  final double height;
  final double borderRadius;
  final bool isLoading;

  const GlowingButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.width,
    this.height = 50.0,
    this.borderRadius = 12.0,
    this.isLoading = false,
  });

  @override
  State<GlowingButton> createState() => _GlowingButtonState();
}

class _GlowingButtonState extends State<GlowingButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = widget.onPressed == null || widget.isLoading;

    Widget buttonContent = Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDisabled 
            ? [Colors.grey.withValues(alpha: 0.3), Colors.grey.withValues(alpha: 0.1)]
            : [
                _isHovered || _isPressed ? AppTheme.primaryCyan : AppTheme.primaryViolet,
                _isHovered || _isPressed ? AppTheme.primaryViolet : AppTheme.primaryCyan,
              ],
        ),
        boxShadow: [
          if (!isDisabled && (_isHovered || _isPressed))
            BoxShadow(
              color: AppTheme.glowColor,
              blurRadius: 15,
              spreadRadius: 2,
              offset: Offset(0, 0),
            ),
        ],
      ),
      child: Center(
        child: widget.isLoading
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : DefaultTextStyle(
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                child: widget.child,
              ),
      ),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          if (!isDisabled) {
            widget.onPressed!();
          }
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, _isPressed || _isHovered ? -2 : 0, 0), // Elevate slightly
          child: AnimatedScale(
            scale: _isPressed ? 0.95 : 1.0,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            child: buttonContent,
          ),
        ),
      ),
    );
  }
}
