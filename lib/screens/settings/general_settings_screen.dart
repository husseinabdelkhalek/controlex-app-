import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../core/localization.dart';
import 'profile_settings_screen.dart';
import 'integrations_settings_screen.dart';
import 'security_settings_screen.dart';

class GeneralSettingsScreen extends StatefulWidget {
  const GeneralSettingsScreen({super.key});

  @override
  State<GeneralSettingsScreen> createState() => _GeneralSettingsScreenState();
}

class _GeneralSettingsScreenState extends State<GeneralSettingsScreen> {
  bool _isLoading = true;
  String _username = '';
  String _email = '';
  String? _googleProfilePicture;
  String _aioUser = '';
  String _aioKey = '';
  String _firebaseUrl = '';
  String _firebaseSecret = '';
  bool _twoFactorEnabled = false;
  List<dynamic> _sessions = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  void _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final userRes = await ApiService.userMe();
      final sessionsRes = await ApiService.getSessions();
      if (mounted) {
        setState(() {
          _username = userRes['username'] ?? '';
          _email = userRes['email'] ?? '';
          _aioUser = userRes['adafruitUsername'] ?? '';
          _aioKey = userRes['adafruitApiKey'] ?? '';
          _firebaseUrl = userRes['firebaseUrl'] ?? '';
          _firebaseSecret = userRes['firebaseSecret'] ?? '';
          _googleProfilePicture = userRes['googleProfilePicture'];
          _twoFactorEnabled = userRes['security']?['twoFactorEnabled'] ?? false;
          _sessions = sessionsRes;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildGlassButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
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

  @override
  Widget build(BuildContext context) {
    final isAr = AppLocalization.isArabicNotifier.value;
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: Text(
          isAr ? 'الإعدادات العامة' : 'General Settings',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppTheme.primaryCyan))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildGlassButton(
                    icon: Icons.badge,
                    title: AppLocalization.get('personal_info'),
                    subtitle: isAr ? 'تعديل بيانات الحساب' : 'Edit profile details',
                    color: AppTheme.primaryCyan,
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProfileSettingsScreen(
                            initialData: {
                              'username': _username,
                              'email': _email,
                              'googleProfilePicture': _googleProfilePicture,
                            },
                          ),
                        ),
                      );
                      if (result == true) _fetchData();
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildGlassButton(
                    icon: Icons.cloud_sync,
                    title: isAr ? 'الربط والبيانات' : 'Integrations',
                    subtitle: isAr ? 'إعدادات Adafruit و Firebase' : 'Adafruit & Firebase settings',
                    color: AppTheme.primaryViolet,
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => IntegrationsSettingsScreen(
                            initialData: {
                              'adafruitUsername': _aioUser,
                              'adafruitApiKey': _aioKey,
                              'firebaseUrl': _firebaseUrl,
                              'firebaseSecret': _firebaseSecret,
                            },
                          ),
                        ),
                      );
                      if (result == true) _fetchData();
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildGlassButton(
                    icon: Icons.security,
                    title: AppLocalization.get('security_settings'),
                    subtitle: isAr ? 'التحقق بخطوتين والجلسات' : '2FA & Active Sessions',
                    color: Colors.greenAccent,
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
                  ),
                ],
              ),
            ),
    );
  }
}
