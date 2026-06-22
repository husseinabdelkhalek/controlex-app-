import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/interactive_grid.dart';
import '../widgets/glass_card.dart';
import '../core/localization.dart';
import '../widgets/glass_popups.dart';
import 'local_dashboard_screen.dart';

class TutorialSandboxScreen extends StatefulWidget {
  const TutorialSandboxScreen({super.key});

  @override
  State<TutorialSandboxScreen> createState() => _TutorialSandboxScreenState();
}

class _TutorialSandboxScreenState extends State<TutorialSandboxScreen> {
  int _step = 0; // 0: Add, 1: Form, 2: Edit, 3: Move/Resize, 4: Done
  bool _isEditMode = false;
  final List<GridItemData> _items = [];
  String _widgetName = '';

  Widget _buildStepCard() {
    String text = '';
    if (_step == 0) text = AppLocalization.get('sandbox_step1');
    if (_step == 1) text = AppLocalization.get('sandbox_step2');
    if (_step == 2) text = AppLocalization.get('sandbox_step3');
    if (_step == 3) text = AppLocalization.get('sandbox_step4');
    if (_step == 4) text = AppLocalization.get('sandbox_success');

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryViolet.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryViolet.withOpacity(0.5)),
        boxShadow: [BoxShadow(color: AppTheme.primaryViolet.withOpacity(0.2), blurRadius: 10)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.school, color: AppTheme.primaryViolet, size: 28),
              const SizedBox(width: 12),
              Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold))),
            ],
          ),
          if (_step == 4) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryCyan,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LocalDashboardScreen(startTour: true)));
              },
              child: Text(AppLocalization.get('sandbox_finish_btn'), style: const TextStyle(fontWeight: FontWeight.bold)),
            )
          ]
        ],
      ),
    );
  }

  void _showDummyForm() {
    setState(() => _step = 1);
    final ctrl = TextEditingController();
    showGlassDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(AppLocalization.isArabicNotifier.value ? 'إنشاء أداة تجريبية' : 'Create Dummy Widget', style: const TextStyle(color: AppTheme.primaryCyan)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: AppLocalization.isArabicNotifier.value ? 'مثال: إضاءة الغرفة' : 'e.g. Room Light',
            hintStyle: const TextStyle(color: Colors.white54),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryCyan)),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryCyan, foregroundColor: Colors.black),
            onPressed: () {
              if (ctrl.text.isEmpty) return;
              Navigator.pop(context);
              setState(() {
                _widgetName = ctrl.text;
                _items.add(GridItemData(
                  id: 'dummy_1',
                  x: 0, y: 0, w: 2, h: 2,
                  child: GlassCard(
                    baseColor: AppTheme.cardBaseColor,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.lightbulb, color: AppTheme.primaryCyan, size: 32),
                          const SizedBox(height: 8),
                          Text(_widgetName, style: const TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ));
                _step = 2; // Move to edit mode step
              });
            },
            child: Text(AppLocalization.isArabicNotifier.value ? 'حفظ' : 'Save'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundBase,
      appBar: AppBar(
        title: Text(AppLocalization.get('sandbox_title')),
        automaticallyImplyLeading: false,
        actions: [
          if (_step >= 2)
            IconButton(
              icon: Icon(_isEditMode ? Icons.check_circle : Icons.edit, color: _isEditMode ? Colors.green : AppTheme.primaryCyan),
              onPressed: () {
                if (_step == 2) {
                  setState(() {
                    _isEditMode = true;
                    _step = 3;
                  });
                } else if (_step >= 3) {
                  setState(() => _isEditMode = !_isEditMode);
                }
              },
            )
        ],
      ),
      body: Column(
        children: [
          _buildStepCard(),
          Expanded(
            child: _items.isEmpty
                ? Center(
                    child: Icon(Icons.dashboard_customize, size: 80, color: Colors.white.withOpacity(0.1)),
                  )
                : InteractiveGrid(
                    isEditMode: _isEditMode,
                    items: _items,
                    onItemChanged: (item) {
                      if (_step == 3) {
                        setState(() {
                          _step = 4;
                          _isEditMode = false;
                        });
                      }
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: (_step == 0 || _step == 1) ? FloatingActionButton(
        backgroundColor: AppTheme.primaryViolet,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () {
          if (_step == 0) {
            _showDummyForm();
          }
        },
      ) : null,
    );
  }
}
