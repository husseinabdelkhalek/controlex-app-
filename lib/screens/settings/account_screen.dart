import '../../widgets/app_snackbar.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../auth/login_screen.dart';
import '../../services/api_service.dart';
import '../../core/localization.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/app_tour_overlay.dart';

import '../admin_dashboard_screen.dart';
import '../local_dashboard_screen.dart';
import '../sub_admin_dashboard_screen.dart';
import '../settings/profile_settings_screen.dart';
import '../settings/integrations_settings_screen.dart';
import '../settings/security_settings_screen.dart';
import '../settings/device_setup_screen.dart';

class AccountScreen extends StatefulWidget {
  final bool startTour;
  const AccountScreen({super.key, this.startTour = false});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  // ── Tour Keys ────────────────────────────────────────────────────────
  final GlobalKey _langSectionKey = GlobalKey();
  final GlobalKey _supportSectionKey = GlobalKey();

  // ── Controllers & state ──────────────────────────────────────────────
  final _usernameCtrl = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passCtrl     = TextEditingController();
  final _aioUserCtrl  = TextEditingController();
  final _aioKeyCtrl   = TextEditingController();
  final _firebaseUrlCtrl    = TextEditingController();
  final _firebaseSecretCtrl = TextEditingController();

  bool _twoFactorEnabled = false;
  bool _isLoading = true;
  String _joinedDate = '';
  List<dynamic> _sessions = [];
  String? _googleProfilePicture;
  String _role = 'user';
  String _subAdminCode = '';
  bool _isLocalControlPinned = false;

  // ── Design tokens (Klivvr AI design system) ──────────────────────────
  static const _bgCard        = Color(0xFF111119);
  static const _bgIcon        = Color(0xFF1e1e2a);
  static const _textPrimary   = Color(0xFFF2F2F7);
  static const _textSecondary = Color(0xFF8E8E9E);
  static const _chevron       = Color(0xFF4A4A5A);
  static const _divider       = Color(0x0FFFFFFF);
  static const _dangerRed     = Color(0xFFFF453A);

  // ─────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────
  void _onLangChange() => setState(() {});

