import 'dart:ui';
import '../../widgets/app_snackbar.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

import '../../services/api_service.dart';
import '../../core/localization.dart';
import '../../widgets/cyber_grid_painter.dart';
import '../auth/login_screen.dart' hide CyberGridPainter;

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
  bool _passVisible = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _resetPassword() async {
    final code = _codeCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    if (code.isEmpty) {
      AppSnackbar.showInfo(context, AppLocalization.get('invalid_code'));
      return;
    }
    if (password.isEmpty) {
      AppSnackbar.showInfo(context, AppLocalization.get('enter_password'));
      return;
    }
    
    if (password.length < 6) {
      AppSnackbar.showInfo(context, AppLocalization.get('password_too_short'));
      return;
    }
    
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.resetPassword(
         widget.email, code, password
      );
      setState(() => _isLoading = false);
      if (!mounted) return;
      
      final bool isSuccess = res['success'] == true || 
          (res['msg'] != null && (res['msg'].contains('نجاح') || res['msg'].toLowerCase().contains('success') || res['msg'].toLowerCase().contains('updated')));
      
      if (isSuccess) {
         AppSnackbar.showSuccess(context, res['msg'] ?? AppLocalization.get('profile_updated'));
         Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
      } else {
         AppSnackbar.showError(context, res['msg'] ?? AppLocalization.get('invalid_code'));
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      AppSnackbar.showError(context, AppLocalization.get('request_reset_failed'));
    }
  }

  void _resendCode() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.forgotPassword(widget.email);
      setState(() => _isLoading = false);
      if (!mounted) return;
      
      final bool isSuccess = res['success'] == true || 
          (res['msg'] != null && (res['msg'].contains('تم إرسال') || res['msg'].toLowerCase().contains('sent') || res['msg'].toLowerCase().contains('success')));
      
      if (isSuccess) {
         AppSnackbar.showSuccess(context, res['msg'] ?? AppLocalization.get('code_resent'));
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
                        Icon(Icons.lock_reset, size: 64, color: AppTheme.primaryViolet),
                        const SizedBox(height: 16),
                        Text(
                          isAr 
                            ? 'لقد أرسلنا رمزًا مكونًا من 6 أرقام إلى\n${widget.email}'
                            : 'We sent a 6-digit code to\n${widget.email}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70, height: 1.4),
                        ),
                        const SizedBox(height: 32),
                        TextField(
                          controller: _codeCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 8),
                          textAlign: TextAlign.center,
                          decoration: AppTheme.inputDecoration(
                            labelText: isAr ? 'رمز التحقق' : 'Verification Code',
                            prefixIcon: Icons.security,
                          ).copyWith(
                            counterText: "",
                            hintText: '000000',
                            hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 8),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _passwordCtrl,
                          obscureText: !_passVisible,
                          style: const TextStyle(color: Colors.white),
                          decoration: AppTheme.inputDecoration(
                            labelText: isAr ? 'كلمة المرور الجديدة' : 'New Password',
                            prefixIcon: Icons.lock,
                            suffixIcon: IconButton(
                              icon: Icon(_passVisible ? Icons.visibility : Icons.visibility_off, color: Colors.white54),
                              onPressed: () => setState(() => _passVisible = !_passVisible),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isAr ? 'لم يصلك الرمز؟' : 'Didn\'t receive code?',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                            ),
                            TextButton(
                              onPressed: _isLoading ? null : _resendCode,
                              child: Text(
                                AppLocalization.get('resend_code'),
                                style: TextStyle(color: AppTheme.primaryCyan, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _resetPassword,
                            child: _isLoading 
                                ? const CircularProgressIndicator(color: Colors.white) 
                                : Text(isAr ? 'تحديث كلمة المرور' : 'Update Password', style: const TextStyle(color: Colors.white, fontSize: 16)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                              (r) => false,
                            );
                          },
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

