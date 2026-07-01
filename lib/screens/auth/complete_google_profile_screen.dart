import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../dashboard_screen.dart';

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
  bool _isLoading = false;

  @override
  void dispose() {
    _aioUserCtrl.dispose();
    _aioKeyCtrl.dispose();
    _firebaseUrlCtrl.dispose();
    _firebaseSecretCtrl.dispose();
    super.dispose();
  }

  void _save() async {
    setState(() => _isLoading = true);
    try {
      await ApiService.userUpdate({
        'adafruitUsername': _aioUserCtrl.text.trim(),
        'adafruitApiKey': _aioKeyCtrl.text.trim(),
        'firebaseUrl': _firebaseUrlCtrl.text.trim(),
        'firebaseSecret': _firebaseSecretCtrl.text.trim(),
      });
    } catch (_) {}
    setState(() => _isLoading = false);
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
        (r) => false,
      );
    }
  }

  void _skip() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
      (r) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0C10),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0B0C10), Color(0xFF1F2833)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                // Welcome icon
                Container(
                  width: 80, height: 80,
                  margin: const EdgeInsets.symmetric(horizontal: 140),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF00FFCC).withValues(alpha: 0.15),
                    border: Border.all(color: const Color(0xFF00FFCC), width: 2),
                  ),
                  child: const Icon(Icons.waving_hand, color: Color(0xFF00FFCC), size: 40),
                ),
                const SizedBox(height: 24),
                Text(
                  'أهلاً ${widget.username}! 👋',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'تم إنشاء حسابك بنجاح عبر جوجل.\nأضف بيانات Adafruit للتحكم في أجهزتك.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.6),
                ),
                const SizedBox(height: 40),

                // Adafruit section
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF00FFCC).withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.cloud_sync, color: Color(0xFF00FFCC), size: 20),
                          const SizedBox(width: 8),
                          const Text('Adafruit IO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(20)),
                            child: const Text('اختياري', style: TextStyle(color: Colors.white38, fontSize: 10)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text('للتحكم في لوحات Arduino/ESP عبر الإنترنت', style: TextStyle(color: Colors.white38, fontSize: 11)),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _aioUserCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'اسم مستخدم Adafruit',
                          labelStyle: const TextStyle(color: Colors.white54),
                          hintText: 'اسم المستخدم في Adafruit IO',
                          hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                          prefixIcon: const Icon(Icons.cloud_circle_outlined, color: Colors.white54),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white24)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF00FFCC))),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _aioKeyCtrl,
                        obscureText: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'مفتاح Adafruit API',
                          labelStyle: const TextStyle(color: Colors.white54),
                          hintText: 'مفتاح API من لوحة تحكم Adafruit',
                          hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                          prefixIcon: const Icon(Icons.vpn_key_outlined, color: Colors.white54),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white24)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF00FFCC))),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
                SizedBox(
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00FFCC),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 8,
                      shadowColor: const Color(0xFF00FFCC).withValues(alpha: 0.4),
                    ),
                    onPressed: _isLoading ? null : _save,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.black)
                        : const Text('حفظ والمتابعة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _skip,
                  child: const Text('تخطي الآن، سأضيفها لاحقاً', style: TextStyle(color: Colors.white38, fontSize: 13)),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
