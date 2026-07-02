import '../widgets/app_snackbar.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import '../theme/app_theme.dart';
import '../core/localization.dart';
import '../services/api_service.dart';
import '../widgets/glass_card.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/smart_hint.dart';
import '../widgets/ai_floating_button.dart';

class AutomationsScreen extends StatefulWidget {
  const AutomationsScreen({super.key});
  @override
  State<AutomationsScreen> createState() => _AutomationsScreenState();
}

class _AutomationsScreenState extends State<AutomationsScreen> with TickerProviderStateMixin {
  List<Map<String, dynamic>> _rules = [];
  List<dynamic> _widgets = [];
  bool _isLoading = true;
  bool _powerSaving = false;
  late AnimationController _fabController;

  void _onLangChange() => setState(() {});

  @override
  void initState() {
    super.initState();
    AppLocalization.isArabicNotifier.addListener(_onLangChange);
    _fabController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);
    _loadData();
    _checkVisitReminder();
  }

  @override
  void dispose() {
    AppLocalization.isArabicNotifier.removeListener(_onLangChange);
    _fabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final widgets = await ApiService.getWidgets();
      final rules = await ApiService.getAutomationRules();
      Map<String, dynamic> psStatus = {};
      try { psStatus = await ApiService.getPowerSavingStatus(); } catch (_) {}
      if (mounted) {
        setState(() {
          _widgets = widgets;
          _rules = rules.map((e) => Map<String, dynamic>.from(e)).toList();
          _powerSaving = psStatus['powerSaving'] ?? false;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Shows a reminder dialog every 3rd visit if power saving is OFF
  Future<void> _checkVisitReminder() async {
    final prefs = await SharedPreferences.getInstance();
    int visits = (prefs.getInt('automations_visit_count') ?? 0) + 1;
    await prefs.setInt('automations_visit_count', visits);
    
    // Show reminder every 3 visits, and only if power saving is not already on
    if (visits % 3 == 0) {
      // Wait a moment for the screen to load
      await Future.delayed(const Duration(milliseconds: 800));
      Map<String, dynamic> psStatus = {};
      try { psStatus = await ApiService.getPowerSavingStatus(); } catch (_) {}
      if (psStatus['powerSaving'] == true) return; // Already on, no need to remind
      
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            Icon(Icons.battery_saver, color: Colors.orangeAccent, size: 28),
            SizedBox(width: 10),
            Expanded(child: Text(AppLocalization.get('power_saving_reminder_title'),
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
          ]),
          content: Text(
            AppLocalization.get('power_saving_reminder_msg'),
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppLocalization.get('later'), style: TextStyle(color: Colors.white38)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              icon: Icon(Icons.battery_saver, color: Colors.white, size: 18),
              label: Text(AppLocalization.get('enable_now'), style: TextStyle(color: Colors.white)),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await ApiService.setPowerSaving(true);
                  setState(() => _powerSaving = true);
                  if (mounted) AppSnackbar.showSuccess(context, AppLocalization.get('power_saving_enabled'));
                } catch (_) {}
              },
            ),
          ],
        ),
      );
    }
  }

  void _deleteRule(int index) {
    final rule = _rules[index];
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      title: Text(AppLocalization.get('delete_rule_confirm'), style: TextStyle(color: Colors.white)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalization.get('cancel'), style: TextStyle(color: Colors.white54))),
        TextButton(onPressed: () async {
          Navigator.pop(ctx);
          try {
            await ApiService.deleteAutomationRule(rule['id']);
            setState(() => _rules.removeAt(index));
            if (mounted) AppSnackbar.showError(context, AppLocalization.get('rule_deleted'));
          } catch (e) {
            if (mounted) AppSnackbar.showError(context, e.toString());
          }
        }, child: Text(AppLocalization.get('delete'), style: TextStyle(color: Colors.redAccent))),
      ],
    ));
  }

  String _conditionSymbol(String c) {
    switch (c) { case '>': return '>'; case '<': return '<'; case '=': return '='; case '!=': return '≠'; default: return c; }
  }

  String _actionLabel(String t) {
    switch (t) {
      case 'turn_on': return AppLocalization.get('action_turn_on');
      case 'turn_off': return AppLocalization.get('action_turn_off');
      case 'send_notif': return AppLocalization.get('action_send_notif');
      case 'send_email': return AppLocalization.get('action_send_email');
      case 'send_feed': return AppLocalization.get('action_send_feed');
      case 'emergency_call': return AppLocalization.isArabicNotifier.value ? 'اتصال طوارئ' : 'Emergency Call';
      default: return t;
    }
  }

  IconData _actionIcon(String t) {
    switch (t) {
      case 'turn_on': return Icons.power_settings_new;
      case 'turn_off': return Icons.power_off;
      case 'send_notif': return Icons.notifications_active;
      case 'send_email': return Icons.email;
      case 'send_feed': return Icons.send;
      case 'emergency_call': return Icons.phone_in_talk;
      default: return Icons.bolt;
    }
  }

  void _openRuleEditor({Map<String, dynamic>? existing, int? editIndex}) {
    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    final valueCtrl = TextEditingController(text: existing?['triggerValue'] ?? '');
    // For email: extraData = "email||message"
    String existingExtra = existing?['extraData'] ?? '';
    final emailCtrl = TextEditingController();
    final emailMsgCtrl = TextEditingController();
    final notifMsgCtrl = TextEditingController();
    final feedValCtrl = TextEditingController();
    final emergencyMsgCtrl = TextEditingController();
    String selRingtone = 'default';

    String actionType = existing?['actionType'] ?? 'turn_on';
    if (actionType == 'send_email' && existingExtra.contains('||')) {
      final parts = existingExtra.split('||');
      emailCtrl.text = parts[0];
      emailMsgCtrl.text = parts.length > 1 ? parts[1] : '';
    } else if (actionType == 'send_notif') {
      notifMsgCtrl.text = existingExtra;
    } else if (actionType == 'send_feed') {
      feedValCtrl.text = existingExtra;
    } else if (actionType == 'emergency_call' && existingExtra.contains('||')) {
      final parts = existingExtra.split('||');
      selRingtone = parts[0];
      emergencyMsgCtrl.text = parts.length > 1 ? parts[1] : '';
    } else if (actionType == 'emergency_call') {
      emergencyMsgCtrl.text = existingExtra;
    }

    String? selTriggerWidgetId = existing?['triggerWidgetId'];
    String? selTriggerWidgetName = existing?['triggerWidgetName'];
    String selCondition = existing?['condition'] ?? '>';
    String selActionType = actionType;
    String? selActionWidgetId = existing?['actionWidgetId'];
    String? selActionWidgetName = existing?['actionWidgetName'];

    final sensors = _widgets.where((w) => w['type'] == 'sensor').toList();
    final toggles = _widgets.where((w) => w['type'] == 'toggle' || w['type'] == 'push').toList();
    final allWidgets = _widgets;
    final conditions = ['>', '<', '=', '!='];
    final actions = ['turn_on', 'turn_off', 'send_notif', 'send_email', 'send_feed', 'emergency_call'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModalState) {
        bool needsWidget = selActionType == 'turn_on' || selActionType == 'turn_off' || selActionType == 'send_feed';

        return Container(
          height: MediaQuery.of(ctx).size.height * 0.92,
          decoration: BoxDecoration(color: Color(0xFF0B0A1A), borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(children: [
            Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            Padding(padding: const EdgeInsets.all(16),
              child: Text(existing != null ? AppLocalization.get('edit_rule') : AppLocalization.get('create_rule'),
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
            Expanded(child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _buildInputField(nameCtrl, AppLocalization.get('rule_name'), AppLocalization.get('rule_name_hint'), Icons.label),
                SizedBox(height: 24),
                // ═══════ IF BLOCK ═══════
                _buildBlockHeader(AppLocalization.get('if_trigger'), AppTheme.primaryCyan, Icons.sensors),
                SizedBox(height: 12),
                _buildDropdownCard<String>(
                  label: AppLocalization.get('select_sensor'), value: selTriggerWidgetId,
                  items: sensors.map((s) => DropdownMenuItem<String>(value: s['id'], child: Text(s['name'] ?? 'Sensor', style: TextStyle(color: Colors.white)))).toList(),
                  onChanged: (v) { setModalState(() { selTriggerWidgetId = v; selTriggerWidgetName = sensors.firstWhere((s) => s['id'] == v)['name']; }); },
                  icon: Icons.sensors,
                ),
                SizedBox(height: 12),
                _buildDropdownCard<String>(
                  label: AppLocalization.get('select_condition'), value: selCondition,
                  items: conditions.map((c) {
                    String label;
                    switch (c) { case '>': label = AppLocalization.get('greater_than'); break; case '<': label = AppLocalization.get('less_than'); break;
                      case '=': label = AppLocalization.get('equal_to'); break; case '!=': label = AppLocalization.get('not_equal'); break; default: label = c; }
                    return DropdownMenuItem<String>(value: c, child: Text(label, style: TextStyle(color: Colors.white)));
                  }).toList(),
                  onChanged: (v) => setModalState(() => selCondition = v ?? '>'),
                  icon: Icons.compare_arrows,
                ),
                SizedBox(height: 12),
                // Value field - accepts BOTH text and numbers
                _buildInputField(valueCtrl, AppLocalization.get('enter_value'), '25 or ON', Icons.pin),
                SizedBox(height: 8),
                Center(child: _buildConnectorLine()),
                SizedBox(height: 8),
                // ═══════ THEN BLOCK ═══════
                _buildBlockHeader(AppLocalization.get('then_action'), AppTheme.accentNeon, Icons.bolt),
                SizedBox(height: 12),
                _buildDropdownCard<String>(
                  label: AppLocalization.get('select_action'), value: selActionType,
                  items: actions.map((a) => DropdownMenuItem<String>(value: a, child: Row(children: [
                    Icon(_actionIcon(a), color: AppTheme.accentNeon, size: 18), SizedBox(width: 8),
                    Flexible(child: Text(_actionLabel(a), style: TextStyle(color: Colors.white), overflow: TextOverflow.ellipsis)),
                  ]))).toList(),
                  onChanged: (v) async {
                    setModalState(() { selActionType = v ?? 'turn_on'; selActionWidgetId = null; selActionWidgetName = null; });
                    if (v == 'emergency_call') {
                      final prefs = await SharedPreferences.getInstance();
                      final shown = prefs.getBool('emergency_call_setup_shown') ?? false;
                      if (!shown) {
                        await prefs.setBool('emergency_call_setup_shown', true);
                        if (ctx.mounted) {
                          final isAr = AppLocalization.isArabicNotifier.value;
                          showDialog(
                            context: ctx,
                            builder: (dialogCtx) => AlertDialog(
                              backgroundColor: const Color(0xFF1A1A2E),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              title: Row(children: [
                                Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 28),
                                SizedBox(width: 10),
                                Expanded(child: Text(
                                  isAr ? '⚠️ إعداد مطلوب لمكالمات الطوارئ' : '⚠️ Setup Required for Emergency Calls',
                                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                )),
                              ]),
                              content: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      isAr
                                        ? 'عشان مكالمة الطوارئ توصلك حتى لو التطبيق مغلق، لازم تفعّل هذه الإعدادات في موبايلك:'
                                        : 'For emergency calls to work even when the app is closed, you must enable these settings on your phone:',
                                      style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                                    ),
                                    SizedBox(height: 16),
                                    _buildSetupStep('1', isAr ? 'تفعيل التشغيل التلقائي (Autostart)' : 'Enable Autostart', isAr ? 'الإعدادات ← التطبيقات ← controlex ← تشغيل تلقائي ✅' : 'Settings → Apps → controlex → Autostart ✅', Icons.play_circle_fill_rounded, Colors.greenAccent),
                                    SizedBox(height: 12),
                                    _buildSetupStep('2', isAr ? 'السماح بالنوافذ المنبثقة في الخلفية' : 'Allow Popups in Background', isAr ? 'الإعدادات ← التطبيقات ← controlex ← أذونات أخرى ← عرض نوافذ منبثقة: دائماً مسموح' : 'Settings → Apps → controlex → Other permissions → Display pop-up windows: Always Allow', Icons.open_in_new, Colors.cyanAccent),
                                    SizedBox(height: 12),
                                    _buildSetupStep('3', isAr ? 'السماح بالعرض على شاشة القفل' : 'Show on Lock Screen', isAr ? 'الإعدادات ← التطبيقات ← controlex ← أذونات أخرى ← عرض على شاشة القفل: مفعّل' : 'Settings → Apps → controlex → Other permissions → Show on Lock screen: Enabled', Icons.lock_open_rounded, Colors.amberAccent),
                                  ],
                                ),
                              ),
                              actions: [
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                  onPressed: () => Navigator.pop(dialogCtx),
                                  child: Text(isAr ? 'فهمت، شكراً!' : 'Got it, Thanks!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          );
                        }
                      }
                    }
                  },
                  icon: Icons.flash_on,
                ),
                SizedBox(height: 12),
                if (needsWidget)
                  _buildDropdownCard<String>(
                    label: AppLocalization.get('select_widget'), value: selActionWidgetId,
                    items: (selActionType == 'send_feed' ? allWidgets : toggles)
                      .map((w) => DropdownMenuItem<String>(value: w['id'], child: Text(w['name'] ?? 'Widget', style: TextStyle(color: Colors.white)))).toList(),
                    onChanged: (v) {
                      final list = selActionType == 'send_feed' ? allWidgets : toggles;
                      setModalState(() { selActionWidgetId = v; selActionWidgetName = list.firstWhere((w) => w['id'] == v)['name']; });
                    },
                    icon: Icons.widgets,
                  ),
                // ── Email: two fields (address + message) ──
                if (selActionType == 'send_email') ...[
                  SizedBox(height: 12),
                  _buildInputField(emailCtrl, AppLocalization.get('email_address'), 'user@example.com', Icons.email),
                  SizedBox(height: 12),
                  _buildInputField(emailMsgCtrl, AppLocalization.get('notif_message'), AppLocalization.get('notif_message_hint'), Icons.message),
                ],
                // ── Notification: message field ──
                if (selActionType == 'send_notif') ...[
                  SizedBox(height: 12),
                  _buildInputField(notifMsgCtrl, AppLocalization.get('notif_message'), AppLocalization.get('notif_message_hint'), Icons.message),
                ],
                if (selActionType == 'send_feed') ...[
                  SizedBox(height: 12),
                  _buildInputField(feedValCtrl, AppLocalization.get('feed_value'), '1', Icons.send),
                ],
                // ── Emergency Call: message field + ringtone ──
                if (selActionType == 'emergency_call') ...[
                  SizedBox(height: 12),
                  _buildInputField(emergencyMsgCtrl, AppLocalization.isArabicNotifier.value ? 'نص التحذير' : 'Alert Message', AppLocalization.isArabicNotifier.value ? 'مثال: حريق!' : 'e.g. Fire!', Icons.warning),
                  SizedBox(height: 12),
                  _buildDropdownCard<String>(
                    label: AppLocalization.isArabicNotifier.value ? 'اختر النغمة' : 'Select Ringtone',
                    value: selRingtone,
                    items: [
                      DropdownMenuItem(value: 'default', child: Text(AppLocalization.isArabicNotifier.value ? 'الافتراضي' : 'Default', style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(value: 'alarm1', child: Text(AppLocalization.isArabicNotifier.value ? 'إنذار 1' : 'Alarm 1', style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(value: 'alarm2', child: Text(AppLocalization.isArabicNotifier.value ? 'إنذار 2' : 'Alarm 2', style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(value: 'silent', child: Text(AppLocalization.isArabicNotifier.value ? 'صامت (اهتزاز فقط)' : 'Silent (Vibrate Only)', style: TextStyle(color: Colors.white))),
                    ],
                    onChanged: (v) => setModalState(() => selRingtone = v ?? 'default'),
                    icon: Icons.music_note,
                  ),
                ],
                SizedBox(height: 32),
                SizedBox(width: double.infinity, height: 54, child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryViolet,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 8, shadowColor: AppTheme.primaryViolet.withValues(alpha: 0.5),
                  ),
                  onPressed: () async {
                    if (nameCtrl.text.isEmpty || selTriggerWidgetId == null || valueCtrl.text.isEmpty) return;
                    // Build extraData based on action type
                    String extraData = '';
                    if (selActionType == 'send_email') {
                      extraData = '${emailCtrl.text}||${emailMsgCtrl.text}';
                    } else if (selActionType == 'send_notif') {
                      extraData = notifMsgCtrl.text;
                    } else if (selActionType == 'send_feed') {
                      extraData = feedValCtrl.text;
                    } else if (selActionType == 'emergency_call') {
                      extraData = '$selRingtone||${emergencyMsgCtrl.text}';
                    }

                    final data = {
                      'name': nameCtrl.text,
                      'triggerWidgetId': selTriggerWidgetId,
                      'triggerWidgetName': selTriggerWidgetName ?? '',
                      'condition': selCondition,
                      'triggerValue': valueCtrl.text,
                      'actionType': selActionType,
                      'actionWidgetId': selActionWidgetId ?? '',
                      'actionWidgetName': selActionWidgetName ?? '',
                      'extraData': extraData,
                      'isActive': existing?['isActive'] ?? true,
                    };

                    try {
                      if (editIndex != null && existing != null) {
                        await ApiService.updateAutomationRule(existing['id'], data);
                      } else {
                        await ApiService.createAutomationRule(data);
                      }
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      _loadData(); // Refresh from server
                      if (mounted) AppSnackbar.showSuccess(context, editIndex != null ? AppLocalization.get('rule_updated') : AppLocalization.get('rule_created'));
                    } catch (e) {
                      if (mounted) AppSnackbar.showError(context, e.toString());
                    }
                  },
                  child: Text(AppLocalization.get('save_rule'), style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                )),
                SizedBox(height: 40),
              ]),
            )),
          ]),
        );
      }),
    );
  }

  Widget _buildBlockHeader(String title, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.05)]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 22), SizedBox(width: 10),
        Text(title, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 2)),
      ]),
    );
  }

  Widget _buildConnectorLine() {
    return Column(children: [
      Container(width: 3, height: 20, decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppTheme.primaryCyan, AppTheme.primaryViolet]),
        borderRadius: BorderRadius.circular(2),
      )),
      Container(width: 14, height: 14, decoration: BoxDecoration(
        shape: BoxShape.circle, color: AppTheme.primaryViolet,
        border: Border.all(color: AppTheme.accentNeon, width: 2),
        boxShadow: [BoxShadow(color: AppTheme.accentNeon.withValues(alpha: 0.5), blurRadius: 8)],
      )),
      Container(width: 3, height: 20, decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppTheme.primaryViolet, AppTheme.accentNeon]),
        borderRadius: BorderRadius.circular(2),
      )),
    ]);
  }

  Widget _buildInputField(TextEditingController ctrl, String label, String hint, IconData icon) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: TextField(
            controller: ctrl, style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: label, hintText: hint,
              labelStyle: TextStyle(color: Colors.white54), hintStyle: TextStyle(color: Colors.white24),
              prefixIcon: Icon(icon, color: AppTheme.primaryCyan, size: 20),
              border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownCard<T>({required String label, T? value, required List<DropdownMenuItem<T>> items, required ValueChanged<T?> onChanged, required IconData icon}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Row(children: [
            Icon(icon, color: AppTheme.primaryCyan, size: 20), SizedBox(width: 8),
            Expanded(child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: (items.any((i) => i.value == value)) ? value : null,
                hint: Text(label, style: TextStyle(color: Colors.white38)),
                dropdownColor: const Color(0xFF1A1A2E), isExpanded: true, items: items, onChanged: onChanged,
              ),
            )),
          ]),
        ),
      ),
    );
  }

  Widget _buildRuleCard(Map<String, dynamic> rule, int index) {
    final bool isActive = rule['isActive'] ?? false;
    final String name = rule['name'] ?? '';
    final String triggerName = rule['triggerWidgetName'] ?? '';
    final String condition = rule['condition'] ?? '=';
    final String triggerValue = rule['triggerValue'] ?? '';
    final String aType = rule['actionType'] ?? 'turn_on';
    final String actionName = rule['actionWidgetName'] ?? '';
    
    final String lastTriggeredStr = rule['lastTriggered'] ?? '';
    String lastTriggeredLabel = '';
    if (lastTriggeredStr.isNotEmpty) {
      try {
        final DateTime dt = DateTime.parse(lastTriggeredStr).toLocal();
        final String formatted = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
        lastTriggeredLabel = AppLocalization.isArabicNotifier.value ? 'آخر تفعيل: $formatted' : 'Last triggered: $formatted';
      } catch (e) {
        lastTriggeredLabel = '';
      }
    }

    return Dismissible(
      key: Key(rule['id'] ?? index.toString()),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async { _deleteRule(index); return false; },
      background: Container(
        alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(20)),
        child: Icon(Icons.delete_forever, color: Colors.redAccent, size: 32),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openRuleEditor(existing: rule, editIndex: index),
        child: GlassCard(
          baseColor: AppTheme.cardBaseColor,
          child: Padding(padding: const EdgeInsets.all(16), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [
                      isActive ? AppTheme.primaryCyan : Colors.grey,
                      isActive ? AppTheme.primaryViolet : Colors.grey.shade700,
                    ])),
                  child: Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                ),
                SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  SizedBox(height: 2),
                  Row(children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: isActive ? Colors.greenAccent : Colors.redAccent)),
                    SizedBox(width: 6),
                    Text(isActive ? AppLocalization.get('scenario_running') : AppLocalization.get('scenario_stopped'),
                      style: TextStyle(color: isActive ? Colors.greenAccent : Colors.redAccent, fontSize: 12)),
                  ]),
                ])),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.scale(scale: 0.85, child: Switch(
                      value: isActive,
                      activeColor: AppTheme.primaryCyan,
                      activeTrackColor: AppTheme.primaryCyan.withValues(alpha: 0.3),
                      onChanged: (v) async {
                        setState(() => rule['isActive'] = v);
                        try { await ApiService.toggleAutomationRule(rule['id']); } catch (_) {}
                      },
                    )),
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                      tooltip: AppLocalization.get('delete') ?? 'Delete',
                      onPressed: () => _deleteRule(index),
                    ),
                  ],
                ),
              ]),
              SizedBox(height: 14),
              _buildMiniBlock(AppLocalization.get('if_trigger'), AppTheme.primaryCyan,
                '$triggerName ${_conditionSymbol(condition)} $triggerValue', Icons.sensors),
              Padding(padding: const EdgeInsets.only(left: 20), child: Container(width: 2, height: 16,
                color: AppTheme.primaryViolet.withValues(alpha: 0.5))),
              _buildMiniBlock(AppLocalization.get('then_action'), AppTheme.accentNeon,
                '${_actionLabel(aType)}${actionName.isNotEmpty ? ' → $actionName' : ''}',
                _actionIcon(aType)),
              if (lastTriggeredLabel.isNotEmpty) ...[
                SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.access_time, color: Colors.white54, size: 14),
                    SizedBox(width: 6),
                    Text(lastTriggeredLabel, style: TextStyle(color: Colors.white54, fontSize: 11)),
                  ],
                ),
              ],
            ],
          )),
        ),
      ),
    );
  }

  Widget _buildMiniBlock(String tag, Color color, String text, IconData icon) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.4))),
        child: Text(tag, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
      ),
      SizedBox(width: 10),
      Icon(icon, color: color.withValues(alpha: 0.7), size: 16),
      SizedBox(width: 6),
      Flexible(child: Text(text, style: TextStyle(color: Colors.white70, fontSize: 13), overflow: TextOverflow.ellipsis)),
    ]);
  }

  static Widget _buildSetupStep(String number, String title, String description, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.2), border: Border.all(color: color)),
            child: Center(child: Text(number, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14))),
          ),
          SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon, color: color, size: 16),
                SizedBox(width: 6),
                Flexible(child: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13))),
              ]),
              SizedBox(height: 4),
              Text(description, style: TextStyle(color: Colors.white54, fontSize: 11, height: 1.4)),
            ],
          )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundBase,
      appBar: AppBar(
        title: Text(AppLocalization.get('automations')),
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new), onPressed: () => Navigator.pop(context)),
        actions: [
          // Power Saving indicator (read-only — admin controls it)
          if (_powerSaving)
            Tooltip(
              message: AppLocalization.get('power_saving_on'),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.4)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.battery_saver, color: Colors.orangeAccent, size: 16),
                  SizedBox(width: 4),
                  Text('⚡', style: TextStyle(fontSize: 12)),
                ]),
              ),
            ),
          SizedBox(width: 4),
        ],
      ),
      body: Stack(children: [
        Positioned(top: -120, right: -80, child: Container(width: 300, height: 300,
          decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.primaryViolet.withValues(alpha: 0.15)),
          child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container()))),
        Positioned(bottom: -80, left: -60, child: Container(width: 280, height: 280,
          decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.accentNeon.withValues(alpha: 0.1)),
          child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80), child: Container()))),
        _isLoading
          ? Center(child: CircularProgressIndicator(color: AppTheme.primaryCyan))
          : _rules.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.auto_fix_high, size: 64, color: AppTheme.primaryCyan.withValues(alpha: 0.4)),
                SizedBox(height: 16),
                Text(AppLocalization.get('no_rules'), style: TextStyle(color: Colors.white54, fontSize: 16)),
                SizedBox(height: 8),
                Text(AppLocalization.get('no_rules_hint'), style: TextStyle(color: Colors.white30, fontSize: 13)),
              ]))
             : RefreshIndicator(
                color: AppTheme.primaryCyan,
                onRefresh: _loadData,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: _rules.length + 2, // Always Banner + Header + Rules
                  itemBuilder: (ctx, i) {
                    // 1. Power saving banner (always at 0)
                    if (i == 0) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _powerSaving 
                              ? [Colors.orange.withValues(alpha: 0.15), Colors.orange.withValues(alpha: 0.05)]
                              : [Colors.green.withValues(alpha: 0.1), Colors.green.withValues(alpha: 0.03)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _powerSaving 
                              ? Colors.orangeAccent.withValues(alpha: 0.3)
                              : Colors.greenAccent.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Row(children: [
                          Icon(
                            _powerSaving ? Icons.battery_saver : Icons.bolt, 
                            color: _powerSaving ? Colors.orangeAccent : Colors.greenAccent, 
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocalization.get(_powerSaving ? 'power_saving_on' : 'power_saving_off'),
                                  style: TextStyle(
                                    color: _powerSaving ? Colors.orangeAccent : Colors.greenAccent, 
                                    fontSize: 13, 
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  AppLocalization.isArabicNotifier.value 
                                    ? 'يتحكم في معدل تحديث البيانات للحفاظ على استقرار السيرفر'
                                    : 'Controls data refresh rate to preserve server stability',
                                  style: TextStyle(color: Colors.white38, fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _powerSaving,
                            activeColor: Colors.orangeAccent,
                            inactiveThumbColor: Colors.greenAccent,
                            inactiveTrackColor: Colors.green.withValues(alpha: 0.3),
                            onChanged: (v) async {
                              // Optimistic update
                              setState(() {
                                _powerSaving = v;
                              });
                              try {
                                await ApiService.setPowerSaving(v);
                                if (context.mounted) {
                                  AppSnackbar.showSuccess(context, v 
                                      ? AppLocalization.get('power_saving_enabled')
                                      : AppLocalization.get('power_saving_disabled'));
                                }
                              } catch (_) {
                                setState(() {
                                  _powerSaving = !v;
                                });
                              }
                            },
                          ),
                        ]),
                      );
                    }
                    
                    // 2. Scenario header (always at 1)
                    if (i == 1) {
                      return Padding(padding: const EdgeInsets.only(bottom: 16),
                        child: Row(children: [
                          Icon(Icons.auto_awesome_mosaic, color: AppTheme.primaryCyan, size: 20),
                          SizedBox(width: 8),
                          Text(AppLocalization.get('my_scenarios'), style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                          const Spacer(),
                          Text('${_rules.length}', style: TextStyle(color: AppTheme.primaryCyan, fontSize: 14, fontWeight: FontWeight.bold)),
                        ]));
                    }
                    
                    // 3. Automation rules (always offset by 2)
                    return Padding(padding: const EdgeInsets.only(bottom: 14), child: _buildRuleCard(_rules[i - 2], i - 2));
                  },
                ),
              ),
      ]),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const AiFloatingButton(),
          SizedBox(height: 16),
          AnimatedBuilder(
            animation: _fabController,
            builder: (ctx, child) => Transform.scale(
              scale: 1.0 + (_fabController.value * 0.06),
              child: child,
            ),
            child: SmartHint(
              condition: _rules.isEmpty && !_isLoading,
              message: AppLocalization.isArabicNotifier.value ? 'أنشئ أول أتمتة لك!' : 'Create your first Automation!',
              child: FloatingActionButton.extended(
                backgroundColor: AppTheme.primaryViolet,
                icon: Icon(Icons.add, color: Colors.white),
                label: Text(AppLocalization.get('create_rule'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () => _openRuleEditor(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
