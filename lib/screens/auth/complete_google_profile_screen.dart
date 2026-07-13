import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/api_service.dart';
import '../dashboard_screen.dart';
import '../../core/localization.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/glass_popups.dart';
import '../../theme/app_theme.dart';
import '../../widgets/premium_app_bar.dart';
import '../../widgets/glowing_button.dart';
import '../../widgets/cyber_grid_painter.dart';

/// Shown after first Google Sign-In to collect missing profile data
class CompleteGoogleProfileScreen extends StatefulWidget {
  final String username;
  const CompleteGoogleProfileScreen({super.key, required this.username});

  @override
  State<CompleteGoogleProfileScreen> createState() => _CompleteGoogleProfileScreenState();
}

class _CompleteGoogleProfileScreenState extends State<CompleteGoogleProfileScreen> {
  final _aioUserCtrl = TextEditingController();
  final _aioKeyCtrl  = TextEditingController();
  final _firebaseUrlCtrl = TextEditingController();
  final _firebaseSecretCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _setupCodeCtrl = TextEditingController(); // Stores the setup code
  final _subAdminPromoCodeCtrl = TextEditingController();

  bool _isLoading = false;
  bool _passVisible = false;

  // Setup Code Verification State (stored from the dialog)
  bool? _isSetupCodeValid;
  int _setupCodeWidgetsCount = 0;

  // Distributor Referral State
  bool _isLinkedToSubAdmin = false;
  String? _parentAdminCode;
  String? _parentAdminName;

  // Distributor Selection State:
  // 0: None, 1: Linked to a Distributor (تبع موزع), 2: Become a Distributor (عايز أبقى موزع)
  int _distributorMode = 0;

  void _onLangChange() => setState(() {});

  @override
  void initState() {
    super.initState();
    AppLocalization.isArabicNotifier.addListener(_onLangChange);
  }

  @override
  void dispose() {
    AppLocalization.isArabicNotifier.removeListener(_onLangChange);
    _aioUserCtrl.dispose();
    _aioKeyCtrl.dispose();
    _firebaseUrlCtrl.dispose();
    _firebaseSecretCtrl.dispose();
    _passwordCtrl.dispose();
    _setupCodeCtrl.dispose();
    _subAdminPromoCodeCtrl.dispose();
    super.dispose();
  }

