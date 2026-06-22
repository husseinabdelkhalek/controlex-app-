import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/glass_card.dart';
import '../widgets/ai_floating_button.dart';
import '../widgets/interactive_grid.dart';
import '../theme/app_theme.dart';
import 'settings_screen.dart';
import 'account_screen.dart';
import 'local_dashboard_screen.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../widgets/joystick_widget.dart';
import '../widgets/terminal_widget.dart';
import '../services/biometric_service.dart';
import '../widgets/interactive_chart_widget.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../widgets/voice_command_overlay.dart';
import '../services/notification_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/app_tour_overlay.dart';
import '../services/voice_parser.dart';
import 'automations_screen.dart';
import 'smart_scenes_screen.dart';
import '../widgets/app_snackbar.dart';
import 'manage_pages_dialog.dart';
import 'dart:async';
import '../core/haptic_helper.dart';
import '../core/localization.dart';
import '../widgets/ai_chat_overlay.dart';


class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isEditMode = false;
  bool _isLoading = true;
  List<dynamic> _scenes = [];
  final Map<String, bool> _executingScenes = {};
  bool _isScrollingLocked = false;
  List<GridItemData> _items = [];
  List<dynamic> _rawWidgets = [];
  List<dynamic> _notifications = [];
  int _unreadCount = 0;
  final Map<String, double> _sliderValues = {};
  final Map<String, DateTime> _lastSliderUpdate = {};
  Map<String, bool> _localToggleStates = {};
  
  // Local position cache - preserves user's layout even on restarts/slow server
  Map<String, Map<String, int>> _localPositions = {};
  Map<String, List<Map<String, dynamic>>> _chartHistory = {};
  Map<String, dynamic>? _userProfile;
  List<dynamic> _pages = [];
  String _activePageId = 'all';
  
  // Cold-start retry state
  int _retryCount = 0;
  static const int _maxRetries = 5;
  String? _serverStatusMessage;
  bool _isLocalControlPinned = false;

  // GlobalKeys for App Tour highlights
  final GlobalKey _drawerKey = GlobalKey();
  final GlobalKey _notificationsKey = GlobalKey();
  final GlobalKey _editKey = GlobalKey();
  final GlobalKey _gridKey = GlobalKey();
  final GlobalKey _micKey = GlobalKey();
  final GlobalKey _aiTourKey = GlobalKey();
  final GlobalKey _addKey = GlobalKey();

  void _onLangChange() => setState(() {});

  void _loadPinState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _isLocalControlPinned = prefs.getBool('pin_local_control') ?? false;
        });
      }
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    AppLocalization.isArabicNotifier.addListener(_onLangChange);
    _loadPinState();
    _loadLocalPositions().then((_) {
       _loadChartHistory().then((_) {
          _loadWidgets();
          _fetchProfile();
          _fetchNotifications();
          _loadScenes();
       });
    });
    _setupSocket();
    
    // Register FCM token now that we have an active session
    NotificationService.registerAfterLogin();
  }

  @override
  void dispose() {
    AppLocalization.isArabicNotifier.removeListener(_onLangChange);
    super.dispose();
  }

  Future<void> _fetchNotifications() async {
     try {
        final notifs = await ApiService.getNotifications();
        if (mounted) setState(() {
            _notifications = notifs;
            _unreadCount = 0;
        });
     } catch(_) {}
  }

  Future<void> _fetchProfile() async {
     try {
        final profile = await ApiService.userMe();
        if (mounted) {
          setState(() {
            _userProfile = profile;
            _pages = profile['preferences']?['pages'] ?? [];
          });
        }
     } catch(_) {}
  }

  Future<void> _loadScenes() async {
    try {
      final list = await ApiService.getScenes();
      if (mounted) {
        setState(() {
          _scenes = list;
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
      await ApiService.executeScene(id, actions);

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
                    MaterialPageRoute(builder: (_) => const SmartScenesScreen(isLocalMode: false)),
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
                  borderColor: isExecuting ? color : color.withOpacity(0.2),
                  baseColor: isExecuting ? color.withOpacity(0.08) : AppTheme.cardBaseColor,
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
                              color: color.withOpacity(0.12),
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
  Future<void> _loadLocalPositions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('local_widget_positions');
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
      await prefs.setString('local_widget_positions', json.encode(_localPositions));
    } catch (_) {}
  }

  Future<void> _loadChartHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('local_chart_history');
      if (saved != null) {
        final decoded = json.decode(saved) as Map<String, dynamic>;
        setState(() {
          _chartHistory = decoded.map((k, v) {
            final list = (v as List).map((e) => Map<String, dynamic>.from(e)).toList();
            return MapEntry(k, list);
          });
        });
      }
    } catch (_) {}
  }

  Future<void> _saveChartHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('local_chart_history', json.encode(_chartHistory));
    } catch (_) {}
  }

  Future<void> _checkFirstTimeTour() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasSeen = prefs.getBool('has_completed_tour_v1') ?? false;
      if (!hasSeen && mounted) {
        _startTour();
      }
    } catch (_) {}
  }

  void _startTour() {
    final List<TourStep> tourSteps = [
      const TourStep(
        titleKey: 'tour_welcome_title',
        descKey: 'tour_welcome_desc',
      ),
      TourStep(
        titleKey: 'tour_drawer_title',
        descKey: 'tour_drawer_desc',
        targetKey: _drawerKey,
        isCircular: true,
      ),
      TourStep(
        titleKey: 'tour_grid_title',
        descKey: 'tour_grid_desc',
        targetKey: _gridKey,
      ),
      TourStep(
        titleKey: 'tour_notifications_title',
        descKey: 'tour_notifications_desc',
        targetKey: _notificationsKey,
        isCircular: true,
      ),
      TourStep(
        titleKey: 'tour_edit_title',
        descKey: 'tour_edit_desc',
        targetKey: _editKey,
        isCircular: true,
      ),
      TourStep(
        targetKey: _micKey,
        titleKey: 'tour_mic_title',
        descKey: 'tour_mic_desc',
      ),
      TourStep(
        targetKey: _aiTourKey,
        titleKey: 'المساعد الذكي (AI Assistant)',
        descKey: 'يمكنك الاعتماد على المساعد الذكي لتنفيذ أوامرك، إنشاء القواعد، وإدارة منزلك ذكياً عبر المحادثة.',
      ),
      TourStep(
        titleKey: 'tour_add_title',
        descKey: 'tour_add_desc',
        targetKey: _addKey,
        isCircular: true,
      ),
      TourStep(
        titleKey: 'tour_settings_transition_title',
        descKey: 'tour_settings_transition_desc',
        targetKey: _addKey,
        isCircular: true,
      ),
    ];

    AppTour.show(
      context,
      tourSteps,
      onComplete: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('has_completed_tour_v1', true);
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen(startTour: true)),
          ).then((result) {
            if (result == 'start_tour') {
              Future.delayed(const Duration(milliseconds: 300), () {
                if (mounted) _startTour();
              });
            } else {
              _loadWidgets();
            }
          });
        }
      },
      onSkip: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('has_completed_tour_v1', true);
      },
    );
  }



  Future<void> _setupSocket() async {
    try {
      final user = await ApiService.userMe();
      print('👤 User ID for socket: ${user['id']}');
      
      if (user['id'] != null) {
        // ✅ الآن نستخدم await لأن الاتصال أصبح async
        await SocketService.connect(user['id']);
        print('🔗 Setting up socket listeners...');
        
        // Listen for widget status updates (toggles, sliders, joysticks)
        SocketService.socket?.on('widget-status-update', (data) {
          print('📡 Received widget-status-update: $data');
          if (mounted && !_isEditMode) {
            _updateWidgetFromSocket(data);
          }
        });
        
        // Listen for sensor-specific data
        SocketService.socket?.on('sensor-data', (data) {
          print('📡 Received sensor-data event: $data');
          if (mounted && !_isEditMode) {
            _updateWidgetFromSocket(data);
          }
        });
        
        // Alternative sensor event name
        SocketService.socket?.on('new-sensor-reading', (data) {
          print('📡 Received new-sensor-reading event: $data');
          if (mounted && !_isEditMode) {
            _updateWidgetFromSocket(data);
          }
        });
        
        // Listen for notifications
        SocketService.socket?.on('new-notification', (data) {
          print('📡 Received new-notification: $data');
          if (mounted) {
            setState(() {
              _notifications.insert(0, data);
              _unreadCount++;
            });
            // Fire native OS push notification
            NotificationService.showNotification(
              title: data['title'] ?? 'ControlEx',
              body: data['message'] ?? 'New notification',
              id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            );
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(data['title'] ?? 'New Notification'),
              backgroundColor: AppTheme.neonBlue,
            ));
          }
        });
        
        print('✅ Socket listeners set up successfully');
      } else {
        print('❌ User ID not found - socket not connected');
      }
    } catch (e) {
      print('❌ Error setting up socket: $e');
    }
  }

  void _updateWidgetFromSocket(dynamic data) {
    if (data == null) {
      print('⚠️  Received null socket data');
      return;
    }
    
    String? widgetId = data['widgetId'];
    if (widgetId == null) {
      print('⚠️  Socket data missing widgetId: $data');
      return;
    }
    
    print('🔄 Updating widget $widgetId with socket data: $data');
    
    setState(() {
      for (var i = 0; i < _rawWidgets.length; i++) {
        if (_rawWidgets[i]['id'] == widgetId) {
          _rawWidgets[i]['state'] ??= {};
          
          // Update lastValue if provided (for sensors)
          if (data['lastValue'] != null) {
            print('   📊 Setting lastValue: ${data['lastValue']}');
            _rawWidgets[i]['state']['lastValue'] = data['lastValue'].toString();
          }
          
          // Also support 'value' key from sensor-data events
          if (data['value'] != null) {
            print('   📊 Setting value: ${data['value']}');
            _rawWidgets[i]['state']['lastValue'] = data['value'].toString();
          }

          if (_rawWidgets[i]['type'] == 'chart') {
             double? val = double.tryParse(_rawWidgets[i]['state']['lastValue'].toString());
             if (val != null) {
                _chartHistory.putIfAbsent(widgetId, () => []);
                _chartHistory[widgetId]!.add({'time': DateTime.now().toIso8601String(), 'value': val});
                if (_chartHistory[widgetId]!.length > 1000) {
                   _chartHistory[widgetId]!.removeAt(0);
                }
                _saveChartHistory();
             }
          }
          
          // Update other state properties
          if (data['isActive'] != null) {
            print('   🔌 Setting isActive: ${data['isActive']}');
            _rawWidgets[i]['state']['isActive'] = data['isActive'];
          }
          
          if (data['lastUpdate'] != null) {
            _rawWidgets[i]['state']['lastUpdate'] = data['lastUpdate'];
          }
          
          // Handle slider-specific updates
          if (_rawWidgets[i]['type'] == 'slider') {
            if (_lastSliderUpdate.containsKey(widgetId) && DateTime.now().difference(_lastSliderUpdate[widgetId]!).inSeconds < 3) {
              // Skip overwriting if the user just changed it recently to avoid snap-back
            } else {
              double? newVal = double.tryParse(_rawWidgets[i]['state']['lastValue'].toString());
              if (newVal != null) {
                _sliderValues[widgetId] = newVal;
              }
            }
          }
          
          print('✅ Widget $widgetId updated successfully');
          break;
        }
      }
      
      if (!_rawWidgets.any((w) => w['id'] == widgetId)) {
        print('⚠️  Widget with ID $widgetId not found in _rawWidgets');
      }
    });
  }

  Future<void> _refreshWidgetStates() async {
    print('🔄 Manually refreshing widget states from API...');
    try {
      final widgets = await ApiService.getWidgets();
      if (mounted) {
        setState(() {
          _rawWidgets = widgets;
          _sliderValues.clear(); // Ensure UI reflects server data
          
          // Log new sensor values
          for (var w in widgets) {
            if (w['type'] == 'sensor') {
              final value = w['state']?['lastValue'];
              print('📊 Updated sensor ${w['id']}: $value');
            }
          }
        });
        print('✅ Widget states refreshed');
      }
    } catch (e) {
      print('❌ Error refreshing widget states: $e');
    }
  }

  Future<void> _loadWidgets({bool isRetry = false}) async {
    if (!isRetry) {
      _retryCount = 0;
      if (mounted) setState(() {
        _isLoading = true;
        _serverStatusMessage = null;
      });
    }
    try {
       print('📥 Loading widgets from API...');
       final widgets = await ApiService.getWidgets();
       
       // ✅ Success: process and show whatever the server returned
       // (empty list is valid - user might just have no widgets)
       print('📦 Received ${widgets.length} widgets from API');
       
       // Log sensor widgets specifically
       for (var w in widgets) {
         if (w['type'] == 'sensor') {
           print('📊 Sensor Widget: ${w['id']} - ${w['name']}');
           print('   State: ${w['state']}');
           print('   Value: ${w['state']?['lastValue'] ?? 'null'}');
         }
       }
       
       if (mounted) {
         setState(() {
            _rawWidgets = widgets;
            _isLoading = false;
            _serverStatusMessage = null;
            _retryCount = 0;
         });
       }
       _packItemsForCurrentPage();
       _saveLocalPositions();
       _loadScenes();
       
       // ✅ الحل: بعد التحميل الأول، حاول التحديث بعد 2 ثانية
       // لأن السيرفر قد يحتاج وقت لجمع بيانات السينسور من الأجهزة
       Future.delayed(const Duration(seconds: 2), () {
         if (mounted) {
           print('⏱️  Retrying widget fetch after 2s to get sensor data...');
           _refreshWidgetStates();
         }
       });
       
       if (mounted) {
         WidgetsBinding.instance.addPostFrameCallback((_) {
           _checkFirstTimeTour();
         });
       }
       
    } catch (e) {
       print('❌ Error loading widgets: $e');
       if (_retryCount < _maxRetries) {
         _retryCount++;
         final waitSec = _retryCount <= 2 ? 6 : 10;
         final wakingUp = AppLocalization.get('server_waking_up').replaceAll('%s', '$_retryCount').replaceFirst('%s', '$_maxRetries');
         final waitText = AppLocalization.get('wait_sec').replaceAll('%s', '$waitSec');
         if (mounted) setState(() {
           _serverStatusMessage = '$wakingUp\n$waitText';
         });
         await Future.delayed(Duration(seconds: waitSec));
         if (mounted) return _loadWidgets(isRetry: true);
         return;
       }
       if (mounted) setState(() {
         _isLoading = false;
         _serverStatusMessage = AppLocalization.get('server_error_retry');
       });
    }
  }

  void _updateWidgetPosition(GridItemData item, [bool showToast = true]) async {
    // 1. Immediately cache locally
    _localPositions[item.id] = {'x': item.x, 'y': item.y, 'w': item.w, 'h': item.h};
    _saveLocalPositions();
    
    // 2. Persist to server using the specialized endpoint
    try {
      await ApiService.updateWidgetPosition(item.id, item.x, item.y, item.w, item.h);
      if (showToast && mounted) {
         AppSnackbar.showSuccess(context, AppLocalization.get('layout_saved') ?? 'Layout Saved');
      }
    } catch (e) {
      if (mounted) AppSnackbar.showError(context, e);
    }
  }

  void _packItemsForCurrentPage() {
    List<GridItemData> list = [];
    for (var w in _rawWidgets) {
      final id = w['id'] as String;
      final pId = w['configuration']?['pageId'] ?? w['pageId'];
      if (_activePageId != 'all' && pId?.toString() != _activePageId) continue;
      
      if (_localPositions.containsKey(id)) {
        final pos = _localPositions[id]!;
        list.add(GridItemData(
            id: id,
            x: pos['x']!, y: pos['y']!, w: pos['w']!, h: pos['h']!,
            child: const SizedBox()
        ));
      } else {
        var gs = w['gs'] ?? w['configuration']?['gs'];
        int x = gs != null ? (gs['x'] ?? 0) : 0;
        int y = gs != null ? (gs['y'] ?? 0) : 0;
        int width = gs != null ? (gs['w'] ?? 1) : 1;
        int height = gs != null ? (gs['h'] ?? 1) : 1;
        
        list.add(GridItemData(
            id: id, x: x, y: y, w: width, h: height,
            child: const SizedBox()
        ));
        
        _localPositions[id] = {'x': x, 'y': y, 'w': width, 'h': height};
      }
    }
    
    InteractiveGrid.pack(list, 4);

    if (mounted) {
      setState(() {
        _items = list;
      });
    }
  }

  Widget _buildPageTabs() {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildPageTab('all', AppLocalization.isArabicNotifier.value ? 'الكل' : 'All'),
          ..._pages.map((p) => _buildPageTab(p['id'].toString(), p['name'].toString())),
        ],
      ),
    );
  }

  Widget _buildPageTab(String id, String name) {
    final isActive = _activePageId == id;
    return GestureDetector(
      onTap: () {
        setState(() => _activePageId = id);
        _packItemsForCurrentPage();
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primaryCyan.withOpacity(0.2) : Colors.white.withOpacity(0.05),
          border: Border.all(color: isActive ? AppTheme.primaryCyan : Colors.white12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(name, style: TextStyle(
            color: isActive ? AppTheme.primaryCyan : Colors.white54,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          )),
        ),
      ),
    );
  }

  void _handleSwipe(bool isLeft) {
    final pageIds = ['all', ..._pages.map((p) => p['id'].toString())];
    final currentIndex = pageIds.indexOf(_activePageId);
    if (currentIndex == -1) return;

    final isRtl = AppLocalization.isArabicNotifier.value;
    final direction = isLeft ? (isRtl ? -1 : 1) : (isRtl ? 1 : -1);
    final targetIndex = currentIndex + direction;

    if (targetIndex >= 0 && targetIndex < pageIds.length) {
      setState(() {
        _activePageId = pageIds[targetIndex];
      });
      _packItemsForCurrentPage();
    }
  }

  /// Shows a bottom-sheet that lets the user pick a page to assign this widget to.
  void _showMoveToPageDialog(GridItemData item) {
    // Find the raw widget data
    final raw = _rawWidgets.firstWhere((w) => w['id'] == item.id, orElse: () => null);
    if (raw == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F0E26),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalization.isArabicNotifier.value ? 'نقل الأداة إلى صفحة' : 'Move Widget to Page',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              // "All / No page" option
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.primaryCyan.withOpacity(0.15),
                  ),
                  child: const Icon(Icons.dashboard, color: AppTheme.primaryCyan, size: 20),
                ),
                title: Text(
                  AppLocalization.isArabicNotifier.value ? 'الكل (بدون صفحة)' : 'All (no page)',
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    raw['configuration'] ??= {};
                    raw['configuration']['pageId'] = null;
                    raw['pageId'] = null;
                    await ApiService.updateWidgetPageId(raw['id'], null);
                    setState(() {});
                    _packItemsForCurrentPage();
                    if (mounted) AppSnackbar.showSuccess(context, AppLocalization.isArabicNotifier.value ? 'تم نقل الأداة' : 'Widget moved');
                  } catch (e) {
                    if (mounted) AppSnackbar.showError(context, e);
                  }
                },
              ),
              const Divider(color: Colors.white12),
              ..._pages.map((p) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFBB86FC).withOpacity(0.15),
                    ),
                    child: const Icon(Icons.layers, color: Color(0xFFBB86FC), size: 20),
                  ),
                  title: Text(p['name'], style: const TextStyle(color: Colors.white)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    try {
                      final pageId = p['id'].toString();
                      raw['configuration'] ??= {};
                      raw['configuration']['pageId'] = pageId;
                      raw['pageId'] = pageId;
                      await ApiService.updateWidgetPageId(raw['id'], pageId);
                      setState(() {});
                      _packItemsForCurrentPage();
                      if (mounted) AppSnackbar.showSuccess(context, AppLocalization.isArabicNotifier.value ? 'تم نقل الأداة' : 'Widget moved');
                    } catch (e) {
                      if (mounted) AppSnackbar.showError(context, e);
                    }
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWidgetByType(dynamic w, GridItemData item) {
    String type = w['type'] ?? 'toggle';
    String name = w['name'] ?? 'Unknown';
    bool isActive = _localToggleStates.containsKey(w['id']) 
        ? _localToggleStates[w['id']]! 
        : (w['state']?['isActive'] ?? false);
        
    Color color = AppTheme.primaryCyan;
    if (w['appearance'] != null && w['appearance']['primaryColor'] != null) {
       String h = w['appearance']['primaryColor'].toString().replaceAll('#', '');
       if (h.length == 6) h = 'FF$h';
       color = Color(int.parse(h, radix: 16));
    }

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
    } else if (type == 'chart') {
       return _buildChartWidget(w, name, color);
    } else if (type == 'slider') {
       return _buildSliderWidget(w, item);
    } else if (type == 'joystick') {
       return JoystickWidget(
          id: w['id'], title: name, isEditMode: _isEditMode,
          upCmd: w['configuration']?['upCommand'] ?? 'UP',
          downCmd: w['configuration']?['downCommand'] ?? 'DOWN',
          leftCmd: w['configuration']?['leftCommand'] ?? 'LEFT',
          rightCmd: w['configuration']?['rightCommand'] ?? 'RIGHT',
          onInteractionStart: () => setState(() => _isScrollingLocked = true),
          onInteractionEnd: () => setState(() => _isScrollingLocked = false),
       );
    } else if (type == 'terminal') {
       return TerminalWidget(id: w['id'], title: name, isEditMode: _isEditMode, requireBiometric: w['configuration']?['biometricEnabled'] ?? false);
    } else if (type == 'colorpicker') {
       return _buildColorPickerWidget(w, item);
    }
    
    return GlassCard(
      baseColor: AppTheme.cardBaseColor,
      child: Center(child: Text(name, style: const TextStyle(color: Colors.white)))
    );
  }

  @override
  Widget build(BuildContext context) {
    // Sync children
    for(var i=0; i<_items.len    return Scaffold(
      backgroundColor: AppTheme.backgroundBase,
      appBar: PremiumAppBar(
        titleText: AppLocalization.get('dashboard'),
        leading: Builder(
          builder: (context) {
            return IconButton(
              key: _drawerKey,
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
            );
          }
        ),
        actions: [
          Stack(
            key: _notificationsKey,
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications, color: Colors.white),
                onPressed: _showNotifications,
              ),
              if (_unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text('$_unreadCount', style: const TextStyle(color: Colors.white, fontSize: 10), textAlign: TextAlign.center),
                  ),
                )
            ],
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: AppTheme.primaryCyan),
            onPressed: () async {
              final updatedPages = await showDialog<List<dynamic>>(
                context: context,
                builder: (ctx) => ManagePagesDialog(currentPages: _pages),
              );
              if (updatedPages != null) {
                setState(() {
                  _pages = updatedPages;
                  if (!_pages.any((p) => p['id'] == _activePageId)) {
                    _activePageId = 'all';
                  }
                });
                _packItemsForCurrentPage();
              }
            },
          ),
          IconButton(
            key: _editKey,
            icon: Icon(_isEditMode ? Icons.check_circle : Icons.edit, color: _isEditMode ? Colors.green : AppTheme.primaryCyan),
            onPressed: () {
              setState(() => _isEditMode = !_isEditMode);
            },
          )
        ],
      ),
      drawer: Drawer(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xDC080614), // Deep dark semi-translucent base
            border: Border(
              right: BorderSide(
                color: AppTheme.primaryCyan.withOpacity(0.2),
                width: 1.5,
              ),
            ),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.primaryViolet.withOpacity(0.15), Colors.transparent],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    border: Border(
                      bottom: BorderSide(color: Colors.white.withOpacity(0.06), width: 1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                       if (_userProfile?['googleProfilePicture'] != null)
                         Container(
                           decoration: BoxDecoration(
                             shape: BoxShape.circle,
                             border: Border.all(color: AppTheme.primaryCyan.withOpacity(0.5), width: 1.5),
                           ),
                           child: CircleAvatar(
                             radius: 30,
                             backgroundImage: NetworkImage(_userProfile?['googleProfilePicture'] as String),
                             backgroundColor: Colors.transparent,
                           ),
                         )
                       else
                         Container(
                           padding: const EdgeInsets.all(8),
                           decoration: BoxDecoration(
                             shape: BoxShape.circle,
                             color: AppTheme.primaryCyan.withOpacity(0.1),
                           ),
                           child: const Icon(Icons.account_circle, size: 48, color: AppTheme.primaryCyan),
                         ),
                       const SizedBox(height: 12),
                       Text(_userProfile?['username'] ?? 'ControlEx User', 
                         style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
                       ),
                       if (_userProfile?['email'] != null)
                         Text(_userProfile?['email'] as String, 
                           style: const TextStyle(color: Colors.white38, fontSize: 11)
                         ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _buildDrawerTile(
                  icon: Icons.dashboard,
                  iconColor: AppTheme.primaryCyan,
                  title: AppLocalization.get('dashboard'),
                  onTap: () => Navigator.pop(context),
                ),
                if (_isLocalControlPinned)
                  _buildDrawerTile(
                    icon: Icons.wifi,
                    iconColor: Colors.orangeAccent,
                    title: AppLocalization.get('local_control'),
                    subtitle: AppLocalization.get('local_desc'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const LocalDashboardScreen()));
                    },
                  ),
                _buildDrawerTile(
                  icon: Icons.settings,
                  iconColor: Colors.white54,
                  title: AppLocalization.get('create_widgets'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())).then((_) => _loadWidgets());
                  },
                ),
                _buildDrawerTile(
                  icon: Icons.auto_awesome,
                  iconColor: Colors.purpleAccent,
                  title: AppLocalization.get('automations'),
                  subtitle: AppLocalization.get('automations_subtitle'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AutomationsScreen()));
                  },
                ),
                _buildDrawerTile(
                  icon: Icons.bolt,
                  iconColor: Colors.amberAccent,
                  title: AppLocalization.get('smart_scenes'),
                  subtitle: AppLocalization.get('smart_scenes_subtitle'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SmartScenesScreen(isLocalMode: false))).then((_) {
                      _loadScenes();
                    });
                  },
                ),
                _buildDrawerTile(
                  icon: Icons.person,
                  iconColor: Colors.white54,
                  title: AppLocalization.get('account'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountScreen())).then((result) {
                      _loadPinState();
                      if (result == 'start_tour') {
                        Future.delayed(const Duration(milliseconds: 300), () {
                          if (mounted) _startTour();
                        });
                      } else {
                        _loadWidgets();
                      }
                    });
                  },
                ),
                _buildDrawerTile(
                  icon: Icons.android,
                  iconColor: Colors.greenAccent,
                  title: AppLocalization.isArabicNotifier.value ? 'تحميل التطبيق / مشاركة' : 'Download / Share App',
                  onTap: () async {
                    Navigator.pop(context);
                    final uri = Uri.parse('https://drive.google.com/file/d/103HWObnaKqg6TGd4tn3DHEUs7M6UJ3To/view?usp=drive_link');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('لا يمكن فتح الرابط')),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [ion);
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('لا يمكن فتح الرابط')),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          // Vibrant Neon Background Mesh
          Positioned(
            top: -150,
            right: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryViolet.withOpacity(0.18),
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
                color: AppTheme.neonBlue.withOpacity(0.15),
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
                color: AppTheme.accentNeon.withOpacity(0.12),
              ),
              child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90), child: Container()),
            ),
          ),
          _isLoading 
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: AppTheme.primaryCyan),
                  if (_serverStatusMessage != null) ...[
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        children: [
                          Text(
                            _serverStatusMessage!,
                            style: const TextStyle(color: Colors.white70, fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            AppLocalization.get('free_hosting_hint'),
                            style: const TextStyle(color: Colors.white38, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              )
            : RefreshIndicator(
                color: AppTheme.primaryCyan,
                backgroundColor: AppTheme.cardBaseColor,
                onRefresh: () async {
                  await Future.wait([
                    _loadWidgets(),
                    _loadScenes(),
                  ]);
                },
                child: GestureDetector(
                  onHorizontalDragEnd: (_isEditMode || _isScrollingLocked)
                      ? null
                      : (details) {
                          if (details.primaryVelocity == null) return;
                          if (details.primaryVelocity! < -200) {
                            _handleSwipe(true);
                          } else if (details.primaryVelocity! > 200) {
                            _handleSwipe(false);
                          }
                        },
                  child: SingleChildScrollView(
                    key: _gridKey,
                    physics: _isScrollingLocked ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildQuickScenes(_scenes.where((s) => s['showOnDashboard'] == true).toList()),
                        if (_pages.isNotEmpty) _buildPageTabs(),
                        if (_items.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 64.0),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _serverStatusMessage ?? AppLocalization.get('no_widgets'),
                                    style: const TextStyle(color: Colors.white54),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  TextButton.icon(
                                    icon: const Icon(Icons.refresh, color: AppTheme.primaryCyan),
                                    label: Text(AppLocalization.get('retry'), style: const TextStyle(color: AppTheme.primaryCyan)),
                                    onPressed: () => _loadWidgets(),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          InteractiveGrid(
                             items: _items,
                             crossAxisCount: 4,
                             isEditMode: _isEditMode,
                             onItemChanged: (item) => _updateWidgetPosition(item, true),
                             onMoveRequest: _pages.isEmpty ? null : (item) => _showMoveToPageDialog(item),
                             onInteractionStateChanged: (active) {
                               setState(() => _isScrollingLocked = active);
                             },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          AiFloatingButton(tourKey: _aiTourKey),
          const SizedBox(height: 16),
          FloatingActionButton(
            key: _micKey,
            heroTag: 'micFAB',
            backgroundColor: AppTheme.primaryCyan,
            child: const Icon(Icons.mic, color: Colors.black),
            onPressed: () {
               VoiceCommandOverlay.show(
                  context, 
                  _rawWidgets,
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
            },
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            key: _addKey,
            heroTag: 'addFAB',
            backgroundColor: AppTheme.primaryViolet,
            child: const Icon(Icons.add, color: Colors.white),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())).then((_) => _loadWidgets()),
          ),
        ],
      ),
    );
  }

  String _formatNotifTime(dynamic ts) {
    if (ts == null) return '';
    try {
      final dt = DateTime.parse(ts.toString()).toLocal();
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } catch (_) {
      return '';
    }
  }

  void _showNotifications() {
     setState(() => _unreadCount = 0);
     showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF0F0E26), // Solid deep dark blue-violet
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (ctx) {
           return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 48), // balance space
                      Text(AppLocalization.isArabicNotifier.value ? 'الإشعارات' : 'Notifications', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      _notifications.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.delete_sweep, color: Colors.redAccent, size: 24),
                            onPressed: () async {
                              // Optimistic UI clear
                              setState(() {
                                _notifications = [];
                              });
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                content: Text(AppLocalization.isArabicNotifier.value ? 'تم مسح جميع الإشعارات' : 'All notifications cleared'),
                                backgroundColor: Colors.redAccent,
                              ));
                              
                              try {
                                await ApiService.clearNotifications();
                              } catch (err) {
                                debugPrint("Background notifications deletion failed: $err");
                              }
                            },
                          )
                        : const SizedBox(width: 48),
                    ],
                  ),
                  const Divider(color: Colors.white12),
                  Expanded(
                    child: _notifications.isEmpty
                      ? Center(child: Text(AppLocalization.isArabicNotifier.value ? 'لا توجد إشعارات بعد' : 'No notifications yet', style: const TextStyle(color: Colors.white38)))
                      : ListView.builder(
                          itemCount: _notifications.length,
                          itemBuilder: (ctx, i) {
                             final n = _notifications[i];
                             final ts = n['timestamp'];
                             return Container(
                               margin: const EdgeInsets.symmetric(vertical: 6),
                               decoration: BoxDecoration(
                                 color: Colors.white.withValues(alpha: 0.04),
                                 borderRadius: BorderRadius.circular(14),
                                 border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                               ),
                               child: ListTile(
                                 contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                 leading: CircleAvatar(
                                   backgroundColor: AppTheme.neonBlue.withValues(alpha: 0.15),
                                   child: const Icon(Icons.notifications_active, color: AppTheme.neonBlue, size: 20),
                                 ),
                                 title: Text(
                                   n['title'] ?? '', 
                                   style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                 ),
                                 subtitle: Text(
                                   n['message'] ?? '', 
                                   style: const TextStyle(color: Colors.white70, fontSize: 12),
                                 ),
                                 trailing: ts != null 
                                   ? Text(
                                       _formatNotifTime(ts), 
                                       style: const TextStyle(color: Colors.white38, fontSize: 10),
                                     )
                                   : null,
                               ),
                             );
                          }
                        )
                  )
                ]
              )
           );
        }
     );
  }

  Widget _buildToggleWidget(dynamic w, String title, IconData icon, bool value, Color color) {
    return LayoutBuilder(builder: (builderContext, constraints) {
      final size = constraints.biggest.shortestSide;
      final config = w['configuration'] ?? {};
      final String onCmd = config['onCommand'] ?? 'ON';
      final String offCmd = config['offCommand'] ?? 'OFF';
      final String id = w['id'];

      return GestureDetector(
        onTap: _isEditMode ? null : () async {
            if (config['biometricEnabled'] == true) {
              bool auth = await BiometricService.authenticate(context);
              if (!auth) return;
            }
            bool newState = !value;
            setState(() => _localToggleStates[id] = newState);
            try {
               await ApiService.sendCommand(id, newState ? onCmd : offCmd);
            } catch(e) {
               debugPrint('Toggle Error: $e');
               setState(() => _localToggleStates[id] = value);
               if (context.mounted) {
                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                   content: Text(e.toString().replaceAll('Exception: ', '')),
                   backgroundColor: Colors.redAccent,
                   duration: const Duration(seconds: 3),
                 ));
               }
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
                          activeColor: color, 
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
    return LayoutBuilder(builder: (builderContext, constraints) {
      final size = constraints.biggest.shortestSide;
      return _PushButtonWidget(
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
    print('🎨 Building sensor widget: $title = $value $unit');
    
    return LayoutBuilder(builder: (builderContext, constraints) {
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

  Widget _buildChartWidget(dynamic w, String title, Color color) {
    final String id = w['id'];
    final config = w['configuration'] ?? {};
    final String? unit = config['unit'];
    final double minVal = double.tryParse(config['min']?.toString() ?? '0') ?? 0;
    final double maxVal = double.tryParse(config['max']?.toString() ?? '100') ?? 100;

    final history = _chartHistory[id] ?? [];
    
    // Add current value if it exists but history is empty (on fresh load)
    if (history.isEmpty && w['state'] != null && w['state']['lastValue'] != null) {
       double? val = double.tryParse(w['state']['lastValue'].toString());
       if (val != null) {
          history.add({'time': DateTime.now().toIso8601String(), 'value': val});
       }
    }

    return InteractiveChartWidget(
      title: title,
      history: history,
      min: minVal,
      max: maxVal,
      color: color,
      isEditMode: _isEditMode,
      unit: unit,
    );
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
                        _lastSliderUpdate[id] = DateTime.now();
                        try {
                          await ApiService.sendCommand(id, v.toStringAsFixed(0));
                       } catch (e) {
                          if (mounted) {
                             ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('خطأ في إرسال القيمة: $e'))
                             );
                             // Revert local value on failure
                             setState(() {
                                _sliderValues.remove(id);
                             });
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
             BoxShadow(color: color.withOpacity(0.5), blurRadius: 8, spreadRadius: 1)
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
                color: currentColor.withOpacity(0.3),
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
                            color: AppTheme.darkBackground.withOpacity(0.8),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
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
                                     String hexString = '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
                                     setState(() {
                                         w['state'] ??= {};
                                         w['state']['lastValue'] = hexString;
                                     });
                                     try {
                                       await ApiService.sendCommand(id, hexString);
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
                                     String hexString = '#${c.value.toRadixString(16).padLeft(8, '0').substring(2)}';
                                     setState(() { w['state'] ??= {}; w['state']['lastValue'] = hexString; });
                                     ApiService.sendCommand(id, hexString);
                                   }),
                                   _buildSwatch(const Color(0xFFFFD1A4), (c) { // Warm white
                                     setModalState(() => pickerColor = c);
                                     String hexString = '#${c.value.toRadixString(16).padLeft(8, '0').substring(2)}';
                                     setState(() { w['state'] ??= {}; w['state']['lastValue'] = hexString; });
                                     ApiService.sendCommand(id, hexString);
                                   }),
                                   _buildSwatch(Colors.red, (c) {
                                     setModalState(() => pickerColor = c);
                                     String hexString = '#${c.value.toRadixString(16).padLeft(8, '0').substring(2)}';
                                     setState(() { w['state'] ??= {}; w['state']['lastValue'] = hexString; });
                                     ApiService.sendCommand(id, hexString);
                                   }),
                                   _buildSwatch(Colors.green, (c) {
                                     setModalState(() => pickerColor = c);
                                     String hexString = '#${c.value.toRadixString(16).padLeft(8, '0').substring(2)}';
                                     setState(() { w['state'] ??= {}; w['state']['lastValue'] = hexString; });
                                     ApiService.sendCommand(id, hexString);
                                   }),
                                   _buildSwatch(Colors.blue, (c) {
                                     setModalState(() => pickerColor = c);
                                     String hexString = '#${c.value.toRadixString(16).padLeft(8, '0').substring(2)}';
                                     setState(() { w['state'] ??= {}; w['state']['lastValue'] = hexString; });
                                     ApiService.sendCommand(id, hexString);
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
}

/// Dedicated StatefulWidget for Push buttons so the press animation 
/// (color flash) is managed locally and never missed due to parent rebuilds.
class _PushButtonWidget extends StatefulWidget {
  final Map<String, dynamic> widgetData;
  final String title;
  final IconData icon;
  final Color color;
  final double size;
  final bool isEditMode;

  const _PushButtonWidget({
    required this.widgetData,
    required this.title,
    required this.icon,
    required this.color,
    required this.size,
    required this.isEditMode,
  });

  @override
  State<_PushButtonWidget> createState() => _PushButtonWidgetState();
}

class _PushButtonWidgetState extends State<_PushButtonWidget> {
  bool _isPressed = false;

  Future<void> _handlePress() async {
    if (widget.isEditMode || _isPressed) return;
    final config = widget.widgetData['configuration'] ?? {};
    if (config['biometricEnabled'] == true) {
      bool auth = await BiometricService.authenticate(context);
      if (!auth) return;
    }
    setState(() => _isPressed = true);
    try {
      final onCmd = config['onCommand'] ?? 'ON';
      await ApiService.sendCommand(widget.widgetData['id'], onCmd);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 3),
        ));
      }
    }
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
