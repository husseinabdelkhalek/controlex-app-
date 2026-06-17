import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import '../services/api_service.dart';
import '../core/localization.dart';
import 'package:url_launcher/url_launcher.dart';
import 'local_dashboard_screen.dart';
import 'admin_dashboard_screen.dart';
import '../core/api_constants.dart';
import '../widgets/app_tour_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:url_launcher/url_launcher.dart';
import '../services/socket_service.dart';

import 'sub_admin_dashboard_screen.dart';

class AccountScreen extends StatefulWidget {
  final bool startTour;
  const AccountScreen({super.key, this.startTour = false});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  // GlobalKeys for Onboarding Tour Highlights
  final GlobalKey _langSectionKey = GlobalKey();
  final GlobalKey _supportSectionKey = GlobalKey();

  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  
  final _aioUserCtrl = TextEditingController();
  final _aioKeyCtrl = TextEditingController();
  final _firebaseUrlCtrl = TextEditingController();
  final _firebaseSecretCtrl = TextEditingController();
  
  bool _twoFactorEnabled = false;
  bool _isLoading = true;
  bool _is2FALoading = false;
  bool _showAdafruit = true;
  bool _showFirebase = true;
  String _joinedDate = '';
  List<dynamic> _sessions = [];
  String? _googleProfilePicture;
  String _role = 'user';
  String _subAdminCode = '';
  bool _isLocalControlPinned = false;
  bool _showSessions = false;

  void _onLangChange() => setState(() {});

