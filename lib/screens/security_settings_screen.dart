import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../core/localization.dart';
import '../widgets/app_snackbar.dart';

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
      if (mounted) {
        setState(() {
          _sessions = sessionsRes;
        });
      }
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
    } catch(e) {
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
         AppSnackbar.showSuccess(context, AppLocalization.isArabicNotifier.value ? 'تم إنهاء الجلسة' : 'Session terminated');
       }
    } catch (e) {
       if (mounted) AppSnackbar.showError(context, 'Failed to terminate session');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: Text(AppLocalization.get('security_settings')),
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(decoration: AppTheme.glassDecoration(borderRadius: BorderRadius.zero)),
        elevation: 0,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 2FA Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBaseColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _twoFactorEnabled ? AppTheme.primaryCyan.withValues(alpha: 0.3) : Colors.white12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _twoFactorEnabled ? AppTheme.primaryCyan.withValues(alpha: 0.2) : Colors.white10,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.security, color: _twoFactorEnabled ? AppTheme.primaryCyan : Colors.white54, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocalization.get('two_factor_auth'),
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _twoFactorEnabled ? AppLocalization.get('enabled') : AppLocalization.get('disabled'),
                              style: TextStyle(color: _twoFactorEnabled ? AppTheme.primaryCyan : Colors.white54, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      if (_is2FALoading)
                        const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryCyan))
                      else
                        Switch(
                          value: _twoFactorEnabled,
                          onChanged: (val) => _toggle2FA(),
                          activeColor: AppTheme.primaryCyan,
                        ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                Text(
                  AppLocalization.get('active_sessions'),
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                
                if (_sessions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator(color: AppTheme.primaryCyan)),
                  )
                else
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

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBaseColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: ListTile(
                         contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                         leading: Container(
                           padding: const EdgeInsets.all(10),
                           decoration: BoxDecoration(
                             color: Colors.white.withValues(alpha: 0.05),
                             borderRadius: BorderRadius.circular(12),
                           ),
                           child: Icon(deviceIcon, color: AppTheme.primaryCyan, size: 24),
                         ),
                         title: Text(deviceName, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                         subtitle: Text(deviceInfo['ip'] ?? s['ip'] ?? 'Unknown IP', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                         trailing: IconButton(
                           icon: const Icon(Icons.power_settings_new, color: Colors.redAccent),
                           tooltip: AppLocalization.isArabicNotifier.value ? 'إنهاء الجلسة' : 'Terminate',
                           onPressed: () => _terminateSession(s['id']),
                         ),
                      ),
                    );
                  }),
              ],
            ),
          ),
          if (_isLoading && _sessions.isEmpty)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryCyan),
              ),
            ),
        ],
      ),
    );
  }
}
