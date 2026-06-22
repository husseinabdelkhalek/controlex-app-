import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../core/localization.dart';
import '../services/api_service.dart';
import 'glass_card.dart';
import 'glowing_button.dart';

class WidgetToolSelectorDialog extends StatefulWidget {
  final String widgetId;

  const WidgetToolSelectorDialog({Key? key, required this.widgetId}) : super(key: key);

  @override
  State<WidgetToolSelectorDialog> createState() => _WidgetToolSelectorDialogState();
}

class _WidgetToolSelectorDialogState extends State<WidgetToolSelectorDialog> {
  bool _isLoading = true;
  List<dynamic> _tools = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTools();
  }

  Future<void> _loadTools() async {
    try {
      final widgets = await ApiService.getWidgets();
      if (mounted) {
        setState(() {
          _tools = widgets;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  IconData _getToolIcon(String type) {
    switch (type.toLowerCase()) {
      case 'toggle':
        return Icons.power_settings_new;
      case 'push':
        return Icons.touch_app;
      case 'sensor':
        return Icons.sensors;
      case 'slider':
        return Icons.linear_scale;
      case 'colorpicker':
      case 'color':
        return Icons.color_lens;
      case 'terminal':
        return Icons.terminal;
      default:
        return Icons.device_unknown;
    }
  }

  Color _getToolColor(String type) {
    switch (type.toLowerCase()) {
      case 'toggle':
        return AppTheme.primaryCyan;
      case 'push':
        return AppTheme.primaryViolet;
      case 'sensor':
        return Colors.greenAccent;
      case 'slider':
        return Colors.orangeAccent;
      case 'colorpicker':
      case 'color':
        return Colors.purpleAccent;
      case 'terminal':
        return Colors.yellowAccent;
      default:
        return Colors.white54;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalization.isArabicNotifier.value;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: GlassCard(
        baseColor: AppTheme.cardBaseColor.withValues(alpha: 0.8),
        borderColor: AppTheme.primaryViolet.withValues(alpha: 0.5),
        borderRadius: 24,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isArabic ? 'اختر الأداة للودجت' : 'Select Widget Tool',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white54),
                  ),
                ],
              ),
              const Divider(color: Colors.white12, height: 20),
              
              // Content
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: _buildContent(isArabic),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(bool isArabic) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryCyan),
        ),
      );
    }

    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 12),
            Text(
              isArabic ? 'حدث خطأ أثناء تحميل الأدوات' : 'Error loading tools',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            GlowingButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });
                _loadTools();
              },
              child: Text(isArabic ? 'إعادة المحاولة' : 'Retry'),
            ),
          ],
        ),
      );
    }

    if (_tools.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Text(
          isArabic ? 'لا توجد أدوات متاحة للربط.' : 'No tools available to link.',
          style: const TextStyle(color: Colors.white54),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: _tools.length,
      itemBuilder: (context, index) {
        final tool = _tools[index];
        final name = tool['name'].toString();
        final type = tool['type']?.toString() ?? 'toggle';
        
        final color = _getToolColor(type);
        final icon = _getToolIcon(type);

        return Card(
          color: Colors.white.withValues(alpha: 0.05),
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Colors.white10),
          ),
          child: ListTile(
            onTap: () => Navigator.pop(context, tool),
            leading: CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(icon, color: color, size: 20),
            ),
            title: Text(
              name,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              type.toUpperCase(),
              style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.w600),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
          ),
        );
      },
    );
  }
}
