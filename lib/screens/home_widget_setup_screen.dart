import '../widgets/app_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:home_widget/home_widget.dart';
import '../theme/app_theme.dart';
import '../core/localization.dart';
import '../widgets/glowing_button.dart';

class HomeWidgetSetupScreen extends StatefulWidget {
  const HomeWidgetSetupScreen({super.key});

  @override
  State<HomeWidgetSetupScreen> createState() => _HomeWidgetSetupScreenState();
}

class _HomeWidgetSetupScreenState extends State<HomeWidgetSetupScreen> {
  bool _isLoading = false;

  Future<void> _pinWidget(String providerName) async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_home_widget', true); // Don't show promo again

      await HomeWidget.requestPinWidget(
        name: providerName,
        androidName: providerName,
      );

      if (mounted) {
        AppSnackbar.showSuccess(context, 
              AppLocalization.isArabicNotifier.value
                  ? 'تم طلب إضافة الودجت بنجاح! راجع شاشتك الرئيسية أو قم بإضافتها يدوياً.'
                  : 'Widget pin requested successfully! Check your home screen or add it manually.',
            );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, 'Error: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalization.isArabicNotifier.value;
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundBase,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(isArabic ? 'ودجت الشاشة الرئيسية' : 'Home Screen Widget'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.widgets_outlined, size: 80, color: AppTheme.primaryViolet),
            SizedBox(height: 24),
            Text(
              isArabic 
                  ? 'كيفية تخصيص الودجات للأدوات:' 
                  : 'How to assign widgets to tools:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32),
            
            _buildStep(
              number: '1',
              title: isArabic ? 'أضف الودجت للشاشة' : 'Add Widget to Screen',
              desc: isArabic 
                  ? 'اضغط على الزر بالأسفل لإنشاء ودجت فارغ على شاشتك الرئيسية، أو قم بإضافتها يدوياً.' 
                  : 'Tap the button below to pin an empty widget to your home screen, or add it manually.',
            ),
            SizedBox(height: 16),
            _buildStep(
              number: '2',
              title: isArabic ? 'اضغط للإعداد' : 'Tap to Setup',
              desc: isArabic 
                  ? 'اذهب للشاشة الرئيسية واضغط على الودجت الجديد الذي سيظهر بداخله "اضغط للإعداد".' 
                  : 'Go to your home screen and tap the new widget that says "Tap to Setup".',
            ),
            SizedBox(height: 16),
            _buildStep(
              number: '3',
              title: isArabic ? 'اختر الأداة' : 'Select Tool',
              desc: isArabic 
                  ? 'سيفتح لك التطبيق لتختار الأداة التي تريد ربطها (مثلاً: إضاءة الغرفة)، وسيظل الودجت مرتبطاً بها!' 
                  : 'The app will open and ask you to select a tool (e.g. Room Light), and it will stay linked forever!',
            ),
            
            SizedBox(height: 48),
            GlowingButton(
              isLoading: _isLoading,
              onPressed: () => _pinWidget('ControlExWidgetProvider'),
              child: Text(isArabic ? 'إضافة ودجت صغير (2x1)' : 'Pin Small Widget (2x1)'),
            ),
            SizedBox(height: 16),
            GlowingButton(
              isLoading: _isLoading,
              onPressed: () => _pinWidget('ControlExLargeWidgetProvider'),
              child: Text(isArabic ? 'إضافة ودجت متوسط (2x2)' : 'Pin Medium Widget (2x2)'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep({required String number, required String title, required String desc}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppTheme.primaryViolet.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.primaryViolet),
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(color: AppTheme.primaryCyan, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                desc,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
