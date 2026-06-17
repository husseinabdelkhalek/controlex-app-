import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LocalService {
  static String _deviceIp = '';
  static const String _ipKey = 'local_device_ip';
  static const String _widgetsKey = 'local_widgets';

  // --- IP Management ---
  static String get deviceIp => _deviceIp;

  static Future<void> loadIp() async {
    final prefs = await SharedPreferences.getInstance();
    _deviceIp = prefs.getString(_ipKey) ?? '';
  }

  static Future<void> saveIp(String ip) async {
    _deviceIp = ip.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ipKey, _deviceIp);
  }

  // --- Send Command to ESP via HTTP ---
  static Future<Map<String, dynamic>> sendCommand(String widgetId, dynamic value) async {
    if (_deviceIp.isEmpty) {
      throw Exception('لم يتم تحديد عنوان IP للجهاز.');
    }

    final widgets = await getWidgets();
    final widget = widgets.firstWhere(
      (w) => w['id'] == widgetId,
      orElse: () => throw Exception('الأداة غير موجودة.'),
    );

    final String commandPath = (widget['feedName'] ?? '').toString().trim();
    if (commandPath.isEmpty) {
      throw Exception('لم يتم تحديد مسار الأمر (Command Path) لهذه الأداة.');
    }

    // Build the URL: http://IP/commandPath?value=VALUE
    String url = 'http://$_deviceIp/$commandPath?value=$value';

    try {
      final response = await http.get(
        Uri.parse(url),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Update widget state locally
        await _updateWidgetState(widgetId, value.toString());
        return {'msg': 'تم إرسال الأمر بنجاح', 'status': response.statusCode};
      } else {
        throw Exception('ESP رفض الأمر (${response.statusCode})');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException') || e.toString().contains('SocketException')) {
        throw Exception('لا يمكن الوصول للجهاز على $_deviceIp. تأكد من اتصال WiFi.');
      }
      rethrow;
    }
  }

  // --- Check Connection ---
  static Future<bool> checkConnection() async {
    if (_deviceIp.isEmpty) return false;
    try {
      final response = await http.get(
        Uri.parse('http://$_deviceIp/'),
      ).timeout(const Duration(seconds: 3));
      return response.statusCode >= 200 && response.statusCode < 400;
    } catch (_) {
      return false;
    }
  }

  // --- Local Widget CRUD (SharedPreferences) ---
  static Future<List<Map<String, dynamic>>> getWidgets() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_widgetsKey);
    if (raw == null || raw.isEmpty) return [];
    final List<dynamic> decoded = json.decode(raw);
    return decoded.cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> createWidget(Map<String, dynamic> data) async {
    final widgets = await getWidgets();
    final id = 'local_${DateTime.now().millisecondsSinceEpoch}';
    final widget = {
      'id': id,
      'name': data['name'] ?? '',
      'feedName': data['feedName'] ?? '', // This is the command path in local mode
      'type': data['type'] ?? 'toggle',
      'appearance': data['appearance'] ?? {
        'primaryColor': '#00e5ff',
        'activeColor': '#00e5ff',
        'glowColor': '#8A2BE2',
      },
      'configuration': data['configuration'] ?? {
        'onCommand': data['onCommand'] ?? 'ON',
        'offCommand': data['offCommand'] ?? 'OFF',
        'min': data['configuration']?['min'] ?? 0,
        'max': data['configuration']?['max'] ?? 100,
        'unit': data['unit'] ?? '',
      },
      'state': {'isActive': false, 'lastValue': null},
      'gs': {'x': 0, 'y': 0, 'w': 1, 'h': 1},
    };
    widgets.add(widget);
    await _saveWidgets(widgets);
    return widget;
  }

  static Future<Map<String, dynamic>> updateWidget(String id, Map<String, dynamic> data) async {
    final widgets = await getWidgets();
    final index = widgets.indexWhere((w) => w['id'] == id);
    if (index == -1) throw Exception('الأداة غير موجودة.');

    final existing = widgets[index];
    existing['name'] = data['name'] ?? existing['name'];
    existing['feedName'] = data['feedName'] ?? existing['feedName'];
    existing['type'] = data['type'] ?? existing['type'];
    
    if (data['configuration'] != null) {
      existing['configuration'] = <String, dynamic>{
        ...existing['configuration'] ?? {},
        ...data['configuration'],
      };
    }
    if (data['onCommand'] != null) existing['configuration']['onCommand'] = data['onCommand'];
    if (data['offCommand'] != null) existing['configuration']['offCommand'] = data['offCommand'];
    if (data['primaryColor'] != null) {
      existing['appearance'] = existing['appearance'] ?? {};
      existing['appearance']['primaryColor'] = data['primaryColor'];
    }

    widgets[index] = existing;
    await _saveWidgets(widgets);
    return existing;
  }

  static Future<void> deleteWidget(String id) async {
    final widgets = await getWidgets();
    widgets.removeWhere((w) => w['id'] == id);
    await _saveWidgets(widgets);
  }

  static Future<void> updateWidgetPosition(String id, int x, int y, int w, int h) async {
    final widgets = await getWidgets();
    final index = widgets.indexWhere((wi) => wi['id'] == id);
    if (index != -1) {
      widgets[index]['gs'] = {'x': x, 'y': y, 'w': w, 'h': h};
      await _saveWidgets(widgets);
    }
  }

  static Future<void> _updateWidgetState(String widgetId, String value) async {
    final widgets = await getWidgets();
    final index = widgets.indexWhere((w) => w['id'] == widgetId);
    if (index != -1) {
      widgets[index]['state'] = {
        'isActive': value.toUpperCase() == (widgets[index]['configuration']?['onCommand'] ?? 'ON').toString().toUpperCase(),
        'lastValue': value,
      };
      await _saveWidgets(widgets);
    }
  }

  static Future<void> _saveWidgets(List<Map<String, dynamic>> widgets) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_widgetsKey, json.encode(widgets));
  }
}