  void _loadPinState() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _isLocalControlPinned = prefs.getBool('pin_local_control') ?? false);
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
          _emailCtrl.text    = userRes['email']    ?? '';
          _aioUserCtrl.text  = userRes['adafruitUsername'] ?? '';
          _aioKeyCtrl.text   = userRes['adafruitApiKey']   ?? '';
          _firebaseUrlCtrl.text    = userRes['firebaseUrl']    ?? '';
          _firebaseSecretCtrl.text = userRes['firebaseSecret'] ?? '';
          _twoFactorEnabled = userRes['security']?['twoFactorEnabled'] ?? false;
          if (userRes['createdAt'] != null) {
            final date = DateTime.parse(userRes['createdAt'].toString());
            _joinedDate =
                '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          }
          _googleProfilePicture = userRes['googleProfilePicture'];
          _role         = userRes['role']         ?? 'user';
          _subAdminCode = userRes['subAdminCode'] ?? '';
          _sessions   = sessionsRes;
          _isLoading  = false;
        });
      }
    } catch (e) {
      if (mounted) {
        _showToast('Failed to load data');
        setState(() => _isLoading = false);
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // Actions
  // ─────────────────────────────────────────────────────────────────────
  void _logout() async {
    final isAr = AppLocalization.isArabicNotifier.value;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _bgCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isAr ? 'تسجيل الخروج' : 'Sign Out',
          style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Text(
          isAr ? 'هل أنت متأكد أنك تريد تسجيل الخروج؟' : 'Are you sure you want to sign out?',
          style: const TextStyle(color: _textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isAr ? 'إلغاء' : 'Cancel', style: const TextStyle(color: _textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _dangerRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isAr ? 'خروج' : 'Sign Out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ApiService.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _showToast(String msg) => AppSnackbar.showSuccess(context, msg);

  // ─────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.darkBackground,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final isAr = AppLocalization.isArabicNotifier.value;

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          isAr ? 'الحساب' : 'Account',
          style: const TextStyle(
            color: _textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          // Add Device action
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.primaryViolet.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppTheme.primaryViolet.withValues(alpha: 0.4),
                  width: 1.2,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DeviceSetupScreen()),
                  );
                  if (result == true) _fetchData();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add, color: Color(0xFFD8B4FE), size: 16),
                      const SizedBox(width: 4),
                      Text(
                        isAr ? 'إضافة جهاز' : 'Add Device',
                        style: const TextStyle(
                          color: Color(0xFFD8B4FE),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Profile Header ────────────────────────────────────
            _buildProfileHeader(isAr),
            const SizedBox(height: 20),

            // ── Admin Panel (role-gated) ──────────────────────────
            if (_role == 'admin') ...[
              _buildNavRow(
                icon: Icons.shield_rounded,
                title: AppLocalization.get('admin_panel'),
                subtitle: AppLocalization.get('admin_desc'),
                iconColor: const Color(0xFFFF6B6B),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDashboardScreen())),
              ),
              const SizedBox(height: 10),
            ],

            // ── Distributor Dashboard (sub-admin / main admin) ────
            () {
              final bool isMainAdmin = _emailCtrl.text.toLowerCase() == 'hussianabdk577@gmail.com';
              final bool show = (_role == 'sub_admin') || isMainAdmin || _subAdminCode.isNotEmpty;
              if (!show) return const SizedBox.shrink();
              return Column(
                children: [
                  _buildNavRow(
                    icon: Icons.storefront_rounded,
                    title: isAr ? 'لوحة تحكم الموزع' : 'Distributor Dashboard',
                    subtitle: isAr
                        ? 'أكواد QR للعملاء، التحكم بحساباتهم، ومراقبة التفعيل.'
                        : 'Customer QRs, group management, and activation monitoring.',
                    iconColor: const Color(0xFF00FFCC),
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
                            builder: (ctx, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Scaffold(
                                  backgroundColor: Color(0xFF090A0F),
                                  body: Center(child: CircularProgressIndicator()),
                                );
                              }
                              final full = snapshot.data ?? profile;
                              if (full['subAdminCode'] == null || full['subAdminCode'] == '') {
                                full['subAdminCode'] = profile['subAdminCode'];
                              }
                              return SubAdminDashboardScreen(userProfile: full);
                            },
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                ],
              );
            }(),

            // ═══════════════════════════════════════════════════════
            // ACCOUNT SECTION
            // ═══════════════════════════════════════════════════════
            _buildSectionLabel(isAr ? 'الحساب' : 'Account'),
            const SizedBox(height: 8),
            _buildCard([
              _buildNavRow(
                icon: Icons.badge_rounded,
                title: AppLocalization.get('personal_info'),
                subtitle: isAr ? 'تعديل الاسم والبريد' : 'Edit your profile details',
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileSettingsScreen(
                        initialData: {
                          'username': _usernameCtrl.text,
                          'email': _emailCtrl.text,
                          'googleProfilePicture': _googleProfilePicture,
                        },
                      ),
                    ),
                  );
                  if (result == true) _fetchData();
                },
                inCard: true,
              ),
              _buildRowDivider(),
              _buildNavRow(
                icon: Icons.cloud_sync_rounded,
                title: isAr ? 'الربط والبيانات' : 'Integrations',
                subtitle: isAr ? 'إعدادات Adafruit و Firebase' : 'Adafruit & Firebase settings',
                iconColor: AppTheme.primaryViolet,
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => IntegrationsSettingsScreen(
                        initialData: {
                          'adafruitUsername': _aioUserCtrl.text,
                          'adafruitApiKey': _aioKeyCtrl.text,
                          'firebaseUrl': _firebaseUrlCtrl.text,
                          'firebaseSecret': _firebaseSecretCtrl.text,
                        },
                      ),
                    ),
                  );
                  if (result == true) _fetchData();
                },
                inCard: true,
              ),
              _buildRowDivider(),
              _buildNavRow(
                icon: Icons.security_rounded,
                title: isAr ? 'الخصوصية والأمان' : 'Privacy & Security',
                subtitle: isAr ? 'التحقق بخطوتين، الجلسات، وحذف الحساب' : '2FA, sessions & account deletion',
                iconColor: const Color(0xFF30D158),
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SecuritySettingsScreen(
                        initialData: {
                          'security': {'twoFactorEnabled': _twoFactorEnabled},
                        },
                        initialSessions: _sessions,
                      ),
                    ),
                  );
                  if (result == true) _fetchData();
                },
                inCard: true,
              ),
            ]),

            const SizedBox(height: 20),

            // ═══════════════════════════════════════════════════════
            // PREFERENCES SECTION
            // ═══════════════════════════════════════════════════════
            _buildSectionLabel(isAr ? 'التفضيلات' : 'Preferences', key: _langSectionKey),
            const SizedBox(height: 8),
            _buildCard([
              // Language toggle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Row(
                  children: [
                    _iconCircle(icon: Icons.language_rounded),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(AppLocalization.get('language'), style: const TextStyle(color: _textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                          Text(AppLocalization.get('english_ar'), style: const TextStyle(color: _textSecondary, fontSize: 12.5)),
                        ],
                      ),
                    ),
                    // EN / AR pill toggle
                    _buildLangToggle(isAr),
                  ],
                ),
              ),
              _buildRowDivider(),
              // Theme
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                child: Row(
                  children: [
                    _iconCircle(icon: Icons.color_lens_rounded),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(isAr ? 'مظهر التطبيق' : 'App Theme', style: const TextStyle(color: _textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                          Text(isAr ? 'داكن / زجاجي متوهج' : 'Dark / Glassmorphism', style: const TextStyle(color: _textSecondary, fontSize: 12.5)),
                        ],
                      ),
                    ),
                    ValueListenableBuilder<String>(
                      valueListenable: AppTheme.themeNotifier,
                      builder: (ctx, currentTheme, _) => _buildThemeDropdown(currentTheme, isAr),
                    ),
                  ],
                ),
              ),
              _buildRowDivider(),
              // Local Control
              _buildNavRow(
                icon: Icons.wifi_rounded,
                title: AppLocalization.get('local_control'),
                subtitle: AppLocalization.get('local_desc'),
                iconColor: Colors.orangeAccent,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LocalDashboardScreen())),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final prefs = await SharedPreferences.getInstance();
                        setState(() => _isLocalControlPinned = !_isLocalControlPinned);
                        await prefs.setBool('pin_local_control', _isLocalControlPinned);
                        _showToast(
                          _isLocalControlPinned
                              ? (isAr ? 'تم تثبيت التحكم المحلي في القائمة' : 'Local Control pinned')
                              : (isAr ? 'تم إلغاء التثبيت' : 'Local Control unpinned'),
                        );
                      },
                      child: Icon(
                        _isLocalControlPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                        color: _isLocalControlPinned ? AppTheme.primaryCyan : const Color(0xFF4A4A5A),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.chevron_right_rounded, color: _chevron, size: 22),
                  ],
                ),
                inCard: true,
              ),
              _buildRowDivider(),
              // App Tour
              _buildNavRow(
                icon: Icons.explore_rounded,
                title: isAr ? 'جولة في التطبيق' : 'App Tour',
                subtitle: isAr ? 'شرح تفاعلي لمميزات وأزرار لوحة التحكم' : 'Interactive showcase of features & buttons',
                onTap: () => Navigator.pop(context, 'start_tour'),
                inCard: true,
              ),
            ]),

            const SizedBox(height: 20),

            // ═══════════════════════════════════════════════════════
            // SUPPORT SECTION
            // ═══════════════════════════════════════════════════════
            _buildSectionLabel(isAr ? 'الدعم الفني' : 'Technical Support', key: _supportSectionKey),
            const SizedBox(height: 8),
            _buildCard([
              _buildNavRow(
                icon: Icons.email_outlined,
                title: AppLocalization.get('email'),
                subtitle: 'hussianabdk577@gmail.com',
                onTap: () async {
                  final Uri url = Uri.parse('mailto:hussianabdk577@gmail.com');
                  if (await canLaunchUrl(url)) await launchUrl(url);
                },
                trailing: const Icon(Icons.open_in_new_rounded, color: _chevron, size: 18),
                inCard: true,
              ),
              _buildRowDivider(),
              _buildNavRow(
                icon: Icons.chat_rounded,
                title: AppLocalization.get('whatsapp_contact'),
                subtitle: '+201091601661',
                iconColor: const Color(0xFF25D366),
                onTap: () async {
                  final Uri url = Uri.parse('https://wa.me/201091601661');
                  if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
                },
                trailing: const Icon(Icons.open_in_new_rounded, color: _chevron, size: 18),
                inCard: true,
              ),
            ]),

            const SizedBox(height: 20),

            // ═══════════════════════════════════════════════════════
            // SIGN OUT  –  stays on the Account screen as a card row
            // ═══════════════════════════════════════════════════════
            _buildCard([
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _logout,
                  borderRadius: BorderRadius.circular(20),
                  splashColor: _dangerRed.withValues(alpha: 0.08),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    child: Row(
                      children: [
                        _iconCircle(icon: Icons.logout_rounded, isDanger: true),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            AppLocalization.get('logout'),
                            style: const TextStyle(
                              color: _dangerRed,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: _dangerRed.withValues(alpha: 0.4), size: 22),
                      ],
                    ),
                  ),
                ),
              ),
            ]),

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // WIDGET HELPERS
  // ─────────────────────────────────────────────────────────────────────

  Widget _buildProfileHeader(bool isAr) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 24, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Purple glow ring
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.primaryViolet.withValues(alpha: 0.35),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              CircleAvatar(
                radius: 44,
                backgroundColor: AppTheme.primaryViolet,
                backgroundImage: (_googleProfilePicture != null && _googleProfilePicture!.startsWith('http'))
                    ? NetworkImage(_googleProfilePicture!)
                    : null,
                child: (_googleProfilePicture == null || !_googleProfilePicture!.startsWith('http'))
                    ? const Icon(Icons.person_rounded, size: 48, color: Colors.white)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _usernameCtrl.text,
            style: const TextStyle(color: _textPrimary, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4),
          ),
          const SizedBox(height: 4),
          Text(
            _emailCtrl.text,
            style: const TextStyle(color: _textSecondary, fontSize: 13),
          ),
          if (_joinedDate.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              (isAr ? 'انضم في: ' : 'Joined: ') + _joinedDate,
              style: TextStyle(color: _textSecondary.withValues(alpha: 0.6), fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label, {Key? key}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.only(left: 4, bottom: 0),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: _textSecondary,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.9,
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }

  Widget _buildRowDivider() {
    return const Divider(color: _divider, height: 1, indent: 70);
  }

  Widget _buildNavRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
    Widget? trailing,
    bool inCard = false,
  }) {
    final effectiveColor = iconColor ?? AppTheme.primaryCyan;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: effectiveColor.withValues(alpha: 0.06),
        highlightColor: effectiveColor.withValues(alpha: 0.03),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              _iconCircle(icon: icon, color: iconColor),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: _textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: const TextStyle(color: _textSecondary, fontSize: 12.5)),
                  ],
                ),
              ),
              trailing ?? const Icon(Icons.chevron_right_rounded, color: _chevron, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconCircle({required IconData icon, Color? color, bool isDanger = false}) {
    final effective = isDanger ? _dangerRed : (color ?? AppTheme.primaryCyan);
    return Container(
      width: 38, height: 38,
      decoration: BoxDecoration(
        color: isDanger ? _dangerRed.withValues(alpha: 0.12) : _bgIcon,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6)],
      ),
      child: Icon(icon, size: 18, color: effective),
    );
  }

  Widget _buildLangToggle(bool isAr) {
    return Container(
      height: 34,
      width: 100,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
      ),
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            left: AppLocalization.isArabicNotifier.value ? 50 : 0,
            right: AppLocalization.isArabicNotifier.value ? 0 : 50,
            top: 0, bottom: 0,
            child: Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryCyan, AppTheme.primaryCyan.withValues(alpha: 0.8)],
                ),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [BoxShadow(color: AppTheme.primaryCyan.withValues(alpha: 0.3), blurRadius: 4)],
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
    );
  }

  Widget _buildThemeDropdown(String currentTheme, bool isAr) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentTheme,
          dropdownColor: const Color(0xFF15132C),
          icon: Icon(Icons.arrow_drop_down_rounded, color: AppTheme.primaryCyan),
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
          onChanged: (String? val) async {
            if (val != null) {
              AppTheme.switchTheme(val);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('app_theme', val);
            }
          },
          items: [
            DropdownMenuItem(value: 'dark',  child: Text(isAr ? 'داكن'  : 'Dark')),
            DropdownMenuItem(value: 'glass', child: Text(isAr ? 'زجاجي' : 'Glass')),
          ],
        ),
      ),
    );
  }
}