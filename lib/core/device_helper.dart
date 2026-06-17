import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

class DeviceHelper {
  static Future<Map<String, String>> getDeviceIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('device_id');
    
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await prefs.setString('device_id', deviceId);
    }
    
    String deviceName = 'Unknown Device';
    String platform = kIsWeb ? 'Web' : Platform.operatingSystem;

    if (!kIsWeb) {
      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      try {
        if (Platform.isAndroid) {
          AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
          deviceName = '${androidInfo.brand} ${androidInfo.model}';
        } else if (Platform.isIOS) {
          IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
          deviceName = iosInfo.name;
        } else if (Platform.isWindows) {
           WindowsDeviceInfo winInfo = await deviceInfo.windowsInfo;
           deviceName = winInfo.computerName;
        }
      } catch (e) {
        // Fallback
      }
    } else {
      deviceName = 'Web Browser';
    }

    return {
      'deviceId': deviceId,
      'deviceName': deviceName,
      'platform': platform
    };
  }
}
