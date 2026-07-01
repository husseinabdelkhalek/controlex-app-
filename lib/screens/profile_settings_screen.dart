import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../core/localization.dart';
import '../widgets/app_snackbar.dart';

class ProfileSettingsScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;

  const ProfileSettingsScreen({super.key, this.initialData});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;
  String? _googleProfilePicture;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _usernameCtrl.text = widget.initialData!['username'] ?? '';
      _emailCtrl.text = widget.initialData!['email'] ?? '';
      _googleProfilePicture = widget.initialData!['googleProfilePicture'];
    } else {
      _fetchData();
    }
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final userRes = await ApiService.userMe();
      if (mounted) {
        setState(() {
          _usernameCtrl.text = userRes['username'] ?? '';
          _emailCtrl.text = userRes['email'] ?? '';
          _googleProfilePicture = userRes['googleProfilePicture'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, 'Failed to load profile data');
        setState(() => _isLoading = false);
      }
    }
  }

  void _updateProfile() async {
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text.trim();
    
    if (email.isNotEmpty && !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      AppSnackbar.showError(context, AppLocalization.isArabicNotifier.value ? 'يرجى إدخال بريد إلكتروني صحيح' : 'Please enter a valid email');
      return;
    }

    if (password.isNotEmpty && password.length < 6) {
      AppSnackbar.showError(context, AppLocalization.isArabicNotifier.value ? 'كلمة المرور يجب أن تكون 6 أحرف على الأقل' : 'Password must be at least 6 characters');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final data = <String, dynamic>{
         'username': _usernameCtrl.text.trim(),
      };
      if (email.isNotEmpty) data['email'] = email;
      if (password.isNotEmpty) data['password'] = password;
      
      final res = await ApiService.userUpdate(data);
      if (mounted) {
        AppSnackbar.showSuccess(context, res['msg'] ?? AppLocalization.get('profile_updated'));
        Navigator.pop(context, true); // Return true to indicate change
      }
    } catch (e) {
      if (mounted) AppSnackbar.showError(context, 'Update failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {bool isPassword = false}) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: AppTheme.primaryCyan),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.primaryCyan.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryCyan, width: 2),
        ),
        filled: true,
        fillColor: AppTheme.cardBaseColor.withValues(alpha: 0.3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: Text(AppLocalization.get('personal_info')),
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
                Center(
                  child: Hero(
                    tag: 'profile_avatar',
                    child: CircleAvatar(
                      radius: 50, 
                      backgroundColor: AppTheme.primaryViolet, 
                      backgroundImage: (_googleProfilePicture != null && _googleProfilePicture!.startsWith('http')) ? NetworkImage(_googleProfilePicture!) : null,
                      child: (_googleProfilePicture == null || !_googleProfilePicture!.startsWith('http')) ? const Icon(Icons.person, size: 50, color: Colors.white) : null
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                _buildTextField(AppLocalization.get('username'), _usernameCtrl, Icons.person_outline),
                const SizedBox(height: 16),
                _buildTextField(AppLocalization.get('email'), _emailCtrl, Icons.email_outlined),
                const SizedBox(height: 16),
                _buildTextField(AppLocalization.get('new_password_optional'), _passCtrl, Icons.lock_outline, isPassword: true),
                const SizedBox(height: 32),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryCyan,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                    shadowColor: AppTheme.primaryCyan.withValues(alpha: 0.5),
                  ),
                  onPressed: _isLoading ? null : _updateProfile,
                  child: Text(
                    AppLocalization.get('update_profile'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                )
              ],
            ),
          ),
          if (_isLoading)
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
