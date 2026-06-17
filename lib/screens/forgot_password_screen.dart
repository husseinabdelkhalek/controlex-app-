import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../services/api_service.dart';
import 'reset_password_screen.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال بريد إلكتروني صحيح'))
      );
      return;
    }
    
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.forgotPassword(email);
      setState(() => _isLoading = false);
      
      if (res['msg'] != null && res['msg'].contains('تم إرسال')) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['msg'])));
         Navigator.push(context, MaterialPageRoute(builder: (_) => ResetPasswordScreen(email: email)));
      } else {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['msg'] ?? 'Error occurred')));
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to request reset.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(title: const Text('FORGOT PASSWORD')),
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
                  const Icon(Icons.password, size: 64, color: AppTheme.primaryCyan),
                  const SizedBox(height: 24),
                  const Text('Enter your registered email address to receive a 6-digit reset code.',
                     textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _emailCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      labelStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(Icons.email, color: Colors.white54),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white24)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primaryCyan)),
                    ),
                    onSubmitted: (_) => _sendResetCode(),
                  ),
                  const SizedBox(height: 32),
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
                          ? const CircularProgressIndicator(color: Colors.white) 
                          : const Text('Send Reset Code', style: TextStyle(color: Colors.white, fontSize: 16)),
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
