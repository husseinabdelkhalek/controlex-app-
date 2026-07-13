import 'dart:ui';
import '../../widgets/app_snackbar.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../services/api_service.dart';
import '../../core/localization.dart';
import '../../widgets/cyber_grid_painter.dart';
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
    if (_codeCtrl.text.isEmpty) {
      AppSnackbar.showInfo(context, AppLocalization.get('invalid_code'));
      return;
    }
    
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
         AppSnackbar.showError(context, res['msg'] ?? AppLocalization.get('invalid_2fa'));
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      AppSnackbar.showError(context, AppLocalization.get('invalid_2fa'));
    }
  }

  void _resendCode() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.resend2FaCode(widget.email);
      setState(() => _isLoading = false);
      if (!mounted) return;
      
      final bool isSuccess = res['success'] == true || 
          (res['msg'] != null && (res['msg'].toLowerCase().contains('sent') || res['msg'].toLowerCase().contains('success') || res['msg'].contains('إرسال') || res['msg'].contains('أرسلنا')));
      
      if (isSuccess) {
         AppSnackbar.showSuccess(context, res['msg'] ?? AppLocalization.get('code_resent'));
      } else {
         AppSnackbar.showError(context, res['msg'] ?? AppLocalization.get('invalid_2fa'));
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
                        Icon(Icons.security, size: 64, color: AppTheme.primaryCyan),
                        const SizedBox(height: 16),
                        Text(
                          isAr 
                            ? 'يرجى إدخال الرمز المكون من 6 أرقام المرسل إلى\n${widget.email}'
                            : 'Please enter the 6-digit code sent to\n${widget.email}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70, height: 1.4),
                        ),
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
                          decoration: AppTheme.inputDecoration(
                            labelText: isAr ? 'رمز التحقق' : 'Verification Code',
                            prefixIcon: Icons.security,
                          ).copyWith(
                            counterText: "",
                            hintText: '000000',
                            hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 8),
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
                            onPressed: _isLoading ? null : _verifyCode,
                            child: _isLoading 
                                ? const CircularProgressIndicator(color: Colors.white) 
                                : Text(isAr ? 'التحقق وتسجيل الدخول' : 'Verify to Login', style: const TextStyle(color: Colors.white, fontSize: 16)),
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

