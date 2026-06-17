import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'api_service.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/notification_params.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/ios_params.dart';
import 'package:uuid/uuid.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static String? _fcmToken;

  /// Get the current FCM token (useful for debugging)
  static String? get fcmToken => _fcmToken;

  static Future<void> initialize() async {
    if (_initialized) return;

    // ==================== LOCAL NOTIFICATIONS ====================
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('🔔 Notification tapped: ${response.payload}');
      },
    );

    // Request notification permission on Android 13+
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      await androidImpl.requestNotificationsPermission();
    }

    // Request SYSTEM_ALERT_WINDOW for CallKit (Draw over other apps)
    if (Platform.isAndroid) {
      var status = await Permission.systemAlertWindow.status;
      if (!status.isGranted) {
        await Permission.systemAlertWindow.request();
      }
      
      var batteryStatus = await Permission.ignoreBatteryOptimizations.status;
      if (!batteryStatus.isGranted) {
        await Permission.ignoreBatteryOptimizations.request();
      }
    }

    // ==================== FCM (Firebase Cloud Messaging) ====================
    await _initFCM();

    _initialized = true;
    debugPrint('✅ NotificationService initialized (FCM + Local)');
  }

  /// Initialize Firebase Cloud Messaging for background push notifications
  static Future<void> _initFCM() async {
    final messaging = FirebaseMessaging.instance;

    // Request permission (required on iOS, helpful on Android 13+)
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('🔔 FCM Permission: ${settings.authorizationStatus}');

    // Get the FCM token
    try {
      _fcmToken = await messaging.getToken();
      debugPrint('🔑 FCM Token: $_fcmToken');
      
      // Send token to server
      if (_fcmToken != null) {
        await _sendTokenToServer(_fcmToken!);
      }
    } catch (e) {
      debugPrint('⚠️ Failed to get FCM token: $e');
    }

    // Listen for token refresh (happens periodically)
    messaging.onTokenRefresh.listen((newToken) {
      _fcmToken = newToken;
      debugPrint('🔄 FCM Token refreshed: $newToken');
      _sendTokenToServer(newToken);
    });

    // Handle foreground messages (app is open)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint('📩 FCM foreground message: ${message.data}');
      
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
          duration: 60000,
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
      } else if (message.notification != null) {
        showNotification(
          title: message.notification!.title ?? 'ControlEx',
          body: message.notification!.body ?? '',
          id: message.hashCode,
          payload: message.data['type'],
        );
      }
    });

    // Handle when user taps notification that opened the app
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('📱 FCM notification tap opened app: ${message.notification?.title}');
    });

    // Check if app was opened from a terminated state via notification
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('🚀 App opened from FCM notification: ${initialMessage.notification?.title}');
    }
  }

  /// Send FCM token to backend server for push delivery
  static Future<void> _sendTokenToServer(String token) async {
    try {
      final authToken = await ApiService.getToken();
      if (authToken == null) {
        debugPrint('⏳ No auth token yet, will send FCM token after login');
        return;
      }
      
      await ApiService.saveFCMToken(token);
      debugPrint('✅ FCM token sent to server');
    } catch (e) {
      debugPrint('⚠️ Failed to send FCM token to server: $e');
    }
  }

  /// Re-register FCM token after login (call this after successful login)
  static Future<void> registerAfterLogin() async {
    if (_fcmToken != null) {
      await _sendTokenToServer(_fcmToken!);
    } else {
      // Try getting token again
      try {
        _fcmToken = await FirebaseMessaging.instance.getToken();
        if (_fcmToken != null) {
          await _sendTokenToServer(_fcmToken!);
        }
      } catch (e) {
        debugPrint('⚠️ Failed to get FCM token after login: $e');
      }
    }
  }

  /// Remove FCM token from server (call on logout)
  static Future<void> unregisterOnLogout() async {
    if (_fcmToken != null) {
      try {
        await ApiService.removeFCMToken(_fcmToken!);
        debugPrint('✅ FCM token removed from server');
      } catch (e) {
        debugPrint('⚠️ Failed to remove FCM token: $e');
      }
    }
  }

  /// Show a local notification (used for foreground FCM + Socket.IO notifications)
  static Future<void> showNotification({
    required String title,
    required String body,
    int id = 0,
    String? payload,
  }) async {
    if (!_initialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'controlex_notifications',
      'ControlEx Notifications',
      channelDescription: 'Notifications from ControlEx admin system',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF8A2BE2),
      styleInformation: BigTextStyleInformation(''),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      id,
      title,
      body,
      details,
      payload: payload,
    );
  }
}
