import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../core/localization.dart';
import '../screens/home_widget_setup_screen.dart';
import 'glowing_button.dart';
import 'glass_card.dart';
import 'glass_popups.dart';

class PromoDialogWidget extends StatelessWidget {
  const PromoDialogWidget({Key? key}) : super(key: key);

  static void show(BuildContext context) {
    showGlassModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const PromoDialogWidget(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isArabic = AppLocalization.isArabicNotifier.value;
    return GlassCard(
      baseColor: AppTheme.cardBaseColor.withValues(alpha: 0.65),
      borderColor: AppTheme.primaryViolet,
      borderRadius: 30.0,
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Pull bar
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: Colors.white30,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                
                // Title
                Text(
                  isArabic ? 'اكتشف الميزات الجديدة! 🚀' : 'Discover New Features! 🚀',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                
                // Description
                Text(
                  isArabic 
                    ? 'لقد أضفنا للتو "اختصارات التطبيق"! يمكنك الآن الضغط مطولاً على أيقونة التطبيق من الشاشة الرئيسية للوصول السريع إلى الأتمتة والمشاهد والتحكم المحلي.\n\nوقريباً جداً، سنوفر "ودجات الشاشة الرئيسية" بتصميم زجاجي رائع كما بالصورة للتحكم بأجهزتك دون الحاجة لفتح التطبيق.'
                    : 'We just added "App Quick Actions"! Long-press the app icon to quickly jump into Automations, Scenes, or Local Control.\n\nComing very soon: "Home Screen Widgets" with a stunning glassmorphic design to control your devices instantly without opening the app.',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                
                // Mockup Image
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryCyan.withValues(alpha: 0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                      )
                    ],
                    border: Border.all(
                      color: AppTheme.primaryCyan.withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset(
                      'assets/images/widgets_mockup.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 200,
                        color: Colors.black26,
                        child: const Center(
                          child: Icon(Icons.image_not_supported, color: Colors.white24, size: 40),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                
                // Action Button
                GlowingButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('has_seen_promo_permanently', true);
                    if (context.mounted) {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const HomeWidgetSetupScreen()),
                      );
                    }
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_outline, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(isArabic ? 'رائع، سأجربها!' : 'Awesome, I will try it!'),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Do not show again
                TextButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('has_seen_promo_permanently', true);
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: Text(
                    isArabic ? 'لا تظهر هذه الرسالة مرة أخرى' : 'Do not show again',
                    style: const TextStyle(
                      color: Colors.white54,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white54,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
