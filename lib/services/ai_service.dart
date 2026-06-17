import 'dart:convert';
import 'api_service.dart';

class AiService {
  static Future<String> processAICommand(String userMessage, List<Map<String, dynamic>> chatHistory) async {
    // We now just forward the request to the backend server.
    // The server handles context gathering, API key rotation, role verification, and static responses.
    
    // Convert history format to match the backend expectation
    final history = chatHistory.map((h) {
      return {
        'role': h['role'],
        'parts': h['parts']
      };
    }).toList();

    try {
      final responseMap = await ApiService.chatWithAi(userMessage, history);
      return json.encode(responseMap);
    } catch (e) {
      throw Exception('فشل في الاتصال بالمساعد الذكي: $e');
    }
  }
}
