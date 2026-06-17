import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:nfc_host_card_emulation/nfc_host_card_emulation.dart';

class NfcService {
  static bool _isInitialized = false;
  static Function(String)? onMessageReceived;

  // The custom AID must match apduservice.xml
  static final Uint8List _customAid = Uint8List.fromList([
    0xF0, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06
  ]);

  static Future<void> init() async {
    if (_isInitialized) return;
    
    try {
      // Bypassing checkDeviceNfcState() because it returns false negatives on some devices
      await NfcHce.init(
        aid: _customAid,
        permanentApduResponses: true,
        listenOnlyConfiguredPorts: false,
      );

      NfcHce.stream.listen((command) {
        debugPrint('Received APDU on port ${command.port}');
        if (command.data != null && command.data!.isNotEmpty) {
          final text = utf8.decode(command.data!);
          debugPrint('NFC Received Data: $text');
          if (onMessageReceived != null) {
            onMessageReceived!(text);
          }
        }
      });
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing NFC HCE: $e');
    }
  }

  /// Sets up the payload the phone will send to the reader when scanned.
  static Future<void> setPayload(String payload) async {
    if (!_isInitialized) await init();
    try {
      final bytes = utf8.encode(payload);
      // Register on multiple ports (P2 bytes) just in case the reader sends P2 > 0
      for (int i = 0; i <= 5; i++) {
        await NfcHce.addApduResponse(i, bytes);
      }
      debugPrint('NFC Payload set: $payload');
    } catch (e) {
      debugPrint('Error setting NFC payload: $e');
    }
  }

  /// Clears the current payload so the phone stops responding
  static Future<void> clearPayload() async {
    if (!_isInitialized) return;
    try {
      for (int i = 0; i <= 5; i++) {
        await NfcHce.removeApduResponse(i);
      }
      debugPrint('NFC Payload cleared');
    } catch (e) {
      debugPrint('Error clearing NFC payload: $e');
    }
  }
}
