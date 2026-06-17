import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:ui';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../core/localization.dart';
import '../services/api_service.dart';
import '../services/local_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/smart_hint.dart';
import '../widgets/ai_floating_button.dart';

class SmartScenesScreen extends StatefulWidget {
  final bool isLocalMode;
  const SmartScenesScreen({super.key, this.isLocalMode = false});

  @override
  State<SmartScenesScreen> createState() => _SmartScenesScreenState();
}

class _SmartScenesScreenState extends State<SmartScenesScreen> with TickerProviderStateMixin {
  List<dynamic> _scenes = [];
  List<dynamic> _widgets = [];
  bool _isLoading = true;
  final Map<String, bool> _executingScenes = {};
  late AnimationController _fabController;

  static const String _localModeScenesKey = 'local_control_scenes_v1';

  void _onLangChange() => setState(() {});

  @override
  void initState() {
    super.initState();
    AppLocalization.isArabicNotifier.addListener(_onLangChange);
    _fabController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);
    _loadData();
  }

  @override
  void dispose() {
    AppLocalization.isArabicNotifier.removeListener(_onLangChange);
    _fabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      if (widget.isLocalMode) {
        // Local offline mode
        _widgets = await LocalService.getWidgets();
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_localModeScenesKey);
        _scenes = raw != null && raw.isNotEmpty ? json.decode(raw) : [];
      } else {
        // Cloud mode
        _widgets = await ApiService.getWidgets();
        _scenes = await ApiService.getScenes();
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveLocalModeScenes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localModeScenesKey, json.encode(_scenes));
  }

  IconData _getIconData(String name) {
    switch (name) {
      case 'bolt': return Icons.bolt;
      case 'bed': return Icons.bed;
      case 'sunny': return Icons.wb_sunny;
      case 'wb_twilight': return Icons.nights_stay;
      case 'tv': return Icons.tv;
      case 'lock': return Icons.lock;
      case 'coffee': return Icons.coffee;
      case 'gamepad': return Icons.gamepad;
      default: return Icons.bolt;
    }
  }

  Color _getColorFromHex(String hex) {
    try {
      final h = hex.replaceAll('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return AppTheme.primaryCyan;
    }
  }

  Future<void> _triggerScene(Map<String, dynamic> scene) async {
    final String id = scene['id'].toString();
    final String name = scene['name'] ?? '';
    final actions = scene['actions'] as List<dynamic>;

    setState(() => _executingScenes[id] = true);

    try {
      if (widget.isLocalMode) {
        // Parallel offline direct execution to local ESP
        List<Future> futures = [];
        for (var action in actions) {
          futures.add(LocalService.sendCommand(action['widgetId'], action['value']).catchError((e) {
            debugPrint("Local command failed: $e");
          }));
        }
        await Future.wait(futures);
      } else {
        // Call cloud service
        await ApiService.executeScene(id, actions);
      }

      if (mounted) {
        AppSnackbar.showSuccess(context, '${AppLocalization.get('scene_executed')} ($name)');
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _executingScenes[id] = false);
      }
    }
  }

  void _deleteScene(int index) {
    final scene = _scenes[index];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(AppLocalization.get('delete_scene') ?? 'Delete Scene', style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalization.get('cancel'), style: const TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              try {
                if (widget.isLocalMode) {
                  setState(() {
                    _scenes.removeAt(index);
                    _isLoading = false;
                  });
                  await _saveLocalModeScenes();
                } else {
                  await ApiService.deleteScene(scene['id']);
                  await _loadData();
                }
                if (mounted) {
                  AppSnackbar.showSuccess(context, AppLocalization.get('scene_deleted') ?? 'Scene Deleted');
                }
              } catch (e) {
                if (mounted) {
                  AppSnackbar.showError(context, e);
                  setState(() => _isLoading = false);
                }
              }
            },
            child: Text(AppLocalization.get('delete'), style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _openSceneEditor({Map<String, dynamic>? existing, int? editIndex}) {
    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    String selectedIcon = existing?['icon'] ?? 'bolt';
    String selectedColor = existing?['color'] ?? '#00F1FF';
    bool showOnDashboard = existing?['showOnDashboard'] ?? true;

    // Map to quickly find action value configured for each widget
    final Map<String, dynamic> actionValues = {};
    final Map<String, bool> selectedWidgets = {};
    final Map<String, TextEditingController> textControllers = {};

    if (existing != null && existing['actions'] != null) {
      for (var action in existing['actions']) {
        final String wId = action['widgetId'];
        selectedWidgets[wId] = true;
        actionValues[wId] = action['value'];
      }
    }

    final icons = ['bolt', 'bed', 'sunny', 'wb_twilight', 'tv', 'lock', 'coffee', 'gamepad'];
    final colors = ['#00F1FF', '#B026FF', '#FF007F', '#2D00F7', '#4CAF50'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModalState) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.92,
          decoration: const BoxDecoration(
            color: Color(0xFF0B0A1A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  existing != null ? AppLocalization.get('edit_scene') : AppLocalization.get('create_scene'),
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Scene Name
                      _buildInputField(nameCtrl, AppLocalization.get('scene_name'), AppLocalization.get('scene_name_hint'), Icons.edit_note),
                      const SizedBox(height: 20),

                      // Icon Selector
                      Text(AppLocalization.get('scene_icon'), style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 55,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: icons.length,
                          itemBuilder: (ctx, idx) {
                            final key = icons[idx];
                            final isSel = selectedIcon == key;
                            return GestureDetector(
                              onTap: () => setModalState(() => selectedIcon = key),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 50,
                                margin: const EdgeInsets.only(right: 10),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSel ? _getColorFromHex(selectedColor).withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                                  border: Border.all(color: isSel ? _getColorFromHex(selectedColor) : Colors.white12, width: 2),
                                ),
                                child: Icon(_getIconData(key), color: isSel ? _getColorFromHex(selectedColor) : Colors.white54, size: 24),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Color Theme Selector
                      Text(AppLocalization.get('scene_color'), style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 45,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: colors.length,
                          itemBuilder: (ctx, idx) {
                            final key = colors[idx];
                            final isSel = selectedColor == key;
                            return GestureDetector(
                              onTap: () => setModalState(() => selectedColor = key),
                              child: Container(
                                width: 40,
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _getColorFromHex(key),
                                  border: Border.all(color: isSel ? Colors.white : Colors.transparent, width: 2.5),
                                  boxShadow: isSel ? [BoxShadow(color: _getColorFromHex(key).withValues(alpha: 0.6), blurRadius: 10)] : [],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Show on Dashboard
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(AppLocalization.get('show_on_dashboard'), style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
                          Transform.scale(
                            scale: 0.9,
                            child: Switch(
                              value: showOnDashboard,
                              activeColor: _getColorFromHex(selectedColor),
                              activeTrackColor: _getColorFromHex(selectedColor).withValues(alpha: 0.3),
                              onChanged: (v) => setModalState(() => showOnDashboard = v),
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white12, height: 30),

                      // Actions List
                      Text(AppLocalization.get('select_devices'), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(AppLocalization.get('select_devices_desc'), style: const TextStyle(color: Colors.white30, fontSize: 11)),
                      const SizedBox(height: 14),

                      _widgets.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 20.0),
                                child: Text(AppLocalization.get('no_widgets'), style: const TextStyle(color: Colors.white24, fontSize: 14)),
                              ),
                            )
                          : () {
                              final List<dynamic> commandableWidgets = _widgets.where((w) {
                                final String type = w['type'] ?? '';
                                return type == 'toggle' || type == 'push' || type == 'slider' || type == 'terminal';
                              }).toList();

                              if (commandableWidgets.isEmpty) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 20.0),
                                    child: Text(AppLocalization.get('no_widgets'), style: const TextStyle(color: Colors.white24, fontSize: 14)),
                                  ),
                                );
                              }

                              return ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: commandableWidgets.length,
                                itemBuilder: (ctx, idx) {
                                  final widget = commandableWidgets[idx];
                                  final String wId = widget['id'];
                                  final String wName = widget['name'] ?? 'Widget';
                                  final String wType = widget['type'] ?? 'toggle';
                                  final isChecked = selectedWidgets[wId] ?? false;

                                  // Default fallback value
                                  String? configuredVal = actionValues[wId]?.toString();
                                  if (configuredVal == null) {
                                    if (wType == 'toggle') {
                                      configuredVal = (widget['configuration']?['onCommand'] ?? 'ON').toString();
                                    } else if (wType == 'slider') {
                                      configuredVal = (widget['configuration']?['min'] ?? '0').toString();
                                    } else {
                                      configuredVal = 'ON';
                                    }
                                    actionValues[wId] = configuredVal;
                                  }

                                  TextEditingController? tCtrl;
                                  if (wType == 'terminal') {
                                    tCtrl = textControllers.putIfAbsent(wId, () => TextEditingController(text: configuredVal));
                                  }

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: isChecked ? _getColorFromHex(selectedColor).withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.02),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isChecked ? _getColorFromHex(selectedColor).withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.06),
                                        width: 1.2,
                                      ),
                                    ),
                                    child: CheckboxListTile(
                                      activeColor: _getColorFromHex(selectedColor),
                                      title: Text(wName, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                                      subtitle: Padding(
                                        padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                                        child: isChecked
                                            ? _buildActionValueSelector(widget, configuredVal, (newVal) {
                                                setModalState(() {
                                                  actionValues[wId] = newVal;
                                                });
                                              }, selectedColor, tCtrl)
                                            : Text(wType.toUpperCase(), style: const TextStyle(color: Colors.white24, fontSize: 10)),
                                      ),
                                      value: isChecked,
                                      onChanged: (v) {
                                        setModalState(() {
                                          selectedWidgets[wId] = v ?? false;
                                        });
                                      },
                                    ),
                                  );
                                },
                              );
                            }(),
                      const SizedBox(height: 30),

                      if (existing != null) ...[
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: const BorderSide(color: Colors.redAccent, width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            icon: const Icon(Icons.delete_outline, size: 20),
                            label: Text(
                              AppLocalization.isArabicNotifier.value ? 'حذف هذا السيناريو' : 'Delete this Scene',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _deleteScene(editIndex!);
                            },
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _getColorFromHex(selectedColor),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 8,
                            shadowColor: _getColorFromHex(selectedColor).withValues(alpha: 0.4),
                          ),
                          onPressed: () async {
                            if (nameCtrl.text.trim().isEmpty) return;

                            // Build actions payload
                            final List<Map<String, dynamic>> finalActions = [];
                            selectedWidgets.forEach((wId, isSel) {
                              if (isSel) {
                                final widgetItem = _widgets.firstWhere((w) => w['id'] == wId);
                                finalActions.add({
                                  'widgetId': wId,
                                  'widgetName': widgetItem['name'] ?? 'Widget',
                                  'value': actionValues[wId] ?? 'ON',
                                });
                              }
                            });

                            if (finalActions.isEmpty) return;

                            final payload = {
                              'name': nameCtrl.text.trim(),
                              'icon': selectedIcon,
                              'color': selectedColor,
                              'showOnDashboard': showOnDashboard,
                              'actions': finalActions,
                            };

                            Navigator.pop(ctx);
                            setState(() => _isLoading = true);

                            try {
                              if (widget.isLocalMode) {
                                if (editIndex != null && existing != null) {
                                  payload['id'] = existing['id'];
                                  _scenes[editIndex] = payload;
                                } else {
                                  payload['id'] = 'local_scene_${DateTime.now().millisecondsSinceEpoch}';
                                  _scenes.insert(0, payload);
                                }
                                await _saveLocalModeScenes();
                                setState(() => _isLoading = false);
                              } else {
                                if (editIndex != null && existing != null) {
                                  await ApiService.updateScene(existing['id'], payload);
                                } else {
                                  await ApiService.createScene(payload);
                                }
                                await _loadData();
                              }

                              if (mounted) {
                                AppSnackbar.showSuccess(context, editIndex != null ? (AppLocalization.get('scene_updated') ?? 'Scene Updated') : (AppLocalization.get('scene_created') ?? 'Scene Created'));
                              }
                            } catch (e) {
                              if (mounted) {
                                AppSnackbar.showError(context, e);
                                setState(() => _isLoading = false);
                              }
                            }
                          },
                          child: Text(
                            AppLocalization.get('save'),
                            style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildActionValueSelector(
    dynamic widget,
    String currentVal,
    ValueChanged<String> onChanged,
    String themeColor,
    TextEditingController? textController,
  ) {
    final String type = widget['type'] ?? 'toggle';
    final config = widget['configuration'] ?? {};

    if (type == 'toggle') {
      final onCmd = (config['onCommand'] ?? 'ON').toString();
      final offCmd = (config['offCommand'] ?? 'OFF').toString();
      final isCurrentlyOn = currentVal == onCmd;

      return Row(
        children: [
          Text(AppLocalization.isArabicNotifier.value ? 'الحالة المستهدفة: ' : 'Target state: ', style: const TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              final nextVal = isCurrentlyOn ? offCmd : onCmd;
              onChanged(nextVal);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isCurrentlyOn ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: isCurrentlyOn ? Colors.green : Colors.red, width: 1.2),
              ),
              child: Text(
                isCurrentlyOn ? 'ON' : 'OFF',
                style: TextStyle(color: isCurrentlyOn ? Colors.greenAccent : Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      );
    }

    if (type == 'push') {
      final pushCmd = (config['command'] ?? '1').toString();
      return Row(
        children: [
          Text(AppLocalization.isArabicNotifier.value ? 'أمر التشغيل: ' : 'Trigger command: ', style: const TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _getColorFromHex(themeColor).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _getColorFromHex(themeColor).withValues(alpha: 0.3), width: 1.2),
            ),
            child: Text(
              pushCmd,
              style: TextStyle(color: _getColorFromHex(themeColor), fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      );
    }

    if (type == 'slider') {
      final double min = double.tryParse(config['min']?.toString() ?? '0') ?? 0;
      final double max = double.tryParse(config['max']?.toString() ?? '100') ?? 100;
      final double initial = double.tryParse(currentVal) ?? min;

      return Row(
        children: [
          Text('${initial.toStringAsFixed(0)} ${config['unit'] ?? ''}', style: TextStyle(color: _getColorFromHex(themeColor), fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(width: 10),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
              ),
              child: Slider(
                value: initial.clamp(min, max),
                min: min,
                max: max,
                activeColor: _getColorFromHex(themeColor),
                inactiveColor: Colors.white12,
                onChanged: (v) {
                  onChanged(v.toStringAsFixed(0));
                },
              ),
            ),
          ),
        ],
      );
    }

    // Default: text input
    return Row(
      children: [
        Text(AppLocalization.isArabicNotifier.value ? 'الطلب: ' : 'Command: ', style: const TextStyle(color: Colors.white38, fontSize: 12)),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 35,
            child: TextField(
              controller: textController,
              onChanged: onChanged,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.04),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _getColorFromHex(themeColor))),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputField(TextEditingController ctrl, String label, String hint, IconData icon) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: TextField(
            controller: ctrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              labelStyle: const TextStyle(color: Colors.white54),
              hintStyle: const TextStyle(color: Colors.white24),
              prefixIcon: Icon(icon, color: AppTheme.primaryCyan, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSceneCard(dynamic scene, int index) {
    final String id = scene['id'].toString();
    final String name = scene['name'] ?? '';
    final String iconKey = scene['icon'] ?? 'bolt';
    final String colorHex = scene['color'] ?? '#00F1FF';
    final List<dynamic> actions = scene['actions'] ?? [];
    final bool isExecuting = _executingScenes[id] ?? false;
    final themeColor = _getColorFromHex(colorHex);

    return Dismissible(
      key: Key(id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        _deleteScene(index);
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(20)),
        child: const Icon(Icons.delete_forever, color: Colors.redAccent, size: 32),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openSceneEditor(existing: scene, editIndex: index),
        child: GlassCard(
          borderColor: themeColor.withValues(alpha: 0.4),
          baseColor: AppTheme.cardBaseColor,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [themeColor, themeColor.withValues(alpha: 0.6)]),
                        boxShadow: [BoxShadow(color: themeColor.withValues(alpha: 0.4), blurRadius: 10, spreadRadius: 1)],
                      ),
                      child: Icon(_getIconData(iconKey), color: Colors.black, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            AppLocalization.isArabicNotifier.value ? 'يتحكم في ${actions.length} أجهزة' : 'Controls ${actions.length} devices',
                            style: const TextStyle(color: Colors.white30, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Trigger/Play Button
                    GestureDetector(
                      onTap: isExecuting ? null : () => _triggerScene(scene),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isExecuting ? Colors.white12 : themeColor.withValues(alpha: 0.15),
                          border: Border.all(color: isExecuting ? Colors.white24 : themeColor.withValues(alpha: 0.4), width: 1.5),
                        ),
                        child: isExecuting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Icon(Icons.play_arrow, color: themeColor, size: 20),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Trash / Delete Button
                    GestureDetector(
                      onTap: () => _deleteScene(index),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.redAccent.withValues(alpha: 0.1),
                          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3), width: 1.5),
                        ),
                        child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Compact Action Tags
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: actions.map<Widget>((act) {
                    final String devName = act['widgetName'] ?? 'Device';
                    final String devVal = act['value'] ?? 'ON';
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(devName, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: devVal == 'ON'
                                  ? Colors.green.withValues(alpha: 0.2)
                                  : devVal == 'OFF'
                                      ? Colors.red.withValues(alpha: 0.2)
                                      : themeColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              devVal,
                              style: TextStyle(
                                color: devVal == 'ON'
                                    ? Colors.greenAccent
                                    : devVal == 'OFF'
                                        ? Colors.redAccent
                                        : themeColor,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundBase,
      appBar: AppBar(
        title: Text(AppLocalization.get('smart_scenes')),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new), onPressed: () => Navigator.pop(context)),
      ),
      body: Stack(
        children: [
          // Moving glowing background neon spheres
          Positioned(
            top: -120,
            right: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.primaryViolet.withValues(alpha: 0.15)),
              child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container()),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.accentNeon.withValues(alpha: 0.1)),
              child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80), child: Container()),
            ),
          ),

          _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryCyan))
              : _scenes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bolt, size: 64, color: AppTheme.primaryCyan.withValues(alpha: 0.4)),
                          const SizedBox(height: 16),
                          Text(AppLocalization.get('no_scenes'), style: const TextStyle(color: Colors.white54, fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(AppLocalization.get('no_scenes_hint'), style: const TextStyle(color: Colors.white30, fontSize: 13)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: AppTheme.primaryCyan,
                      onRefresh: _loadData,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        itemCount: _scenes.length,
                        itemBuilder: (ctx, idx) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _buildSceneCard(_scenes[idx], idx),
                        ),
                      ),
                    ),
        ],
      ),
      floatingActionButton: widget.isLocalMode
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const AiFloatingButton(),
                const SizedBox(height: 16),
                AnimatedBuilder(
                  animation: _fabController,
                  builder: (ctx, child) => Transform.scale(
                    scale: 1.0 + (_fabController.value * 0.06),
                    child: child,
                  ),
                  child: SmartHint(
                    condition: _scenes.isEmpty && !_isLoading,
                    message: AppLocalization.isArabicNotifier.value ? 'أنشئ أول مشهد لك!' : 'Create your first Scene!',
                    child: FloatingActionButton.extended(
                      backgroundColor: AppTheme.primaryViolet,
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: Text(AppLocalization.get('create_scene'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      onPressed: _openSceneEditor,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
