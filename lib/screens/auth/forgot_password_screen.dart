import '../../widgets/app_snackbar.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../services/api_service.dart';
import '../auth/reset_password_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  void _sendResetCode() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return;
    
    // Email regex validation
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      AppSnackbar.showInfo(context, 'يرجى إدخال بريد إلكتروني صحيح');
      return;
    }
    
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.forgotPassword(email);
      setState(() => _isLoading = false);
      if (!mounted) return;
      
      if (res['msg'] != null && res['msg'].contains('تم إرسال')) {
         AppSnackbar.showInfo(context, res['msg']);
         Navigator.push(context, MaterialPageRoute(builder: (_) => ResetPasswordScreen(email: email)));
      } else {
         AppSnackbar.showError(context, res['msg'] ?? 'Error occurred');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      AppSnackbar.showError(context, 'Failed to request reset.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(title: Text('FORGOT PASSWORD')),
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
                  Icon(Icons.password, size: 64, color: AppTheme.primaryCyan),
                  SizedBox(height: 24),
                  Text('Enter your registered email address to receive a 6-digit reset code.',
                     textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
                  SizedBox(height: 32),
                  TextField(
                    controller: _emailCtrl,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      labelStyle: TextStyle(color: Colors.white54),
                      prefixIcon: Icon(Icons.email, color: Colors.white54),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white24)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.primaryCyan)),
                    ),
                    onSubmitted: (_) => _sendResetCode(),
                  ),
                  SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryViolet,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isLoading ? null : _sendResetCode,
                      child: _isLoading 
                          ? CircularProgressIndicator(color: Colors.white) 
                          : Text('Send Reset Code', style: TextStyle(color: Colors.white, fontSize: 16)),
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