  void _save() async {
    final password = _passwordCtrl.text.trim();
    if (password.isEmpty || password.length < 6) {
      AppSnackbar.showWarning(
        context,
        AppLocalization.isArabicNotifier.value 
            ? 'يرجى تعيين كلمة مرور لتأمين الحساب (6 أحرف على الأقل)' 
            : 'Please set a secure account password (at least 6 characters long)',
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final res = await ApiService.completeGoogleSignup(
        password: password,
        adafruitUsername: _aioUserCtrl.text.trim(),
        adafruitApiKey: _aioKeyCtrl.text.trim(),
        firebaseUrl: _firebaseUrlCtrl.text.trim(),
        firebaseSecret: _firebaseSecretCtrl.text.trim(),
        parentAdminCode: (_distributorMode == 1 && _isLinkedToSubAdmin) ? _parentAdminCode : null,
        subAdminPromoCode: (_distributorMode == 2) ? _subAdminPromoCodeCtrl.text.trim() : null,
        setupCode: _setupCodeCtrl.text.trim(),
      );
      setState(() => _isLoading = false);

      final msg = res['msg'] ?? '';
      if (msg.contains('نجاح') || res['id'] != null || res['success'] == true) {
        if (mounted) {
          AppSnackbar.showSuccess(
            context,
            AppLocalization.isArabicNotifier.value 
                ? 'تم إكمال الملف الشخصي بنجاح!' 
                : 'Profile completed successfully!',
          );
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const DashboardScreen()),
            (r) => false,
          );
        }
      } else {
        if (mounted) AppSnackbar.showError(context, msg.isNotEmpty ? msg : 'فشل حفظ البيانات');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) AppSnackbar.showError(context, e.toString());
    }
  }

  void _skip() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
      (r) => false,
    );
  }



  Widget _sectionHeader(String text) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 8),
    child: Text(text, style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
  );

  void _showJoinSubAdminDialog() {
    showGlassModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _JoinSubAdminChoiceSheet(
        onChoiceSelected: (isQr) {
          Navigator.pop(context); // Close the choice sheet
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
                      ? 'تم التحقق بنجاح! تم ربط حسابك بالموزع.'
                      : 'Verified successfully! Linked to distributor.',
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _showAddDeviceDialog() {
    final isAr = AppLocalization.isArabicNotifier.value;
    final dialogCodeCtrl = TextEditingController(text: _setupCodeCtrl.text);
    bool isChecking = false;
    bool? isValid;
    int widgetCount = 0;
    Timer? dialogDebounce;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void onCodeChanged() {
              final text = dialogCodeCtrl.text.trim().toUpperCase();
              if (text.isEmpty) {
                setDialogState(() {
                  isValid = null;
                  isChecking = false;
                  widgetCount = 0;
                });
                return;
              }

              if (dialogDebounce?.isActive ?? false) dialogDebounce!.cancel();
              dialogDebounce = Timer(const Duration(milliseconds: 600), () async {
                if (text.length >= 9) {
                  setDialogState(() {
                    isChecking = true;
                    isValid = null;
                  });
                  try {
                    final result = await ApiService.verifySetupCode(text);
                    setDialogState(() {
                      isChecking = false;
                      isValid = result['valid'] == true;
                      widgetCount = result['widgetCount'] ?? 0;
                    });
                  } catch (_) {
                    setDialogState(() {
                      isChecking = false;
                      isValid = false;
                      widgetCount = 0;
                    });
                  }
                } else {
                  setDialogState(() {
                    isValid = null;
                    isChecking = false;
                  });
                }
              });
            }

            return AlertDialog(
              backgroundColor: AppTheme.cardBaseColor.withValues(alpha: 0.95),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: AppTheme.glassBorder, width: 1.5),
              ),
              title: Row(
                children: [
                  Icon(Icons.developer_board, color: AppTheme.primaryCyan, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    isAr ? 'إضافة جهاز جديد' : 'Add New Device',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    isAr 
                        ? 'أدخل كود إعداد الجهاز الخاص بك للربط التلقائي.' 
                        : 'Enter your device setup code to automatically link it.',
                    style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: dialogCodeCtrl,
                    onChanged: (_) => onCodeChanged(),
                    style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 16, letterSpacing: 2),
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: isAr ? 'كود إعداد الجهاز' : 'Device Setup Code',
                      labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                      hintText: 'CX-XXXXXX',
                      hintStyle: const TextStyle(color: Colors.white24),
                      prefixIcon: const Icon(Icons.key, color: Colors.white54),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white24)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.primaryCyan)),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.02),
                    ),
                  ),
                  if (isChecking)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, left: 4, right: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryCyan),
                          ),
                          const SizedBox(width: 8),
                          Text(isAr ? 'جاري التحقق...' : 'Checking...', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    )
                  else if (isValid != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, left: 4, right: 4),
                      child: Text(
                        isValid!
                            ? (isAr 
                                ? 'كود تفعيل صالح — يحتوي على $widgetCount من الأدوات' 
                                : 'Valid setup code — contains $widgetCount widgets')
                            : (isAr 
                                ? 'كود تفعيل غير صالح أو مستخدم' 
                                : 'Invalid or used setup code'),
                        style: TextStyle(
                          color: isValid! ? AppTheme.primaryCyan : Colors.redAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    dialogDebounce?.cancel();
                    Navigator.pop(context);
                  },
                  child: Text(isAr ? 'إلغاء' : 'Cancel', style: const TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryCyan,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: (isValid == true) ? () {
                    setState(() {
                      _setupCodeCtrl.text = dialogCodeCtrl.text.trim().toUpperCase();
                      _isSetupCodeValid = true;
                      _setupCodeWidgetsCount = widgetCount;
                    });
                    dialogDebounce?.cancel();
                    Navigator.pop(context);
                  } : null,
                  child: Text(isAr ? 'إضافة' : 'Add', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
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
              child: Icon(Icons.verified, color: Color(0xFF00FFCC), size: 20),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalization.isArabicNotifier.value ? 'ربط الحساب بالمشرف الجانبي' : 'Linked to Sub-Admin Distributor',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 2),
                  Text(
                    _parentAdminName ?? '',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.cancel, color: Colors.redAccent, size: 20),
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
            AppLocalization.isArabicNotifier.value ? 'يرجى ربط حسابك بالموزع المعتمد الخاص بك' : 'Please link your account under your distributor',
            style: TextStyle(color: Colors.white38, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF00FFCC),
              side: BorderSide(color: Color(0xFF00FFCC), width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: Icon(Icons.qr_code_scanner, size: 18),
            label: Text(
              AppLocalization.isArabicNotifier.value ? 'مسح QR أو إدخال كود الموزع' : 'Scan QR or Enter Distributor Code',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            onPressed: _showJoinSubAdminDialog,
          )
        ],
      ),
    );
  }

  Widget _buildAddedDeviceCard() {
    final isAr = AppLocalization.isArabicNotifier.value;
    if (_setupCodeCtrl.text.isEmpty) {
      return Container(
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
              isAr ? 'لم يتم إضافة أي جهاز للربط بعد' : 'No device has been added for linking yet',
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
              icon: const Icon(Icons.add, size: 18),
              label: Text(
                isAr ? 'إضافة كود إعداد الجهاز' : 'Add Device Setup Code',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              onPressed: _showAddDeviceDialog,
            )
          ],
        ),
      );
    }

    return Container(
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
            child: Icon(Icons.developer_board, color: Color(0xFF00FFCC), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAr ? 'تم ربط كود الجهاز' : 'Device Code Staged',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_setupCodeCtrl.text} (${isAr ? "$_setupCodeWidgetsCount أدوات" : "$_setupCodeWidgetsCount widgets"})',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: Color(0xFF00FFCC), size: 20),
            onPressed: _showAddDeviceDialog,
          ),
          IconButton(
            icon: const Icon(Icons.cancel, color: Colors.redAccent, size: 20),
            onPressed: () {
              setState(() {
                _setupCodeCtrl.clear();
                _isSetupCodeValid = null;
                _setupCodeWidgetsCount = 0;
              });
            },
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAr = AppLocalization.isArabicNotifier.value;
    final titleText = isAr ? 'إكمال بيانات الحساب' : 'Complete Profile Setup';

    return Scaffold(
      backgroundColor: AppTheme.backgroundBase,
      appBar: PremiumAppBar(
        titleText: titleText,
        actions: [
          TextButton.icon(
            onPressed: _showAddDeviceDialog,
            icon: const Icon(Icons.add, color: Color(0xFF0EA5E9), size: 18),
            label: Text(
              isAr ? 'إضافة جهاز' : 'Add Device',
              style: const TextStyle(color: Color(0xFF0EA5E9), fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
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

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 10),
                  // Welcome icon
                  Container(
                    width: 70, height: 70,
                    margin: const EdgeInsets.symmetric(horizontal: 140),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.primaryCyan.withValues(alpha: 0.15),
                      border: Border.all(color: AppTheme.primaryCyan, width: 2),
                    ),
                    child: Icon(Icons.waving_hand, color: AppTheme.primaryCyan, size: 32),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isAr ? 'أهلاً ${widget.username}! 👋' : 'Welcome ${widget.username}! 👋',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isAr 
                      ? 'تم تسجيل دخولك بنجاح عبر جوجل.\nيرجى إكمال تهيئة حسابك للمتابعة.'
                      : 'Account authorized successfully via Google.\nPlease complete setting up your profile below.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  
                  // --- CARD 1: PASSWORD ---
                  _sectionHeader(isAr ? 'المعلومات الأساسية وتأمين الحساب' : 'Basic Info & Security'),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        padding: const EdgeInsets.all(20.0),
                        decoration: AppTheme.glassDecoration(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _passwordCtrl,
                              obscureText: !_passVisible,
                              style: const TextStyle(color: Colors.white),
                              decoration: AppTheme.inputDecoration(
                                labelText: isAr ? 'تعيين كلمة مرور الحساب' : 'Set Account Password',
                                hintText: isAr ? 'أدخل كلمة مرور (6 أحرف على الأقل)' : 'Enter secure password (min 6 chars)',
                                prefixIcon: Icons.lock_outline,
                                suffixIcon: IconButton(
                                  icon: Icon(_passVisible ? Icons.visibility : Icons.visibility_off, color: Colors.white54),
                                  onPressed: () => setState(() => _passVisible = !_passVisible),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- CARD 2: DEVICE CONFIG ---
                  _sectionHeader(isAr ? 'إعداد الجهاز وتوصيله' : 'Device Configuration'),
                  _buildAddedDeviceCard(),
                  const SizedBox(height: 20),

                  // --- CARD 3: DISTRIBUTORS GATEWAY ---
                  _sectionHeader(isAr ? 'بوابة الموزعين والشركاء' : 'Distributors & Merchant Gateway'),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        padding: const EdgeInsets.all(20.0),
                        decoration: AppTheme.glassDecoration(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: ChoiceChip(
                                    label: Text(isAr ? 'بدون موزع' : 'No Distributor'),
                                    selected: _distributorMode == 0,
                                    onSelected: (val) {
                                      if (val) setState(() => _distributorMode = 0);
                                    },
                                    selectedColor: AppTheme.primaryViolet.withValues(alpha: 0.2),
                                    backgroundColor: Colors.transparent,
                                    labelStyle: TextStyle(
                                      color: _distributorMode == 0 ? AppTheme.primaryCyan : Colors.white60,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    side: BorderSide(
                                      color: _distributorMode == 0 ? AppTheme.primaryCyan : Colors.white10,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: ChoiceChip(
                                    label: Text(isAr ? 'تابع لموزع' : 'Merchant Client'),
                                    selected: _distributorMode == 1,
                                    onSelected: (val) {
                                      if (val) setState(() => _distributorMode = 1);
                                    },
                                    selectedColor: AppTheme.primaryViolet.withValues(alpha: 0.2),
                                    backgroundColor: Colors.transparent,
                                    labelStyle: TextStyle(
                                      color: _distributorMode == 1 ? AppTheme.primaryCyan : Colors.white60,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    side: BorderSide(
                                      color: _distributorMode == 1 ? AppTheme.primaryCyan : Colors.white10,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: ChoiceChip(
                                    label: Text(isAr ? 'كن موزعاً' : 'Become Merchant'),
                                    selected: _distributorMode == 2,
                                    onSelected: (val) {
                                      if (val) setState(() => _distributorMode = 2);
                                    },
                                    selectedColor: AppTheme.primaryViolet.withValues(alpha: 0.2),
                                    backgroundColor: Colors.transparent,
                                    labelStyle: TextStyle(
                                      color: _distributorMode == 2 ? AppTheme.primaryCyan : Colors.white60,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    side: BorderSide(
                                      color: _distributorMode == 2 ? AppTheme.primaryCyan : Colors.white10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_distributorMode == 1) ...[
                              _buildMerchantLinkStatusCard(),
                            ] else if (_distributorMode == 2) ...[
                              const SizedBox(height: 16),
                              TextField(
                                controller: _subAdminPromoCodeCtrl,
                                style: const TextStyle(color: Colors.white),
                                decoration: AppTheme.inputDecoration(
                                  labelText: isAr ? 'كود تفعيل موزع معتمد' : 'Sub-Admin Promo Code',
                                  hintText: isAr ? 'أدخل كود تفعيل الموزع المعتمد الخاص بك' : 'Enter sub-admin license/promo key',
                                  prefixIcon: Icons.stars_sharp,
                                ),
                                textCapitalization: TextCapitalization.characters,
                              ),
                            ] else ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                                child: Text(
                                  isAr 
                                    ? 'حدد إذا كنت قد قمت بشراء جهازك من موزع معتمد، أو تملك كود تفعيل موزع.' 
                                    : 'Select if you bought your device through a merchant, or own a sub-admin promo key.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white30, fontSize: 11),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- CARD 4: ADAFRUIT IO ---
                  _sectionHeader('ADAFRUIT IO — ${isAr ? 'اختياري' : 'Optional'}'),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        padding: const EdgeInsets.all(20.0),
                        decoration: AppTheme.glassDecoration(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              isAr
                                  ? 'للتحكم بالأجهزة واللمبات الذكية عبر Adafruit IO (يمكن إضافتها لاحقاً)'
                                  : 'To control smart devices via Adafruit IO (can be added later)',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _aioUserCtrl,
                              style: const TextStyle(color: Colors.white),
                              decoration: AppTheme.inputDecoration(
                                labelText: isAr ? 'اسم مستخدم Adafruit' : 'Adafruit IO Username',
                                hintText: 'Adafruit IO username',
                                prefixIcon: Icons.cloud_circle_outlined,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _aioKeyCtrl,
                              obscureText: true,
                              style: const TextStyle(color: Colors.white),
                              decoration: AppTheme.inputDecoration(
                                labelText: isAr ? 'مفتاح Adafruit API' : 'Adafruit IO AIO Key',
                                hintText: 'Adafruit AIO key',
                                prefixIcon: Icons.vpn_key_outlined,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- CARD 5: FIREBASE ---
                  _sectionHeader('FIREBASE RTDB — ${isAr ? 'اختياري' : 'Optional'}'),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        padding: const EdgeInsets.all(20.0),
                        decoration: AppTheme.glassDecoration(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              isAr
                                  ? 'للتحكم في الأجهزة الاحترافية عبر Firebase (يمكن إضافته لاحقاً)'
                                  : 'To control smart devices via Firebase RTDB (can be added later)',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _firebaseUrlCtrl,
                              style: const TextStyle(color: Colors.white),
                              decoration: AppTheme.inputDecoration(
                                labelText: AppLocalization.get('firebase_db_url'),
                                hintText: 'https://your-project.firebaseio.com/',
                                prefixIcon: Icons.link,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _firebaseSecretCtrl,
                              obscureText: true,
                              style: const TextStyle(color: Colors.white),
                              decoration: AppTheme.inputDecoration(
                                labelText: AppLocalization.get('firebase_secret'),
                                hintText: 'Firebase Secret Key',
                                prefixIcon: Icons.security,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                  GlowingButton(
                    onPressed: _isLoading ? null : _save,
                    isLoading: _isLoading,
                    height: 55,
                    borderRadius: 16,
                    child: Text(
                      isAr ? 'إكمال الحساب والمتابعة' : 'Complete Setup & Continue',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _skip,
                    child: Text(
                      isAr ? 'تخطي وإضافة التفضيلات لاحقاً' : 'Skip setup, add details later',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
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
            SizedBox(height: 24),
            Icon(Icons.supervised_user_circle, size: 50, color: Color(0xFF00FFCC)),
            SizedBox(height: 16),
            Text(
              ar ? 'الانضمام لموزع معتمد' : 'Join a Distributor',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              ar 
                  ? 'حابب تعمل اسكان لل QR كود ولا تحط الكود يدوي؟' 
                  : 'Would you like to scan the QR code or enter the code manually?',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            SizedBox(height: 28),
            
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
            SizedBox(height: 14),
            
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
            SizedBox(height: 10),
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
      if (!mounted) return;
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
            SizedBox(height: 20),
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
            SizedBox(height: 10),
            Text(
              ar
                  ? 'اربط حسابك بالموزع الخاص بك لتحميل أدواتك المخصصة والسيناريوهات فورياً.'
                  : 'Link under your merchant to deploy pre-configured assets instantly.',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
            SizedBox(height: 20),
            
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
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00FFCC),
                                    boxShadow: [
                                      BoxShadow(color: const Color(0xFF00FFCC), blurRadius: 10, spreadRadius: 1.5)
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


