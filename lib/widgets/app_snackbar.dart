import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/localization.dart';

class AppSnackbar {
  static OverlayEntry? _currentOverlay;

  // Translate / map raw errors to friendly localized messages
  static String getFriendlyErrorMessage(dynamic error) {
    if (error == null) return AppLocalization.isArabicNotifier.value ? 'حدث خطأ غير متوقع' : 'An unexpected error occurred';
    
    final String errStr = error.toString().toLowerCase();
    
    if (AppLocalization.isArabicNotifier.value) {
      if (errStr.contains('timeout') || errStr.contains('connection timed out')) {
        return 'انتهت مهلة الاتصال! الخادم (السيرفر) يستغرق وقتاً طويلاً للاستجابة. يرجى التحقق من اتصالك بالشبكة.';
      }
      if (errStr.contains('socketexception') || errStr.contains('handshake') || errStr.contains('failed host lookup') || errStr.contains('network') || errStr.contains('errno 110')) {
        return 'فشل الاتصال بالإنترنت! يرجى التأكد من تشغيل الواي فاي أو بيانات الهاتف الخاصة بك.';
      }
      if (errStr.contains('401') || errStr.contains('unauthorized') || errStr.contains('invalid token') || errStr.contains('login_failed') || errStr.contains('فشل التسجيل')) {
        return 'اسم المستخدم أو كلمة المرور غير صحيحة، أو انتهت صلاحية الجلسة. يرجى التحقق والمحاولة مجدداً.';
      }
      if (errStr.contains('403') || errStr.contains('forbidden')) {
        return 'ليس لديك الصلاحية الكافية للقيام بهذا الإجراء!';
      }
      if (errStr.contains('404') || errStr.contains('not found')) {
        return 'تعذر العثور على العنصر المطلوب! ربما تم حذفه مسبقاً أو غير موجود في النظام.';
      }
      if (errStr.contains('500') || errStr.contains('internal server error')) {
        return 'خطأ داخلي في الخادم (السيرفر)! نحن نعمل على إصلاحه الآن، يرجى المحاولة لاحقاً.';
      }
      if (errStr.contains('quota exceeded') || errStr.contains('limit') || errStr.contains('429') || errStr.contains('too many requests')) {
        return 'تم تجاوز الحد المسموح للطلبات مؤقتاً! يرجى المحاولة مجدداً بعد بضع دقائق.';
      }
      if (errStr.contains('local') || errStr.contains('esp') || errStr.contains('refused') || errStr.contains('http get failed') || errStr.contains('local command failed')) {
        return 'تعذر الوصول لجهاز الـ ESP المحلي! تأكد من اتصال هاتفك بنفس شبكة الواي فاي ومن تشغيل الجهاز وتوصيله بالكهرباء.';
      }
      return 'فشل الإجراء: $error';
    } else {
      // English messages
      if (errStr.contains('timeout') || errStr.contains('connection timed out')) {
        return 'Connection timed out! The server is taking too long to respond. Please check your network.';
      }
      if (errStr.contains('socketexception') || errStr.contains('handshake') || errStr.contains('failed host lookup') || errStr.contains('network') || errStr.contains('errno 110')) {
        return 'Network connection error! Please make sure you are connected to a working Wi-Fi or cellular network.';
      }
      if (errStr.contains('401') || errStr.contains('unauthorized') || errStr.contains('invalid token') || errStr.contains('login_failed') || errStr.contains('register_failed')) {
        return 'Incorrect username/password or session expired. Please check and try again.';
      }
      if (errStr.contains('403') || errStr.contains('forbidden')) {
        return 'You do not have permission to perform this action.';
      }
      if (errStr.contains('404') || errStr.contains('not found')) {
        return 'Requested item not found! It might have been deleted or is unavailable.';
      }
      if (errStr.contains('500') || errStr.contains('internal server error')) {
        return 'Internal server error! We are working on a fix, please try again later.';
      }
      if (errStr.contains('quota exceeded') || errStr.contains('limit') || errStr.contains('429') || errStr.contains('too many requests')) {
        return 'Request quota exceeded! Please try again in a few moments.';
      }
      if (errStr.contains('local') || errStr.contains('esp') || errStr.contains('refused') || errStr.contains('http get failed') || errStr.contains('local command failed')) {
        return 'Unable to reach the local ESP device! Verify that your phone is on the same Wi-Fi network and that the device is powered.';
      }
      return 'Action failed: $error';
    }
  }

