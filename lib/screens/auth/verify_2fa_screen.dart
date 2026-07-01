import '../../widgets/app_snackbar.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../services/api_service.dart';
import '../dashboard_screen.dart';

class Verify2FAScreen extends StatefulWidget {
  final String email;
  const Verify2FAScreen({super.key, required this.email});

  @override
  State<Verify2FAScreen> createState() => _Verify2FAScreenState();
}

class _Verify2FAScreenState extends State<Verify2FAScreen> {
  final _codeCtrl = TextEditingController();
  bool _isLoading = false;

  void _verifyCode() async {
    if (_codeCtrl.text.isEmpty) return;
    
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.verify2Fa(widget.email, _codeCtrl.text.trim());
      setState(() => _isLoading = false);
      if (!mounted) return;
      
      if (res['token'] != null) {
         await ApiService.saveToken(res['token']);
         if (!mounted) return;
         Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const DashboardScreen()), (r) => false);
      } else {
         AppSnackbar.showInfo(context, res['msg'] ?? 'Invalid 2FA code');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      AppSnackbar.showError(context, 'Failed to verify code.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(title: const Text('TWO-FACTOR AUTH')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: GlassCard(
            baseColor: AppTheme.cardBaseColor,
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.security, size: 64, color: AppTheme.primaryCyan),
                  const SizedBox(height: 16),
                  Text('Please enter the 6-digit code sent to\n${widget.email}',
                     textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _codeCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 8),
                    textAlign: TextAlign.center,
                    onChanged: (val) {
                      if (val.length == 6) {
                        _verifyCode();
                      }
                    },
                    onSubmitted: (_) => _verifyCode(),
                    maxLength: 6,
                    decoration: InputDecoration(
                      hintText: '000000',
                      hintStyle: const TextStyle(color: Colors.white24),
                      counterText: "",
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white24)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primaryCyan)),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryViolet,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isLoading ? null : _verifyCode,
                      child: _isLoading 
                          ? const CircularProgressIndicator(color: Colors.white) 
                          : const Text('Verify to Login', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
