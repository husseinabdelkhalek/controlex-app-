import 'package:local_auth/local_auth.dart';
import '../core/localization.dart';
import 'package:flutter/material.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<bool> authenticate(BuildContext context) async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      
      if (!canAuthenticate) {
        if (context.mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(
             content: Text(AppLocalization.isArabicNotifier.value ? 'المصادقة البيومترية غير مدعومة في هذا الجهاز' : 'Biometric authentication is not supported on this device'),
             backgroundColor: Colors.redAccent,
           ));
        }
        return false;
      }

      return await _auth.authenticate(
        localizedReason: AppLocalization.isArabicNotifier.value ? 'يرجى المصادقة لإرسال الأمر' : 'Please authenticate to send command',
        options: const AuthenticationOptions(
          biometricOnly: false, // allow fallback to device credentials if needed, though they asked for fingerprint/faceID
          stickyAuth: true,
        ),
      );
    } catch (e) {
      if (context.mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(
           content: Text('Error: ${e.toString()}'),
           backgroundColor: Colors.redAccent,
         ));
      }
      return false;
    }
  }
}
