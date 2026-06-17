import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui';
import '../core/localization.dart';

class TourStep {
  final String titleKey;
  final String descKey;
  final GlobalKey? targetKey;
  final bool isCircular;
  final bool requireInteraction;
  final bool advanceOnTap;
  final VoidCallback? onTargetTapped;

  const TourStep({
    required this.titleKey,
    required this.descKey,
    this.targetKey,
    this.isCircular = false,
    this.requireInteraction = false,
    this.advanceOnTap = true,
    this.onTargetTapped,
  });
}

class AppTour {
  static OverlayEntry? _overlayEntry;

  static bool get isShowing => _overlayEntry != null;

  static void show(BuildContext context, List<TourStep> steps, {VoidCallback? onComplete, VoidCallback? onSkip}) {
    if (_overlayEntry != null) return;
    _overlayEntry = OverlayEntry(
      builder: (context) => AppTourOverlay(
        steps: steps,
        onClose: () {
          _overlayEntry?.remove();
          _overlayEntry = null;
          onComplete?.call();
        },
        onSkip: () {
          _overlayEntry?.remove();
          _overlayEntry = null;
          onSkip?.call();
        },
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  static void dismiss() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}

class AppTourOverlay extends StatefulWidget {
  final List<TourStep> steps;
  final VoidCallback onClose;
  final VoidCallback? onSkip;

  const AppTourOverlay({
    super.key,
    required this.steps,
    required this.onClose,
    this.onSkip,
  });

  @override
  State<AppTourOverlay> createState() => _AppTourOverlayState();
}

class _AppTourOverlayState extends State<AppTourOverlay> with TickerProviderStateMixin {
  int _currentStepIndex = 0;
  late AnimationController _pulseController;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  bool _showWrongTapMessage = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 10).chain(CurveTween(curve: Curves.elasticIn)).animate(_shakeController);

    _scrollToTarget();
  }

  void _scrollToTarget() {
    if (_currentStepIndex >= widget.steps.length) return;
    final key = widget.steps[_currentStepIndex].targetKey;
    if (key == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = key.currentContext;
      if (context != null) {
        ScrollableState? verticalScrollable;
        context.visitAncestorElements((element) {
          if (element.widget is Scrollable) {
            try {
              final state = (element as StatefulElement).state;
              if (state is ScrollableState && state.widget.axis == Axis.vertical) {
                verticalScrollable = state;
                return false; // Stop traversing
              }
            } catch (_) {}
          }
          return true;
        });

        final renderObj = context.findRenderObject();
        if (renderObj != null) {
          if (verticalScrollable != null) {
            verticalScrollable!.position.ensureVisible(
              renderObj,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              alignment: 0.5,
            );
          } else {
            Scrollable.ensureVisible(
              context,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              alignment: 0.5,
            );
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  Rect? _getTargetRect() {
    if (_currentStepIndex >= widget.steps.length) return null;
    final key = widget.steps[_currentStepIndex].targetKey;
    if (key == null) return null;
    
    final currentCtx = key.currentContext;
    if (currentCtx == null) return null;
    
    final renderBox = currentCtx.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.attached || !renderBox.hasSize) return null;
    
    final size = renderBox.size;
    final position = renderBox.localToGlobal(Offset.zero);
    
    if (size.width == 0 || size.height == 0) return null;
    return position & size;
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    
    final targetRect = _getTargetRect();
    final step = widget.steps[_currentStepIndex];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Semi-transparent cutout backdrop overlay
          AnimatedBuilder(
            animation: Listenable.merge([_pulseController, _shakeController]),
            builder: (context, child) {
              return CustomPaint(
                size: Size(screenWidth, screenHeight),
                painter: HolePainter(
                  hole: targetRect,
                  isCircular: step.isCircular,
                  animationValue: _pulseController.value,
                  shakeOffset: _shakeController.isAnimating ? _shakeAnimation.value : 0,
                  isErrorState: _showWrongTapMessage,
                ),
              );
            },
          ),
          
          // HoleInteractionBlocker to absorb taps outside the card and allow taps inside
          Positioned.fill(
            child: HoleInteractionBlocker(
              hole: _getTargetRect(),
              onWrongTap: () {
                if (widget.steps[_currentStepIndex].requireInteraction) {
                  _shakeController.forward(from: 0);
                  setState(() => _showWrongTapMessage = true);
                  Future.delayed(const Duration(seconds: 2), () {
                    if (mounted) setState(() => _showWrongTapMessage = false);
                  });
                }
              },
              onCorrectTap: () {
                final step = widget.steps[_currentStepIndex];
                if (step.requireInteraction) {
                  step.onTargetTapped?.call();
                  if (step.advanceOnTap) {
                    if (_currentStepIndex < widget.steps.length - 1) {
                      setState(() {
                        _showWrongTapMessage = false;
                        _currentStepIndex++;
                        _scrollToTarget();
                      });
                    } else {
                      widget.onClose();
                    }
                  }
                }
              },
              child: const SizedBox.shrink(),
            ),
          ),
          
          // The floating glassmorphic information card
          _buildStepCard(targetRect, screenWidth, screenHeight),
        ],
      ),
    );
  }

  Widget _buildStepCard(Rect? targetRect, double screenWidth, double screenHeight) {
    final step = widget.steps[_currentStepIndex];
    final title = AppLocalization.get(step.titleKey);
    final desc = AppLocalization.get(step.descKey);

    double top;
    double left = 16.0;
    double right = 16.0;

    final mediaQuery = MediaQuery.of(context);

    if (targetRect == null) {
      // Welcome or success steps (centered)
      top = screenHeight * 0.3;
    } else {
      final targetCenterY = targetRect.center.dy;
      if (targetCenterY < screenHeight / 2) {
        // Target is at top half, card goes to the bottom area of the screen
        top = screenHeight - 290.0;
        if (top < targetRect.bottom + 20.0) {
          top = targetRect.bottom + 20.0;
        }
      } else {
        // Target is at bottom half, card goes to the top area of the screen
        top = mediaQuery.padding.top + 60.0;
        if (top + 220.0 > targetRect.top) {
          top = targetRect.top - 240.0;
          if (top < 80.0) top = 80.0;
        }
      }
    }

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
      top: top,
      left: left,
      right: right,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.12),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00F1FF).withOpacity(0.08),
                  blurRadius: 30,
                  spreadRadius: -10,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFB026FF).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFB026FF).withOpacity(0.4)),
                      ),
                      child: Text(
                        '${_currentStepIndex + 1} / ${widget.steps.length}',
                        style: const TextStyle(
                          color: Color(0xFFD070FF),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  desc,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.5,
                    fontFamily: 'Inter',
                  ),
                ),
                if (_showWrongTapMessage)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            AppLocalization.get('tour_interact_hint'),
                            style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_currentStepIndex < widget.steps.length - 1)
                      TextButton(
                        onPressed: widget.onSkip ?? widget.onClose,
                        child: Text(
                          AppLocalization.get('tour_skip'),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 14,
                          ),
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    Row(
                      children: [
                        if (_currentStepIndex > 0) ...[
                          OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _currentStepIndex--;
                                _scrollToTarget();
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.white.withOpacity(0.2)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                            child: Text(
                              AppLocalization.get('tour_back'),
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (!step.requireInteraction || !step.advanceOnTap)
                          ElevatedButton(
                            onPressed: () {
                              if (_currentStepIndex < widget.steps.length - 1) {
                                setState(() {
                                  _showWrongTapMessage = false;
                                  _currentStepIndex++;
                                  _scrollToTarget();
                                });
                              } else {
                                widget.onClose();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00F1FF),
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                              elevation: 5,
                              shadowColor: const Color(0xFF00F1FF).withOpacity(0.4),
                            ),
                            child: Text(
                              _currentStepIndex < widget.steps.length - 1
                                  ? AppLocalization.get('tour_next')
                                  : AppLocalization.get('tour_finish'),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ),
                        if (step.requireInteraction && step.advanceOnTap)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00F1FF).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF00F1FF).withOpacity(0.5)),
                            ),
                            child: Text(
                              AppLocalization.get('tour_tap_to_continue'),
                              style: const TextStyle(
                                color: Color(0xFF00F1FF),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HolePainter extends CustomPainter {
  final Rect? hole;
  final bool isCircular;
  final double animationValue;
  final double shakeOffset;
  final bool isErrorState;

  HolePainter({
    this.hole,
    this.isCircular = false,
    this.animationValue = 0.0,
    this.shakeOffset = 0.0,
    this.isErrorState = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.8);
    
    if (hole == null) {
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
      return;
    }

    final path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    
    // Add extra padding around the targeted element
    const double padding = 6.0;
    Rect paddedRect = hole!.inflate(padding);
    
    // Apply shake offset
    if (shakeOffset != 0) {
      paddedRect = paddedRect.shift(Offset(shakeOffset % 10 - 5, 0));
    }

    if (isCircular) {
      path.addOval(paddedRect);
    } else {
      path.addRRect(RRect.fromRectAndRadius(paddedRect, const Radius.circular(16)));
    }
    
    path.fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);

    // Neon Border with color shifting gradient and breathing width
    final Color borderStartColor = isErrorState ? Colors.redAccent : const Color(0xFF00F1FF); // Neon Cyan / Red
    final Color borderEndColor = isErrorState ? Colors.orangeAccent : const Color(0xFFB026FF);   // Neon Violet / Orange
    final Color activeColor = Color.lerp(borderStartColor, borderEndColor, animationValue)!;

    // Glowing border shadow
    final glowPaint = Paint()
      ..color = activeColor.withOpacity(0.35 * (1.0 - (animationValue * 0.3)))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0 + (animationValue * 4.0)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);

    // Primary border stroke
    final borderPaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 + (animationValue * 1.0);

    if (isCircular) {
      canvas.drawCircle(paddedRect.center, paddedRect.width / 2, glowPaint);
      canvas.drawCircle(paddedRect.center, paddedRect.width / 2, borderPaint);
    } else {
      canvas.drawRRect(RRect.fromRectAndRadius(paddedRect, const Radius.circular(16)), glowPaint);
      canvas.drawRRect(RRect.fromRectAndRadius(paddedRect, const Radius.circular(16)), borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant HolePainter oldDelegate) {
    return oldDelegate.hole != hole ||
           oldDelegate.isCircular != isCircular ||
           oldDelegate.animationValue != animationValue ||
           oldDelegate.shakeOffset != shakeOffset ||
           oldDelegate.isErrorState != isErrorState;
  }
}

class HoleInteractionBlocker extends SingleChildRenderObjectWidget {
  final Rect? hole;
  final VoidCallback onWrongTap;
  final VoidCallback onCorrectTap;

  const HoleInteractionBlocker({
    super.key,
    this.hole,
    required this.onWrongTap,
    required this.onCorrectTap,
    Widget? child,
  }) : super(child: child);

  @override
  RenderHoleInteractionBlocker createRenderObject(BuildContext context) {
    return RenderHoleInteractionBlocker(
      hole: hole,
      onWrongTap: onWrongTap,
      onCorrectTap: onCorrectTap,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderHoleInteractionBlocker renderObject) {
    renderObject
      ..hole = hole
      ..onWrongTap = onWrongTap
      ..onCorrectTap = onCorrectTap;
  }
}

class RenderHoleInteractionBlocker extends RenderProxyBox {
  Rect? _hole;
  VoidCallback _onWrongTap;
  VoidCallback _onCorrectTap;

  RenderHoleInteractionBlocker({
    Rect? hole,
    required VoidCallback onWrongTap,
    required VoidCallback onCorrectTap,
    RenderBox? child,
  })  : _hole = hole,
        _onWrongTap = onWrongTap,
        _onCorrectTap = onCorrectTap,
        super(child);

  set hole(Rect? value) {
    if (_hole == value) return;
    _hole = value;
  }

  set onWrongTap(VoidCallback value) {
    _onWrongTap = value;
  }

  set onCorrectTap(VoidCallback value) {
    _onCorrectTap = value;
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (_hole != null && _hole!.contains(position)) {
      result.add(BoxHitTestEntry(this, position));
      return false; 
    }
    
    if (size.contains(position)) {
      result.add(BoxHitTestEntry(this, position));
      return true; 
    }
    return false;
  }

  @override
  void handleEvent(PointerEvent event, HitTestEntry entry) {
    if (event is PointerDownEvent) {
      if (_hole != null && _hole!.contains(event.position)) {
        _onCorrectTap();
      } else {
        _onWrongTap();
      }
    }
  }
}
