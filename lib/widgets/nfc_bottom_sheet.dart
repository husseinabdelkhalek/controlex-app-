import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:lottie/lottie.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import '../theme/app_theme.dart';
import '../services/nfc_service.dart';
import '../core/localization.dart';
import 'glass_card.dart';

import 'package:app_settings/app_settings.dart';
import 'package:nfc_host_card_emulation/nfc_host_card_emulation.dart';

enum NfcSheetState { waiting, processing, success, error, disabled }

class NfcBottomSheet extends StatefulWidget {
  final String payload;
  final String title;
  final String description;
  final Duration timeout;

  const NfcBottomSheet({
    Key? key,
    required this.payload,
    required this.title,
    required this.description,
    this.timeout = const Duration(seconds: 15),
  }) : super(key: key);

  static Future<String?> show({
    required BuildContext context,
    required String payload,
    required String title,
    required String description,
  }) {
    return showMaterialModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => NfcBottomSheet(
        payload: payload,
        title: title,
        description: description,
      ),
    );
  }

  @override
  State<NfcBottomSheet> createState() => _NfcBottomSheetState();
}

class _NfcBottomSheetState extends State<NfcBottomSheet> {
  NfcSheetState _state = NfcSheetState.waiting;
  String _message = '';

  @override
  void initState() {
    super.initState();
    _startNfc();
  }

  Future<void> _startNfc() async {
    try {
      final nfcState = await NfcHce.checkDeviceNfcState();
      if (nfcState != NfcState.enabled) {
        if (mounted) {
          setState(() {
            _state = NfcSheetState.disabled;
          });
        }
        return; // Stop here if NFC is disabled
      }
    } catch (e) {
      // If check fails on some devices, just continue and try to init
    }

    await NfcService.init();
    await NfcService.setPayload(widget.payload);

    // Listen for replies from the reader (e.g., Auth Code or OK)
    NfcService.onMessageReceived = (msg) {
      if (!mounted) return;
      setState(() {
        _state = NfcSheetState.success;
        _message = msg;
      });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.of(context).pop(msg);
      });
    };

    // Timeout
    Future.delayed(widget.timeout, () {
      if (mounted && _state == NfcSheetState.waiting) {
        setState(() {
          _state = NfcSheetState.error;
        });
        NfcService.clearPayload();
      }
    });
  }

  @override
  void dispose() {
    NfcService.clearPayload();
    NfcService.onMessageReceived = null;
    super.dispose();
  }

  Widget _buildIcon() {
    switch (_state) {
      case NfcSheetState.waiting:
        return const SizedBox(
          height: 150,
          child: _PhoneTapAnimation(),
        );
      case NfcSheetState.processing:
        return const SizedBox(
          height: 150,
          child: Center(child: CircularProgressIndicator(color: AppTheme.primaryCyan)),
        );
      case NfcSheetState.success:
        return const SizedBox(
          height: 150,
          child: _SuccessCheckAnimation(),
        );
      case NfcSheetState.error:
        return const SizedBox(
          height: 150,
          child: Icon(Icons.error_outline, size: 100, color: Colors.redAccent),
        );
      case NfcSheetState.disabled:
        return const SizedBox(
          height: 150,
          child: Icon(Icons.nfc_outlined, size: 100, color: Colors.orangeAccent),
        );
    }
  }

  String _getStatusText() {
    switch (_state) {
      case NfcSheetState.waiting:
        return widget.description;
      case NfcSheetState.processing:
        return "Processing...";
      case NfcSheetState.success:
        return "Success!";
      case NfcSheetState.error:
        return AppLocalization.isArabicNotifier.value ? "انتهى الوقت. حاول مرة أخرى." : "NFC Timeout. Try again.";
      case NfcSheetState.disabled:
        return AppLocalization.isArabicNotifier.value ? "خاصية الـ NFC غير مفعلة في هاتفك." : "NFC is disabled on your phone.";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      child: GlassCard(
        borderRadius: 32,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _getStatusText(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _state == NfcSheetState.error ? Colors.redAccent : Colors.white70,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 32),
              _buildIcon(),
              const SizedBox(height: 32),
              if (_state == NfcSheetState.error)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryCyan,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  ),
                  onPressed: () {
                    setState(() {
                      _state = NfcSheetState.waiting;
                    });
                    _startNfc();
                  },
                  child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.bold)),
                )
              else if (_state == NfcSheetState.disabled)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  ),
                  onPressed: () async {
                    await AppSettings.openAppSettings(type: AppSettingsType.nfc);
                    // Retry checking after returning
                    setState(() => _state = NfcSheetState.processing);
                    _startNfc();
                  },
                  icon: const Icon(Icons.settings),
                  label: Text(AppLocalization.isArabicNotifier.value ? 'تفعيل NFC' : 'Enable NFC', style: const TextStyle(fontWeight: FontWeight.bold)),
                )
              else
                const SizedBox(height: 48), // Padding equivalent
            ],
          ),
        ),
      ),
    );
  }
}

