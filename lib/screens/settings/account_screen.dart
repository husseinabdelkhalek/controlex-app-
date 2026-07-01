import '../../widgets/app_snackbar.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../auth/login_screen.dart';
import '../../services/api_service.dart';
import '../../core/localization.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/app_tour_overlay.dart';
import '../../services/socket_service.dart';
import '../admin_dashboard_screen.dart';
import '../local_dashboard_screen.dart';
import '../sub_admin_dashboard_screen.dart';
import '../settings/profile_settings_screen.dart';
import '../settings/integrations_settings_screen.dart';
import '../settings/security_settings_screen.dart';

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
  
  
  
  String _joinedDate = '';
  List<dynamic> _sessions = [];
  String? _googleProfilePicture;
  String _role = 'user';
  String _subAdminCode = '';
  bool _isLocalControlPinned = false;
  

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
      
      if (mounted) {
        setState(() {
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

         

         _sessions = sessionsRes;
         _isLoading = false;
      });
      }
    } catch (e) {
      if (mounted) {
         _showToast('Failed to load data');
         setState(() => _isLoading = false);
      }
    }
  }

  // Methods moved to separate settings screens
  
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
            
            _buildGlassButton(
              icon: Icons.badge,
              title: AppLocalization.get('personal_info'),
              subtitle: AppLocalization.isArabicNotifier.value ? 'تعديل بيانات الحساب' : 'Edit profile details',
              color: AppTheme.primaryCyan,
              onTap: () async {
                final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileSettingsScreen(initialData: {'username': _usernameCtrl.text, 'email': _emailCtrl.text, 'googleProfilePicture': _googleProfilePicture})));
                if (result == true) _fetchData();
              },
            ),
            const SizedBox(height: 12),
            _buildGlassButton(
              icon: Icons.cloud_sync,
              title: AppLocalization.isArabicNotifier.value ? 'الربط والبيانات' : 'Integrations',
              subtitle: AppLocalization.isArabicNotifier.value ? 'إعدادات Adafruit و Firebase' : 'Adafruit & Firebase settings',
              color: AppTheme.primaryViolet,
              onTap: () async {
                final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => IntegrationsSettingsScreen(initialData: {'adafruitUsername': _aioUserCtrl.text, 'adafruitApiKey': _aioKeyCtrl.text, 'firebaseUrl': _firebaseUrlCtrl.text, 'firebaseSecret': _firebaseSecretCtrl.text})));
                if (result == true) _fetchData();
              },
            ),
            const SizedBox(height: 12),
            _buildGlassButton(
              icon: Icons.security,
              title: AppLocalization.get('security_settings'),
              subtitle: AppLocalization.isArabicNotifier.value ? 'التحقق بخطوتين والجلسات' : '2FA & Active Sessions',
              color: Colors.greenAccent,
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => SecuritySettingsScreen(initialData: {'security': {'twoFactorEnabled': _twoFactorEnabled}}, initialSessions: _sessions)));
                _fetchData();
              },
            ),
            const SizedBox(height: 16),

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


            
            const SizedBox(height: 16),
            ElevatedButton.icon(
               style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, foregroundColor: Colors.redAccent, elevation: 0, side: const BorderSide(color: Colors.redAccent, width: 2), minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
               icon: const Icon(Icons.logout),
               label: Text(AppLocalization.get('logout'), style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
               onPressed: () async {
                 await ApiService.logout();
                 if (context.mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
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


  Widget _buildGlassButton({required IconData icon, required String title, required String subtitle, required Color color, required VoidCallback onTap}) {
    return Container(
      decoration: AppTheme.glassDecoration(
        borderRadius: BorderRadius.circular(20),
        borderColor: color.withValues(alpha: 0.3),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          splashColor: color.withValues(alpha: 0.1),
          highlightColor: color.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 8, spreadRadius: 1)
                    ],
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, color: color.withValues(alpha: 0.5), size: 16),
              ],
            ),
          ),
        ),
      ),
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
     AppSnackbar.showSuccess(context, msg);
   }
}