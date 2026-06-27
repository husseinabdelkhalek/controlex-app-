import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/api_constants.dart';
import '../core/device_helper.dart';
import '../core/localization.dart';
import 'notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:home_widget/home_widget.dart';

class ApiService {
  static const _storage = FlutterSecureStorage();

  static Future<String?> getToken() async {
    try {
      final token = await _storage.read(key: 'x-auth-token');
      if (token != null) return token;
    } catch (_) {
      // Catch platform exceptions in background isolates
    }
    try {
      return await HomeWidget.getWidgetData<String>('widget_auth_token');
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveToken(String token) async {
    await _storage.write(key: 'x-auth-token', value: token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('background_auth_token', token);
    try {
      await HomeWidget.saveWidgetData('widget_auth_token', token);
    } catch (_) {}
  }

  static Future<void> clearAuth() async {
    await _storage.delete(key: 'x-auth-token');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('background_auth_token');
    try {
      await HomeWidget.saveWidgetData('widget_auth_token', null);
    } catch (_) {}
  }

  static Future<Map<String, String>> _getHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'x-auth-token': token,
    };
  }

  static Future<Map<String, dynamic>> checkAppVersion() async {
    try {
      final response = await http.get(Uri.parse('${ApiConstants.baseUrl}/api/app-version')).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  static Future<Map<String, dynamic>> chatWithAi(String message, List<dynamic> history) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/api/ai/chat'),
        headers: await _getHeaders(),
        body: json.encode({'message': message, 'history': history}),
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final err = json.decode(response.body);
        throw Exception(err['msg'] ?? 'Failed to chat with AI');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // --- Auth Methods ---
  
  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final deviceInfo = await DeviceHelper.getDeviceIdentity();
      final response = await http.post(
        Uri.parse(ApiConstants.login),
        headers: await _getHeaders(),
        body: json.encode({'email': email, 'password': password, 'deviceInfo': deviceInfo}),
      );
      
      if (response.body.isNotEmpty && response.body.startsWith('{')) {
         return json.decode(response.body);
      } else {
        throw Exception(AppLocalization.get('login_failed') + ': ${response.statusCode}');
      }
    } catch (e) {
      throw Exception(AppLocalization.get('network_error'));
    }
  }

  static Future<List<dynamic>> getNotifications() async {
    final token = await getToken();
    if (token == null) throw Exception(AppLocalization.get('login_required'));

    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/api/notifications'),
      headers: {
        'x-auth-token': token,
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load notifications');
    }
  }

  static Future<Map<String, dynamic>> clearNotifications() async {
    final token = await getToken();
    if (token == null) throw Exception(AppLocalization.get('login_required'));

    final response = await http.delete(
      Uri.parse('${ApiConstants.baseUrl}/api/notifications'),
      headers: {
        'x-auth-token': token,
      },
    );
    return await _handleResponse(response);
  }
  static Future<Map<String, dynamic>> register(
    String username,
    String email,
    String password, {
    String adafruitUsername = '',
    String adafruitApiKey = '',
    String firebaseUrl = '',
    String firebaseSecret = '',
    String? subAdminPromoCode,
    String? parentAdminCode,
    String? setupCode,
  }) async {
    final deviceInfo = await DeviceHelper.getDeviceIdentity();
    final response = await http.post(
      Uri.parse(ApiConstants.register),
      headers: await _getHeaders(),
      body: json.encode({
        'username': username,
        'email': email,
        'password': password,
        if (adafruitUsername.isNotEmpty) 'adafruitUsername': adafruitUsername,
        if (adafruitApiKey.isNotEmpty) 'adafruitApiKey': adafruitApiKey,
        if (firebaseUrl.isNotEmpty) 'firebaseUrl': firebaseUrl,
        if (firebaseSecret.isNotEmpty) 'firebaseSecret': firebaseSecret,
        'deviceInfo': deviceInfo,
        if (subAdminPromoCode != null && subAdminPromoCode.isNotEmpty) 'subAdminPromoCode': subAdminPromoCode,
        if (parentAdminCode != null && parentAdminCode.isNotEmpty) 'parentAdminCode': parentAdminCode,
        if (setupCode != null && setupCode.isNotEmpty) 'setupCode': setupCode,
      }),
    );
    
    final res = json.decode(response.body);
    return res;
  }

  static Future<Map<String, dynamic>> verifySetupCode(String code) async {
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/api/auth/verify-setup-code'),
      headers: await _getHeaders(),
      body: json.encode({'code': code}),
    );
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> applySetupCode(String code) async {
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/api/user/apply-setup-code'),
      headers: await _getHeaders(),
      body: json.encode({'code': code}),
    );
    return await _handleResponse(response);
  }

  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    final response = await http.post(
      Uri.parse(ApiConstants.forgotPassword),
      headers: await _getHeaders(),
      body: json.encode({'email': email}),
    );
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> verifyResetCode(String email, String code) async {
    final response = await http.post(
      Uri.parse(ApiConstants.verifyResetCode),
      headers: await _getHeaders(),
      body: json.encode({'email': email, 'code': code}),
    );
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> resetPassword(String email, String code, String newPassword) async {
    final response = await http.post(
      Uri.parse(ApiConstants.resetPassword),
      headers: await _getHeaders(),
      body: json.encode({
        'email': email, 
        'code': code, 
        'newPassword': newPassword, 
        'confirmPassword': newPassword
      }),
    );
    return json.decode(response.body);
  }
  static Future<Map<String, dynamic>> logout() async {
    final response = await http.post(
      Uri.parse(ApiConstants.logout),
      headers: await _getHeaders(),
    );
    // Unregister FCM token before clearing the auth token
    try {
      await removeFCMToken(NotificationService.fcmToken ?? '');
    } catch (_) {}
    
    await clearAuth();
    return json.decode(response.body);
  }

  // --- User Profile Endpoints ---

  static Future<Map<String, dynamic>> userMe() async {
    final response = await http.get(
      Uri.parse(ApiConstants.userMe),
      headers: await _getHeaders(),
    ).timeout(const Duration(seconds: 10));
    final data = json.decode(response.body);
    return data;
  }

  static Future<Map<String, dynamic>> userUpdate(Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse(ApiConstants.userUpdate),
      headers: await _getHeaders(),
      body: json.encode(data),
    );
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> updatePreferences(Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('${ApiConstants.baseUrl}/api/user/preferences'),
      headers: await _getHeaders(),
      body: json.encode(data),
    );
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> exportData() async {
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/api/user/export'),
      headers: await _getHeaders(),
    );
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> importData(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/api/user/import'),
      headers: await _getHeaders(),
      body: json.encode(data),
    );
    return json.decode(response.body);
  }


