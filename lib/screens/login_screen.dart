import 'package:flutter/material.dart';
import 'register_screen.dart';
import 'dashboard_screen.dart';
import 'local_dashboard_screen.dart';
import 'forgot_password_screen.dart';
import 'verify_2fa_screen.dart';
import '../services/api_service.dart';
import 'complete_google_profile_screen.dart';
import '../core/localization.dart';
import '../theme/app_theme.dart';
import 'dart:ui';
import 'banned_screen.dart';


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
         if (mounted) ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('فشل الحصول على Firebase Token'))
         );
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
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['msg'] ?? 'تم إرسال رمز التحقق')));
             // Save the email we got from Google to use for verification
             _emailController.text = res['email'] ?? ''; 
             setState(() => _showOTPField = true);
           }
        } else {
          final errMsg = res['msg'] ?? 'فشل تسجيل الدخول بجوجل';
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errMsg), duration: const Duration(seconds: 4))
          );
       }
     } catch(e) {
       setState(() => _isLoading = false);
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('فشل تسجيل الدخول بجوجل'), duration: Duration(seconds: 4))
       );
     }
  }

  void _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) return;

    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال بريد إلكتروني صحيح'))
      );
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
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['msg'] ?? 'تم إرسال رمز التحقق')));
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
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['msg'] ?? AppLocalization.get('login_failed'))));
      }
    } catch (e) {
      if (mounted) {
         setState(() => _isLoading = false);
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalization.get('network_error'))));
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
           if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['msg'] ?? 'الرمز غير صحيح')));
        }
     } catch (e) {
        if (mounted) {
           setState(() => _isLoading = false);
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل التحقق: $e')));
        }
     }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(color: AppTheme.backgroundBase),
          Positioned(
            top: -50,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryViolet.withOpacity(0.2),
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
                color: AppTheme.primaryCyan.withOpacity(0.15),
              ),
              child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container()),
            ),
          ),
          Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.dashboard_customize, size: 80, color: Color(0xFF00FFCC)),
                const SizedBox(height: 24),
                Text(AppLocalization.get('login_title'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(AppLocalization.get('login_subtitle'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 16)),
                const SizedBox(height: 48),
                if (!_showOTPField) ...[
                  TextField(
                    controller: _emailController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: AppLocalization.get('email'),
                      labelStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(Icons.email, color: Colors.white54),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white24)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF00FFCC))),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: AppLocalization.get('password'),
                      labelStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(Icons.lock, color: Colors.white54),
                      suffixIcon: IconButton(
                         icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: Colors.white54),
                         onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                      ),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white24)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF00FFCC))),
                    ),
                    obscureText: !_isPasswordVisible,
                    onSubmitted: (_) => _handleLogin(),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                      child: Text(AppLocalization.get('forgot_password'), style: const TextStyle(color: Color(0xFF00FFCC))),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8A2BE2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isLoading ? null : _handleLogin,
                      child: _isLoading 
                          ? const CircularProgressIndicator(color: Colors.white) 
                          : Text(AppLocalization.get('login_btn'), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.g_mobiledata, size: 32, color: Colors.red),
                      label: Text(AppLocalization.get('google_btn'), style: const TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold)),
                      onPressed: _isLoading ? null : _googleAuth,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterScreen()));
                    },
                    child: Text(AppLocalization.get('no_account'), style: const TextStyle(color: Color(0xFF00FFCC))),
                  ),
                  const Divider(color: Colors.white12, height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orangeAccent,
                        side: const BorderSide(color: Colors.orangeAccent, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.wifi, size: 22),
                      label: const Text('التحكم المحلي / Local Control', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LocalDashboardScreen()));
                      },
                    ),
                  ),
                ] else ...[
                  const Icon(Icons.security, size: 64, color: Color(0xFF00FFCC)),
                  const SizedBox(height: 16),
                  const Text('أدخل رمز التحقق المرسل لبريدك', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 8),
                    maxLength: 6,
                    onChanged: (value) {
                      if (value.length == 6) {
                        _handleVerifyOTP();
                      }
                    },
                    decoration: InputDecoration(
                      counterText: "",
                      hintText: '000000',
                      hintStyle: const TextStyle(color: Colors.white24),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white24)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF00FFCC))),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8A2BE2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isLoading ? null : _handleVerifyOTP,
                      child: _isLoading 
                          ? const CircularProgressIndicator(color: Colors.white) 
                          : const Text('تحقق وادخل', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _showOTPField = false),
                    child: const Text('الغاء', style: TextStyle(color: Colors.white54)),
                  ),
                ],
              ],
            ),
          ),
        ),
        ],
      ),
    );
  }
}
