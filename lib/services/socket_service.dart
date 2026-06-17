import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../core/api_constants.dart';
import 'api_service.dart';

class SocketService {
  static IO.Socket? socket;

  static Future<void> connect(String userId) async {
    if (socket != null && socket!.connected) {
      print('⚠️  Socket already connected, skipping duplicate connection');
      return;
    }

    // ✅ الحل: الحصول على التوكن وتمريره إلى Socket.IO
    final token = await ApiService.getToken();
    
    print('🔌 Attempting to connect to Socket.IO server at: $baseUrl');
    print('🔑 Using authentication token: ${token != null ? '✅ Present' : '❌ Missing'}');
    
    socket = IO.io(ApiConstants.baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      // ✅ إضافة التوكن للـ Socket authentication
      if (token != null) 'auth': {
        'token': token,
      }
    });

    socket!.connect();

    socket!.onConnect((_) {
      print('✅ Connected to Socket.IO server UI');
      print('📤 Joining user room: $userId');
      socket!.emit('join-user-room', userId);
    });

    socket!.onError((error) {
      print('❌ Socket error: $error');
    });

    socket!.onConnectError((error) {
      print('❌ Socket connection error: $error');
    });

    socket!.onDisconnect((_) {
      print('❌ Disconnected from Socket.IO server');
    });
    
    // Default listeners
    socket!.on('widget-status-update', (data) {
      print('📨 Widget updated via socket: $data');
    });
    
    socket!.on('sensor-data', (data) {
      print('📨 Sensor data received via socket: $data');
    });
    
    socket!.on('new-sensor-reading', (data) {
      print('📨 New sensor reading via socket: $data');
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
