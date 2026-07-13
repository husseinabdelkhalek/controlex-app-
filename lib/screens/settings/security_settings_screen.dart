import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../core/localization.dart';
import '../../widgets/app_snackbar.dart';
import '../auth/login_screen.dart';
import '../../services/socket_service.dart';

class SecuritySettingsScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final List<dynamic>? initialSessions;

  const SecuritySettingsScreen({super.key, this.initialData, this.initialSessions});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  bool _twoFactorEnabled = false;
  bool _isLoading = false;
  bool _is2FALoading = false;
  List<dynamic> _sessions = [];
  bool _showAllSessions = false;

  // ── Design tokens (mirrors Klivvr design system) ──────────────────────
  static const _bgCard        = Color(0xFF111119);
  static const _bgIcon        = Color(0xFF1e1e2a);
  static const _dangerRed     = Color(0xFFFF453A);
  static const _divider       = Color(0x0FFFFFFF);   // 6% white
  static const _textPrimary   = Color(0xFFF2F2F7);
  static const _textSecondary = Color(0xFF8E8E9E);
  static const _chevron       = Color(0xFF4A4A5A);

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _twoFactorEnabled = widget.initialData!['security']?['twoFactorEnabled'] ?? false;
      if (widget.initialSessions != null) {
        _sessions = widget.initialSessions!;
      } else {
        _fetchSessions();
      }
    } else {
      _fetchData();
    }
  }

  void _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final userRes = await ApiService.userMe();
      final sessionsRes = await ApiService.getSessions();
      if (mounted) {
        setState(() {
          _twoFactorEnabled = userRes['security']?['twoFactorEnabled'] ?? false;
          _sessions = sessionsRes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, 'Failed to load security data');
        setState(() => _isLoading = false);
      }
    }
  }

  void _fetchSessions() async {
    try {
      final sessionsRes = await ApiService.getSessions();
      if (mounted) setState(() => _sessions = sessionsRes);
    } catch (_) {}
  }

  void _toggle2FA() async {
    if (_is2FALoading) return;
    setState(() => _is2FALoading = true);
    try {
      if (_twoFactorEnabled) {
        final res = await ApiService.disable2FA();
        if (mounted) {
          AppSnackbar.showSuccess(context, res['msg'] ?? AppLocalization.get('disabled'));
          setState(() => _twoFactorEnabled = false);
        }
      } else {
        final res = await ApiService.enable2FA();
        if (mounted) {
          AppSnackbar.showSuccess(context, res['msg'] ?? AppLocalization.get('enabled'));
          setState(() => _twoFactorEnabled = true);
        }
      }
    } catch (e) {
      if (mounted) AppSnackbar.showError(context, 'خطأ: $e (تأكد من تحديث السيرفر)');
    } finally {
      if (mounted) setState(() => _is2FALoading = false);
    }
  }

  void _terminateSession(String id) async {
    try {
      await ApiService.terminateSession(id);
      _fetchSessions();
      if (mounted) {
        AppSnackbar.showSuccess(
          context,
          AppLocalization.isArabicNotifier.value ? 'تم إنهاء الجلسة' : 'Session terminated',
        );
      }
    } catch (e) {
      if (mounted) AppSnackbar.showError(context, 'Failed to terminate session');
    }
  }

  // ── Danger Zone handlers ───────────────────────────────────────────────
  void _clearData() async {
    final confirmed = await _showDangerBottomSheet(
      icon: Icons.delete_sweep_rounded,
      title: AppLocalization.isArabicNotifier.value ? 'حذف البيانات؟' : 'Delete My Data?',
      description: AppLocalization.isArabicNotifier.value
          ? 'سيتم مسح جميع أجهزتك وأتمتتك ومشاهدك المحفوظة بشكل دائم. لا يمكن التراجع عن هذا الإجراء.'
          : 'All your devices, automations, and saved scenes will be permanently erased. This action cannot be reversed.',
      confirmLabel: AppLocalization.isArabicNotifier.value ? 'حذف البيانات' : 'Delete My Data',
    );
    if (!confirmed || !mounted) return;
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.clearData();
      if (mounted) {
        AppSnackbar.showSuccess(context, res['msg'] ?? AppLocalization.get('data_cleared'));
        _fetchData();
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, 'فشل مسح البيانات: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  void _deleteAccount() async {
    final confirmed = await _showDangerBottomSheet(
      icon: Icons.person_remove_rounded,
      title: AppLocalization.isArabicNotifier.value ? 'حذف الحساب؟' : 'Delete Account?',
      description: AppLocalization.isArabicNotifier.value
          ? 'سيتم حذف حسابك في ControleX وجميع بياناتك ورصيدك بشكل نهائي. لا يمكن التراجع عن هذا الإجراء إطلاقاً.'
          : 'Your ControleX account, devices, and all associated data will be permanently deleted. You will not be able to recover it.',
      confirmLabel: AppLocalization.isArabicNotifier.value ? 'حذف حسابي' : 'Delete My Account',
    );
    if (!confirmed || !mounted) return;
    setState(() => _isLoading = true);
    try {
      await ApiService.deleteAccount();
      try { SocketService.disconnect(); } catch (_) {}
      await ApiService.clearAuth();
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (r) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, 'حدث خطأ: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  /// Slide-up danger confirmation sheet (Klivvr style).
  Future<bool> _showDangerBottomSheet({
    required IconData icon,
    required String title,
    required String description,
    required String confirmLabel,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DangerBottomSheet(
        icon: icon,
        title: title,
        description: description,
        confirmLabel: confirmLabel,
      ),
    );
    return result == true;
  }

  // ─────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isAr = AppLocalization.isArabicNotifier.value;
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _buildBackButton(context),
        title: Text(
          isAr ? 'الخصوصية والأمان' : 'Privacy & Security',
          style: const TextStyle(
            color: _textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Main Security Card ─────────────────────────────
                _buildCard([
                  // 2FA row
                  _buildToggleRow(
                    icon: Icons.security_rounded,
                    title: AppLocalization.get('two_factor_auth'),
                    subtitle: isAr
                        ? 'حماية إضافية بكود يُرسل إلى بريدك الإلكتروني'
                        : 'Extra protection via email verification code',
                    value: _twoFactorEnabled,
                    loading: _is2FALoading,
                    onChanged: (_) => _toggle2FA(),
                  ),
                ]),

                const SizedBox(height: 14),

                // ── Active Sessions ────────────────────────────────
                _buildSectionLabel(isAr ? 'الجلسات النشطة' : 'Active Sessions'),
                const SizedBox(height: 8),

                if (_sessions.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else ...[
                  ..._sessions.take(_showAllSessions ? _sessions.length : 3).map((s) {
                    final deviceInfo = s['deviceInfo'] ?? {};
                    final deviceName = deviceInfo['deviceName'] ?? deviceInfo['userAgent'] ?? 'PC / Browser';
                    final platform = (deviceInfo['platform'] ?? '').toString().toLowerCase();
                    IconData deviceIcon = Icons.laptop_rounded;
                    if (platform.contains('android') || deviceName.toLowerCase().contains('android')) {
                      deviceIcon = Icons.phone_android_rounded;
                    } else if (platform.contains('ios') ||
                        deviceName.toLowerCase().contains('iphone') ||
                        deviceName.toLowerCase().contains('ipad') ||
                        deviceName.toLowerCase().contains('apple')) {
                      deviceIcon = Icons.phone_iphone_rounded;
                    }
                    return _buildSessionTile(
                      icon: deviceIcon,
                      name: deviceName,
                      ip: deviceInfo['ip'] ?? s['ip'] ?? 'Unknown IP',
                      onTerminate: () => _terminateSession(s['id']),
                    );
                  }),
                  if (_sessions.length > 3)
                    GestureDetector(
                      onTap: () => setState(() => _showAllSessions = !_showAllSessions),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _showAllSessions 
                                  ? (isAr ? 'إخفاء الأجهزة' : 'Hide devices') 
                                  : (isAr ? 'عرض كل الأجهزة (${_sessions.length})' : 'Show all devices (${_sessions.length})'),
                              style: const TextStyle(color: _textSecondary, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              _showAllSessions ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                              color: _textSecondary,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],

                // ── Danger Zone Divider ────────────────────────────
                const SizedBox(height: 24),
                _buildDangerDivider(isAr ? 'منطقة الخطر' : 'Danger Zone'),
                const SizedBox(height: 10),

                // ── Danger Actions Card ────────────────────────────
                _buildCard([
                  _buildDangerRow(
                    icon: Icons.delete_sweep_rounded,
                    title: isAr ? 'حذف البيانات' : 'Delete My Data',
                    subtitle: isAr
                        ? 'مسح الأجهزة والأتمتة والمشاهد بشكل دائم'
                        : 'Permanently erase all devices, automations & scenes',
                    onTap: _clearData,
                  ),
                  _buildRowDivider(),
                  _buildDangerRow(
                    icon: Icons.person_remove_rounded,
                    title: isAr ? 'حذف الحساب' : 'Delete Account',
                    subtitle: isAr
                        ? 'إغلاق حسابك نهائياً. لا يمكن التراجع عن هذا.'
                        : 'Permanently close your account. This cannot be undone.',
                    onTap: _deleteAccount,
                  ),
                ]),

                const SizedBox(height: 40),
              ],
            ),
          ),

          // Full-screen loading overlay
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // WIDGET BUILDERS
  // ─────────────────────────────────────────────────────────────────────

  Widget _buildBackButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          width: 38, height: 38,
          decoration: const BoxDecoration(color: _bgIcon, shape: BoxShape.circle),
          child: const Icon(Icons.arrow_back_ios_new_rounded, color: _textPrimary, size: 16),
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
      child: Column(children: children),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
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

  Widget _buildRowDivider() {
    return const Divider(color: _divider, height: 1, indent: 70);
  }

  // ── Toggle Row (2FA) ───────────────────────────────────────────────────
  Widget _buildToggleRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required bool loading,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          _iconCircle(icon: icon),
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
          if (loading)
            const SizedBox(
              width: 24, height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: const Color(0xFF30D158),
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: const Color(0xFF3A3A4A),
              trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
            ),
        ],
      ),
    );
  }

  // ── Danger Row ────────────────────────────────────────────────────────
  Widget _buildDangerRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: _dangerRed.withValues(alpha: 0.08),
        highlightColor: _dangerRed.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              _iconCircle(icon: icon, isDanger: true),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: _dangerRed, fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: TextStyle(color: _dangerRed.withValues(alpha: 0.55), fontSize: 12.5)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: _chevron, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  // ── Session Tile ──────────────────────────────────────────────────────
  Widget _buildSessionTile({
    required IconData icon,
    required String name,
    required String ip,
    required VoidCallback onTerminate,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: _iconCircle(icon: icon),
        title: Text(name, style: const TextStyle(color: _textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Text(ip, style: const TextStyle(color: _textSecondary, fontSize: 12)),
        trailing: IconButton(
          icon: const Icon(Icons.power_settings_new_rounded, color: _dangerRed, size: 22),
          tooltip: AppLocalization.isArabicNotifier.value ? 'إنهاء الجلسة' : 'Terminate',
          onPressed: onTerminate,
        ),
      ),
    );
  }

  // ── Danger Zone Divider ───────────────────────────────────────────────
  Widget _buildDangerDivider(String label) {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: _dangerRed.withValues(alpha: 0.14))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              color: _dangerRed.withValues(alpha: 0.42),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ),
        Expanded(child: Container(height: 1, color: _dangerRed.withValues(alpha: 0.14))),
      ],
    );
  }

  // ── Icon Circle ───────────────────────────────────────────────────────
  Widget _iconCircle({required IconData icon, bool isDanger = false}) {
    return Container(
      width: 38, height: 38,
      decoration: BoxDecoration(
        color: isDanger ? _dangerRed.withValues(alpha: 0.12) : _bgIcon,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6)],
      ),
      child: Icon(icon, size: 18, color: isDanger ? _dangerRed : _textPrimary),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// DANGER BOTTOM SHEET  –  Klivvr-style confirmation modal
