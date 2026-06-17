import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;
  const ResetPasswordScreen({super.key, required this.email});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _codeCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _resetPassword() async {
    final code = _codeCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    if (code.isEmpty || password.isEmpty) return;
    
    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('كلمة المرور يجب أن تكون 6 أحرف على الأقل'))
      );
      return;
    }
    
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.resetPassword(
         widget.email, code, password
      );
      setState(() => _isLoading = false);
      
      if (res['msg'] != null && res['msg'].contains('نجاح')) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['msg'])));
         Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
      } else {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['msg'] ?? 'Invalid code')));
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to reset.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(title: const Text('NEW PASSWORD')),
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
                  const Icon(Icons.lock_reset, size: 64, color: AppTheme.primaryViolet),
                  const SizedBox(height: 16),
                  Text('We sent a 6-digit code to\n${widget.email}',
                     textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _codeCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 8),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: '000000',
                      hintStyle: const TextStyle(color: Colors.white24),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white24)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primaryCyan)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _passwordCtrl,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      labelStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(Icons.lock, color: Colors.white54),
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
                        backgroundColor: AppTheme.primaryCyan,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isLoading ? null : _resetPassword,
                      child: _isLoading 
                          ? const CircularProgressIndicator(color: Colors.black) 
                          : const Text('Update Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
