import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter/cupertino.dart';
import 'dart:ui';
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../widgets/glass_card.dart';
import '../widgets/glowing_button.dart';
import '../widgets/interactive_grid.dart';
import '../theme/app_theme.dart';
import 'settings/local_settings_screen.dart';
import 'auth/login_screen.dart';
import '../services/local_service.dart';
import '../widgets/terminal_widget.dart';
import '../core/localization.dart';
import '../services/biometric_service.dart';
import '../widgets/voice_command_overlay.dart';
import '../widgets/glass_popups.dart';
import '../widgets/ai_chat_overlay.dart';
import '../widgets/premium_app_bar.dart';
import '../widgets/app_tour_overlay.dart';
import 'settings/account_screen.dart';
import 'smart_scenes_screen.dart';
import '../widgets/app_snackbar.dart';
import '../core/haptic_helper.dart';

class LocalDashboardScreen extends StatefulWidget {
  final bool startTour;
  const LocalDashboardScreen({super.key, this.startTour = false});

  @override
  State<LocalDashboardScreen> createState() => _LocalDashboardScreenState();
}

class _LocalDashboardScreenState extends State<LocalDashboardScreen> {
  bool _isEditMode = false;
  bool _isLoading = true;
  List<dynamic> _scenes = [];
  final Map<String, bool> _executingScenes = {};

  // GlobalKeys for Onboarding Tour Highlights
  final GlobalKey _localGridKey = GlobalKey();
  final GlobalKey _settingsKey = GlobalKey();
  final GlobalKey _aiTourKey = GlobalKey();
  final bool _isScrollingLocked = false;
  List<GridItemData> _items = [];
  List<Map<String, dynamic>> _rawWidgets = [];
  final Map<String, double> _sliderValues = {};
  final Map<String, DateTime> _lastSliderUpdate = {};
  final Map<String, bool> _localToggleStates = {};
  
  Map<String, Map<String, int>> _localPositions = {};
  bool _isConnected = false;
  Timer? _syncTimer;

  void _onLangChange() => setState(() {});