// ═══════════════════════════════════════════════════════════════════════
class _DangerBottomSheet extends StatefulWidget {
  final IconData icon;
  final String title;
  final String description;
  final String confirmLabel;

  const _DangerBottomSheet({
    required this.icon,
    required this.title,
    required this.description,
    required this.confirmLabel,
  });

  @override
  State<_DangerBottomSheet> createState() => _DangerBottomSheetState();
}

class _DangerBottomSheetState extends State<_DangerBottomSheet> {
  final _ctrl = TextEditingController();
  bool _inputError = false;

  static const _bgCard    = Color(0xFF111119);
  static const _bgItem    = Color(0xFF16161F);
  static const _dangerRed = Color(0xFFFF453A);
  static const _textPrimary   = Color(0xFFF2F2F7);
  static const _textSecondary = Color(0xFF8E8E9E);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onConfirm() {
    if (_ctrl.text.trim().toUpperCase() != 'DELETE') {
      setState(() => _inputError = true);
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final isAr = AppLocalization.isArabicNotifier.value;
    return Container(
      decoration: const BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Icon
            Container(
              width: 68, height: 68,
              decoration: BoxDecoration(
                color: _dangerRed.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(widget.icon, color: _dangerRed, size: 32),
            ),
            const SizedBox(height: 16),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                widget.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Description
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                widget.description,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _textSecondary, fontSize: 14, height: 1.55),
              ),
            ),

            // Input label
            Padding(
              padding: const EdgeInsets.only(left: 24, right: 24, top: 22, bottom: 8),
              child: Align(
                alignment: isAr ? Alignment.centerRight : Alignment.centerLeft,
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(color: _textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                    children: [
                      TextSpan(text: isAr ? 'اكتب ' : 'Type '),
                      const TextSpan(
                        text: 'DELETE',
                        style: TextStyle(color: _dangerRed, fontWeight: FontWeight.w700),
                      ),
                      TextSpan(text: isAr ? ' للتأكيد' : ' to confirm'),
                    ],
                  ),
                ),
              ),
            ),

            // Text field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextField(
                controller: _ctrl,
                textAlign: TextAlign.center,
                autocorrect: false,
                style: const TextStyle(color: _textPrimary, fontSize: 15),
                onChanged: (_) => setState(() => _inputError = false),
                decoration: InputDecoration(
                  hintText: isAr ? 'اكتب DELETE هنا…' : 'Type DELETE here…',
                  hintStyle: const TextStyle(color: _textSecondary),
                  filled: true,
                  fillColor: _bgItem,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: _inputError ? _dangerRed : _dangerRed.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _dangerRed, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  errorText: _inputError
                      ? (isAr ? 'يرجى كتابة DELETE بالضبط' : 'Please type DELETE exactly')
                      : null,
                ),
              ),
            ),

            // Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Confirm (red)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _dangerRed,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _onConfirm,
                    child: Text(
                      widget.confirmLabel,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.1),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Cancel
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _textPrimary,
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(
                      isAr ? 'إلغاء' : 'Cancel',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