class _PhoneTapAnimation extends StatefulWidget {
  const _PhoneTapAnimation();
  @override
  State<_PhoneTapAnimation> createState() => _PhoneTapAnimationState();
}

class _PhoneTapAnimationState extends State<_PhoneTapAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this, 
      duration: const Duration(seconds: 2)
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        // Smooth sine wave for floating effect
        final sineValue = math.sin(_ctrl.value * 2 * math.pi);
        final yOffset = sineValue * 8;
        final rotation = sineValue * 0.04;
        
        // Pulsing wave opacity
        final waveProgress = _ctrl.value;

        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // NFC Waves emitting from the top
            for (int i = 0; i < 3; i++)
              Positioned(
                top: -10 - (i * 20.0) - (waveProgress * 20),
                child: Opacity(
                  opacity: (1.0 - waveProgress - (i * 0.2)).clamp(0.0, 1.0),
                  child: Icon(Icons.wifi, size: 60 + (i * 20), color: AppTheme.primaryCyan),
                ),
              ),
              
            // 3D-like Premium Phone
            Transform.translate(
              offset: Offset(0, 25 + yOffset),
              child: Transform.rotate(
                angle: rotation,
                child: Container(
                  width: 90,
                  height: 180,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E), // Dark iPhone color
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFF48484A), width: 3.5), // Metal frame
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 25,
                        offset: const Offset(0, 15),
                      ),
                      // Inner glow from screen
                      BoxShadow(
                        color: AppTheme.primaryCyan.withValues(alpha: 0.15),
                        blurRadius: 30,
                        spreadRadius: -5,
                      )
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Screen gradient (OLED black)
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF2C2C2E),
                              Color(0xFF101012),
                            ],
                          ),
                        ),
                      ),
                      // Screen Reflection (Animated for 3D glass effect)
                      Positioned(
                        top: -80 + (sineValue * 30),
                        left: -80,
                        right: -80,
                        height: 300,
                        child: Transform.rotate(
                          angle: -math.pi / 5,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.0),
                                  Colors.white.withValues(alpha: 0.12),
                                  Colors.white.withValues(alpha: 0.0),
                                ],
                                stops: const [0.4, 0.5, 0.6],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Dynamic Island / Notch
                      Align(
                        alignment: Alignment.topCenter,
                        child: Container(
                          margin: const EdgeInsets.only(top: 8),
                          width: 30,
                          height: 9,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      // Apple Pay / Wallet Card UI on screen
                      Center(
                        child: Container(
                          width: 60,
                          height: 38,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00C6FF), Color(0xFF0072FF)], // Vibrant card colors
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blueAccent.withValues(alpha: 0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ]
                          ),
                          child: const Center(
                            child: Icon(Icons.contactless, color: Colors.white, size: 20),
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SuccessCheckAnimation extends StatefulWidget {
  const _SuccessCheckAnimation();
  @override
  State<_SuccessCheckAnimation> createState() => _SuccessCheckAnimationState();
}

class _SuccessCheckAnimationState extends State<_SuccessCheckAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(100, 100),
          painter: _CheckmarkPainter(_ctrl.value),
        );
      },
    );
  }
}

class _CheckmarkPainter extends CustomPainter {
  final double progress;
  _CheckmarkPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primaryCyan
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Draw glowing circle
    final circleProgress = (progress * 2).clamp(0.0, 1.0);
    final path = Path();
    path.addArc(Rect.fromCircle(center: center, radius: radius), -math.pi / 2, circleProgress * 2 * math.pi);
    canvas.drawPath(path, paint);

    // 2. Add glow to circle when complete
    if (circleProgress == 1.0) {
      final glowPaint = Paint()
        ..color = AppTheme.primaryCyan.withValues(alpha: 0.2)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius, glowPaint);
    }

    // 3. Draw Checkmark
    if (progress > 0.5) {
      final checkProgress = ((progress - 0.5) * 2).clamp(0.0, 1.0);
      final checkPath = Path();
      
      final startX = size.width * 0.28;
      final startY = size.height * 0.52;
      final midX = size.width * 0.45;
      final midY = size.height * 0.70;
      final endX = size.width * 0.72;
      final endY = size.height * 0.35;

      checkPath.moveTo(startX, startY);
      
      if (checkProgress < 0.4) {
        // Draw first leg
        final p = checkProgress / 0.4;
        checkPath.lineTo(
          startX + (midX - startX) * p,
          startY + (midY - startY) * p,
        );
      } else {
        // Draw first leg full
        checkPath.lineTo(midX, midY);
        // Draw second leg
        final p = (checkProgress - 0.4) / 0.6;
        checkPath.lineTo(
          midX + (endX - midX) * p,
          midY + (endY - midY) * p,
        );
      }
      canvas.drawPath(checkPath, paint);
    }
  }

  @override
  bool shouldRepaint(_CheckmarkPainter oldDelegate) => oldDelegate.progress != progress;
}
