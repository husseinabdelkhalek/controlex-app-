import 'dart:ui';
import '../../widgets/app_snackbar.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../services/api_service.dart';
import '../../core/localization.dart';
import '../../widgets/cyber_grid_painter.dart';
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
    if (email.isEmpty) {
      AppSnackbar.showInfo(context, AppLocalization.get('enter_email'));
      return;
    }
    
    // Email regex validation
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      AppSnackbar.showInfo(context, AppLocalization.get('enter_valid_email'));
      return;
    }
    
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.forgotPassword(email);
      setState(() => _isLoading = false);
      if (!mounted) return;
      
      final bool isSuccess = res['success'] == true || 
          (res['msg'] != null && (res['msg'].contains('تم إرسال') || res['msg'].toLowerCase().contains('sent') || res['msg'].toLowerCase().contains('success')));
      
      if (isSuccess) {
         AppSnackbar.showSuccess(context, res['msg'] ?? AppLocalization.get('code_resent'));
         Navigator.push(context, MaterialPageRoute(builder: (_) => ResetPasswordScreen(email: email)));
      } else {
         AppSnackbar.showError(context, res['msg'] ?? 'Error occurred');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      AppSnackbar.showError(context, AppLocalization.get('request_reset_failed'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = AppLocalization.isArabicNotifier.value;
    return Scaffold(
      body: Stack(
        children: [
          Container(color: AppTheme.backgroundBase),
          // Cyber grid background
          Positioned.fill(
            child: CustomPaint(
              painter: CyberGridPainter(),
            ),
          ),
          // Background blobs
          Positioned(
            top: -50,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryViolet.withValues(alpha: 0.1),
              ),
              child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container()),
            ),
          ),
          
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.all(32.0),
                    decoration: AppTheme.glassDecoration(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.password, size: 64, color: AppTheme.primaryCyan),
                        const SizedBox(height: 24),
                        Text(
                          isAr 
                            ? 'أدخل البريد الإلكتروني المسجل لتلقي رمز التحقق المكون من 6 أرقام.'
                            : 'Enter your registered email address to receive a 6-digit reset code.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70, height: 1.4),
                        ),
                        const SizedBox(height: 32),
                        TextField(
                          controller: _emailCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: AppTheme.inputDecoration(
                            labelText: isAr ? 'البريد الإلكتروني' : 'Email Address',
                            prefixIcon: Icons.email_outlined,
                          ),
                          onSubmitted: (_) => _sendResetCode(),
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _sendResetCode,
                            child: _isLoading 
                                ? const CircularProgressIndicator(color: Colors.white) 
                                : Text(isAr ? 'إرسال الرمز' : 'Send Reset Code', style: const TextStyle(color: Colors.white, fontSize: 16)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            isAr ? 'العودة لتسجيل الدخول' : 'Back to Login',
                            style: TextStyle(color: AppTheme.primaryCyan, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
