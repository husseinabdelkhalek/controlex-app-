import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../core/api_constants.dart';
import 'api_service.dart';

class SocketService {
  static io.Socket? socket;

  static Future<void> connect(String userId) async {
    if (socket != null && socket!.connected) {
      debugPrint('⚠️  Socket already connected, skipping duplicate connection');
      return;
    }

    // ✅ الحل: الحصول على التوكن وتمريره إلى Socket.IO
    final token = await ApiService.getToken();
    
    debugPrint('🔌 Attempting to connect to Socket.IO server at: $baseUrl');
    debugPrint('🔑 Using authentication token: ${token != null ? '✅ Present' : '❌ Missing'}');
    
    socket = io.io(ApiConstants.baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      // ✅ إضافة التوكن للـ Socket authentication
      if (token != null) 'auth': {
        'token': token,
      }
    });

    socket!.connect();

    socket!.onConnect((_) {
      debugPrint('✅ Connected to Socket.IO server UI');
      debugPrint('📤 Joining user room: $userId');
      socket!.emit('join-user-room', userId);
    });

    socket!.onError((error) {
      debugPrint('❌ Socket error: $error');
    });

    socket!.onConnectError((error) {
      debugPrint('❌ Socket connection error: $error');
    });

    socket!.onDisconnect((_) {
      debugPrint('❌ Disconnected from Socket.IO server');
    });
    
    // Default listeners
    socket!.on('widget-status-update', (data) {
      debugPrint('📨 Widget updated via socket: $data');
    });
    
    socket!.on('sensor-data', (data) {
      debugPrint('📨 Sensor data received via socket: $data');
    });
    
    socket!.on('new-sensor-reading', (data) {
      debugPrint('📨 New sensor reading via socket: $data');
    });
  }

  static const String baseUrl = ApiConstants.baseUrl;

  static void disconnect() {
    if (socket != null) {
      socket!.disconnect();
      socket = null;
    }
  }

  static void emitWidgetUpdate(Map<String, dynamic> data) {
    if (socket != null && socket!.connected) {
      socket!.emit('widget-update', data);
    }
  }
}
