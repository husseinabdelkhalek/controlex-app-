import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/api_service.dart';
import '../core/localization.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/glass_popups.dart';
import '../theme/app_theme.dart';
import '../widgets/premium_app_bar.dart';
import '../widgets/glowing_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameCtrl = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passCtrl     = TextEditingController();
  final _realPassCtrl = TextEditingController();
  final _aioUserCtrl  = TextEditingController();
  final _aioKeyCtrl   = TextEditingController();
  final _firebaseUrlCtrl = TextEditingController();
  final _firebaseSecretCtrl = TextEditingController();
  final _setupCodeCtrl = TextEditingController();

  // Sub-Admin State
  bool _isSubAdmin = false;
  String? _subAdminPromoCode;
  Timer? _debounceTimer;
  bool _realPassVisible = false;

  // Linked Client State
  bool _isLinkedToSubAdmin = false;
  String? _parentAdminCode;
  String? _parentAdminName;

  // Setup Code Verification State
  bool _isSetupCodeChecking = false;
  bool? _isSetupCodeValid;
  int _setupCodeWidgetsCount = 0;
  Timer? _setupCodeDebounce;

  void _onLangChange() => setState(() {});

  @override
  void initState() {
    super.initState();
    AppLocalization.isArabicNotifier.addListener(_onLangChange);
    _passCtrl.addListener(_onPasswordChanged);
    _setupCodeCtrl.addListener(_onSetupCodeChanged);
  }

  @override
  void dispose() {
    AppLocalization.isArabicNotifier.removeListener(_onLangChange);
    _passCtrl.removeListener(_onPasswordChanged);
    _setupCodeCtrl.removeListener(_onSetupCodeChanged);
    _debounceTimer?.cancel();
    _setupCodeDebounce?.cancel();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _realPassCtrl.dispose();
    _aioUserCtrl.dispose();
    _aioKeyCtrl.dispose();
    _firebaseUrlCtrl.dispose();
    _firebaseSecretCtrl.dispose();
    _setupCodeCtrl.dispose();
    super.dispose();
  }

  void _onSetupCodeChanged() {
    final text = _setupCodeCtrl.text.trim().toUpperCase();
    if (text.isEmpty) {
      setState(() {
        _isSetupCodeValid = null;
        _isSetupCodeChecking = false;
        _setupCodeWidgetsCount = 0;
      });
      return;
    }

    if (_setupCodeDebounce?.isActive ?? false) _setupCodeDebounce!.cancel();
    _setupCodeDebounce = Timer(const Duration(milliseconds: 600), () async {
      if (text.length >= 9) {
        setState(() {
          _isSetupCodeChecking = true;
          _isSetupCodeValid = null;
        });
        try {
          final result = await ApiService.verifySetupCode(text);
          setState(() {
            _isSetupCodeChecking = false;
            _isSetupCodeValid = result['valid'] == true;
            _setupCodeWidgetsCount = result['widgetCount'] ?? 0;
          });
        } catch (_) {
          setState(() {
            _isSetupCodeChecking = false;
            _isSetupCodeValid = false;
            _setupCodeWidgetsCount = 0;
          });
        }
      } else {
        setState(() {
          _isSetupCodeValid = null;
          _isSetupCodeChecking = false;
        });
      }
    });
  }

  void _onPasswordChanged() {
    final text = _passCtrl.text.trim();
    if (text.isEmpty) {
      if (_isSubAdmin || _isLinkedToSubAdmin) {
        setState(() {
          _isSubAdmin = false;
          _subAdminPromoCode = null;
          _isLinkedToSubAdmin = false;
          _parentAdminCode = null;
          _parentAdminName = null;
        });
      }
      return;
    }

    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 600), () async {
      if (text.length >= 6) {
        try {
          final result = await ApiService.verifySubAdminCode(text);
          if (result['valid'] == true) {
            final name = result['name'] as String? ?? 'الموزع';
            final type = result['type'] as String? ?? '';
            if (type == 'sub_admin') {
              setState(() {
                _isSubAdmin = true;
                _subAdminPromoCode = text;
                _isLinkedToSubAdmin = false;
                _parentAdminCode = null;
                _parentAdminName = null;
              });
            } else {
              // merchant_client — link as client under this distributor
              setState(() {
                _isSubAdmin = false;
                _subAdminPromoCode = null;
                _isLinkedToSubAdmin = true;
                _parentAdminCode = text;
                _parentAdminName = name;
              });
            }
            if (mounted) {
              AppSnackbar.showSuccess(
                context,
                AppLocalization.isArabicNotifier.value
                    ? 'تم التعرف على الموزع: $name'
                    : 'Distributor recognized: $name',
              );
            }
          } else {
            // Reset states if code is invalid (silent fail)
            setState(() {
              _isSubAdmin = false;
              _subAdminPromoCode = null;
              _isLinkedToSubAdmin = false;
              _parentAdminCode = null;
              _parentAdminName = null;
            });
          }
        } catch (_) {
          // Reset states on error (silent fail)
          setState(() {
            _isSubAdmin = false;
            _subAdminPromoCode = null;
            _isLinkedToSubAdmin = false;
            _parentAdminCode = null;
            _parentAdminName = null;
          });
        }
      } else {
        // Reset states if length is less than 6
        setState(() {
          _isSubAdmin = false;
          _subAdminPromoCode = null;
          _isLinkedToSubAdmin = false;
          _parentAdminCode = null;
          _parentAdminName = null;
        });
      }
    });
  }


  bool _isLoading = false;
  bool _passVisible = false;

  InputDecoration _inputDec(String label, String hint, IconData icon, {bool isPassword = false, Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24, fontSize: 11),
      prefixIcon: Icon(icon, color: AppTheme.primaryCyan, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.03),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppTheme.primaryViolet.withValues(alpha: 0.2), width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppTheme.primaryCyan, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  void _handleRegister() async {
    final email = _emailCtrl.text.trim();
    final username = _usernameCtrl.text.trim();
    final passwordKey = _passCtrl.text.trim();
    final realPassword = _realPassCtrl.text.trim();

    if (username.isEmpty || email.isEmpty || passwordKey.isEmpty) {
      AppSnackbar.showWarning(
        context,
        AppLocalization.isArabicNotifier.value ? 'جميع الحقول الأساسية مطلوبة' : 'All basic fields are required',
      );
      return;
    }

    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      AppSnackbar.showWarning(
        context,
        AppLocalization.isArabicNotifier.value ? 'يرجى إدخال بريد إلكتروني صحيح' : 'Please enter a valid email address',
      );
      return;
    }

    // Determine final password to submit
    final finalPassword = _isSubAdmin ? realPassword : passwordKey;
    if (finalPassword.isEmpty) {
      AppSnackbar.showWarning(
        context,
        AppLocalization.isArabicNotifier.value ? 'يرجى تعيين كلمة المرور لتأمين الحساب' : 'Please set a secure account password',
      );
      return;
    }

    if (finalPassword.length < 6) {
      AppSnackbar.showWarning(
        context,
        AppLocalization.isArabicNotifier.value ? 'كلمة المرور يجب أن تكون 6 أحرف على الأقل' : 'Password must be at least 6 characters long',
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final res = await ApiService.register(
        username,
        email,
        finalPassword,
        adafruitUsername: _aioUserCtrl.text.trim(),
        adafruitApiKey: _aioKeyCtrl.text.trim(),
        firebaseUrl: _firebaseUrlCtrl.text.trim(),
        firebaseSecret: _firebaseSecretCtrl.text.trim(),
        subAdminPromoCode: _isSubAdmin ? _subAdminPromoCode : null,
        parentAdminCode: _isLinkedToSubAdmin ? _parentAdminCode : null,
        setupCode: _setupCodeCtrl.text.trim(),
      );
      setState(() => _isLoading = false);

      final msg = res['msg'] ?? '';
      if (msg.contains('نجاح') || res['id'] != null) {
        if (mounted) {
          AppSnackbar.showSuccess(
            context,
            AppLocalization.isArabicNotifier.value ? 'تم إنشاء الحساب بنجاح! سجل دخولك الآن.' : 'Account created successfully! Log in now.',
          );
          Navigator.pop(context);
        }
      } else {
        if (mounted) AppSnackbar.showError(context, msg.isNotEmpty ? msg : 'فشل التسجيل');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) AppSnackbar.showError(context, e);
    }
  }

  Widget _sectionHeader(String text) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 8),
    child: Text(text, style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
  );

  void _showJoinSubAdminDialog() {
    showGlassModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _JoinSubAdminChoiceSheet(
        onChoiceSelected: (isQr) {
          Navigator.pop(context); // Close the choice sheet
          // Show the actual verification sheet with the chosen active tab!
          showGlassModalBottomSheet(
            context: this.context,
            isScrollControlled: true,
            builder: (context) => _JoinSubAdminSheet(
              initialTab: isQr ? 0 : 1,
              onCodeVerified: (code, merchantName) {
                setState(() {
                  _isLinkedToSubAdmin = true;
                  _parentAdminCode = code;
                  _parentAdminName = merchantName;
                });
                AppSnackbar.showSuccess(
                  this.context,
                  AppLocalization.isArabicNotifier.value
                      ? 'تم التحقق بنجاح! تم ربط حسابك بالموزع، يرجى إكمال تسجيل حسابك بالأسفل.'
                      : 'Verified successfully! Linked to distributor, please complete your registration below.',
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildMerchantLinkStatusCard() {
    if (_isLinkedToSubAdmin) {
      return Container(
        margin: const EdgeInsets.only(top: 14),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF00FFCC).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF00FFCC).withValues(alpha: 0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00FFCC).withValues(alpha: 0.05),
              blurRadius: 10,
            )
          ]
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00FFCC).withValues(alpha: 0.15),
              ),
              child: const Icon(Icons.verified, color: Color(0xFF00FFCC), size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalization.isArabicNotifier.value ? 'ربط الحساب بالمشرف الجانبي' : 'Linked to Sub-Admin Distributor',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _parentAdminName ?? '',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.cancel, color: Colors.redAccent, size: 20),
              onPressed: () {
                setState(() {
                  _isLinkedToSubAdmin = false;
                  _parentAdminCode = null;
                  _parentAdminName = null;
                });
                AppSnackbar.showInfo(
                  context,
                  AppLocalization.isArabicNotifier.value ? 'تم إلغاء ربط الحساب بالموزع' : 'Unlinked from distributor successfully',
                );
              },
            )
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AppLocalization.isArabicNotifier.value ? 'هل تود التسجيل كعميل تابع لموزع؟' : 'Are you registering as a client of a merchant?',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF00FFCC),
              side: const BorderSide(color: Color(0xFF00FFCC), width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.qr_code_scanner, size: 18),
            label: Text(
              AppLocalization.isArabicNotifier.value ? 'مسح QR أو إدخال كود الموزع' : 'Scan QR or Enter Distributor Code',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            onPressed: _showJoinSubAdminDialog,
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleText = AppLocalization.isArabicNotifier.value ? 'إنشاء حساب جديد' : 'Create New Account';
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundBase,
      appBar: PremiumAppBar(
        titleText: titleText,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
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
          
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.person_add, size: 60, color: AppTheme.primaryCyan),
                const SizedBox(height: 8),
                Text(
                  AppLocalization.isArabicNotifier.value ? 'أنشئ حسابك الآن' : 'Create Your Account',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                Text(
                  AppLocalization.isArabicNotifier.value ? 'أدخل بياناتك للبدء في رحلتك الذكية' : 'Input your details to start your smart journey',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
                
                _sectionHeader(AppLocalization.isArabicNotifier.value ? 'المعلومات الأساسية' : 'Primary Information'),
                TextField(
                  controller: _usernameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDec(
                    AppLocalization.isArabicNotifier.value ? 'اسم المستخدم' : 'Username',
                    AppLocalization.isArabicNotifier.value ? 'أدخل اسم المستخدم الخاص بك' : 'Enter your username',
                    Icons.person_outline,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDec(
                    AppLocalization.isArabicNotifier.value ? 'البريد الإلكتروني' : 'Email Address',
                    AppLocalization.isArabicNotifier.value ? 'أدخل بريدك الإلكتروني' : 'Enter your email',
                    Icons.email_outlined,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Password input (with promo key check auto-trigger)
                TextField(
                  controller: _passCtrl,
                  obscureText: !_isSubAdmin && !_passVisible,
                  readOnly: _isSubAdmin,
                  style: TextStyle(color: _isSubAdmin ? AppTheme.primaryCyan : Colors.white),
                  decoration: _inputDec(
                    _isSubAdmin
                        ? (AppLocalization.isArabicNotifier.value ? 'كود الأدمن الجانبي المعتمد' : 'Verified Sub-Admin Promo Code')
                        : (AppLocalization.isArabicNotifier.value ? 'كلمة المرور / كود الموزع' : 'Password / Activation Code'),
                    AppLocalization.isArabicNotifier.value
                        ? 'أدخل كلمة المرور (أو كود التاجر للتسجيل كأدمن)'
                        : 'Enter password (or promo code to sign up as admin)',
                    _isSubAdmin ? Icons.verified_user_rounded : Icons.lock_outline,
                    suffix: _isSubAdmin
                        ? IconButton(
                            icon: const Icon(Icons.edit, color: AppTheme.primaryCyan),
                            onPressed: () {
                              setState(() {
                                _isSubAdmin = false;
                                _subAdminPromoCode = null;
                                _passCtrl.clear();
                                _realPassCtrl.clear();
                              });
                            },
                          )
                        : IconButton(
                            icon: Icon(_passVisible ? Icons.visibility : Icons.visibility_off, color: Colors.white54),
                            onPressed: () => setState(() => _passVisible = !_passVisible),
                          ),
                  ),
                ),
                
                // Sub-admin secondary real password (also shown when linking as merchant client)
                if (_isSubAdmin || _isLinkedToSubAdmin) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _realPassCtrl,
                    obscureText: !_realPassVisible,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDec(
                      AppLocalization.isArabicNotifier.value
                          ? (_isSubAdmin ? 'كلمة المرور الحقيقية للأدمن' : 'كلمة مرور الحساب الخاص بك')
                          : (_isSubAdmin ? 'Set Your Real Password' : 'Set Your Account Password'),
                      AppLocalization.isArabicNotifier.value ? 'عين كلمة مرور لتأمين حسابك' : 'Choose a secure password for your account',
                      Icons.lock_outline,
                      suffix: IconButton(
                        icon: Icon(_realPassVisible ? Icons.visibility : Icons.visibility_off, color: Colors.white54),
                        onPressed: () => setState(() => _realPassVisible = !_realPassVisible),
                      ),
                    ),
                  ),
  
                ],
  
                // Setup code field (Optional)
                if (!_isSubAdmin) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _setupCodeCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDec(
                      AppLocalization.isArabicNotifier.value ? 'كود إعداد الجهاز (اختياري)' : 'Device Setup Code (Optional)',
                      AppLocalization.isArabicNotifier.value ? 'أدخل كود CX-XXXXXX الممنوح لك' : 'Enter CX-XXXXXX setup code if you have one',
                      Icons.developer_board,
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                  if (_isSetupCodeChecking)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0, left: 4, right: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryCyan),
                          ),
                          SizedBox(width: 8),
                          Text('جاري التحقق...', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    )
                  else if (_isSetupCodeValid != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, left: 4, right: 4),
                      child: Text(
                        _isSetupCodeValid!
                            ? (AppLocalization.isArabicNotifier.value 
                                ? 'كود تفعيل صالح — يحتوي على $_setupCodeWidgetsCount من الأدوات' 
                                : 'Valid setup code — contains $_setupCodeWidgetsCount widgets')
                            : (AppLocalization.isArabicNotifier.value 
                                ? 'كود تفعيل غير صالح أو مستخدم' 
                                : 'Invalid or used setup code'),
                        style: TextStyle(
                          color: _isSetupCodeValid! ? AppTheme.primaryCyan : Colors.redAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
  
                // Distributor linkage panel
                if (!_isSubAdmin) _buildMerchantLinkStatusCard(),
  
                _sectionHeader('ADAFRUIT IO — ' + (AppLocalization.isArabicNotifier.value ? 'اختياري' : 'Optional')),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.glassBorder.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalization.isArabicNotifier.value
                            ? 'للتحكم بالأجهزة واللمبات الذكية عبر Adafruit IO (يمكن إضافتها لاحقاً)'
                            : 'To control smart devices via Adafruit IO (can be added later)',
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _aioUserCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDec(
                          AppLocalization.isArabicNotifier.value ? 'اسم مستخدم Adafruit' : 'Adafruit IO Username',
                          'Adafruit IO username',
                          Icons.cloud_circle_outlined,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _aioKeyCtrl,
                        obscureText: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDec(
                          AppLocalization.isArabicNotifier.value ? 'مفتاح Adafruit API' : 'Adafruit IO AIO Key',
                          'Adafruit AIO key',
                          Icons.vpn_key_outlined,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _sectionHeader('FIREBASE RTDB - ' + (AppLocalization.isArabicNotifier.value ? 'اختياري' : 'Optional')),
                      Container(
                        margin: const EdgeInsets.only(top: 8, bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocalization.isArabicNotifier.value
                                  ? 'للتحكم في الأجهزة الاحترافية عبر Firebase (يمكن إضافته لاحقاً)'
                                  : 'To control smart devices via Firebase RTDB (can be added later)',
                              style: const TextStyle(color: Colors.white38, fontSize: 11),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _firebaseUrlCtrl,
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDec(
                                AppLocalization.get('firebase_db_url'),
                                'https://your-project.firebaseio.com/',
                                Icons.link,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _firebaseSecretCtrl,
                              obscureText: true,
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDec(
                                AppLocalization.get('firebase_secret'),
                                'Firebase Secret Key',
                                Icons.security,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
  
                const SizedBox(height: 32),
                GlowingButton(
                  onPressed: _isLoading ? null : _handleRegister,
                  isLoading: _isLoading,
                  height: 55,
                  borderRadius: 16,
                  child: Text(
                    AppLocalization.isArabicNotifier.value ? 'إنشاء الحساب' : 'Create Account',
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Beautiful Choice Prompt Sheet for QR vs Manual
class _JoinSubAdminChoiceSheet extends StatelessWidget {
  final Function(bool isQr) onChoiceSelected;

  const _JoinSubAdminChoiceSheet({required this.onChoiceSelected});

  @override
  Widget build(BuildContext context) {
    final ar = AppLocalization.isArabicNotifier.value;
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1319).withValues(alpha: 0.65),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          border: Border.all(color: Colors.white10, width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 45,
                height: 5,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 24),
            Icon(Icons.supervised_user_circle, size: 50, color: const Color(0xFF00FFCC)),
            const SizedBox(height: 16),
            Text(
              ar ? 'الانضمام لموزع معتمد' : 'Join a Distributor',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              ar 
                  ? 'حابب تعمل اسكان لل QR كود ولا تحط الكود يدوي؟' 
                  : 'Would you like to scan the QR code or enter the code manually?',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 28),
            
            // Scan QR Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FFCC).withValues(alpha: 0.15),
                foregroundColor: const Color(0xFF00FFCC),
                side: const BorderSide(color: Color(0xFF00FFCC), width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => onChoiceSelected(true),
              icon: const Icon(Icons.qr_code_scanner, size: 20),
              label: Text(
                ar ? 'مسح رمز الـ QR (الكاميرا)' : 'Scan QR Code (Camera)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            const SizedBox(height: 14),
            
            // Manual Code Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                foregroundColor: const Color(0xFF00E5FF),
                side: const BorderSide(color: Color(0xFF00E5FF), width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => onChoiceSelected(false),
              icon: const Icon(Icons.keyboard_outlined, size: 20),
              label: Text(
                ar ? 'كتابة الكود يدوياً' : 'Enter Code Manually',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

// Beautiful Glass Invites & Simulated QR Scanner Sheet
class _JoinSubAdminSheet extends StatefulWidget {
  final int initialTab;
  final Function(String code, String merchantName) onCodeVerified;

  const _JoinSubAdminSheet({required this.onCodeVerified, this.initialTab = 0});

  @override
  State<_JoinSubAdminSheet> createState() => _JoinSubAdminSheetState();
}

class _JoinSubAdminSheetState extends State<_JoinSubAdminSheet> with SingleTickerProviderStateMixin {
  late AnimationController _scannerLaserCtrl;
  late int _activeTab;
  final _codeCtrl = TextEditingController();
  bool _isChecking = false;
  String? _errorMessage;

  bool _cameraPermissionGranted = false;
  bool _hasCheckedPermission = false;
  MobileScannerController? _scannerController;
  bool _isScanned = false;

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
    _scannerLaserCtrl = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _checkCameraPermission();
  }

  void _checkCameraPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted) {
      if (mounted) {
        setState(() {
          _cameraPermissionGranted = true;
          _hasCheckedPermission = true;
          _scannerController = MobileScannerController(
            detectionSpeed: DetectionSpeed.noDuplicates,
            facing: CameraFacing.back,
          );
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _hasCheckedPermission = true;
        });
      }
    }
  }

  void _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      if (mounted) {
        setState(() {
          _cameraPermissionGranted = true;
          _scannerController = MobileScannerController(
            detectionSpeed: DetectionSpeed.noDuplicates,
            facing: CameraFacing.back,
          );
        });
      }
    } else {
      if (mounted) {
        AppSnackbar.showWarning(
          context,
          AppLocalization.isArabicNotifier.value
              ? 'يرجى تفعيل صلاحية الكاميرا من إعدادات الهاتف لمسح الـ QR.'
              : 'Please grant camera permissions in settings to scan QR.',
        );
      }
    }
  }

  @override
  void dispose() {
    _scannerLaserCtrl.dispose();
    _codeCtrl.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  void _verifyCode(String code) async {
    if (code.trim().isEmpty) return;
    setState(() {
      _isChecking = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiService.verifyMerchantClientCode(code.trim());
      setState(() => _isChecking = false);
      if (res['valid'] == true) {
        widget.onCodeVerified(code.trim(), res['merchantName'] ?? 'الموزع المعتمد');
        Navigator.pop(context);
      } else {
        setState(() {
          _isScanned = false; // Reset to allow re-scan
          _errorMessage = AppLocalization.isArabicNotifier.value
              ? 'رمز الموزع غير صحيح أو غير مفعل!'
              : 'Invalid or deactivated distributor code!';
        });
      }
    } catch (_) {
      setState(() {
        _isChecking = false;
        _isScanned = false; // Reset to allow re-scan
        _errorMessage = AppLocalization.isArabicNotifier.value
            ? 'خطأ في الاتصال بالخادم. يرجى التحقق من الشبكة.'
            : 'Server communication error. Check your connection.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomOffset = mediaQuery.viewInsets.bottom;
    final ar = AppLocalization.isArabicNotifier.value;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Container(
        padding: EdgeInsets.fromLTRB(24, 20, 24, bottomOffset + 24),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1319).withValues(alpha: 0.65),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          border: Border.all(color: Colors.white10, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 30,
              spreadRadius: 5,
            )
          ]
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Center top handle drag line
            Center(
              child: Container(
                width: 45,
                height: 5,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  ar ? 'الاتصال بالموزع والمشرف' : 'Distributor Integration Console',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            const SizedBox(height: 10),
            Text(
              ar
                  ? 'اربط حسابك بالموزع الخاص بك لتحميل أدواتك المخصصة والسيناريوهات فورياً.'
                  : 'Link under your merchant to deploy pre-configured assets instantly.',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 20),
            
            // Neon Selector Tabs
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _activeTab = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _activeTab == 0 ? const Color(0xFF00FFCC).withValues(alpha: 0.1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _activeTab == 0 ? const Color(0xFF00FFCC) : Colors.transparent,
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.qr_code_scanner, color: _activeTab == 0 ? const Color(0xFF00FFCC) : Colors.white54, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            ar ? 'مسح QR كود' : 'Scan QR Code',
                            style: TextStyle(color: _activeTab == 0 ? const Color(0xFF00FFCC) : Colors.white70, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _activeTab = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _activeTab == 1 ? const Color(0xFF00FFCC).withValues(alpha: 0.1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _activeTab == 1 ? const Color(0xFF00FFCC) : Colors.transparent,
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.keyboard_outlined, color: _activeTab == 1 ? const Color(0xFF00FFCC) : Colors.white54, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            ar ? 'إدخال يدوي' : 'Enter Manually',
                            style: TextStyle(color: _activeTab == 1 ? const Color(0xFF00FFCC) : Colors.white70, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Tab Views
            if (_activeTab == 0) ...[
              if (!_hasCheckedPermission)
                const Center(
                  child: SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator(color: Color(0xFF00FFCC))),
                  ),
                )
              else if (!_cameraPermissionGranted)
                Center(
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white12, width: 1.5),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.camera_alt_outlined, color: Colors.white38, size: 40),
                        const SizedBox(height: 12),
                        Text(
                          ar ? 'مطلوب صلاحية الكاميرا لمسح الـ QR' : 'Camera permission required to scan QR',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white54, fontSize: 10),
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00FFCC),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          onPressed: _requestCameraPermission,
                          child: Text(ar ? 'سماح للكاميرا' : 'Allow Camera', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                  ),
                )
              else
                // Real Live Camera QR Scanner using mobile_scanner!
                Center(
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFF00FFCC).withValues(alpha: 0.4), width: 2),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          MobileScanner(
                            controller: _scannerController,
                            onDetect: (capture) {
                              if (_isScanned) return;
                              final List<Barcode> barcodes = capture.barcodes;
                              for (final barcode in barcodes) {
                                final rawVal = barcode.rawValue;
                                if (rawVal != null && rawVal.trim().isNotEmpty) {
                                  setState(() {
                                    _isScanned = true;
                                  });
                                  _verifyCode(rawVal.trim());
                                  break;
                                }
                              }
                            },
                          ),
                          
                          // Viewfinder corner marks
                          Positioned(top: 12, left: 12, child: Container(width: 20, height: 20, decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFF00FFCC), width: 3), left: BorderSide(color: Color(0xFF00FFCC), width: 3))))),
                          Positioned(top: 12, right: 12, child: Container(width: 20, height: 20, decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFF00FFCC), width: 3), right: BorderSide(color: Color(0xFF00FFCC), width: 3))))),
                          Positioned(bottom: 12, left: 12, child: Container(width: 20, height: 20, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF00FFCC), width: 3), left: BorderSide(color: Color(0xFF00FFCC), width: 3))))),
                          Positioned(bottom: 12, right: 12, child: Container(width: 20, height: 20, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF00FFCC), width: 3), right: BorderSide(color: Color(0xFF00FFCC), width: 3))))),
                          
                          // Animated scanning laser line
                          AnimatedBuilder(
                            animation: _scannerLaserCtrl,
                            builder: (context, child) {
                              return Positioned(
                                top: 24 + (152 * _scannerLaserCtrl.value),
                                left: 16,
                                right: 16,
                                child: Container(
                                  height: 3,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF00FFCC),
                                    boxShadow: [
                                      BoxShadow(color: Color(0xFF00FFCC), blurRadius: 10, spreadRadius: 1.5)
                                    ]
                                  ),
                                ),
                              );
                            },
                          ),
                          if (_isChecking)
                            Container(
                              color: Colors.black54,
                              child: const Center(
                                child: CircularProgressIndicator(color: Color(0xFF00FFCC)),
                              ),
                            )
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              
              if (_errorMessage != null) ...[
                Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 10),
              ],

            ] else ...[
              // Manual Code Input
              TextField(
                controller: _codeCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: ar ? 'رمز الموزع المعتمد' : 'Distributor Activation Code',
                  labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                  prefixIcon: const Icon(Icons.key, color: Colors.white54, size: 18),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white12)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF00FFCC))),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 10),
                Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
              const SizedBox(height: 20),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FFCC),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isChecking ? null : () => _verifyCode(_codeCtrl.text),
                  child: _isChecking
                      ? const CircularProgressIndicator(color: Colors.black)
                      : Text(ar ? 'تحقق وربط المجموعة' : 'Verify & Link Group', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ],
        ),
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

    canvas.drawLine(Offset(0, 0), Offset(size.width, size.height * 0.7), neonPaint);
    canvas.drawLine(Offset(size.width, 0), Offset(0, size.height * 0.7), neonPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