  void _loadPinState() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isLocalControlPinned = prefs.getBool('pin_local_control') ?? false;
      });
    }
  }

  @override
  void dispose() {
    AppLocalization.isArabicNotifier.removeListener(_onLangChange);
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _aioUserCtrl.dispose();
    _aioKeyCtrl.dispose();
    _firebaseUrlCtrl.dispose();
    _firebaseSecretCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    AppLocalization.isArabicNotifier.addListener(_onLangChange);
    _loadPinState();
    _fetchData();
    if (widget.startTour) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) _startTour();
        });
      });
    }
  }

  void _startTour() {
    final List<TourStep> steps = [
      TourStep(
        titleKey: 'tour_account_lang_title',
        descKey: 'tour_account_lang_desc',
        targetKey: _langSectionKey,
        requireInteraction: true,
      ),
      TourStep(
        titleKey: 'tour_account_support_title',
        descKey: 'tour_account_support_desc',
        targetKey: _supportSectionKey,
      ),
      const TourStep(
        titleKey: 'tour_end_title',
        descKey: 'tour_end_desc',
      ),
    ];

    AppTour.show(
      context,
      steps,
      onComplete: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('has_completed_tour_v1', true);
        if (mounted) Navigator.pop(context);
      },
      onSkip: () {},
    );
  }

  void _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final userRes = await ApiService.userMe();
      final sessionsRes = await ApiService.getSessions();
      
      if (mounted) setState(() {
         _usernameCtrl.text = userRes['username'] ?? '';
         _emailCtrl.text = userRes['email'] ?? '';
         _aioUserCtrl.text = userRes['adafruitUsername'] ?? '';
         _aioKeyCtrl.text = userRes['adafruitApiKey'] ?? '';
         _firebaseUrlCtrl.text = userRes['firebaseUrl'] ?? '';
         _firebaseSecretCtrl.text = userRes['firebaseSecret'] ?? '';
         
         _twoFactorEnabled = userRes['security']?['twoFactorEnabled'] ?? false;
         
         if (userRes['createdAt'] != null) {
            final date = DateTime.parse(userRes['createdAt'].toString());
            _joinedDate = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
         }

         _googleProfilePicture = userRes['googleProfilePicture'];
         _role = userRes['role'] ?? 'user';
         _subAdminCode = userRes['subAdminCode'] ?? '';

         bool hasAdafruit = _aioUserCtrl.text.isNotEmpty;
         bool hasFirebase = _firebaseUrlCtrl.text.isNotEmpty;
         
         if (hasAdafruit && !hasFirebase) {
           _showAdafruit = true;
           _showFirebase = false;
         } else if (hasFirebase && !hasAdafruit) {
           _showFirebase = true;
           _showAdafruit = false;
         } else {
           _showAdafruit = true;
           _showFirebase = true;
         }

         _sessions = sessionsRes;
         _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
         _showToast('Failed to load data');
         setState(() => _isLoading = false);
      }
    }
  }

  void _updateProfile() async {
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text.trim();
    
    // Email regex validation
    if (email.isNotEmpty && !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _showToast('يرجى إدخال بريد إلكتروني صحيح');
      return;
    }

    if (password.isNotEmpty && password.length < 6) {
      _showToast('كلمة المرور يجب أن تكون 6 أحرف على الأقل');
      return;
    }

    try {
      final data = <String, dynamic>{
         'username': _usernameCtrl.text.trim(),
      };
      if (email.isNotEmpty) data['email'] = email;
      if (password.isNotEmpty) data['password'] = password;
      
      final res = await ApiService.userUpdate(data);
      _showToast(res['msg'] ?? AppLocalization.get('profile_updated'));
    } catch (e) {
      _showToast('Update failed: $e');
    }
  }

  void _updateAdafruit() async {
    try {
      final data = <String, dynamic>{
         'adafruitUsername': _aioUserCtrl.text.trim(),
         'adafruitApiKey': _aioKeyCtrl.text.trim(),
      };
      final res = await ApiService.userUpdate(data);
      _showToast(res['msg'] ?? AppLocalization.get('api_keys_saved'));
    } catch (e) {
      _showToast('Failed to save API keys: $e');
    }
  }

  void _updateFirebase() async {
    try {
      final data = <String, dynamic>{
         'firebaseUrl': _firebaseUrlCtrl.text.trim(),
         'firebaseSecret': _firebaseSecretCtrl.text.trim(),
      };
      final res = await ApiService.userUpdate(data);
      _showToast(res['msg'] ?? AppLocalization.get('api_keys_saved'));
    } catch (e) {
      _showToast('Failed to save Firebase keys: $e');
    }
  }
  
  void _updatePreferences() async {
     try {
        final data = {
           'preferences': {
             'theme': 'dark',
             'privacy': {
                'allowDataCollection': false
             }
           }
        };
        await ApiService.updatePreferences(data);
     } catch(e) {}
  }

  void _terminateSession(String id) async {
    try {
       await ApiService.terminateSession(id);
       _fetchData();
    } catch (e) {}
  }
  
  void _toggle2FA() async {
    if (_is2FALoading) return;
    setState(() => _is2FALoading = true);
    try {
      if (_twoFactorEnabled) {
         final res = await ApiService.disable2FA();
         _showToast(res['msg'] ?? AppLocalization.get('disabled'));
         setState(() => _twoFactorEnabled = false);
      } else {
         final res = await ApiService.enable2FA();
         _showToast(res['msg'] ?? AppLocalization.get('enabled'));
         setState(() => _twoFactorEnabled = true);
      }
    } catch(e) {
       _showToast('خطأ: $e (تأكد من تحديث السيرفر على Koyeb)');
    } finally {
       if (mounted) setState(() => _is2FALoading = false);
    }
  }
  
  void _clearData() async {
     final confirm = await _showConfirmDialog(
        title: AppLocalization.get('clear_data'),
        content: 'هل أنت متأكد من حذف جميع الأدوات والبيانات؟ لا يمكن التراجع عن هذا الإجراء.',
        isDestructive: true
     );
     if (confirm == true) {
        setState(() => _isLoading = true);
        try {
           final res = await ApiService.clearData();
           _showToast(res['msg'] ?? AppLocalization.get('data_cleared'));
           _fetchData();
        } catch(e) {
           _showToast('فشل مسح البيانات: $e (تأكد من نشر التعديلات للسيرفر)');
           setState(() => _isLoading = false);
        }
     }
  }

  void _deleteAccount() async {
     final confirm = await _showConfirmDialog(
        title: AppLocalization.get('delete_account'),
        content: AppLocalization.isArabicNotifier.value ? 'هل أنت متأكد من أنك تريد حذف حسابك نهائياً؟ هذا الإجراء لا يمكن التراجع عنه وسيحذف جميع أدواتك.' : 'Are you sure you want to permanently delete your account? This cannot be undone.',
        isDestructive: true
     );
     if (confirm == true) {
        setState(() => _isLoading = true);
        try {
           final res = await ApiService.deleteAccount();
           
           try {
             SocketService.disconnect();
           } catch (_) {}

           await ApiService.clearAuth();
           
           if (mounted) {
             // Delay to allow Ripple effects from dialog button to complete
             await Future.delayed(const Duration(milliseconds: 300));
             if (mounted) {
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
             }
           }
        } catch(e) {
           _showToast('حدث خطأ: $e');
           setState(() => _isLoading = false);
        }
     }
  }

  Future<bool?> _showConfirmDialog({required String title, required String content, bool isDestructive = false}) {
     return showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
           backgroundColor: AppTheme.darkBackground,
           surfaceTintColor: Colors.transparent,
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
           title: Text(title, style: TextStyle(color: isDestructive ? Colors.redAccent : Colors.white)),
           content: Text(content, style: const TextStyle(color: Colors.white70)),
           actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء', style: TextStyle(color: Colors.white54))),
              ElevatedButton(
                 style: ElevatedButton.styleFrom(backgroundColor: isDestructive ? Colors.redAccent : AppTheme.primaryCyan, foregroundColor: Colors.white),
                 onPressed: () => Navigator.pop(context, true),
                 child: const Text('تأكيد'),
              ),
           ],
        )
     );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(backgroundColor: AppTheme.darkBackground, body: Center(child: CircularProgressIndicator(color: AppTheme.primaryCyan)));

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(title: Text(AppLocalization.get('account_preferences'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Profile Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppTheme.cardBaseColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.primaryCyan.withValues(alpha: 0.3))),
              child: Column(
                children: [
                   CircleAvatar(
                      radius: 45, 
                      backgroundColor: AppTheme.primaryViolet, 
                      backgroundImage: (_googleProfilePicture != null && _googleProfilePicture!.startsWith('http')) ? NetworkImage(_googleProfilePicture!) : null,
                      child: (_googleProfilePicture == null || !_googleProfilePicture!.startsWith('http')) ? const Icon(Icons.person, size: 50, color: Colors.white) : null
                   ),
                  const SizedBox(height: 16),
                  Text(_usernameCtrl.text, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  Text(_joinedDate, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 16),



            if (_role == 'admin') 
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: AppTheme.cardBaseColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3))),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.shield, color: Colors.redAccent, size: 24),
                  ),
                  title: Text(AppLocalization.get('admin_panel'), style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  subtitle: Text(AppLocalization.get('admin_desc'), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.redAccent),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDashboardScreen()));
                  },
                ),
              ),

            () {
              final bool isMainAdmin = _emailCtrl.text.toLowerCase() == 'hussianabdk577@gmail.com';
              final bool showDistributorDashboard = (_role == 'sub_admin') || 
                                                    (isMainAdmin) || 
                                                    (_subAdminCode.isNotEmpty);
              
              if (!showDistributorDashboard) return const SizedBox.shrink();

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.cardBaseColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF00FFCC).withValues(alpha: 0.3)),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFF00FFCC).withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.storefront_rounded, color: Color(0xFF00FFCC), size: 24),
                  ),
                  title: Text(
                    AppLocalization.isArabicNotifier.value ? 'لوحة تحكم الموزع' : 'Distributor Dashboard',
                    style: const TextStyle(color: Color(0xFF00FFCC), fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    AppLocalization.isArabicNotifier.value
                        ? 'أكواد QR للعملاء، التحكم بحساباتهم، ومراقبة التفعيل.'
                        : 'Customer QRs, group management, and activation monitoring.',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Color(0xFF00FFCC)),
                  onTap: () {
                    final profile = {
                      'username': _usernameCtrl.text,
                      'email': _emailCtrl.text,
                      'subAdminCode': _subAdminCode.isNotEmpty 
                          ? _subAdminCode 
                          : (isMainAdmin ? 'MERCHANT_ADMIN_TEST' : ''),
                      'role': _role,
                    };
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FutureBuilder<Map<String, dynamic>>(
                          future: ApiService.userMe(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Scaffold(
                                backgroundColor: AppTheme.darkBackground,
                                body: Center(child: CircularProgressIndicator(color: Color(0xFF00FFCC))),
                              );
                            }
                            final fullProfile = snapshot.data ?? profile;
                            if (fullProfile['subAdminCode'] == null || fullProfile['subAdminCode'] == '') {
                              fullProfile['subAdminCode'] = profile['subAdminCode'];
                            }
                            return SubAdminDashboardScreen(userProfile: fullProfile);
                          },
                        ),
                      ),
                    );
                  },
                ),
              );
            }(),
            
            _buildSectionCard(
              AppLocalization.get('personal_info'), Icons.badge,
              Column(
                children: [
                  _buildTextField(AppLocalization.get('username'), _usernameCtrl, Icons.person_outline),
                  const Divider(color: Colors.white12),
                  _buildTextField(AppLocalization.get('email'), _emailCtrl, Icons.email_outlined),
                  const Divider(color: Colors.white12),
                  _buildTextField(AppLocalization.get('new_password_optional'), _passCtrl, Icons.lock_outline, isPassword: true),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryCyan, foregroundColor: Colors.black, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: _updateProfile,
                    child: Text(AppLocalization.get('update_profile'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            ),
            
            if (_showAdafruit) _buildSectionCard(
              'Adafruit IO Integration', Icons.cloud_sync,
              Column(
                children: [
                  _buildTextField('Adafruit Username', _aioUserCtrl, Icons.cloud_circle_outlined),
                  const Divider(color: Colors.white12),
                  _buildTextField('Adafruit API Key', _aioKeyCtrl, Icons.vpn_key_outlined, isPassword: true),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryViolet, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: _updateAdafruit,
                    child: const Text('Save API Keys', style: TextStyle(fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            ),
            
            if (_showFirebase) _buildSectionCard(
              'Firebase RTDB Integration', Icons.storage,
              Column(
                children: [
                  _buildTextField('Firebase Database URL', _firebaseUrlCtrl, Icons.link),
                  const Divider(color: Colors.white12),
                  _buildTextField('Firebase Database Secret', _firebaseSecretCtrl, Icons.security, isPassword: true),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryCyan, foregroundColor: Colors.black, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: _updateFirebase,
                    child: const Text('Save Firebase Config', style: TextStyle(fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            ),

            _buildSectionCard(
              AppLocalization.get('app_preferences'), Icons.tune,
              key: _langSectionKey,
              Column(
                 children: [
                     ListTile(
                        leading: const Icon(Icons.language, color: AppTheme.primaryCyan),
                        title: Text(AppLocalization.get('language'), style: const TextStyle(color: Colors.white)),
                        subtitle: Text(AppLocalization.get('english_ar'), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        trailing: Container(
                           height: 36,
                           width: 110,
                           decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
                           ),
                           child: Stack(
                              children: [
                                 AnimatedPositioned(
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeOut,
                                    left: AppLocalization.isArabicNotifier.value ? 55 : 0,
                                    right: AppLocalization.isArabicNotifier.value ? 0 : 55,
                                    top: 0,
                                    bottom: 0,
                                    child: Container(
                                       margin: const EdgeInsets.all(2),
                                       decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                             colors: [AppTheme.primaryCyan, AppTheme.primaryCyan.withValues(alpha: 0.8)],
                                          ),
                                          borderRadius: BorderRadius.circular(16),
                                          boxShadow: [
                                             BoxShadow(
                                                color: AppTheme.primaryCyan.withValues(alpha: 0.3),
                                                blurRadius: 4,
                                                spreadRadius: 1,
                                             )
                                          ],
                                       ),
                                    ),
                                 ),
                                 Row(
                                    children: [
                                       Expanded(
                                          child: GestureDetector(
                                             behavior: HitTestBehavior.opaque,
                                             onTap: () {
                                                if (AppLocalization.isArabicNotifier.value) {
                                                   AppLocalization.toggleLanguage();
                                                   setState(() {});
                                                }
                                             },
                                             child: Center(
                                                child: Text(
                                                   'EN',
                                                   style: TextStyle(
                                                      color: AppLocalization.isArabicNotifier.value ? Colors.white70 : Colors.black,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 12,
                                                   ),
                                                ),
                                             ),
                                          ),
                                       ),
                                       Expanded(
                                          child: GestureDetector(
                                             behavior: HitTestBehavior.opaque,
                                             onTap: () {
                                                if (!AppLocalization.isArabicNotifier.value) {
                                                   AppLocalization.toggleLanguage();
                                                   setState(() {});
                                                }
                                             },
                                             child: Center(
                                                child: Text(
                                                   'AR',
                                                   style: TextStyle(
                                                      color: AppLocalization.isArabicNotifier.value ? Colors.black : Colors.white70,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 12,
                                                   ),
                                                ),
                                             ),
                                          ),
                                       ),
                                    ],
                                 ),
                              ],
                           ),
                        ),
                     ),
                     const Divider(color: Colors.white10),
                     ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                           padding: const EdgeInsets.all(8),
                           decoration: BoxDecoration(color: Colors.orangeAccent.withValues(alpha: 0.1), shape: BoxShape.circle),
                           child: const Icon(Icons.wifi, color: Colors.orangeAccent, size: 20),
                        ),
                        title: Text(AppLocalization.get('local_control'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text(AppLocalization.get('local_desc'), style: const TextStyle(color: Colors.white54, fontSize: 11)),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LocalDashboardScreen())),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                _isLocalControlPinned ? Icons.push_pin : Icons.push_pin_outlined,
                                color: _isLocalControlPinned ? AppTheme.primaryCyan : Colors.white24,
                                size: 20,
                              ),
                              tooltip: AppLocalization.isArabicNotifier.value ? 'تثبيت في القائمة الجانبية' : 'Pin to Drawer',
                              onPressed: () async {
                                final prefs = await SharedPreferences.getInstance();
                                setState(() {
                                  _isLocalControlPinned = !_isLocalControlPinned;
                                });
                                await prefs.setBool('pin_local_control', _isLocalControlPinned);
                                _showToast(
                                  _isLocalControlPinned 
                                    ? (AppLocalization.isArabicNotifier.value ? 'تم تثبيت التحكم المحلي في القائمة' : 'Local Control pinned to drawer')
                                    : (AppLocalization.isArabicNotifier.value ? 'تم إلغاء التثبيت من القائمة' : 'Local Control unpinned from drawer')
                                );
                              },
                            ),
                            const Icon(Icons.chevron_right, color: Colors.white24),
                          ],
                        ),
                     ),
                     const Divider(color: Colors.white10),
                     _buildListTile(
                        icon: Icons.explore,
                        title: AppLocalization.isArabicNotifier.value ? 'جولة في التطبيق' : 'App Tour',
                        subtitle: AppLocalization.isArabicNotifier.value 
                            ? 'شرح تفاعلي لمميزات وأزرار لوحة التحكم' 
                            : 'Interactive showcase of dashboard features & buttons',
                        color: AppTheme.primaryCyan,
                        onTap: () {
                           Navigator.pop(context, 'start_tour');
                        },
                     ),
                 ],
              )
            ),
            
            _buildSectionCard(
              AppLocalization.get('security_settings'), Icons.security,
              Column(
                children: [
                   ListTile(
                     contentPadding: EdgeInsets.zero,
                     title: Text(AppLocalization.get('two_factor_auth'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                     subtitle: Text(_twoFactorEnabled ? AppLocalization.get('enabled') : AppLocalization.get('disabled'), style: TextStyle(color: _twoFactorEnabled ? AppTheme.primaryCyan : Colors.white54)),
                      trailing: _is2FALoading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryCyan))
                        : ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: _twoFactorEnabled ? Colors.redAccent.withValues(alpha: 0.2) : AppTheme.primaryViolet.withValues(alpha: 0.3),
                                foregroundColor: _twoFactorEnabled ? Colors.redAccent : Colors.white, elevation: 0,
                            ),
                            onPressed: _toggle2FA,
                            child: Text(_twoFactorEnabled ? AppLocalization.get('disabled') : AppLocalization.get('enabled')),
                         )
                   ),
                   const Divider(color: Colors.white12),
                   ListTile(
                     contentPadding: EdgeInsets.zero,
                     title: Text(AppLocalization.get('active_sessions'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                     trailing: Icon(
                       _showSessions ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                       color: Colors.white54,
                     ),
                     onTap: () {
                       setState(() {
                         _showSessions = !_showSessions;
                       });
                     },
                   ),
                   if (_showSessions) ...[
                     ..._sessions.map((s) {
                        final deviceInfo = s['deviceInfo'] ?? {};
                        final deviceName = deviceInfo['deviceName'] ?? deviceInfo['userAgent'] ?? 'PC / Browser';
                        final platform = (deviceInfo['platform'] ?? '').toString().toLowerCase();
                        
                        IconData deviceIcon = Icons.laptop;
                        if (platform.contains('android') || deviceName.toLowerCase().contains('android')) {
                          deviceIcon = Icons.phone_android;
                        } else if (platform.contains('ios') || deviceName.toLowerCase().contains('iphone') || deviceName.toLowerCase().contains('ipad') || deviceName.toLowerCase().contains('apple')) {
                          deviceIcon = Icons.phone_iphone;
                        }

                        return ListTile(
                           contentPadding: EdgeInsets.zero,
                           leading: Icon(deviceIcon, color: Colors.white54, size: 20),
                           title: Text(deviceName, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                           subtitle: Text(deviceInfo['ip'] ?? s['ip'] ?? '', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                           trailing: IconButton(icon: const Icon(Icons.power_settings_new, color: Colors.redAccent, size: 20), onPressed: () => _terminateSession(s['id'])),
                        );
                     }),
                   ],
                ],
              ),
            ),
            
            _buildSectionCard(
              AppLocalization.get('data_management'), Icons.storage,
              Column(
                children: [
                   ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.delete_sweep, color: Colors.orange), 
                    title: Text(AppLocalization.get('clear_data'), style: const TextStyle(color: Colors.orange)), 
                    onTap: _clearData
                   ),
                   const Divider(color: Colors.white12),
                   ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.warning, color: Colors.redAccent), 
                    title: Text(AppLocalization.get('delete_account'), style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)), 
                    onTap: _deleteAccount
                   ),
                ],
              ),
            ),
            
            _buildSectionCard(
              AppLocalization.get('technical_support'), Icons.support_agent,
              key: _supportSectionKey,
              Column(
                children: [
                   ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.email_outlined, color: AppTheme.primaryCyan), 
                    title: Text(AppLocalization.get('email'), style: const TextStyle(color: Colors.white, fontSize: 14)), 
                    subtitle: const Text('hussianabdk577@gmail.com', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
                    trailing: const Icon(Icons.open_in_new, color: Colors.white24, size: 16),
                    onTap: () async {
                      final Uri url = Uri.parse('mailto:hussianabdk577@gmail.com');
                      if (await canLaunchUrl(url)) {
                         await launchUrl(url);
                      }
                    },
                   ),
                   const Divider(color: Colors.white12),
                   ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.phone_outlined, color: AppTheme.primaryCyan), 
                    title: Text(AppLocalization.get('whatsapp_contact'), style: const TextStyle(color: Colors.white, fontSize: 14)), 
                    subtitle: const Text('+201091601661', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
                    trailing: const Icon(Icons.open_in_new, color: Colors.white24, size: 16),
                    onTap: () async {
                      final Uri url = Uri.parse('https://wa.me/201091601661');
                      if (await canLaunchUrl(url)) {
                         await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    },
                    ),
                 ],
               ),
             ),

             if (!_showAdafruit) ...[
               const SizedBox(height: 16),
               OutlinedButton.icon(
                 style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primaryViolet, side: BorderSide(color: AppTheme.primaryViolet.withValues(alpha: 0.5)), minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                 icon: const Icon(Icons.add_circle_outline),
                 label: const Text('إضافة قاعدة بيانات Adafruit IO', style: TextStyle(fontWeight: FontWeight.bold)),
                 onPressed: () => setState(() => _showAdafruit = true),
               ),
             ],
             
             if (!_showFirebase) ...[
               const SizedBox(height: 16),
               OutlinedButton.icon(
                 style: OutlinedButton.styleFrom(foregroundColor: Colors.orangeAccent, side: BorderSide(color: Colors.orangeAccent.withValues(alpha: 0.5)), minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                 icon: const Icon(Icons.add_circle_outline),
                 label: const Text('إضافة قاعدة بيانات Firebase RTDB', style: TextStyle(fontWeight: FontWeight.bold)),
                 onPressed: () => setState(() => _showFirebase = true),
               ),
             ],
            
            const SizedBox(height: 16),
            ElevatedButton.icon(
               style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, foregroundColor: Colors.redAccent, elevation: 0, side: const BorderSide(color: Colors.redAccent, width: 2), minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
               icon: const Icon(Icons.logout),
               label: Text(AppLocalization.get('logout'), style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
               onPressed: () async {
                 await ApiService.logout();
                 if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
               },
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(String title, IconData icon, Widget child, {Key? key}) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBaseColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryCyan.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppTheme.primaryCyan.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(icon, color: AppTheme.primaryCyan, size: 20),
              ),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildTextField(String hint, TextEditingController ctrl, IconData icon, {bool isPassword = false}) {
    bool obscure = isPassword;
    return StatefulBuilder(
      builder: (context, setStateLocal) {
         return TextField(
            controller: ctrl,
            obscureText: obscure,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
               hintText: hint,
               hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
               icon: Icon(icon, color: Colors.white54, size: 20),
               suffixIcon: isPassword 
                  ? IconButton(icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: Colors.white54), onPressed: () => setStateLocal(() => obscure = !obscure)) 
                  : null,
               border: InputBorder.none,
            ),
         );
      }
    );
  }

  Widget _buildListTile({required IconData icon, required String title, required String subtitle, required Color color, required VoidCallback onTap}) {
    return ListTile(
       contentPadding: EdgeInsets.zero,
       leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 20),
       ),
       title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
       subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 11)),
       onTap: onTap,
       trailing: const Icon(Icons.chevron_right, color: Colors.white24),
     );
   }
   
   void _showToast(String msg) {
     ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: AppTheme.primaryViolet, content: Text(msg, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
   }
}