  @override
  void initState() {
    super.initState();
    AppLocalization.isArabicNotifier.addListener(_onLangChange);
    _init();
    if (widget.startTour) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) _startTour();
        });
      });
    }
  }

  void _startTour() {
    final List<TourStep> steps = [
      TourStep(
        targetKey: _settingsKey,
        titleKey: 'tour_settings_title',
        descKey: 'tour_settings_desc',
      ),
      TourStep(
        targetKey: _aiTourKey,
        titleKey: 'المساعد الذكي (AI Assistant)',
        descKey: 'يمكنك التحدث إلى المساعد الذكي في أي وقت لمساعدتك في التحكم بالمنزل الذكي وإنشاء قواعد تلقائية.',
      ),
      TourStep(
        titleKey: 'tour_local_grid_title',
        descKey: 'tour_local_grid_desc',
        targetKey: _localGridKey,
      ),
    ];

    AppTour.show(
      context,
      steps,
      onComplete: () {
        Navigator.pop(context);
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AccountScreen(startTour: true)),
          );
        });
      },
      onSkip: () {},
    );
  }

  @override
  void dispose() {
    AppLocalization.isArabicNotifier.removeListener(_onLangChange);
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    await LocalService.loadIp();
    await _loadLocalPositions();
    await _loadWidgets();
    await _loadScenes();
    await _checkConnection();
    
    // Auto Refresh every 5 seconds
    _syncTimer = Timer.periodic(const Duration(seconds: 5), (_) {
       if (mounted && !_isEditMode) _syncDeviceStates();
    });
  }

  Future<void> _loadScenes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('local_control_scenes_v1');
      if (mounted) {
        setState(() {
          _scenes = raw != null && raw.isNotEmpty ? json.decode(raw) : [];
        });
      }
    } catch (_) {}
  }

  Future<void> _triggerSceneFromDashboard(Map<String, dynamic> scene) async {
    final String id = scene['id'].toString();
    final String name = scene['name'] ?? '';
    final actions = scene['actions'] as List<dynamic>;

    setState(() => _executingScenes[id] = true);

    try {
      // Direct offline parallel execution!
      List<Future> futures = [];
      for (var action in actions) {
        futures.add(LocalService.sendCommand(action['widgetId'], action['value']).catchError((e) {
          debugPrint("Local command failed: $e");
          return <String, dynamic>{};
        }));
      }
      await Future.wait(futures);

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

  Widget _buildQuickScenes(List<dynamic> dashboardScenes) {
    if (dashboardScenes.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocalization.get('quick_scenes'),
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SmartScenesScreen(isLocalMode: true)),
                  ).then((_) => _loadScenes());
                },
                child: Text(
                  AppLocalization.isArabicNotifier.value ? 'الكل >' : 'All >',
                  style: const TextStyle(color: AppTheme.primaryCyan, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 82,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: dashboardScenes.length,
            itemBuilder: (ctx, idx) {
              final scene = dashboardScenes[idx];
              final String id = scene['id'].toString();
              final String name = scene['name'] ?? '';
              final String iconKey = scene['icon'] ?? 'bolt';
              final String colorHex = scene['color'] ?? '#00F1FF';
              final isExecuting = _executingScenes[id] ?? false;
              
              IconData iconData = Icons.bolt;
              switch (iconKey) {
                case 'bolt': iconData = Icons.bolt; break;
                case 'bed': iconData = Icons.bed; break;
                case 'sunny': iconData = Icons.wb_sunny; break;
                case 'wb_twilight': iconData = Icons.nights_stay; break;
                case 'tv': iconData = Icons.tv; break;
                case 'lock': iconData = Icons.lock; break;
                case 'coffee': iconData = Icons.coffee; break;
                case 'gamepad': iconData = Icons.gamepad; break;
              }

              Color color = AppTheme.primaryCyan;
              try {
                final h = colorHex.replaceAll('#', '');
                color = Color(int.parse('FF$h', radix: 16));
              } catch (_) {}

              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 140,
                margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: GlassCard(
                  borderColor: isExecuting ? color : color.withValues(alpha: 0.2),
                  baseColor: isExecuting ? color.withValues(alpha: 0.08) : AppTheme.cardBaseColor,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: isExecuting ? null : () => _triggerSceneFromDashboard(scene),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color.withValues(alpha: 0.12),
                            ),
                            child: isExecuting
                                ? SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: color,
                                    ),
                                  )
                                : Icon(iconData, color: color, size: 16),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, overflow: TextOverflow.ellipsis),
                              maxLines: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Future<void> _syncDeviceStates() async {
    if (LocalService.deviceIp.isEmpty) return;
    try {
      final res = await http.get(Uri.parse('http://${LocalService.deviceIp}/status')).timeout(const Duration(seconds: 3));
      if (res.statusCode >= 200 && res.statusCode < 300) {
         if (!_isConnected && mounted) setState(() => _isConnected = true);
         final data = json.decode(res.body);
         bool changed = false;
         for (var w in _rawWidgets) {
            String path = w['feedName'];
            if (data.containsKey(path)) {
               String val = data[path].toString();
               w['state'] ??= {};
               
               if (w['type'] == 'toggle') {
                  bool isOn = val.toUpperCase() == (w['configuration']?['onCommand'] ?? 'ON').toString().toUpperCase();
                  if (w['state']['isActive'] != isOn) {
                     w['state']['isActive'] = isOn;
                     _localToggleStates[w['id']] = isOn;
                     changed = true;
                  }
               } else if (w['type'] == 'slider' || w['type'] == 'sensor') {
                  if (w['type'] == 'slider' && _lastSliderUpdate.containsKey(w['id']) && DateTime.now().difference(_lastSliderUpdate[w['id']]!).inSeconds < 3) {
                     // Skip overwriting if the user just changed it recently to avoid snap-back
                  } else {
                     if (w['state']['lastValue']?.toString() != val) {
                        w['state']['lastValue'] = val;
                        _sliderValues[w['id']] = double.tryParse(val) ?? 0;
                        changed = true;
                     }
                  }
               }
            }
         }
         if (changed && mounted) {
           setState(() {}); // refresh UI
         }
      }
    } catch (_) {
      if (_isConnected && mounted) setState(() => _isConnected = false);
    }
  }

  Future<void> _checkConnection() async {
    final connected = await LocalService.checkConnection();
    if (mounted) setState(() => _isConnected = connected);
  }

  Future<void> _loadLocalPositions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('local_dashboard_positions');
      if (saved != null) {
        final decoded = json.decode(saved) as Map<String, dynamic>;
        setState(() {
          _localPositions = decoded.map((k, v) => MapEntry(k, Map<String, int>.from(v)));
        });
      }
    } catch (_) {}
  }

  Future<void> _saveLocalPositions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('local_dashboard_positions', json.encode(_localPositions));
    } catch (_) {}
  }

  Color _hexToColor(String? hexString) {
    if (hexString == null || hexString.isEmpty) return AppTheme.primaryCyan;
    String h = hexString.replaceAll('#', '');
    if (h.length == 6) h = 'FF$h';
    try {
       return Color(int.parse(h, radix: 16));
    } catch(e) {
       return AppTheme.primaryCyan;
    }
  }

  Future<void> _loadWidgets() async {
    if (mounted) setState(() => _isLoading = true);
    try {
       final widgets = await LocalService.getWidgets();
       
       List<GridItemData> list = [];
       for (var w in widgets) {
          final id = w['id'] as String;
          
          if (_localPositions.containsKey(id)) {
            final pos = _localPositions[id]!;
            list.add(GridItemData(id: id, x: pos['x']!, y: pos['y']!, w: pos['w']!, h: pos['h']!, child: const SizedBox()));
          } else {
            var gs = w['gs'];
            int x = gs != null ? (gs['x'] ?? 0) : 0;
            int y = gs != null ? (gs['y'] ?? 0) : 0;
            int width = gs != null ? (gs['w'] ?? 1) : 1;
            int height = gs != null ? (gs['h'] ?? 1) : 1;
            
            list.add(GridItemData(id: id, x: x, y: y, w: width, h: height, child: const SizedBox()));
            _localPositions[id] = {'x': x, 'y': y, 'w': width, 'h': height};
          }
       }
       
       InteractiveGrid.pack(list, 4);

       if (mounted) {
         setState(() {
          _rawWidgets = widgets;
          _items = list;
          _isLoading = false;
       });
       }
       _saveLocalPositions();
       
    } catch (e) {
       if (mounted) setState(() => _isLoading = false);
    }
  }

  void _updateWidgetPosition(GridItemData item) async {
    _localPositions[item.id] = {'x': item.x, 'y': item.y, 'w': item.w, 'h': item.h};
    _saveLocalPositions();
    await LocalService.updateWidgetPosition(item.id, item.x, item.y, item.w, item.h);
  }

  void _showVoiceOverlay() {
    VoiceCommandOverlay.show(
      context,
      _rawWidgets.cast<dynamic>(),
      isLocalMode: true,
      onCommandExecuted: (id, type, value) {
         if (mounted) {
            setState(() {
               if (type == 'toggle') {
                  bool isTrue = (value == 'ON' || value == '1' || value == true);
                  _localToggleStates[id] = isTrue;
               } else if (type == 'slider') {
                  double? val = double.tryParse(value.toString());
                  if (val != null) {
                     _sliderValues[id] = val;
                     _lastSliderUpdate[id] = DateTime.now();
                  }
               }
            });
         }
      },
    );
  }

  Widget _buildWidgetByType(dynamic w, GridItemData item) {
    String type = w['type'] ?? 'toggle';
    String name = w['name'] ?? 'Unknown';
    bool isActive = _localToggleStates.containsKey(w['id']) 
        ? _localToggleStates[w['id']]! 
        : (w['state']?['isActive'] ?? false);
        
    Color color = _hexToColor(w['appearance']?['primaryColor']);

    IconData icon = Icons.check_circle_outline;
    if (w['icon'] != null && w['icon'].toString().contains('lightbulb')) icon = Icons.lightbulb;
    if (w['icon'] != null && w['icon'].toString().contains('power')) icon = Icons.power_settings_new;

    if (type == 'toggle') {
       return _buildToggleWidget(w, name, icon, isActive, color);
    } else if (type == 'push') {
       return _buildPushWidget(w, name, icon, color);
    } else if (type == 'sensor') {
       // ✅ الحل: التعامل مع null values بشكل صحيح
       final rawValue = w['state']?['lastValue'];
       String value = (rawValue != null && rawValue.toString().trim().isNotEmpty) 
           ? rawValue.toString() 
           : 'Loading...'; // بدل "--" عرض "Loading..."
       String? unit = w['configuration']?['unit'];
       return _buildSensorWidget(name, icon, value, color, unit);
    } else if (type == 'slider') {
       return _buildSliderWidget(w, item);
    } else if (type == 'terminal') {
       return TerminalWidget(id: w['id'], title: name, isEditMode: _isEditMode, isLocalMode: true, requireBiometric: w['configuration']?['biometricEnabled'] ?? false);
    } else if (type == 'colorpicker') {
       return _buildColorPickerWidget(w, item);
    }
    
    return GlassCard(
      baseColor: AppTheme.cardBaseColor,
      child: Center(child: Text(name, style: const TextStyle(color: Colors.white)))
    );
  }

  Widget _buildToggleWidget(dynamic w, String title, IconData icon, bool value, Color color) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = constraints.biggest.shortestSide;
      final config = w['configuration'] ?? {};
      final String onCmd = config['onCommand'] ?? 'ON';
      final String offCmd = config['offCommand'] ?? 'OFF';

      return GestureDetector(
        onTap: _isEditMode ? null : () async {
            if (config['biometricEnabled'] == true) {
              bool auth = await BiometricService.authenticate(context);
              if (!auth) return;
            }
            HapticHelper.lightFeedback();
            bool newState = !value;
            setState(() => _localToggleStates[w['id']] = newState);
            try {
               await LocalService.sendCommand(w['id'], newState ? onCmd : offCmd);
            } catch(e) {
               setState(() => _localToggleStates[w['id']] = value);
            }
        },
        child: GlassCard(
          borderColor: color,
          baseColor: value ? color.withValues(alpha: 0.1) : AppTheme.cardBaseColor,
          child: Padding(
            padding: EdgeInsets.all(size * 0.1),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: size * 0.35, color: value ? color : Colors.white24),
                SizedBox(height: size * 0.05),
                Text(title, 
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: size * 0.14), 
                  textAlign: TextAlign.center,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: size * 0.05),
                Expanded(
                  child: FittedBox(
                     fit: BoxFit.scaleDown,
                     child: IgnorePointer(
                        child: CupertinoSwitch(
                          value: value, 
                          activeTrackColor: color, 
                          onChanged: (_) {},
                        ),
                     ),
                  ),
                ),
              ],
            ),
          )
        ),
      );
    });
  }

  Widget _buildPushWidget(dynamic w, String title, IconData icon, Color color) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = constraints.biggest.shortestSide;
      return _LocalPushButtonWidget(
        widgetData: w,
        title: title,
        icon: icon,
        color: color,
        size: size,
        isEditMode: _isEditMode,
      );
    });
  }

  Widget _buildSensorWidget(String title, IconData icon, String value, Color color, [String? unit]) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = constraints.biggest.shortestSide;
      final showUnit = unit != null && unit.trim().isNotEmpty;

      return GlassCard(
        borderColor: color,
        baseColor: AppTheme.cardBaseColor,
        child: Padding(
           padding: EdgeInsets.all(size * 0.1),
           child: Column(
             mainAxisAlignment: MainAxisAlignment.center,
             children: [
               Icon(icon, size: size * 0.25, color: color),
               SizedBox(height: size * 0.05),
               Text(title, style: TextStyle(color: Colors.white54, fontSize: size * 0.11), maxLines: 1),
               SizedBox(height: size * 0.03),
               Expanded(
                 child: FittedBox(
                   fit: BoxFit.scaleDown,
                   child: Row(
                     mainAxisSize: MainAxisSize.min,
                     crossAxisAlignment: CrossAxisAlignment.end,
                     children: [
                       Text(value, 
                         style: TextStyle(color: Colors.white, fontSize: size * 0.18, fontWeight: FontWeight.bold),
                         textAlign: TextAlign.center,
                       ),
                       if (showUnit) ...[
                         const SizedBox(width: 4),
                         Padding(
                           padding: const EdgeInsets.only(bottom: 2),
                           child: Text(unit, style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: size * 0.08)),
                         ),
                       ],
                     ],
                   ),
                 ),
               ),
             ],
           ),
        )
      );
    });
  }

  Widget _buildSliderWidget(dynamic w, GridItemData item) {
    final String id = w['id'];
    final String title = w['name'] ?? 'Slider';
    final config = w['configuration'] ?? {};
    final String? unit = config['unit'];
    final double minVal = double.tryParse(config['min']?.toString() ?? '0') ?? 0;
    final double maxVal = double.tryParse(config['max']?.toString() ?? '100') ?? 100;
    
    // Initial value from state or local
    final double currentVal = _sliderValues[id] ?? double.tryParse(w['state']?['lastValue']?.toString() ?? minVal.toString()) ?? minVal;
    
    return GlassCard(
      borderColor: _hexToColor(w['appearance']?['primaryColor']),
      baseColor: AppTheme.cardBaseColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(currentVal.toStringAsFixed(0), style: TextStyle(color: _hexToColor(w['appearance']?['primaryColor']), fontSize: 11, fontWeight: FontWeight.bold)),
                    if (unit != null && unit.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 2),
                        child: Text(unit, style: const TextStyle(color: Colors.white54, fontSize: 9)),
                      ),
                  ],
                ),
              ],
            ),
            if (!_isEditMode)
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                  ),
                  child: Slider(
                    value: currentVal.clamp(minVal, maxVal),
                    min: minVal, 
                    max: maxVal,
                    activeColor: _hexToColor(w['appearance']?['primaryColor']),
                    inactiveColor: Colors.white12,
                    onChanged: (v) {
                       setState(() {
                          _sliderValues[id] = v;
                       });
                    },
                    onChangeEnd: (v) async {
                       HapticHelper.lightFeedback();
                       _lastSliderUpdate[id] = DateTime.now();
                       try {
                          await LocalService.sendCommand(id, v.toStringAsFixed(0));
                       } catch (e) {
                          if (mounted) {
                             AppSnackbar.showError(context, 'خطأ في إرسال القيمة: $e');
                             setState(() { _sliderValues.remove(id); });
                          }
                       }
                    },
                  ),
                ),
              ),
          ],
        ),
      )
    );
  }

  Widget _buildSwatch(Color color, Function(Color) onTap) {
    return GestureDetector(
      onTap: () {
        HapticHelper.lightFeedback();
        onTap(color);
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white54, width: 2),
          boxShadow: [
             BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 1)
          ]
        ),
      ),
    );
  }

  Widget _buildColorPickerWidget(dynamic w, GridItemData item) {
    final String id = w['id'];
    final String title = w['name'] ?? 'Color Picker';
    Color currentColor = _hexToColor(w['appearance']?['primaryColor']);
    
    if (w['state']?['lastValue'] != null) {
       String h = w['state']['lastValue'].toString().replaceAll('#', '');
       if (h.length == 6 || h.length == 8) {
         if (h.length == 6) h = 'FF$h';
         try {
           currentColor = Color(int.parse(h, radix: 16));
         } catch(_) {}
       }
    }

    return GlassCard(
      borderColor: currentColor,
      baseColor: AppTheme.cardBaseColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Inner glow blob
          Positioned(
            right: -20,
            bottom: -20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: currentColor.withValues(alpha: 0.3),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: Container(),
              ),
            ),
          ),
          InkWell(
            onTap: _isEditMode ? null : () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (BuildContext context) {
                  Color pickerColor = currentColor;
                  Timer? debounceTimer;
                  
                  return StatefulBuilder(
                    builder: (context, setModalState) {
                      return BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppTheme.darkBackground.withValues(alpha: 0.8),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                              ),
                              const SizedBox(height: 24),
                              Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 24),
                              ColorPicker(
                                pickerColor: pickerColor,
                                onColorChanged: (Color color) {
                                  setModalState(() => pickerColor = color);
                                  HapticHelper.lightFeedback();
                                  
                                  if (debounceTimer?.isActive ?? false) debounceTimer!.cancel();
                                  debounceTimer = Timer(const Duration(milliseconds: 150), () async {
                                     String hexString = '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
                                     setState(() {
                                        w['state'] ??= {};
                                        w['state']['lastValue'] = hexString;
                                     });
                                     try {
                                       await LocalService.sendCommand(id, hexString);
                                     } catch (_) {}
                                  });
                                },
                                pickerAreaHeightPercent: 0.7,
                                enableAlpha: true,
                                displayThumbColor: true,
                                paletteType: PaletteType.hsvWithHue,
                              ),
                              const SizedBox(height: 20),
                              // Quick Swatches
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                   _buildSwatch(Colors.white, (c) {
                                     setModalState(() => pickerColor = c);
                                     String hexString = '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
                                     setState(() { w['state'] ??= {}; w['state']['lastValue'] = hexString; });
                                     LocalService.sendCommand(id, hexString);
                                   }),
                                   _buildSwatch(const Color(0xFFFFD1A4), (c) { // Warm white
                                     setModalState(() => pickerColor = c);
                                     String hexString = '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
                                     setState(() { w['state'] ??= {}; w['state']['lastValue'] = hexString; });
                                     LocalService.sendCommand(id, hexString);
                                   }),
                                   _buildSwatch(Colors.red, (c) {
                                     setModalState(() => pickerColor = c);
                                     String hexString = '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
                                     setState(() { w['state'] ??= {}; w['state']['lastValue'] = hexString; });
                                     LocalService.sendCommand(id, hexString);
                                   }),
                                   _buildSwatch(Colors.green, (c) {
                                     setModalState(() => pickerColor = c);
                                     String hexString = '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
                                     setState(() { w['state'] ??= {}; w['state']['lastValue'] = hexString; });
                                     LocalService.sendCommand(id, hexString);
                                   }),
                                   _buildSwatch(Colors.blue, (c) {
                                     setModalState(() => pickerColor = c);
                                     String hexString = '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
                                     setState(() { w['state'] ??= {}; w['state']['lastValue'] = hexString; });
                                     LocalService.sendCommand(id, hexString);
                                   }),
                                ]
                              ),
                              const SizedBox(height: 30),
                            ],
                          ),
                        ),
                      );
                    }
                  );
                },
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.color_lens, color: currentColor, size: 36),
                  const SizedBox(height: 8),
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDockButton({
    required Key? key,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: () {
        HapticHelper.lightFeedback();
        onTap();
      },
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.12),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 1.2),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }

  Widget _buildCenterVoiceButton() {
    return InkWell(
      onTap: () {
        HapticHelper.lightFeedback();
        _showVoiceOverlay();
      },
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [AppTheme.primaryCyan, AppTheme.primaryViolet],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryCyan.withValues(alpha: 0.4),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: const Icon(Icons.mic, color: Colors.black, size: 22),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    for(var i=0; i<_items.length; i++){
       final raw = _rawWidgets.firstWhere((w) => w['id'] == _items[i].id, orElse: () => <String, dynamic>{});
       if (raw.isNotEmpty) {
          _items[i] = GridItemData(
             id: _items[i].id,
             x: _items[i].x, y: _items[i].y, w: _items[i].w, h: _items[i].h,
             child: _buildWidgetByType(raw, _items[i])
          );
       }
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundBase,
      appBar: PremiumAppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppLocalization.get('local_control'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_isConnected ? Icons.wifi : Icons.wifi_off, size: 10, color: _isConnected ? Colors.greenAccent : Colors.redAccent),
                const SizedBox(width: 4),
                Text(
                  LocalService.deviceIp.isEmpty ? AppLocalization.get('no_ip_selected') : LocalService.deviceIp,
                  style: TextStyle(fontSize: 10, color: _isConnected ? Colors.greenAccent : Colors.white38),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_isEditMode ? Icons.lock_open : Icons.lock_outline, color: _isEditMode ? AppTheme.primaryCyan : Colors.white54),
            onPressed: () {
              setState(() => _isEditMode = !_isEditMode);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          const SizedBox.expand(),
          Positioned(
            top: -150,
            right: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryViolet.withValues(alpha: 0.18),
              ),
              child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 120, sigmaY: 120), child: Container()),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.neonBlue.withValues(alpha: 0.15),
              ),
              child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container()),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).size.height * 0.3,
            left: MediaQuery.of(context).size.width * 0.1,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accentNeon.withValues(alpha: 0.12),
              ),
              child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90), child: Container()),
            ),
          ),
          _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryCyan))
              : RefreshIndicator(
                  color: AppTheme.primaryCyan,
                  backgroundColor: AppTheme.cardBaseColor,
                  onRefresh: () async {
                    await _loadWidgets();
                    await _loadScenes();
                    await _checkConnection();
                  },
                  child: _rawWidgets.isEmpty
                      ? CustomScrollView(
                          slivers: [
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
                                child: Center(
                                  child: GlassCard(
                                    borderColor: AppTheme.primaryCyan.withValues(alpha: 0.3),
                                    baseColor: AppTheme.cardBaseColor,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 20.0),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.wifi_tethering_outlined, size: 64, color: AppTheme.primaryCyan),
                                          const SizedBox(height: 16),
                                          Text(
                                            AppLocalization.get('no_widgets'),
                                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            AppLocalization.get('add_ip_hint'),
                                            style: const TextStyle(color: Colors.white38, fontSize: 13),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 24),
                                          GlowingButton(
                                            width: double.infinity,
                                            onPressed: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(builder: (_) => const LocalSettingsScreen()),
                                            ).then((_) => _init()),
                                            child: Text(
                                              AppLocalization.isArabicNotifier.value
                                                  ? 'إنشاء / إعادة تعيين الأدوات المحلية'
                                                  : 'Create / Reset Local Widgets',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : SingleChildScrollView(
                          key: _localGridKey,
                          physics: _isScrollingLocked ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 110),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildQuickScenes(_scenes.where((s) => s['showOnDashboard'] == true).toList()),
                              InteractiveGrid(
                                items: _items,
                                crossAxisCount: 4,
                                isEditMode: _isEditMode,
                                onItemChanged: (item) {
                                   _updateWidgetPosition(item);
                                },
                              ),
                            ],
                          ),
                        ),
                ),
          
          // Unified Horizontal Floating Glass Quick-Action Dock
          Positioned(
            bottom: 20,
            left: 15,
            right: 15,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(40),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBaseColor.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(
                      color: AppTheme.primaryCyan.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryCyan.withValues(alpha: 0.1),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Logout / Exit Button
                      _buildDockButton(
                        key: null,
                        icon: Icons.logout,
                        color: Colors.redAccent,
                        onTap: () => Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (r) => false,
                        ),
                      ),
                      
                      // Local Settings Button
                      _buildDockButton(
                        key: null,
                        icon: Icons.settings,
                        color: AppTheme.primaryCyan,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LocalSettingsScreen()),
                        ).then((_) => _init()),
                      ),
                      
                      // Central Pulsing Mic / Voice Control Button
                      _buildCenterVoiceButton(),
                      
                      // Smart Scenes Button
                      _buildDockButton(
                        key: null,
                        icon: Icons.bolt,
                        color: Colors.amberAccent,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SmartScenesScreen(isLocalMode: true)),
                        ).then((_) => _loadScenes()),
                      ),
                      
                      // AI Assistant Button
                      _buildDockButton(
                        key: _aiTourKey,
                        icon: Icons.auto_awesome,
                        color: Colors.purpleAccent,
                        onTap: () {
                          showGlassDialog(
                            context: context,
                            barrierColor: Colors.black.withValues(alpha: 0.5),
                            builder: (context) => const AiChatOverlay(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocalPushButtonWidget extends StatefulWidget {
  final Map<String, dynamic> widgetData;
  final String title;
  final IconData icon;
  final Color color;
  final double size;
  final bool isEditMode;

  const _LocalPushButtonWidget({
    required this.widgetData,
    required this.title,
    required this.icon,
    required this.color,
    required this.size,
    required this.isEditMode,
  });

  @override
  State<_LocalPushButtonWidget> createState() => _LocalPushButtonWidgetState();
}

class _LocalPushButtonWidgetState extends State<_LocalPushButtonWidget> {
  bool _isPressed = false;

  Future<void> _handlePress() async {
    if (widget.isEditMode || _isPressed) return;
    final config = widget.widgetData['configuration'] ?? {};
    if (config['biometricEnabled'] == true) {
      bool auth = await BiometricService.authenticate(context);
      if (!auth) return;
    }
    HapticHelper.lightFeedback();
    setState(() => _isPressed = true);
    try {
      final onCmd = config['onCommand'] ?? 'ON';
      await LocalService.sendCommand(widget.widgetData['id'], onCmd);
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _handlePress(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: widget.color.withValues(alpha: _isPressed ? 0.8 : 0.2),
            width: _isPressed ? 1.5 : 1.2,
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _isPressed
                ? [widget.color.withValues(alpha: 0.35), widget.color.withValues(alpha: 0.15)]
                : [Colors.white.withValues(alpha: 0.1), Colors.white.withValues(alpha: 0.05)],
          ),
          boxShadow: _isPressed
              ? [BoxShadow(color: widget.color.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: 2)]
              : [],
        ),
        child: Padding(
          padding: EdgeInsets.all(widget.size * 0.1),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: _isPressed ? 0.85 : 1.0,
                duration: const Duration(milliseconds: 150),
                child: Icon(
                  widget.icon,
                  size: widget.size * 0.4,
                  color: _isPressed ? widget.color : widget.color.withValues(alpha: 0.7),
                ),
              ),
              SizedBox(height: widget.size * 0.08),
              Text(
                widget.title,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: widget.size * 0.14,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
