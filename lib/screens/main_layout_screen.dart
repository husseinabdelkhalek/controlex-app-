import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';
import 'local_dashboard_screen.dart';
import 'automations_screen.dart';
import 'smart_scenes_screen.dart';
import 'settings/account_screen.dart';
import '../widgets/custom_bottom_nav.dart';
import '../widgets/expandable_assistant_fab.dart';
import '../widgets/ai_floating_button.dart';
import '../widgets/app_tour_overlay.dart';
import '../core/tour_keys.dart';

class MainLayoutScreen extends StatefulWidget {
  final String? widgetSetupId;

  const MainLayoutScreen({super.key, this.widgetSetupId});

  @override
  State<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends State<MainLayoutScreen> {
  int _currentIndex = 0;
  bool _isLocalPinned = false;
  List<dynamic> _dashboardWidgets = []; // Used to pass to voice command overlay

  @override
  void initState() {
    super.initState();
    _loadPinState();
  }

  Future<void> _loadPinState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _isLocalPinned = prefs.getBool('pin_local_control') ?? false;
        });
      }
    } catch (_) {}
  }

  // A callback that Dashboard can use to update widgets list
  void _updateDashboardWidgets(List<dynamic> widgets) {
    if (mounted) {
      setState(() {
        _dashboardWidgets = widgets;
      });
    }
  }

  void _onTabChanged(int index) {
    if (index == _currentIndex) return;
    
    // If we navigate back to index 0, reload pin state just in case it changed
    if (index == 0) {
      _loadPinState();
    }
    
    setState(() {
      _currentIndex = index;
    });
  }

  void _startTour() {
    final List<TourStep> tourSteps = [
      const TourStep(
        titleKey: 'tour_welcome_title',
        descKey: 'tour_welcome_desc',
      ),
      TourStep(
        titleKey: 'التبويب السفلي (Navigation)',
        descKey: 'تمت إضافة شريط تنقل سفلي جديد لسهولة الوصول للوحة التحكم، الأتمتة، المشاهد الذكية، والإعدادات.',
        targetKey: TourKeys.bottomNav,
      ),
      TourStep(
        titleKey: 'إضافة أداة (Add Tool)',
        descKey: 'اضغط هنا للذهاب إلى الإعدادات وإضافة أدوات جديدة للوحة التحكم.',
        targetKey: TourKeys.dashboardAdd,
        isCircular: true,
      ),
      TourStep(
        titleKey: 'tour_grid_title',
        descKey: 'tour_grid_desc',
        targetKey: TourKeys.dashboardGrid,
      ),
      TourStep(
        titleKey: 'tour_notifications_title',
        descKey: 'tour_notifications_desc',
        targetKey: TourKeys.dashboardNotifications,
        isCircular: true,
      ),
      TourStep(
        titleKey: 'tour_edit_title',
        descKey: 'tour_edit_desc',
        targetKey: TourKeys.dashboardEdit,
        isCircular: true,
      ),
      TourStep(
        titleKey: 'المساعد الذكي (AI Assistant)',
        descKey: 'الزر العائم يمكنك من التحدث مع المساعد الذكي وطلب تنفيذ الأوامر، وإنشاء القواعد.',
        targetKey: TourKeys.fabMain,
        isCircular: true,
        onStepEnter: () {
          TourKeys.fabMain.currentState?.close();
        },
      ),
      TourStep(
        titleKey: 'الأوامر الصوتية',
        descKey: 'اضغط هنا للتحدث مباشرة وإعطاء أوامر صوتية سريعة للنظام.',
        targetKey: TourKeys.fabVoice,
        isCircular: true,
        onStepEnter: () {
          TourKeys.fabMain.currentState?.open();
        },
      ),
      TourStep(
        titleKey: 'المحادثة الذكية',
        descKey: 'اضغط هنا لفتح واجهة المحادثة الذكية الشاملة للتحكم والاستعلام.',
        targetKey: TourKeys.fabAi,
        isCircular: true,
        onStepEnter: () {
          TourKeys.fabMain.currentState?.open();
        },
        onStepLeave: () {
          TourKeys.fabMain.currentState?.close();
        },
      ),
    ];

    AppTour.show(
      context,
      tourSteps,
      onComplete: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('has_completed_tour_v1', true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      extendBody: false, 
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // Index 0: Dashboard (Cloud)
          DashboardScreen(widgetSetupId: widget.widgetSetupId),
          // Index 1: Local Dashboard
          const LocalDashboardScreen(),
          // Index 2: Automations
          const AutomationsScreen(),
          // Index 3: Quick Commands (Smart Scenes)
          const SmartScenesScreen(isLocalMode: false),
          // Index 4: Account
          AccountScreen(
            onStartTour: () {
              setState(() {
                _currentIndex = 0;
              });
              Future.delayed(const Duration(milliseconds: 300), () {
                _startTour();
              });
            },
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.darkBackground,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.darkBackground.withValues(alpha: 0.8),
              Color(0xFF1E213A).withValues(alpha: 0.6), // Soft purple/navy tint to avoid pure black
              AppTheme.darkBackground,
            ],
          ),
        ),
        padding: const EdgeInsets.only(top: 8),
        child: CustomBottomNav(
          key: TourKeys.bottomNav,
          currentIndex: _currentIndex,
          isLocalPinned: _isLocalPinned,
          onTap: _onTabChanged,
        ),
      ),
      floatingActionButton: _currentIndex == 4
          ? const AiFloatingButton()
          : (_currentIndex == 0 || _currentIndex == 1)
              ? ExpandableAssistantFab(
                  key: TourKeys.fabMain,
                  widgets: _dashboardWidgets,
                  isLocalMode: _currentIndex == 1,
                )
              : null,
    );
  }
}
