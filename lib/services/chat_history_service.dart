import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ChatHistoryService {
  static const String _storageKey = 'ai_chat_sessions';

  static Future<void> saveSession(String id, List<dynamic> history) async {
    final prefs = await SharedPreferences.getInstance();
    final String? sessionsStr = prefs.getString(_storageKey);
    List<dynamic> sessions = [];
    if (sessionsStr != null) {
      try {
        sessions = json.decode(sessionsStr);
      } catch (e) {
        sessions = [];
      }
    }

    String title = 'Chat Session';
    // Find first user message for title
    for (var msg in history) {
      if (msg['role'] == 'user' && msg['parts'] != null && msg['parts'].isNotEmpty) {
        try {
          String text = msg['parts'][0]['text'] ?? '';
          title = text.length > 40 ? '${text.substring(0, 40)}...' : text;
          break;
        } catch (_) {}
      }
    }

    final newSession = {
      'id': id,
      'title': title,
      'lastUpdated': DateTime.now().millisecondsSinceEpoch,
      'history': history,
    };

    int existingIndex = sessions.indexWhere((s) => s['id'] == id);
    if (existingIndex >= 0) {
      sessions[existingIndex] = newSession;
    } else {
      sessions.insert(0, newSession);
    }

    await prefs.setString(_storageKey, json.encode(sessions));
  }

  static Future<List<Map<String, dynamic>>> getSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final String? sessionsStr = prefs.getString(_storageKey);
    if (sessionsStr == null) return [];
    
    try {
      List<dynamic> decoded = json.decode(sessionsStr);
      List<Map<String, dynamic>> sessions = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      
      // Sort by lastUpdated descending
      sessions.sort((a, b) => (b['lastUpdated'] as int? ?? 0).compareTo(a['lastUpdated'] as int? ?? 0));
      return sessions;
    } catch (e) {
      return [];
    }
  }

  static Future<void> deleteSession(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final String? sessionsStr = prefs.getString(_storageKey);
    if (sessionsStr == null) return;
    
    try {
      List<dynamic> sessions = json.decode(sessionsStr);
      sessions.removeWhere((s) => s['id'] == id);
      await prefs.setString(_storageKey, json.encode(sessions));
    } catch (e) {}
  }

  static Future<void> deleteOldSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final String? sessionsStr = prefs.getString(_storageKey);
    if (sessionsStr == null) return;
    
    try {
      List<dynamic> sessions = json.decode(sessionsStr);
      final now = DateTime.now().millisecondsSinceEpoch;
      final thirtyDaysMs = 30 * 24 * 60 * 60 * 1000;
      
      sessions.removeWhere((s) {
        final lastUpdated = s['lastUpdated'] as int? ?? 0;
        return (now - lastUpdated) > thirtyDaysMs;
      });
      
      await prefs.setString(_storageKey, json.encode(sessions));
    } catch (e) {}
  }
}