  static Future<Map<String, dynamic>> deleteAccount() async {
    final response = await http.delete(
      Uri.parse('${ApiConstants.baseUrl}/api/user/delete-account'),
      headers: await _getHeaders(),
    );
    return await _handleResponse(response);
  }

  static Future<Map<String, dynamic>> enable2FA() async {
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/api/user/enable-2fa'),
      headers: await _getHeaders(),
    );
    return await _handleResponse(response);
  }

  static Future<Map<String, dynamic>> disable2FA() async {
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/api/user/disable-2fa'),
      headers: await _getHeaders(),
    );
    return await _handleResponse(response);
  }

  static Future<Map<String, dynamic>> verify2Fa(String email, String code) async {
    final deviceInfo = await DeviceHelper.getDeviceIdentity();
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/api/auth/verify-2fa'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email, 'twoFactorCode': code, 'deviceInfo': deviceInfo}),
    );
    return await _handleResponse(response);
  }

  static Future<Map<String, dynamic>> googleAuthMobile(String idToken) async {
    // Sends Firebase ID Token to server — server verifies it and returns JWT
    try {
      final deviceInfo = await DeviceHelper.getDeviceIdentity();
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/api/auth/google/mobile'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({ 'idToken': idToken, 'deviceInfo': deviceInfo }),
      );
      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.contains('application/json')) {
        return {'msg': 'السيرفر لم يتعرف على الطلب (${response.statusCode}). تأكد من نشر آخر تحديثات السيرفر.'};
      }
      if (response.body.isNotEmpty) return json.decode(response.body);
      return {'msg': 'No response from server'};
    } catch (e) {
      return {'msg': 'Connection error'};
    }
  }

  static Future<Map<String, dynamic>> clearData() async {
    final response = await http.post(
      Uri.parse(ApiConstants.clearData),
      headers: await _getHeaders(),
    );
    return await _handleResponse(response);
  }

  static Future<List<dynamic>> getSessions() async {
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/api/user/sessions'),
      headers: await _getHeaders(),
    );
    if(response.statusCode == 200) {
      return json.decode(response.body);
    }
    return [];
  }

  static Future<Map<String, dynamic>> terminateSession(String sessionId) async {
    final response = await http.delete(
      Uri.parse('${ApiConstants.baseUrl}/api/user/sessions/$sessionId'),
      headers: await _getHeaders(),
    );
    return json.decode(response.body);
  }

  // --- Widgets Endpoints ---

  static Future<List<dynamic>> getWidgets() async {
    final response = await http.get(
      Uri.parse(ApiConstants.getWidgets),
      headers: await _getHeaders(),
    ).timeout(const Duration(seconds: 10));
    if(response.statusCode == 200) {
      return json.decode(response.body);
    }
    return [];
  }

  static Future<List<dynamic>> getAdafruitFeeds() async {
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/api/adafruit/feeds'),
      headers: await _getHeaders(),
    );
    if(response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception(json.decode(response.body)['msg'] ?? 'Unknown error fetching feeds');
    }
  }

  static Future<List<dynamic>> getFirebasePaths() async {
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/api/firebase/paths'),
      headers: await _getHeaders(),
    );
    if(response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception(json.decode(response.body)['msg'] ?? 'فشل في جلب مسارات Firebase');
    }
  }

  static Future<Map<String, dynamic>> createWidget(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse(ApiConstants.createWidget),
      headers: await _getHeaders(),
      body: json.encode(data),
    );
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> updateWidget(String id, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse(ApiConstants.updateWidget(id)),
      headers: await _getHeaders(),
      body: json.encode(data),
    );
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> updateWidgetPosition(String id, int x, int y, int w, int h) async {
    final response = await http.put(
      Uri.parse('${ApiConstants.baseUrl}/api/widgets/$id/position'),
      headers: await _getHeaders(),
      body: json.encode({
        'gs': {'x': x, 'y': y, 'w': w, 'h': h}
      }),
    );
    return json.decode(response.body);
  }

  /// Updates the page assignment of a widget. Pass null to unassign from any page.
  static Future<Map<String, dynamic>> updateWidgetPageId(String id, String? pageId) async {
    final response = await http.put(
      Uri.parse('${ApiConstants.baseUrl}/api/widgets/$id'),
      headers: await _getHeaders(),
      body: json.encode({
        'configuration': {'pageId': pageId},
        'pageId': pageId,
      }),
    );
    final res = await _handleResponse(response);
    return res is Map<String, dynamic> ? res : {};
  }

  static Future<Map<String, dynamic>> deleteWidget(String id) async {
    final response = await http.delete(
      Uri.parse(ApiConstants.deleteWidget(id)),
      headers: await _getHeaders(),
    );
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> sendCommand(String widgetId, dynamic value) async {
    final response = await http.post(
      Uri.parse(ApiConstants.sendCommand),
      headers: await _getHeaders(),
      body: json.encode({'widgetId': widgetId, 'value': value}),
    );
    return await _handleResponse(response);
  }

  // ==================== Admin API Methods ====================

  static Future<List<dynamic>> getAdminUsers() async {
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/api/admin/users'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) return json.decode(response.body);
    throw Exception('Failed to fetch users: ${response.statusCode}');
  }

  static Future<Map<String, dynamic>> deleteAdminUser(String userId) async {
    final response = await http.delete(
      Uri.parse('${ApiConstants.baseUrl}/api/admin/users/$userId'),
      headers: await _getHeaders(),
    );
    return await _handleResponse(response);
  }

  static Future<List<dynamic>> getServerLogs() async {
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/api/admin/logs'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) return json.decode(response.body);
    return [];
  }

  static Future<List<dynamic>> getClientLogs() async {
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/api/admin/client-logs'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) return json.decode(response.body);
    return [];
  }

  static Future<List<dynamic>> getAdafruitQuotas() async {
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/api/admin/adafruit-quota'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) return json.decode(response.body);
    return [];
  }

  static Future<Map<String, dynamic>> getAdminStats() async {
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/api/admin/stats'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) return json.decode(response.body);
    return {'todayDatabaseWrites': 0};
  }


  static Future<Map<String, dynamic>> sendAdminNotification(String title, String message, {String targetUserId = 'all'}) async {
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/api/admin/notifications'),
      headers: await _getHeaders(),
      body: json.encode({
        'title': title,
        'message': message,
        'targetUserId': targetUserId,
      }),
    );
    return await _handleResponse(response);
  }

  static Future<List<dynamic>> getAdminSessions(String userId) async {
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/api/admin/sessions/$userId'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) return json.decode(response.body);
    return [];
  }

  static Future<Map<String, dynamic>> adminLogoutDevice(String sessionId) async {
    final response = await http.delete(
      Uri.parse('${ApiConstants.baseUrl}/api/admin/logout-device/$sessionId'),
      headers: await _getHeaders(),
    );
    return await _handleResponse(response);
  }

  static Future<Map<String, dynamic>> updateUserStatus(String userId, String status, {Map<String, dynamic>? adminMessage}) async {
    final response = await http.put(
      Uri.parse('${ApiConstants.baseUrl}/api/admin/users/$userId/status'),
      headers: await _getHeaders(),
      body: json.encode({
        'status': status,
        if (adminMessage != null) 'adminMessage': adminMessage,
      }),
    );
    return await _handleResponse(response);
  }

  static Future<Map<String, dynamic>> updateUserRole(String userId, String role, {List<String>? adminPermissions}) async {
    final response = await http.put(
      Uri.parse('${ApiConstants.baseUrl}/api/admin/users/$userId/role'),
      headers: await _getHeaders(),
      body: json.encode({
        'role': role,
        if (adminPermissions != null) 'adminPermissions': adminPermissions,
      }),
    );
    return await _handleResponse(response);
  }

  // ==================== FCM Token Management ====================

  static Future<Map<String, dynamic>> saveFCMToken(String fcmToken) async {
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/api/user/fcm-token'),
      headers: await _getHeaders(),
      body: json.encode({
        'fcmToken': fcmToken,
        'platform': _getPlatform(),
      }),
    );
    return await _handleResponse(response);
  }

  static Future<Map<String, dynamic>> removeFCMToken(String fcmToken) async {
    final response = await http.delete(
      Uri.parse('${ApiConstants.baseUrl}/api/user/fcm-token'),
      headers: await _getHeaders(),
      body: json.encode({'fcmToken': fcmToken}),
    );
    return await _handleResponse(response);
  }

  static Future<Map<String, dynamic>> triggerManualEmergencyCall(String title, String body, {String ringtone = 'default'}) async {
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/api/user/emergency-call'),
      headers: await _getHeaders(),
      body: json.encode({
        'title': title,
        'body': body,
        'ringtone': ringtone,
      }),
    );
    return await _handleResponse(response);
  }

  static Future<dynamic> _handleResponse(http.Response response) async {
    final body = json.decode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    } else {
      throw Exception(body['msg'] ?? body['message'] ?? 'Unknown error');
    }
  }

  static String _getPlatform() {
    try {
      if (identical(0, 0.0)) return 'web'; // Web platform check
      return 'android'; // Default for mobile
    } catch (_) {
      return 'unknown';
    }
  }

  // ==================== Ban Management ====================

  static Future<List<dynamic>> getBannedDevices() async {
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/api/admin/banned-devices'),
      headers: await _getHeaders(),
    );
    final data = await _handleResponse(response);
    return data is List ? data : [];
  }

  static Future<Map<String, dynamic>> unbanDevice(String banId) async {
    final response = await http.delete(
      Uri.parse('${ApiConstants.baseUrl}/api/admin/unban-device/$banId'),
      headers: await _getHeaders(),
    );
    return await _handleResponse(response);
  }

  static Future<Map<String, dynamic>> banDevice({String? ip, String? deviceId, String? deviceName, String? reason}) async {
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/api/admin/ban-device'),
      headers: await _getHeaders(),
      body: json.encode({
        if (ip != null) 'ip': ip,
        if (deviceId != null) 'deviceId': deviceId,
        if (deviceName != null) 'deviceName': deviceName,
        'reason': reason ?? 'محظور من قبل الإدارة',
      }),
    );
    return await _handleResponse(response);
  }

  // ==================== Admin Automation Management ====================

  static Future<List<dynamic>> getAdminAutomationStats() async {
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/api/admin/automation-stats'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) return json.decode(response.body);
    return [];
  }

  static Future<Map<String, dynamic>> adminTogglePowerSaving(String userId, bool enabled) async {
    final response = await http.put(
      Uri.parse('${ApiConstants.baseUrl}/api/admin/power-saving/$userId'),
      headers: await _getHeaders(),
      body: json.encode({'enabled': enabled}),
    );
    return await _handleResponse(response);
  }

  // ==================== Automation Rules API ====================

  static Future<List<dynamic>> getAutomationRules() async {
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/api/automations'),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 200) return json.decode(response.body);
    return [];
  }

  static Future<Map<String, dynamic>> createAutomationRule(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/api/automations'),
      headers: await _getHeaders(),
      body: json.encode(data),
    );
    return await _handleResponse(response);
  }

  static Future<Map<String, dynamic>> updateAutomationRule(String ruleId, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('${ApiConstants.baseUrl}/api/automations/$ruleId'),
      headers: await _getHeaders(),
      body: json.encode(data),
    );
    return await _handleResponse(response);
  }

  static Future<Map<String, dynamic>> deleteAutomationRule(String ruleId) async {
    final response = await http.delete(
      Uri.parse('${ApiConstants.baseUrl}/api/automations/$ruleId'),
      headers: await _getHeaders(),
    );
    return await _handleResponse(response);
  }

  static Future<Map<String, dynamic>> toggleAutomationRule(String ruleId) async {
    final response = await http.patch(
      Uri.parse('${ApiConstants.baseUrl}/api/automations/$ruleId/toggle'),
      headers: await _getHeaders(),
    );
    return await _handleResponse(response);
  }

  // ==================== Power Saving API ====================

  static Future<Map<String, dynamic>> getPowerSavingStatus() async {
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/api/user/power-saving'),
      headers: await _getHeaders(),
    );
    return await _handleResponse(response);
  }

  static Future<Map<String, dynamic>> setPowerSaving(bool enabled) async {
    final response = await http.put(
      Uri.parse('${ApiConstants.baseUrl}/api/user/power-saving'),
      headers: await _getHeaders(),
      body: json.encode({'enabled': enabled}),
    );
    return await _handleResponse(response);
  }

  // ==================== Smart Scenes / Macros API ====================
  static const String _scenesLocalKey = 'local_scenes_v1';

  static Future<List<dynamic>> getScenes() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/api/scenes'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 4));
      
      if (response.statusCode == 200) {
        final List<dynamic> serverScenes = json.decode(response.body);
        // Sync local cache with server data
        await _saveLocalScenes(serverScenes);
        return serverScenes;
      }
    } catch (_) {}
    
    // Fallback: Return cached local scenes
    return await _getLocalScenes();
  }

  static Future<Map<String, dynamic>> createScene(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/api/scenes'),
        headers: await _getHeaders(),
        body: json.encode(data),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final serverScene = json.decode(response.body);
        // Add to local cache
        final local = await _getLocalScenes();
        local.insert(0, serverScene);
        await _saveLocalScenes(local);
        return serverScene;
      }
    } catch (_) {}

    // Fallback: Create and save locally
    final local = await _getLocalScenes();
    final localScene = {
      'id': 'local_scene_${DateTime.now().millisecondsSinceEpoch}',
      'name': data['name'] ?? '',
      'icon': data['icon'] ?? 'bolt',
      'color': data['color'] ?? '#B026FF',
      'showOnDashboard': data['showOnDashboard'] ?? true,
      'actions': data['actions'] ?? [],
      'createdAt': DateTime.now().toIso8601String(),
    };
    local.insert(0, localScene);
    await _saveLocalScenes(local);
    return localScene;
  }

  static Future<Map<String, dynamic>> updateScene(String id, Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConstants.baseUrl}/api/scenes/$id'),
        headers: await _getHeaders(),
        body: json.encode(data),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final res = json.decode(response.body);
        final updatedScene = res['scene'] ?? res;
        // Update local cache
        final local = await _getLocalScenes();
        final idx = local.indexWhere((s) => s['id'] == id);
        if (idx != -1) {
          local[idx] = updatedScene;
          await _saveLocalScenes(local);
        }
        return res;
      }
    } catch (_) {}

    // Fallback: Update locally
    final local = await _getLocalScenes();
    final idx = local.indexWhere((s) => s['id'] == id);
    if (idx != -1) {
      local[idx]['name'] = data['name'] ?? local[idx]['name'];
      local[idx]['icon'] = data['icon'] ?? local[idx]['icon'];
      local[idx]['color'] = data['color'] ?? local[idx]['color'];
      local[idx]['showOnDashboard'] = data['showOnDashboard'] ?? local[idx]['showOnDashboard'];
      local[idx]['actions'] = data['actions'] ?? local[idx]['actions'];
      await _saveLocalScenes(local);
      return {'msg': 'Updated locally', 'scene': local[idx]};
    }
    throw Exception('Scene not found locally');
  }

  static Future<Map<String, dynamic>> deleteScene(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConstants.baseUrl}/api/scenes/$id'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Delete from local cache
        final local = await _getLocalScenes();
        local.removeWhere((s) => s['id'] == id);
        await _saveLocalScenes(local);
        return json.decode(response.body);
      }
    } catch (_) {}

    // Fallback: Delete locally
    final local = await _getLocalScenes();
    local.removeWhere((s) => s['id'] == id);
    await _saveLocalScenes(local);
    return {'msg': 'Deleted locally'};
  }

  static Future<Map<String, dynamic>> executeScene(String id, List<dynamic> actions) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/api/scenes/$id/execute'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json.decode(response.body);
      }
    } catch (_) {}

    // Fallback: Execute scene locally in parallel on the client!
    List<Future> futures = [];
    for (var action in actions) {
      futures.add(sendCommand(action['widgetId'], action['value']).catchError((e) {
        // Log or silently ignore
      }));
    }
    
    await Future.wait(futures);
    return {'msg': 'Executed locally in parallel', 'success': true};
  }

  // --- Local Fallback Scenes Cache Utilities ---
  static Future<List<dynamic>> _getLocalScenes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_scenesLocalKey);
    if (raw == null || raw.isEmpty) return [];
    return json.decode(raw);
  }

  static Future<void> _saveLocalScenes(List<dynamic> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_scenesLocalKey, json.encode(list));
  }

  // --- Merchant / Sub-Admin Provisioning Endpoints ---

  // Verify Sub-Admin Promo Code (typed in password field) — returns full response map
  static Future<Map<String, dynamic>> verifySubAdminCode(String code) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/api/auth/verify-sub-admin-code'),
        headers: await _getHeaders(),
        body: json.encode({'code': code}),
      ).timeout(const Duration(seconds: 4));
      final body = json.decode(response.body);
      if (response.statusCode == 200 && body['valid'] == true) {
        return body; // { valid: true, type: 'sub_admin'/'merchant_client', name: '...' }
      } else {
        return {'valid': false};
      }
    } catch (_) {
      return {'valid': false};
    }
  }

  // Verify Merchant Client Join Code (scanned/manually entered by a Client)
  static Future<Map<String, dynamic>> verifyMerchantClientCode(String code) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/api/auth/verify-merchant-client-code'),
        headers: await _getHeaders(),
        body: json.encode({'code': code}),
      ).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errBody = json.decode(response.body);
        throw http.ClientException(errBody['msg'] ?? 'Failed to verify join code');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Super Admin: get created sub-admin codes
  static Future<List<dynamic>> getSubAdminPromoKeys() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/api/admin/sub-admin-promo-keys'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errBody = json.decode(response.body);
        throw Exception(errBody['msg'] ?? 'Failed to fetch promo keys');
      }
    } catch (e) {
      return [];
    }
  }

  // Super Admin: create promo key
  static Future<Map<String, dynamic>> generateSubAdminPromoKey(String key) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/api/admin/sub-admin-promo-keys'),
        headers: await _getHeaders(),
        body: json.encode({'code': key}),
      ).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        final errBody = json.decode(response.body);
        throw Exception(errBody['msg'] ?? 'Failed to generate key');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Super Admin: delete promo key
  static Future<Map<String, dynamic>> deleteSubAdminPromoKey(String key) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConstants.baseUrl}/api/admin/sub-admin-promo-keys/$key'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errBody = json.decode(response.body);
        throw Exception(errBody['msg'] ?? 'Failed to delete key');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Sub-Admin: get clients registered under their code
  static Future<List<dynamic>> getMerchantClients(String subAdminCode) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/api/merchant/clients'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errBody = json.decode(response.body);
        final msg = errBody['msg']?.toString() ?? '';
        if (response.statusCode == 403 && (msg.contains('مخصص') || msg.contains('distributor') || msg.contains('merchant'))) {
          try {
            final allUsers = await getAdminUsers();
            return allUsers.where((u) => (u['parentAdminCode'] ?? '').toString() == subAdminCode).toList();
          } catch (_) {}
        }
        throw http.ClientException(msg.isEmpty ? 'Failed to load clients' : msg);
      }
    } catch (e) {
      if (e is http.ClientException) rethrow;
      rethrow;
    }
  }

  static Future<void> toggleMerchantClientStatus(String subAdminCode, String clientId, String newStatus) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConstants.baseUrl}/api/merchant/clients/$clientId/status'),
        headers: await _getHeaders(),
        body: json.encode({'status': newStatus}),
      ).timeout(const Duration(seconds: 4));
      if (response.statusCode != 200) {
        final errBody = json.decode(response.body);
        throw http.ClientException(errBody['msg'] ?? 'Failed to update client status');
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getSubAdminPermissions(String code) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/api/admin/sub-admin-permissions/$code'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {
          'allowSuspend': true,
          'allowBypassQuota': true,
          'maxClients': 100,
        };
      }
    } catch (e) {
      return {
        'allowSuspend': true,
        'allowBypassQuota': true,
        'maxClients': 100,
      };
    }
  }

  static Future<void> saveSubAdminPermissions(String code, Map<String, dynamic> perms) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/api/admin/sub-admin-permissions/$code'),
        headers: await _getHeaders(),
        body: json.encode(perms),
      ).timeout(const Duration(seconds: 4));
      if (response.statusCode != 200 && response.statusCode != 201) {
        final errBody = json.decode(response.body);
        throw Exception(errBody['msg'] ?? 'Failed to save permissions');
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<dynamic> executeGenericApiCall(String method, String url, Map<String, dynamic>? body) async {
    String fullUrl = url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      final path = url.startsWith('/') ? url : '/$url';
      fullUrl = '${ApiConstants.baseUrl}$path';
    }

    final uri = Uri.parse(fullUrl);
    final headers = await _getHeaders();
    final bodyStr = body != null ? json.encode(body) : null;

    http.Response response;
    final methodUpper = method.toUpperCase();

    if (methodUpper == 'GET') {
      response = await http.get(uri, headers: headers);
    } else if (methodUpper == 'POST') {
      response = await http.post(uri, headers: headers, body: bodyStr);
    } else if (methodUpper == 'PUT') {
      response = await http.put(uri, headers: headers, body: bodyStr);
    } else if (methodUpper == 'DELETE') {
      response = await http.delete(uri, headers: headers, body: bodyStr);
    } else if (methodUpper == 'PATCH') {
      response = await http.patch(uri, headers: headers, body: bodyStr);
    } else {
      throw Exception('Unsupported HTTP method: $method');
    }

    return await _handleResponse(response);
  }
}