  static void showSuccess(BuildContext context, String message) {
    _showCustomOverlay(
      context: context,
      message: message,
      icon: Icons.check_circle_outline_rounded,
      glowColor: const Color(0xFF00FF87),
      bgColor: const Color(0xFF071913),
    );
  }

  static void showError(BuildContext context, dynamic error) {
    final message = getFriendlyErrorMessage(error);
    _showCustomOverlay(
      context: context,
      message: message,
      icon: Icons.error_outline_rounded,
      glowColor: const Color(0xFFFF0055),
      bgColor: const Color(0xFF1E060F),
    );
  }

  static void showWarning(BuildContext context, String message) {
    _showCustomOverlay(
      context: context,
      message: message,
      icon: Icons.warning_amber_rounded,
      glowColor: const Color(0xFFFFB300),
      bgColor: const Color(0xFF1C1306),
    );
  }

  static void showInfo(BuildContext context, String message) {
    _showCustomOverlay(
      context: context,
      message: message,
      icon: Icons.info_outline_rounded,
      glowColor: const Color(0xFF00E5FF),
      bgColor: const Color(0xFF05171C),
    );
  }

  static void _showCustomOverlay({
    required BuildContext context,
    required String message,
    required IconData icon,
    required Color glowColor,
    required Color bgColor,
  }) {
    // Safely remove any existing active overlay
    _currentOverlay?.remove();
    _currentOverlay = null;

    final overlayState = Overlay.of(context);

    _currentOverlay = OverlayEntry(
      builder: (ctx) => _AppSnackbarWidget(
        message: message,
        icon: icon,
        glowColor: glowColor,
        bgColor: bgColor,
        onDismiss: () {
          _currentOverlay?.remove();
          _currentOverlay = null;
        },
      ),
    );

    overlayState.insert(_currentOverlay!);
  }
}

class _AppSnackbarWidget extends StatefulWidget {
  final String message;
  final IconData icon;
  final Color glowColor;
  final Color bgColor;
  final VoidCallback onDismiss;

  const _AppSnackbarWidget({
    required this.message,
    required this.icon,
    required this.glowColor,
    required this.bgColor,
    required this.onDismiss,
  });

  @override
  State<_AppSnackbarWidget> createState() => _AppSnackbarWidgetState();
}

class _AppSnackbarWidgetState extends State<_AppSnackbarWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _fadeAnimation;
  bool _isDismissed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _controller.forward();

    // Auto dismiss after 3.2 seconds
    Future.delayed(const Duration(milliseconds: 3200), () {
      if (mounted && !_isDismissed) {
        _dismiss();
      }
    });
  }

  void _dismiss() {
    if (_isDismissed) return;
    _isDismissed = true;
    _controller.reverse().then((_) {
      if (mounted) {
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top + 12;

    return Positioned(
      top: topPadding,
      left: 16,
      right: 16,
      child: SafeArea(
        child: Material(
          color: Colors.transparent,
          child: SlideTransition(
            position: _offsetAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: GestureDetector(
                onTap: _dismiss,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: widget.bgColor.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: widget.glowColor.withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: widget.glowColor.withValues(alpha: 0.15),
                            blurRadius: 20,
                            spreadRadius: 1,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Glowing icon container
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: widget.glowColor.withValues(alpha: 0.12),
                              boxShadow: [
                                BoxShadow(
                                  color: widget.glowColor.withValues(alpha: 0.25),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Icon(widget.icon, color: widget.glowColor, size: 20),
                          ),
                          SizedBox(width: 14),
                          // Message text
                          Expanded(
                            child: Text(
                              widget.message,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
