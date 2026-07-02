import '../../widgets/app_snackbar.dart';
import 'package:flutter/material.dart';
import '../auth/register_screen.dart';
import '../dashboard_screen.dart';
import '../local_dashboard_screen.dart';
import '../auth/forgot_password_screen.dart';
import '../../services/api_service.dart';
import '../auth/complete_google_profile_screen.dart';
import '../../core/localization.dart';
import '../../theme/app_theme.dart';
import 'dart:ui';
import '../status/banned_screen.dart';
import '../../widgets/glowing_button.dart';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _showOTPField = false;
  final TextEditingController _otpController = TextEditingController();

  void _onLangChange() => setState(() {});

  @override
  void initState() {
    super.initState();
    AppLocalization.isArabicNotifier.addListener(_onLangChange);
  }

  @override
  void dispose() {
    AppLocalization.isArabicNotifier.removeListener(_onLangChange);
    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _googleAuth() async {
     try {
       final googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
       final googleUser = await googleSignIn.signIn();
       if (googleUser == null) return; // User cancelled

       setState(() => _isLoading = true);

       // Step 1: Get Google Auth credentials
       final googleAuth = await googleUser.authentication;

       // Step 2: Sign into Firebase using Google credentials
       final credential = GoogleAuthProvider.credential(
         accessToken: googleAuth.accessToken,
         idToken: googleAuth.idToken,
       );
       final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

       // Step 3: Get the real Firebase ID Token
       final firebaseIdToken = await userCredential.user?.getIdToken();

       if (firebaseIdToken == null) {
         setState(() => _isLoading = false);
         if (mounted) AppSnackbar.showError(context, 'فشل الحصول على Firebase Token');
         return;
       }

       // Step 4: Send Firebase token to our backend
       final res = await ApiService.googleAuthMobile(firebaseIdToken);
       setState(() => _isLoading = false);

        if (res['token'] != null) {
           await ApiService.saveToken(res['token']);
           if (mounted) {
             final isNew = res['isNewUser'] == true;
             final username = res['user']?['username'] ?? '';
             Navigator.pushAndRemoveUntil(
               context,
               MaterialPageRoute(
                 builder: (context) => isNew
                     ? CompleteGoogleProfileScreen(username: username)
                     : const DashboardScreen(),
               ),
               (r) => false,
             );
           }
        } else if (res['twoFactorRequired'] == true) {
           if (mounted) {
             AppSnackbar.showSuccess(context, res['msg'] ?? 'تم إرسال رمز التحقق');
             // Save the email we got from Google to use for verification
             _emailController.text = res['email'] ?? ''; 
             setState(() => _showOTPField = true);
           }
        } else {
          final errMsg = res['msg'] ?? 'فشل تسجيل الدخول بجوجل';
          if (mounted) AppSnackbar.showInfo(context, errMsg);
       }
     } catch(e) {
       setState(() => _isLoading = false);
       if (mounted) AppSnackbar.showError(context, 'فشل تسجيل الدخول بجوجل');
     }
  }

  void _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) return;

    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      AppSnackbar.showInfo(context, 'يرجى إدخال بريد إلكتروني صحيح');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final res = await ApiService.login(email, password);
      if (mounted) setState(() => _isLoading = false);

      if (res['token'] != null) {
        await ApiService.saveToken(res['token']);
        if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const DashboardScreen()));
      } else if (res['twoFactorRequired'] == true) {
        if (mounted) {
           AppSnackbar.showSuccess(context, res['msg'] ?? 'تم إرسال رمز التحقق');
           setState(() => _showOTPField = true);
        }
      } else if (res['blocked'] == true) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BannedScreen(message: res['msg']),
            ),
          );
        }
      } else {
        if (mounted) AppSnackbar.showError(context, res['msg'] ?? AppLocalization.get('login_failed'));
      }
    } catch (e) {
      if (mounted) {
         setState(() => _isLoading = false);
         AppSnackbar.showError(context, AppLocalization.get('network_error'));
      }
    }
  }

  void _handleVerifyOTP() async {
     if (_otpController.text.isEmpty) return;
     setState(() => _isLoading = true);
     try {
        final res = await ApiService.verify2Fa(_emailController.text.trim(), _otpController.text.trim());
        if (mounted) setState(() => _isLoading = false);

        if (res['token'] != null) {
           await ApiService.saveToken(res['token']);
           if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const DashboardScreen()));
        } else {
           if (mounted) AppSnackbar.showInfo(context, res['msg'] ?? 'الرمز غير صحيح');
        }
     } catch (e) {
        if (mounted) {
           setState(() => _isLoading = false);
           AppSnackbar.showError(context, 'فشل التحقق: $e');
        }
     }
  }

  InputDecoration _buildInputDecoration(String label, IconData prefixIcon, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
      prefixIcon: Icon(prefixIcon, color: AppTheme.primaryCyan, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.03),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppTheme.primaryViolet.withValues(alpha: 0.2), width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppTheme.primaryCyan, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double topPadding = MediaQuery.of(context).padding.top;
    
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
                color: AppTheme.primaryViolet.withValues(alpha: 0.15),
              ),
              child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container()),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryCyan.withValues(alpha: 0.1),
              ),
              child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container()),
            ),
          ),
          
          // Main content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.rectangle,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppTheme.primaryCyan.withValues(alpha: 0.35),
                          width: 2.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryCyan.withValues(alpha: 0.25),
                            blurRadius: 20,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Image.asset(
                          'assets/icon/app_icon.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [AppTheme.primaryCyan, AppTheme.primaryViolet],
                    ).createShader(bounds),
                    child: Text(
                      AppLocalization.get('login_title'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    AppLocalization.get('login_subtitle'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
                  ),
                  SizedBox(height: 40),
                  
                  if (!_showOTPField) ...[
                    TextField(
                      controller: _emailController,
                      style: TextStyle(color: AppTheme.textPrimary),
                      decoration: _buildInputDecoration(
                        AppLocalization.get('email'),
                        Icons.email_outlined,
                      ),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      style: TextStyle(color: AppTheme.textPrimary),
                      decoration: _buildInputDecoration(
                        AppLocalization.get('password'),
                        Icons.lock_outline,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                            color: AppTheme.textSecondary,
                          ),
                          onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                        ),
                      ),
                      obscureText: !_isPasswordVisible,
                      onSubmitted: (_) => _handleLogin(),
                    ),
                    SizedBox(height: 12),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                        ),
                        child: Text(
                          AppLocalization.get('forgot_password'),
                          style: TextStyle(color: AppTheme.primaryCyan),
                        ),
                      ),
                    ),
                    SizedBox(height: 24),
                    GlowingButton(
                      onPressed: _handleLogin,
                      isLoading: _isLoading,
                      child: Text(AppLocalization.get('login_btn')),
                    ),
                    SizedBox(height: 16),
                    
                    // Side-by-side action buttons
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _isLoading ? null : _googleAuth,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              height: 50,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color: Colors.white.withValues(alpha: 0.03),
                                border: Border.all(color: AppTheme.glassBorder.withValues(alpha: 0.5)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.g_mobiledata, size: 28, color: Colors.redAccent),
                                  SizedBox(width: 4),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      AppLocalization.get('google_btn'),
                                      style: TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (_) => const LocalDashboardScreen()),
                              );
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              height: 50,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color: Colors.white.withValues(alpha: 0.03),
                                border: Border.all(color: AppTheme.glassBorder.withValues(alpha: 0.5)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.wifi, size: 18, color: Colors.orangeAccent),
                                  SizedBox(width: 6),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      'Local Control',
                                      style: TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 24),
                    Center(
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const RegisterScreen()),
                          );
                        },
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                            children: [
                              TextSpan(text: "${AppLocalization.get('no_account')} "),
                              TextSpan(
                                text: "Sign Up",
                                style: TextStyle(color: AppTheme.primaryCyan, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    Icon(Icons.security, size: 64, color: AppTheme.primaryCyan),
                    SizedBox(height: 16),
                    Text(
                      'أدخل رمز التحقق المرسل لبريدك',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                    SizedBox(height: 24),
                    TextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 24, letterSpacing: 8),
                      maxLength: 6,
                      onChanged: (value) {
                        if (value.length == 6) {
                          _handleVerifyOTP();
                        }
                      },
                      decoration: InputDecoration(
                        counterText: "",
                        hintText: '000000',
                        hintStyle: TextStyle(color: Colors.white24),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.white10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: AppTheme.primaryCyan),
                        ),
                      ),
                    ),
                    SizedBox(height: 24),
                    GlowingButton(
                      onPressed: _handleVerifyOTP,
                      isLoading: _isLoading,
                      child: Text('تحقق وادخل'),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _showOTPField = false),
                      child: Text('الغاء', style: TextStyle(color: AppTheme.textSecondary)),
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          // Floating language toggle
          Positioned(
            top: topPadding + 10,
            right: 20,
            child: InkWell(
              onTap: () {
                AppLocalization.isArabicNotifier.value = !AppLocalization.isArabicNotifier.value;
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.white.withValues(alpha: 0.03),
                  border: Border.all(color: AppTheme.glassBorder.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.language, size: 16, color: AppTheme.primaryCyan),
                    SizedBox(width: 6),
                    Text(
                      AppLocalization.isArabicNotifier.value ? "EN" : "العربية",
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CyberGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primaryViolet.withValues(alpha: 0.06)
      ..strokeWidth = 1.0;

    const double step = 25.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Add glowing diagonal lines
    final neonPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          AppTheme.primaryCyan.withValues(alpha: 0.15),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..strokeWidth = 1.5;

    canvas.drawLine(const Offset(0, 0), Offset(size.width, size.height * 0.7), neonPaint);
    canvas.drawLine(Offset(size.width, 0), Offset(0, size.height * 0.7), neonPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

