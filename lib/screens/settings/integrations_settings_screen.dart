import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../core/localization.dart';
import '../../widgets/app_snackbar.dart';

class IntegrationsSettingsScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;

  const IntegrationsSettingsScreen({super.key, this.initialData});

  @override
  State<IntegrationsSettingsScreen> createState() => _IntegrationsSettingsScreenState();
}

class _IntegrationsSettingsScreenState extends State<IntegrationsSettingsScreen> {
  final _aioUserCtrl = TextEditingController();
  final _aioKeyCtrl = TextEditingController();
  final _firebaseUrlCtrl = TextEditingController();
  final _firebaseSecretCtrl = TextEditingController();
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _aioUserCtrl.text = widget.initialData!['adafruitUsername'] ?? '';
      _aioKeyCtrl.text = widget.initialData!['adafruitApiKey'] ?? '';
      _firebaseUrlCtrl.text = widget.initialData!['firebaseUrl'] ?? '';
      _firebaseSecretCtrl.text = widget.initialData!['firebaseSecret'] ?? '';
    } else {
      _fetchData();
    }
  }

  @override
  void dispose() {
    _aioUserCtrl.dispose();
    _aioKeyCtrl.dispose();
    _firebaseUrlCtrl.dispose();
    _firebaseSecretCtrl.dispose();
    super.dispose();
  }

  void _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final userRes = await ApiService.userMe();
      if (mounted) {
        setState(() {
          _aioUserCtrl.text = userRes['adafruitUsername'] ?? '';
          _aioKeyCtrl.text = userRes['adafruitApiKey'] ?? '';
          _firebaseUrlCtrl.text = userRes['firebaseUrl'] ?? '';
          _firebaseSecretCtrl.text = userRes['firebaseSecret'] ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, 'Failed to load integration data');
        setState(() => _isLoading = false);
      }
    }
  }

  void _updateAdafruit() async {
    setState(() => _isLoading = true);
    try {
      final data = <String, dynamic>{
         'adafruitUsername': _aioUserCtrl.text.trim(),
         'adafruitApiKey': _aioKeyCtrl.text.trim(),
      };
      final res = await ApiService.userUpdate(data);
      if (mounted) {
        AppSnackbar.showSuccess(context, res['msg'] ?? AppLocalization.get('api_keys_saved'));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) AppSnackbar.showError(context, 'Failed to save Adafruit keys: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _updateFirebase() async {
    setState(() => _isLoading = true);
    try {
      final data = <String, dynamic>{
         'firebaseUrl': _firebaseUrlCtrl.text.trim(),
         'firebaseSecret': _firebaseSecretCtrl.text.trim(),
      };
      final res = await ApiService.userUpdate(data);
      if (mounted) {
        AppSnackbar.showSuccess(context, res['msg'] ?? AppLocalization.get('api_keys_saved'));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) AppSnackbar.showError(context, 'Failed to save Firebase keys: $e');
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
          borderSide: const BorderSide(color: AppTheme.glassBorder),
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
        title: Text(AppLocalization.isArabicNotifier.value ? 'الربط والبيانات' : 'Integrations'),
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
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBaseColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.primaryViolet.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryViolet.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.cloud_sync, color: AppTheme.primaryViolet),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Text(
                              'Adafruit IO',
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildTextField('Adafruit Username', _aioUserCtrl, Icons.cloud_circle_outlined),
                      const SizedBox(height: 16),
                      _buildTextField('Adafruit API Key', _aioKeyCtrl, Icons.vpn_key_outlined, isPassword: true),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryViolet,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isLoading ? null : _updateAdafruit,
                        child: const Text('Save Adafruit Keys', style: TextStyle(fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBaseColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.orangeAccent.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.storage, color: Colors.orangeAccent),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Text(
                              'Firebase RTDB',
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildTextField('Firebase Database URL', _firebaseUrlCtrl, Icons.link),
                      const SizedBox(height: 16),
                      _buildTextField('Firebase Database Secret', _firebaseSecretCtrl, Icons.security, isPassword: true),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orangeAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isLoading ? null : _updateFirebase,
                        child: const Text('Save Firebase Config', style: TextStyle(fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                ),
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
