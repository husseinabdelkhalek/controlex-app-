import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/api_service.dart';
import 'api_constants.dart';
import 'device_helper.dart';
import 'localization.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_popups.dart';

class ErrorHandler {
  // ==================== RATE LIMITING ====================
  // Prevents excessive API calls that drain Firestore quota
  static final Map<String, DateTime> _lastSentErrors = {};
  static const Duration _minInterval = Duration(seconds: 30);
  static int _totalSentThisSession = 0;
  static const int _maxErrorsPerSession = 50;

  // Errors to completely ignore (not worth sending to server)
  static final List<String> _ignoredPatterns = [
    'Floating SnackBar presented off screen',
    'SnackBar with behavior property',
    'SnackBarBehavior.floating',
    'RenderFlex overflowed',
    'A RenderFlex overflowed by',
    'setState() called after dispose',
    'Looking up a deactivated widget',
    'Null check operator used on a null value', // too generic to be useful
  ];

  static void initialize() {
    // Handle Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      _logError(details.exceptionAsString(), details.stack.toString());
    };

    // Handle background / isolate errors
    PlatformDispatcher.instance.onError = (error, stack) {
      _logError(error.toString(), stack.toString());
      return true;
    };
    
    // Handle Dart errors not caught by anything else
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return Material(
        child: Container(
          color: Colors.black,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 50),
              SizedBox(height: 10),
              Text('An unusual error occurred!', style: TextStyle(color: Colors.white, fontSize: 18)),
              SizedBox(height: 10),
              if (kDebugMode)
                 Padding(
                   padding: const EdgeInsets.all(16.0),
                   child: Text(details.exceptionAsString(), style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                 ),
            ],
          )
        )
      );
    };
  }

  /// Check if this error should be ignored entirely
  static bool _shouldIgnore(String error) {
    for (final pattern in _ignoredPatterns) {
      if (error.contains(pattern)) return true;
    }
    return false;
  }

  /// Check rate limit: only allow 1 report per error type every 30 seconds,
  /// and cap total errors per session to prevent runaway quota usage.
  static bool _isRateLimited(String error) {
    // Cap total errors per session
    if (_totalSentThisSession >= _maxErrorsPerSession) return true;

    // Create a short key from the first 100 chars of the error
    final key = error.length > 100 ? error.substring(0, 100) : error;
    final now = DateTime.now();
    
    if (_lastSentErrors.containsKey(key)) {
      final lastSent = _lastSentErrors[key]!;
      if (now.difference(lastSent) < _minInterval) {
        return true; // Too soon, skip this report
      }
    }
    
    // Allow it: update timestamp and counter
    _lastSentErrors[key] = now;
    _totalSentThisSession++;
    
    // Cleanup old entries to prevent memory leak (keep only last 20)
    if (_lastSentErrors.length > 20) {
      final sorted = _lastSentErrors.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      for (int i = 0; i < sorted.length - 20; i++) {
        _lastSentErrors.remove(sorted[i].key);
      }
    }
    
    return false;
  }

  static Future<void> _logError(String error, String stackTrace) async {
    if (kDebugMode) {
      debugPrint('Crash logged locally: $error');
    }

    // 1. Check if this error should be ignored entirely
    if (_shouldIgnore(error)) {
      if (kDebugMode) debugPrint('⏭️ Error ignored (known harmless): ${error.substring(0, error.length.clamp(0, 60))}');
      return;
    }

    // 2. Check rate limiting
    if (_isRateLimited(error)) {
      if (kDebugMode) debugPrint('⏳ Error rate-limited (sent recently): ${error.substring(0, error.length.clamp(0, 60))}');
      return;
    }
    
    // 3. Send to server (throttled)
    try {
      final token = await ApiService.getToken();
      final deviceInfo = await DeviceHelper.getDeviceIdentity();
      
      await http.post(
        Uri.parse('${ApiConstants.baseUrl}/api/logs/client'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'x-auth-token': token,
        },
        body: json.encode({
          'error': error,
          'stackTrace': stackTrace.length > 2000 ? stackTrace.substring(0, 2000) : stackTrace,
          'deviceInfo': deviceInfo,
          'appVersion': '2.7', // TODO: للايجينت القادم: قم بزيادة هذا الرقم بمقدار 1 للتغييرات الكبيرة، أو 0.1/0.2 للتغييرات العادية
        }),
      );
    } catch (e) {
      // Failed to send to server - do nothing to prevent loops
    }
  }

  static Map<String, String> getDetailedExplanation(dynamic error) {
    final errStr = error.toString().toLowerCase();
    
    // 1. Connection Errors / Offline
    if (errStr.contains('socketexception') || 
        errStr.contains('failed host lookup') || 
        errStr.contains('network_error') || 
        errStr.contains('handshakeexception') ||
        errStr.contains('connection refused') ||
        errStr.contains('connection closed')) {
      return {
        'title_ar': 'عفواً، لا يوجد اتصال بالشبكة! 🔌',
        'title_en': 'Oops, no network connection! 🔌',
        'desc_ar': 'يتعذر على التطبيق الاتصال بالخادم. يرجى التحقق من اتصال الواي فاي أو باقة البيانات وتأكد من أن جهازك متصل بالإنترنت، ثم حاول مجدداً.',
        'desc_en': 'The app cannot connect to the server. Please check your WiFi or mobile data connection and make sure your device has active internet access, then try again.',
        'action_ar': 'التحقق من الاتصال',
        'action_en': 'Check Connection'
      };
    }
    
    // 2. Timeout / Server Cold Start
    if (errStr.contains('timeout') || errStr.contains('504') || errStr.contains('502') || errStr.contains('503')) {
      return {
        'title_ar': 'السيرفر يتهيكل حالياً! ⏱️',
        'title_en': 'Server is warming up! ⏱️',
        'desc_ar': 'السيرفر الخاص بك مستضاف على منصة سحابية مجانية وهو الآن مستيقظ ويقوم بتهيئة نفسه (Cold Start). يستغرق هذا عادةً من 20 إلى 30 ثانية. نحن نحاول الاتصال مجدداً تلقائياً!',
        'desc_en': 'Your server is hosted on a free cloud tier and is currently waking up (Cold Start). This usually takes 20 to 30 seconds. We are trying to reconnect automatically!',
        'action_ar': 'إعادة المحاولة الآن',
        'action_en': 'Retry Now'
      };
    }
    
    // 3. Unauthorized / Session Expired
    if (errStr.contains('401') || errStr.contains('unauthorized') || errStr.contains('login_required') || errStr.contains('jwt') || errStr.contains('token')) {
      return {
        'title_ar': 'انتهت صلاحية الجلسة! 🔐',
        'title_en': 'Session Expired! 🔐',
        'desc_ar': 'تم تسجيل خروجك لحماية حسابك ولأسباب أمنية. يرجى العودة وتسجيل الدخول مرة أخرى لتتمكن من التحكم في أجهزتك الذكية وسحب البيانات.',
        'desc_en': 'You have been logged out for security and account protection. Please log back in to control your smart devices and fetch data.',
        'action_ar': 'تسجيل الدخول مجدداً',
        'action_en': 'Login Again'
      };
    }

    // 4. Rate Limit / Quota Exceeded
    if (errStr.contains('429') || errStr.contains('quota') || errStr.contains('too many requests') || errStr.contains('databasewrites') || errStr.contains('limit exceeded')) {
      return {
        'title_ar': 'تم تجاوز حد الطلبات! 📊',
        'title_en': 'Request Limit Exceeded! 📊',
        'desc_ar': 'لقد أرسل التطبيق عدداً كبيراً من الطلبات خلال فترة قصيرة، أو تم تجاوز الحصة المجانية اليومية لقاعدة البيانات (Firestore Daily Quota). ستعود الخدمة للعمل بشكل طبيعي قريباً أو عند منتصف الليل.',
        'desc_en': 'The app sent too many requests in a short time, or the free daily database writing quota (Firestore) has been exceeded. The service will resume shortly or at server midnight.',
        'action_ar': 'حسناً، فهمت',
        'action_en': 'Got it'
      };
    }

    // 5. Adafruit / IoT Feed errors
    if (errStr.contains('404') || errStr.contains('feed') || errStr.contains('adafruit') || errStr.contains('not found')) {
      return {
        'title_ar': 'خطأ في الربط مع لوحة التحكم! ⚙️',
        'title_en': 'IoT Feed Linking Error! ⚙️',
        'desc_ar': 'تعذر العثور على حقل البيانات (Feed) المحدد على منصة Adafruit IO. يرجى التحقق من صحة اسم المستخدم (Adafruit Username) ومفتاح التحكم (Adafruit API Key) وتسمية الـ Feed بداخل إعدادات التطبيق.',
        'desc_en': 'Could not find this specific data feed on the Adafruit IO platform. Please check that your Adafruit Username, API Key, and Feed Name are correct in settings.',
        'action_ar': 'تعديل الإعدادات',
        'action_en': 'Open Settings'
      };
    }

    // Default Fallback
    return {
      'title_ar': 'حدث خطأ تقني غير متوقع! ⚠️',
      'title_en': 'Unexpected Technical Error! ⚠️',
      'desc_ar': 'حدث خطأ غير معروف أثناء معالجة طلبك:\n"$error"\nلقد تم إرسال تقرير بالخطأ إلى المطورين تلقائياً ونعمل على حله الآن.',
      'desc_en': 'An unknown error occurred while processing your request:\n"$error"\nAn error report has been sent to our developers automatically and we are resolving it.',
      'action_ar': 'موافق',
      'action_en': 'OK'
    };
  }

  static void showFriendlyError(BuildContext context, dynamic error, {VoidCallback? onAction}) {
    final exp = getDetailedExplanation(error);
    final isArabic = AppLocalization.isArabicNotifier.value;
    
    final title = isArabic ? exp['title_ar']! : exp['title_en']!;
    final desc = isArabic ? exp['desc_ar']! : exp['desc_en']!;
    final actionText = isArabic ? exp['action_ar']! : exp['action_en']!;

    showGlassModalBottomSheet(
      context: context,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24).copyWith(
            bottom: MediaQuery.of(ctx).padding.bottom + 24,
          ),
          decoration: AppTheme.glassDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            borderColor: const Color(0xFF00D2FF).withValues(alpha: 0.2),
          ).copyWith(
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF9B51E0).withValues(alpha: 0.15),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handlebar
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              SizedBox(height: 24),
              
              // Title
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 16),
              
              // Description Box (Glassmorphic)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Text(
                  desc,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 13.5,
                    height: 1.6,
                  ),
                ),
              ),
              SizedBox(height: 24),
              
              // Action Button
              Container(
                width: double.infinity,
                height: 55,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [Color(0xFF00D2FF), Color(0xFF9B51E0)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00D2FF).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    if (onAction != null) {
                      onAction();
                    }
                  },
                  child: Text(
                    actionText,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
