import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../core/localization.dart';
import '../../widgets/app_snackbar.dart';

class DeviceSetupScreen extends StatefulWidget {
  const DeviceSetupScreen({super.key});

  @override
  State<DeviceSetupScreen> createState() => _DeviceSetupScreenState();
}

class _DeviceSetupScreenState extends State<DeviceSetupScreen> {
  final _codeCtrl = TextEditingController();
  bool _isLoading = false;
  
  bool _isChecking = false;
  bool? _isValid;
  int _widgetsCount = 0;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _codeCtrl.addListener(_onCodeChanged);
  }

  @override
  void dispose() {
    _codeCtrl.removeListener(_onCodeChanged);
    _codeCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onCodeChanged() {
    final text = _codeCtrl.text.trim().toUpperCase();
    if (text.isEmpty) {
      setState(() {
        _isValid = null;
        _isChecking = false;
        _widgetsCount = 0;
      });
      return;
    }

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      if (text.length >= 9) {
        setState(() {
          _isChecking = true;
          _isValid = null;
        });
        try {
          final result = await ApiService.verifySetupCode(text);
          setState(() {
            _isChecking = false;
            _isValid = result['valid'] == true;
            _widgetsCount = result['widgetCount'] ?? 0;
          });
        } catch (_) {
          setState(() {
            _isChecking = false;
            _isValid = false;
            _widgetsCount = 0;
          });
        }
      } else {
        setState(() {
          _isValid = null;
          _isChecking = false;
        });
      }
    });
  }

  void _applyCode() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      AppSnackbar.showWarning(
        context,
        AppLocalization.isArabicNotifier.value ? 'يرجى إدخال كود التفعيل أولاً' : 'Please enter setup code first',
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final res = await ApiService.applySetupCode(code);
      if (mounted) {
        AppSnackbar.showSuccess(
          context,
          res['msg'] ?? (AppLocalization.isArabicNotifier.value ? 'تم تفعيل وربط إعدادات جهازك بنجاح!' : 'Device activated successfully!'),
        );
        Navigator.pop(context, true); // return true to refresh dashboard/widgets
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(
          context,
          e.toString().replaceAll('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildGlassSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBaseColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryCyan.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: TextStyle(color: AppTheme.primaryCyan, fontWeight: FontWeight.bold, fontSize: 16)),
          SizedBox(height: 16),
          ...children
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAr = AppLocalization.isArabicNotifier.value;
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: Text(AppLocalization.get('ready_device_setup')),
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
                _buildGlassSection(
                  AppLocalization.get('device_activation_code'),
                  [
                    Text(
                      AppLocalization.get('device_activation_code_desc'),
                      style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.6),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _codeCtrl,
                      style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 18, letterSpacing: 2, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: AppLocalization.get('setup_code_label'),
                        labelStyle: const TextStyle(color: Colors.white54, fontSize: 14),
                        hintText: 'CX-XXXXXX',
                        hintStyle: const TextStyle(color: Colors.white24, fontSize: 16),
                        prefixIcon: Icon(Icons.developer_board, color: AppTheme.primaryCyan),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.glassBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.glassBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.primaryCyan, width: 2),
                        ),
                        filled: true,
                        fillColor: AppTheme.cardBaseColor.withValues(alpha: 0.3),
                      ),
                    ),
                    if (_isChecking)
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0, left: 4, right: 4),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryCyan),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isAr ? 'جاري التحقق...' : 'Checking...',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    else if (_isValid != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0, left: 4, right: 4),
                        child: Text(
                          _isValid!
                              ? (isAr 
                                  ? 'كود تفعيل صالح — يحتوي على $_widgetsCount من الأدوات' 
                                  : 'Valid setup code — contains $_widgetsCount widgets')
                              : (isAr 
                                  ? 'كود تفعيل غير صالح أو مستخدم' 
                                  : 'Invalid or used setup code'),
                          style: TextStyle(
                            color: _isValid! ? AppTheme.primaryCyan : Colors.redAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryCyan,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                        shadowColor: AppTheme.primaryCyan.withValues(alpha: 0.5),
                      ),
                      onPressed: _isLoading || _isValid != true ? null : _applyCode,
                      child: Text(
                        isAr ? 'تفعيل وإعداد الجهاز' : 'Activate & Setup Device',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    )
                  ],
                ),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: Center(
                child: CircularProgressIndicator(color: AppTheme.primaryCyan),
              ),
            ),
        ],
      ),
    );
  }
}
