import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'core/localization.dart';
import 'core/error_handler.dart';
import 'services/api_service.dart';
import 'screens/dashboard_screen.dart';
import 'screens/loading_screen.dart';
import 'services/notification_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/notification_params.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/ios_params.dart';
import 'package:uuid/uuid.dart';

// This MUST be a top-level function (not inside a class)
// It runs in a separate isolate when the app is terminated/background
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('🔔 Background FCM message: ${message.data}');
  
  if (message.data['type'] == 'emergency_call') {
    final title = message.data['title'] ?? 'اتصال طوارئ';
    final body = message.data['body'] ?? 'انتبه!';
    final uuid = message.data['uuid'] ?? const Uuid().v4();
    final ringtone = message.data['ringtone'] ?? 'default';

    CallKitParams callKitParams = CallKitParams(
      id: uuid,
      nameCaller: title,
      appName: 'ControlEx',
      avatar: 'https://cdn-icons-png.flaticon.com/512/10330/10330058.png',
      handle: body,
      type: 0,
      duration: 60000, // Ring for 60 seconds
      textAccept: 'حسناً',
      textDecline: 'إغلاق',
      missedCallNotification: NotificationParams(
        showNotification: true,
        isShowCallback: false,
        subtitle: 'فاتك اتصال طوارئ',
        callbackText: '',
      ),
      extra: <String, dynamic>{},
      headers: <String, dynamic>{},
      android: AndroidParams(
        isCustomNotification: false,
        isShowLogo: true,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#FF0000',
        actionColor: '#4CAF50',
        textColor: '#ffffff',
        incomingCallNotificationChannelName: "Emergency Call",
      ),
      ios: IOSParams(
        iconName: 'CallKitLogo',
        handleType: '',
        supportsVideo: false,
        maximumCallGroups: 1,
        maximumCallsPerCallGroup: 1,
        audioSessionMode: 'default',
        audioSessionActive: true,
        audioSessionPreferredSampleRate: 44100.0,
        audioSessionPreferredIOBufferDuration: 0.005,
        supportsDTMF: true,
        supportsHolding: false,
        supportsGrouping: false,
        supportsUngrouping: false,
        ringtonePath: 'system_ringtone_default',
      ),
    );
    await FlutterCallkitIncoming.showCallkitIncoming(callKitParams);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // Register the background message handler BEFORE any other FCM setup
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  await AppLocalization.loadSavedLanguage();
  await NotificationService.initialize();
  ErrorHandler.initialize();
  runApp(const ControlExApp());
}

class ControlExApp extends StatelessWidget {
  const ControlExApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppLocalization.isArabicNotifier,
      builder: (context, isArabic, child) {
         return MaterialApp(
           key: ValueKey(isArabic),
           title: 'ControlEx',
           debugShowCheckedModeBanner: false,
           theme: AppTheme.darkTheme,
           builder: (context, child) {
              return Directionality(
                 textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
                 child: child!,
              );
           },
           home: const AppInitializer(),
         );
      }
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _isLoading = true;
  bool _needsUpdate = false;
  String _downloadUrl = '';
  String? _token;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Run both checks in parallel to save time
    final versionFuture = ApiService.checkAppVersion();
    final tokenFuture = ApiService.getToken();

    final results = await Future.wait([versionFuture, tokenFuture]);
    final versionData = results[0] as Map<String, dynamic>;
    _token = results[1] as String?;

    if (versionData.isNotEmpty) {
      final latestVersion = versionData['latestVersion'];
      // [AI_AGENT_WARNING]: This is the current internal app version. 
      // If you are releasing a new feature or fix that requires an update, increment this number (e.g., 1.7)
      // AND also increment the 'latestVersion' on the server (server.js).
      const double currentVersion = 2.5; 
      if (latestVersion != null && (latestVersion is num) && latestVersion > currentVersion) {
        if (mounted) {
          setState(() {
            _needsUpdate = true;
            _downloadUrl = versionData['downloadUrl'] ?? '';
            _isLoading = false;
          });
        }
        return;
      }
    }
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      // Return the ServerLoadingScreen directly so it doesn't blink or restart
      return const ServerLoadingScreen();
    }

    if (_needsUpdate) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.cyan.withOpacity(0.5), width: 1),
              boxShadow: [
                BoxShadow(color: Colors.cyan.withOpacity(0.2), blurRadius: 20, spreadRadius: 5),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🚀', style: TextStyle(fontSize: 60)),
                const SizedBox(height: 16),
                Text(
                  AppLocalization.isArabicNotifier.value ? 'تحديث متوفر!' : 'Update Available!',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 12),
                Text(
                  AppLocalization.isArabicNotifier.value 
                    ? '✨ خش نزل النسخة الجديدة من هنا واستمتع بأحدث الميزات! 😍'
                    : '✨ A new version is available! Please update to enjoy the latest features. 😍',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () async {
                    if (_downloadUrl.isNotEmpty) {
                      final uri = Uri.parse(_downloadUrl);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    }
                  },
                  icon: const Icon(Icons.download),
                  label: Text(AppLocalization.isArabicNotifier.value ? 'تحديث الآن' : 'Update Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyan,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _needsUpdate = false;
                    });
                  },
                  child: Text(
                    AppLocalization.isArabicNotifier.value ? 'تخطي الآن' : 'Skip for now',
                    style: const TextStyle(color: Colors.grey, decoration: TextDecoration.underline),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_token != null && _token!.isNotEmpty) {
      return const DashboardScreen();
    }
    return const LoginScreen();
  }
}
