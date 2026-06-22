import '../widgets/app_snackbar.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../core/localization.dart';
import '../widgets/app_tour_overlay.dart';
import 'local_dashboard_screen.dart';
import '../widgets/nfc_bottom_sheet.dart';

class SettingsScreen extends StatefulWidget {
  final bool startTour;
  const SettingsScreen({super.key, this.startTour = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  TabController? _tabController;

  // GlobalKeys for Onboarding Tour Highlights
  final GlobalKey _nameKey = GlobalKey();
  final GlobalKey _feedKey = GlobalKey();
  final GlobalKey _typeKey = GlobalKey();
  final GlobalKey _saveButtonKey = GlobalKey();

  final _nameCtrl = TextEditingController();
  final _feedCtrl = TextEditingController();
  final _onCmdCtrl = TextEditingController(text: 'ON');
  final _offCmdCtrl = TextEditingController(text: 'OFF');
  final _unitCtrl = TextEditingController();
  final _minCtrl = TextEditingController(text: '0');
  final _maxCtrl = TextEditingController(text: '100');
  
  final _automationValueCtrl = TextEditingController();
  final _automationMsgCtrl = TextEditingController();
  bool _enableAutomation = false;

  bool _enableNfcControl = false;
  bool _nfcOnly = false;
  final _nfcToolNameCtrl = TextEditingController();
  String? _nfcAuthCode;
  
  bool _requireBiometric = false;
  
  String _selectedProvider = 'adafruit';
  String _selectedType = 'Toggle';
  Color _selectedPrimary = AppTheme.primaryCyan;
  Color _selectedActive = AppTheme.primaryCyan;
  
  List<dynamic> _pages = [];
  String? _selectedPageId;
  
  final List<String> _types = ['Toggle', 'Push', 'Sensor', 'Slider', 'Joystick', 'Terminal', 'ColorPicker', 'Chart'];
  final List<Color> _swatches = [AppTheme.primaryCyan, AppTheme.primaryViolet, Colors.greenAccent, Colors.orangeAccent, Colors.pinkAccent];
  
  List<dynamic> _existingWidgets = [];
  bool _isLoadingList = true;
  String? _editingWidgetId;

  void _onLangChange() => setState(() {});

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    AppLocalization.isArabicNotifier.addListener(_onLangChange);
    _loadExistingWidgets();
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
        titleKey: 'tour_settings_name_title',
        descKey: 'tour_settings_name_desc',
        targetKey: _nameKey,
        requireInteraction: true,
        advanceOnTap: false,
      ),
      TourStep(
        titleKey: 'tour_settings_feed_title',
        descKey: 'tour_settings_feed_desc',
        targetKey: _feedKey,
        requireInteraction: true,
        advanceOnTap: false,
      ),
      TourStep(
        titleKey: 'tour_settings_type_title',
        descKey: 'tour_settings_type_desc',
        targetKey: _typeKey,
        requireInteraction: true,
        advanceOnTap: false,
      ),
      TourStep(
        titleKey: 'tour_settings_save_title',
        descKey: 'tour_settings_save_desc',
        targetKey: _saveButtonKey,
        requireInteraction: true,
      ),
    ];

    AppTour.show(
      context,
      steps,
      onComplete: () {
        Navigator.pop(context);
        Future.delayed(const Duration(milliseconds: 300), () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LocalDashboardScreen(startTour: true)),
          );
        });
      },
      onSkip: () {},
    );
  }

  @override
  void dispose() {
    _tabController?.dispose();
    AppLocalization.isArabicNotifier.removeListener(_onLangChange);
    _nameCtrl.dispose();
    _feedCtrl.dispose();
    _onCmdCtrl.dispose();
    _offCmdCtrl.dispose();
    _unitCtrl.dispose();
    _minCtrl.dispose();
    _maxCtrl.dispose();
    _automationValueCtrl.dispose();
    _automationMsgCtrl.dispose();
    _nfcToolNameCtrl.dispose();
    super.dispose();
  }

  bool _hasAdafruit = false;
  bool _hasFirebase = false;

  void _loadExistingWidgets() async {
     setState(() => _isLoadingList = true);
     try {
       final list = await ApiService.getWidgets();
       final profile = await ApiService.userMe();
       
       bool hasAd = (profile['adafruitUsername']?.toString().isNotEmpty ?? false);
       bool hasFb = (profile['firebaseUrl']?.toString().isNotEmpty ?? false);

       if (mounted) setState(() { 
         _existingWidgets = list; 
         _pages = profile['preferences']?['pages'] ?? [];
         _hasAdafruit = hasAd;
         _hasFirebase = hasFb;

         // Set default provider if they only have one
         if (_hasFirebase && !_hasAdafruit) {
           _selectedProvider = 'firebase';
         } else if (_hasAdafruit && !_hasFirebase) {
           _selectedProvider = 'adafruit';
         }

         _isLoadingList = false; 
       });
     } catch(e) {
       if (mounted) setState(() => _isLoadingList = false);
     }
  }

  void _fillFormForEditing(dynamic w) {
     setState(() {
        _editingWidgetId = w['id'];
        _nameCtrl.text = w['name'] ?? '';
        _feedCtrl.text = w['feedName'] ?? '';
        _selectedProvider = w['provider'] ?? 'adafruit';
        
        String t = (w['type'] ?? 'toggle').toString().toLowerCase();
        _selectedType = _types.firstWhere((e) => e.toLowerCase() == t, orElse: () => 'Toggle');
        
        _onCmdCtrl.text = (w['configuration']?['onCommand'] ?? '').toString();
        _offCmdCtrl.text = (w['configuration']?['offCommand'] ?? '').toString();
        _unitCtrl.text = (w['configuration']?['unit'] ?? '').toString();
        _minCtrl.text = (w['configuration']?['min'] ?? 0).toString();
        _maxCtrl.text = (w['configuration']?['max'] ?? 100).toString();
        
        _enableNfcControl = w['configuration']?['nfcEnabled'] ?? false;
        _nfcOnly = w['configuration']?['nfcOnly'] ?? false;
        _nfcToolNameCtrl.text = w['configuration']?['nfcToolName'] ?? '';
        _nfcAuthCode = w['configuration']?['nfcAuthCode'];
        
        _requireBiometric = w['configuration']?['biometricEnabled'] ?? false;
        
        // Find matching pageId or set to null if not found in current _pages list
        final pId = w['configuration']?['pageId'] ?? w['pageId'];
        if (pId != null && _pages.any((p) => p['id'].toString() == pId.toString())) {
          _selectedPageId = pId.toString();
        } else {
          _selectedPageId = null;
        }

        if (w['appearance']?['primaryColor'] != null) {
           String h = w['appearance']['primaryColor'].toString().replaceAll('#', '');
           if (h.length == 6) h = 'FF$h';
           try {
             _selectedPrimary = Color(int.parse(h, radix: 16));
           } catch(_) {}
        }

        final automations = w['automations'] as List<dynamic>?;
        if (automations != null && automations.isNotEmpty) {
           _enableAutomation = true;
           _automationValueCtrl.text = (automations[0]['conditionValue'] ?? '').toString();
           _automationMsgCtrl.text = (automations[0]['message'] ?? '').toString();
        } else {
           _enableAutomation = false;
           _automationValueCtrl.clear();
           _automationMsgCtrl.clear();
        }
     });
     _tabController?.animateTo(0); // Move back to form tab
  }

  void _deleteWidget(String id) async {
     try {
       await ApiService.deleteWidget(id);
       _showToast(AppLocalization.isArabicNotifier.value ? 'تم حذف الأداة بنجاح' : 'Widget Deleted successfully');
       _loadExistingWidgets();
     } catch (e) {
       _showToast('Delete Failed');
     }
  }

  void _saveWidget() async {
    if (_nameCtrl.text.isEmpty || _feedCtrl.text.isEmpty) {
       _showToast(AppLocalization.isArabicNotifier.value ? 'الاسم والمجرى مطلوبان!' : 'Name and Feed are required!');
       return;
    }
    try {
       Map<String, dynamic> data = {
         'name': _nameCtrl.text.trim(),
         'feedName': _feedCtrl.text.trim(),
         'provider': _selectedProvider,
         'type': _selectedType.toLowerCase(),
         'primaryColor': '#${_selectedPrimary.value.toRadixString(16).padLeft(8, '0').substring(2)}',
         'activeColor': '#${_selectedActive.value.toRadixString(16).padLeft(8, '0').substring(2)}',
         'onCommand': _onCmdCtrl.text,
         'offCommand': _offCmdCtrl.text,
         'unit': _unitCtrl.text,
         'configuration': {
            'min': double.tryParse(_minCtrl.text) ?? 0,
            'max': double.tryParse(_maxCtrl.text) ?? 100,
            'step': 1.0,
            'unit': _unitCtrl.text,
            'onCommand': _onCmdCtrl.text,
            'offCommand': _offCmdCtrl.text,
            'nfcEnabled': _enableNfcControl,
            'nfcOnly': _nfcOnly,
            'nfcToolName': _nfcToolNameCtrl.text,
            'nfcAuthCode': _nfcAuthCode,
            'biometricEnabled': _requireBiometric,
            'pageId': _selectedPageId,
          },
         'automations': _enableAutomation && _automationValueCtrl.text.isNotEmpty ? [
            { 'conditionValue': _automationValueCtrl.text.trim(), 'message': _automationMsgCtrl.text.trim() }
         ] : []
       };
       
       if (_editingWidgetId != null) {
          await ApiService.updateWidget(_editingWidgetId!, data);
          if (_selectedPageId != null) {
            final prefs = await SharedPreferences.getInstance();
            final String? pagesString = prefs.getString('widget_pages');
            Map<String, dynamic> pagesMap = pagesString != null ? jsonDecode(pagesString) : {};
            pagesMap[_editingWidgetId!] = _selectedPageId;
            await prefs.setString('widget_pages', jsonEncode(pagesMap));
          }
          _showToast(AppLocalization.isArabicNotifier.value ? 'تم تحديث الأداة بنجاح!' : 'Widget Updated!');
          setState(() { _editingWidgetId = null; });
       } else {
          final res = await ApiService.createWidget(data);
          if (_selectedPageId != null && res['id'] != null) {
            final prefs = await SharedPreferences.getInstance();
            final String? pagesString = prefs.getString('widget_pages');
            Map<String, dynamic> pagesMap = pagesString != null ? jsonDecode(pagesString) : {};
            pagesMap[res['id']] = _selectedPageId;
            await prefs.setString('widget_pages', jsonEncode(pagesMap));
          }
          _showToast(AppLocalization.isArabicNotifier.value ? 'تم إنشاء الأداة بنجاح!' : 'Widget Created!');
       }
       
       _nameCtrl.clear();
       _feedCtrl.clear();
       _selectedProvider = 'adafruit';
       _automationValueCtrl.clear();
       _automationMsgCtrl.clear();
       setState(() { _enableAutomation = false; });
       _loadExistingWidgets(); 
       _tabController?.animateTo(1); // Auto move to list of widgets
    } catch (e) {
       _showToast('Error saving widget');
     }
  }

  void _showToast(String m) => AppSnackbar.showInfo(context, m);

  Future<void> _setupNfc() async {
    if (_nfcToolNameCtrl.text.isEmpty) {
      _showToast(AppLocalization.isArabicNotifier.value ? 'يرجى إدخال اسم أداة الـ NFC أولاً' : 'Please enter NFC Tool Name first');
      return;
    }
    final code = await NfcBottomSheet.show(
      context: context,
      payload: 'SETUP:${_nfcToolNameCtrl.text}',
      title: AppLocalization.isArabicNotifier.value ? 'إعداد NFC' : 'NFC Setup',
      description: AppLocalization.isArabicNotifier.value ? 'قم بتقريب الهاتف من القارئ للحصول على كود المصادقة...' : 'Bring phone close to reader to get auth code...',
    );
    if (code != null && code.startsWith('CODE:')) {
      setState(() {
        _nfcAuthCode = code.replaceFirst('CODE:', '');
      });
      _showToast(AppLocalization.isArabicNotifier.value ? 'تم التقاط الكود بنجاح!' : 'Code captured successfully!');
    } else if (code != null) {
      _showToast(AppLocalization.isArabicNotifier.value ? 'استجابة غير صحيحة من القارئ' : 'Invalid response from reader');
    }
  }

  void _showFeedsDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: AppTheme.primaryCyan)),
    );

    try {
      final feeds = await ApiService.getAdafruitFeeds();
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (feeds.isEmpty) {
        _showToast('لا يوجد أي Feeds في حساب Adafruit الخاص بك.');
        return;
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppTheme.darkBackground,
          surfaceTintColor: Colors.transparent,
          title: const Text('اختر المجرى (Feed)', style: TextStyle(color: AppTheme.primaryCyan)),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.separated(
              itemCount: feeds.length,
              separatorBuilder: (_, __) => const Divider(color: Colors.white24),
              itemBuilder: (context, index) {
                final feed = feeds[index];
                return ListTile(
                  title: Text(feed['name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text(feed['key'] ?? '', style: const TextStyle(color: Colors.white70)),
                  trailing: const Icon(Icons.check_circle_outline, color: AppTheme.primaryCyan),
                  onTap: () {
                    setState(() {
                      _feedCtrl.text = feed['key'];
                      if (_nameCtrl.text.isEmpty) {
                        _nameCtrl.text = feed['name']; // أخذ الاسم كاسم افتراضي للزر
                      }
                    });
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
            )
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      _showToast(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _showFirebasePathsDialog() async {
    final isArabic = AppLocalization.isArabicNotifier.value;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: AppTheme.primaryCyan)),
    );

    try {
      final paths = await ApiService.getFirebasePaths();
      if (!mounted) return;
      Navigator.pop(context);

      if (paths.isEmpty) {
        _showToast(isArabic ? 'لا يوجد بيانات في قاعدة بيانات Firebase.' : 'No data found in your Firebase database.');
        return;
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppTheme.darkBackground,
          surfaceTintColor: Colors.transparent,
          title: Text(
            isArabic ? 'اختر المسار من Firebase' : 'Select Firebase Path',
            style: const TextStyle(color: AppTheme.primaryCyan),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: ListView.separated(
              itemCount: paths.length,
              separatorBuilder: (_, __) => const Divider(color: Colors.white12, height: 1),
              itemBuilder: (context, index) {
                final item = paths[index];
                final path = item['path'] ?? '';
                final level = item['level'] ?? 0;
                final hasChildren = item['hasChildren'] ?? false;

                return ListTile(
                  contentPadding: EdgeInsets.only(left: 16.0 + (level * 20.0), right: 16),
                  leading: Icon(
                    hasChildren ? Icons.folder_outlined : Icons.data_object,
                    color: hasChildren ? Colors.amberAccent : AppTheme.primaryCyan,
                    size: 20,
                  ),
                  title: Text(
                    path.split('/').last,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: Text(
                    '/$path',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                  trailing: Icon(
                    hasChildren ? Icons.subdirectory_arrow_right : Icons.check_circle_outline,
                    color: hasChildren ? Colors.white24 : AppTheme.primaryCyan,
                    size: 18,
                  ),
                  onTap: () {
                    setState(() {
                      _feedCtrl.text = path;
                      if (_nameCtrl.text.isEmpty) {
                        _nameCtrl.text = path.split('/').last;
                      }
                    });
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(isArabic ? 'إلغاء' : 'Cancel', style: const TextStyle(color: Colors.grey)),
            )
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showToast(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _showDeleteConfirm(String id) {
    final isArabic = AppLocalization.isArabicNotifier.value;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkBackground,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isArabic ? 'تأكيد الحذف' : 'Confirm Deletion',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          isArabic ? 'هل أنت متأكد من رغبتك في حذف أداة التحكم هذه؟' : 'Are you sure you want to delete this control widget?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              isArabic ? 'إلغاء' : 'Cancel',
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context);
              _deleteWidget(id);
            },
            child: Text(
              isArabic ? 'حذف' : 'Delete',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalization.isArabicNotifier.value;
    
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: Text(_editingWidgetId == null 
            ? (isArabic ? 'إعدادات الأدوات' : 'Widgets Settings') 
            : (isArabic ? 'تعديل الأداة' : 'Edit Widget')),
        actions: [
          if (_editingWidgetId != null)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () {
                setState(() {
                  _editingWidgetId = null;
                  _nameCtrl.clear();
                  _feedCtrl.clear();
                  _selectedProvider = 'adafruit';
                  _automationValueCtrl.clear();
                  _automationMsgCtrl.clear();
                  _enableAutomation = false;
                  _enableNfcControl = false;
                  _nfcOnly = false;
                  _nfcToolNameCtrl.clear();
                  _nfcAuthCode = null;
                  _requireBiometric = false;
                });
              },
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryCyan,
          labelColor: AppTheme.primaryCyan,
          unselectedLabelColor: Colors.white54,
          indicatorWeight: 3,
          dividerColor: Colors.transparent,
          tabs: [
            Tab(
              icon: const Icon(Icons.add_box_rounded),
              text: isArabic ? 'أداة جديدة' : 'New Widget',
            ),
            Tab(
              icon: const Icon(Icons.widgets_rounded),
              text: isArabic ? 'أدواتي الحالية' : 'My Widgets',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFormTab(isArabic),
          _buildExistingWidgetsTab(isArabic),
        ],
      ),
    );
  }

  Widget _buildFormTab(bool isArabic) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildGlassSection(
            isArabic ? 'بيانات الأداة الأساسية' : 'Core Widget Settings',
            [
              _buildTextField(AppLocalization.get('widget_name'), _nameCtrl, Icons.widgets, key: _nameKey),
              const SizedBox(height: 12),
              // Show dropdown only if they have BOTH providers or NEITHER provider
              if ((_hasAdafruit && _hasFirebase) || (!_hasAdafruit && !_hasFirebase))
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      dropdownColor: AppTheme.darkBackground,
                      value: _selectedProvider,
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
                      items: [
                        DropdownMenuItem(
                          value: 'adafruit',
                          child: Text(AppLocalization.get('provider_adafruit'), style: const TextStyle(color: Colors.white)),
                        ),
                        DropdownMenuItem(
                          value: 'firebase',
                          child: Text(AppLocalization.get('provider_firebase'), style: const TextStyle(color: Colors.white)),
                        ),
                      ],
                      onChanged: (v) => setState(() => _selectedProvider = v!),
                    ),
                  ),
                )
              else
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      Icon(_selectedProvider == 'firebase' ? Icons.storage : Icons.cloud_sync, color: AppTheme.primaryCyan, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        _selectedProvider == 'firebase' ? AppLocalization.get('provider_firebase') : AppLocalization.get('provider_adafruit'),
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      const Spacer(),
                      const Icon(Icons.check_circle, color: AppTheme.primaryCyan, size: 20),
                    ],
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(AppLocalization.get('feed_name'), _feedCtrl, Icons.rss_feed, key: _feedKey),
                  ),
                  if (_selectedProvider == 'adafruit') ...[
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.primaryCyan.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primaryCyan.withValues(alpha: 0.5)),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.search, color: AppTheme.primaryCyan),
                        tooltip: isArabic ? 'اختر مجرى (Feed)' : 'Select Feed',
                        onPressed: _showFeedsDialog,
                      ),
                    ),
                  ],
                  if (_selectedProvider == 'firebase') ...[
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.5)),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.account_tree_outlined, color: Colors.orangeAccent),
                        tooltip: isArabic ? 'استعراض مسارات Firebase' : 'Browse Firebase Paths',
                        onPressed: _showFirebasePathsDialog,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Theme(
                data: Theme.of(context).copyWith(
                  canvasColor: const Color(0xFF1A1F26),
                ),
                child: DropdownButtonFormField<String>(
                  key: _typeKey,
                  value: _selectedType,
                  style: const TextStyle(color: AppTheme.primaryCyan, fontWeight: FontWeight.bold, fontSize: 16),
                  icon: const Icon(Icons.arrow_drop_down_circle, color: AppTheme.primaryCyan),
                  decoration: InputDecoration(
                    labelText: AppLocalization.get('widget_type'),
                    labelStyle: const TextStyle(color: AppTheme.primaryCyan, fontSize: 16, fontWeight: FontWeight.bold),
                    prefixIcon: const Icon(Icons.category, color: AppTheme.primaryCyan),
                    filled: true,
                    fillColor: Colors.black26,
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: AppTheme.primaryCyan, width: 1.5)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: AppTheme.primaryCyan, width: 2.5)),
                  ),
                  items: _types.map((type) => DropdownMenuItem(
                    value: type, 
                    child: Text(type, style: const TextStyle(color: Colors.white, fontSize: 16))
                  )).toList(),
                  onChanged: (val) => setState(() => _selectedType = val!),
                ),
              ),
              if (_pages.isNotEmpty) ...[
                const SizedBox(height: 12),
                Theme(
                  data: Theme.of(context).copyWith(
                    canvasColor: const Color(0xFF1A1F26),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: _selectedPageId,
                    style: const TextStyle(color: AppTheme.primaryCyan, fontWeight: FontWeight.bold, fontSize: 16),
                    icon: const Icon(Icons.arrow_drop_down_circle, color: AppTheme.primaryCyan),
                    decoration: InputDecoration(
                      labelText: isArabic ? 'اختر الصفحة (اختياري)' : 'Select Page (Optional)',
                      labelStyle: const TextStyle(color: AppTheme.primaryCyan, fontSize: 16, fontWeight: FontWeight.bold),
                      prefixIcon: const Icon(Icons.pages, color: AppTheme.primaryCyan),
                      filled: true,
                      fillColor: Colors.black26,
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: AppTheme.primaryCyan, width: 1.5)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: AppTheme.primaryCyan, width: 2.5)),
                    ),
                    items: [
                      DropdownMenuItem(value: null, child: Text(isArabic ? 'بدون صفحة' : 'None', style: const TextStyle(color: Colors.white, fontSize: 16))),
                      ..._pages.map((p) => DropdownMenuItem(
                        value: p['id'].toString(), 
                        child: Text(p['name'].toString(), style: const TextStyle(color: Colors.white, fontSize: 16))
                      ))
                    ],
                    onChanged: (val) => setState(() => _selectedPageId = val),
                  ),
                ),
              ],
            ],
          ),
          
          const SizedBox(height: 16),
          
          if (_selectedType == 'Toggle' || _selectedType == 'Push' || _selectedType == 'Joystick' || _selectedType == 'Sensor' || _selectedType == 'Slider' || _selectedType == 'Chart')
            _buildGlassSection(
              isArabic ? 'خصائص التشغيل والتحكم' : 'Control Properties',
              [
                if (_selectedType == 'Toggle' || _selectedType == 'Push') ...[
                  _buildTextField('ON Command', _onCmdCtrl, Icons.power),
                  if (_selectedType == 'Toggle') ...[
                    const SizedBox(height: 12),
                    _buildTextField('OFF Command', _offCmdCtrl, Icons.power_off),
                  ]
                ],
                if (_selectedType == 'Sensor' || _selectedType == 'Chart')
                  _buildTextField('Unit (e.g. °C, %)', _unitCtrl, Icons.square_foot),
                if (_selectedType == 'Slider' || _selectedType == 'Chart') ...[
                  _buildTextField(AppLocalization.get('min_value'), _minCtrl, Icons.arrow_downward, isNumber: true),
                  const SizedBox(height: 12),
                  _buildTextField(AppLocalization.get('max_value'), _maxCtrl, Icons.arrow_upward, isNumber: true),
                ]
              ],
            ),
            
          if (_selectedType == 'Toggle' || _selectedType == 'Push' || _selectedType == 'Joystick' || _selectedType == 'Sensor' || _selectedType == 'Slider' || _selectedType == 'Chart')
            const SizedBox(height: 16),
            
          if (_selectedType == 'Toggle' || _selectedType == 'Push' || _selectedType == 'Slider') ...[
            _buildGlassSection(
              isArabic ? 'الإشعارات التلقائية (Automations)' : 'Automations & Alerts',
              [
                SwitchListTile(
                  title: Text(
                    isArabic ? 'تفعيل الإشعار المخصص عند تغير القيمة' : 'Enable custom notification on change',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  activeColor: AppTheme.primaryCyan,
                  value: _enableAutomation,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) => setState(() {
                    _enableAutomation = val;
                    if (val && _automationValueCtrl.text.isEmpty && (_selectedType == 'Toggle' || _selectedType == 'Push')) {
                      _automationValueCtrl.text = _onCmdCtrl.text;
                    }
                  }),
                ),
                if (_enableAutomation) ...[
                  const SizedBox(height: 12),
                  if (_selectedType == 'Toggle' || _selectedType == 'Push')
                    Theme(
                      data: Theme.of(context).copyWith(canvasColor: const Color(0xFF1A1F26)),
                      child: DropdownButtonFormField<String>(
                        value: _automationValueCtrl.text.isEmpty ? _onCmdCtrl.text : _automationValueCtrl.text,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: isArabic ? 'عندما تصبح القيمة' : 'When value becomes',
                          labelStyle: const TextStyle(color: Colors.white54),
                          prefixIcon: const Icon(Icons.touch_app, color: Colors.white54),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white24)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primaryCyan)),
                        ),
                        items: [
                          DropdownMenuItem(value: _onCmdCtrl.text, child: Text('On (${_onCmdCtrl.text})')),
                          if (_selectedType == 'Toggle')
                            DropdownMenuItem(value: _offCmdCtrl.text, child: Text('Off (${_offCmdCtrl.text})')),
                        ],
                        onChanged: (val) => setState(() => _automationValueCtrl.text = val ?? ''),
                      ),
                    )
                  else if (_selectedType == 'Slider')
                    _buildTextField(isArabic ? 'عندما يصبح السلايدر بقيمة' : 'When slider value is', _automationValueCtrl, Icons.tune, isNumber: true),
                  
                  const SizedBox(height: 12),
                  _buildTextField(isArabic ? 'نص رسالة الإشعار' : 'Alert notification text', _automationMsgCtrl, Icons.notifications_active),
                ]
              ],
            ),
            const SizedBox(height: 16),
          ],
          
          _buildGlassSection(
            isArabic ? 'إعدادات NFC' : 'NFC Configuration',
            [
              SwitchListTile(
                title: Text(isArabic ? 'تفعيل التحكم عبر NFC' : 'Enable NFC Control', style: const TextStyle(color: Colors.white, fontSize: 13)),
                activeColor: AppTheme.primaryCyan,
                value: _enableNfcControl,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) => setState(() => _enableNfcControl = val),
              ),
              if (_enableNfcControl) ...[
                const SizedBox(height: 12),
                SwitchListTile(
                  title: Text(isArabic ? 'التحكم عبر NFC فقط (إيقاف Cloud)' : 'NFC Control Only (Disable Cloud)', style: const TextStyle(color: Colors.white, fontSize: 13)),
                  activeColor: AppTheme.primaryCyan,
                  value: _nfcOnly,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) => setState(() => _nfcOnly = val),
                ),
                const SizedBox(height: 12),
                _buildTextField(isArabic ? 'اسم الأداة في جهاز القارئ' : 'Tool Name on Reader Device', _nfcToolNameCtrl, Icons.memory),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _nfcAuthCode == null 
                          ? (isArabic ? 'لم يتم التقاط كود المصادقة بعد' : 'Auth Code not captured yet')
                          : (isArabic ? 'الكود: $_nfcAuthCode' : 'Code: $_nfcAuthCode'),
                        style: TextStyle(color: _nfcAuthCode == null ? Colors.redAccent : Colors.greenAccent, fontSize: 12),
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryCyan, foregroundColor: Colors.black),
                      icon: const Icon(Icons.contactless, size: 16),
                      label: Text(isArabic ? 'إعداد الآن' : 'Setup Now'),
                      onPressed: _setupNfc,
                    )
                  ]
                )
              ]
            ]
          ),
          
          if (_selectedType != 'Slider' && _selectedType != 'Joystick' && _selectedType != 'ColorPicker') ...[
            const SizedBox(height: 16),
            _buildGlassSection(
              isArabic ? 'إعدادات الحماية (البصمة/الوجه)' : 'Security (Biometrics/Face ID)',
              [
                SwitchListTile(
                  title: Text(isArabic ? 'طلب المصادقة قبل الإرسال' : 'Require Authentication before send', style: const TextStyle(color: Colors.white, fontSize: 13)),
                  activeColor: AppTheme.primaryCyan,
                  value: _requireBiometric,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) => setState(() => _requireBiometric = val),
                ),
              ]
            ),
          ],
          const SizedBox(height: 16),

          _buildGlassSection(
            AppLocalization.get('appearance'),
            [
              Text(AppLocalization.get('primary_color'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: _swatches.map((color) => GestureDetector(
                  onTap: () => setState(() => _selectedPrimary = color),
                  child: CircleAvatar(
                    backgroundColor: color,
                    radius: 22,
                    child: _selectedPrimary == color ? const Icon(Icons.check, color: Colors.black, size: 20) : null,
                  ),
                )).toList()
              )
            ],
          ),
          
          const SizedBox(height: 24),
          
          GestureDetector(
            key: _saveButtonKey,
            onTap: _saveWidget,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryCyan, AppTheme.primaryViolet],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryCyan.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _editingWidgetId == null ? Icons.add_circle : Icons.save,
                    color: Colors.black,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _editingWidgetId == null 
                        ? (isArabic ? 'إنشاء أداة تحكم جديدة' : 'Create Control Widget')
                        : (isArabic ? 'حفظ تعديلات الأداة' : 'Save Changes'),
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildExistingWidgetsTab(bool isArabic) {
    return _isLoadingList 
       ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryCyan))
       : _existingWidgets.isEmpty 
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.widgets_outlined, size: 80, color: Colors.white.withValues(alpha: 0.2)),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalization.get('no_widgets_yet'), 
                    style: const TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryCyan,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.add),
                    label: Text(isArabic ? 'إنشاء أداة الآن' : 'Create a widget now'),
                    onPressed: () => _tabController?.animateTo(0),
                  ),
                ],
              ),
            )
          : ListView.separated(
               padding: const EdgeInsets.all(16),
               itemCount: _existingWidgets.length,
               separatorBuilder: (_, __) => const SizedBox(height: 12),
               itemBuilder: (context, index) {
                  final w = _existingWidgets[index];
                  final color = _hexToColor(w['appearance']?['primaryColor']);
                  final type = w['type']?.toString().toLowerCase() ?? 'toggle';
                  
                  IconData iconData = Icons.widgets;
                  if (type == 'toggle') iconData = Icons.power;
                  if (type == 'push') iconData = Icons.touch_app;
                  if (type == 'sensor') iconData = Icons.sensors;
                  if (type == 'slider') iconData = Icons.linear_scale;
                  if (type == 'joystick') iconData = Icons.gamepad;
                  if (type == 'terminal') iconData = Icons.terminal;
                  if (type == 'colorpicker') iconData = Icons.color_lens;

                  return Container(
                     decoration: BoxDecoration(
                        color: AppTheme.cardBaseColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: color.withValues(alpha: 0.15)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ]
                     ),
                     child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                           padding: const EdgeInsets.all(12),
                           decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                           ),
                           child: Icon(iconData, color: color, size: 24),
                        ),
                        title: Text(
                          w['name'] ?? '', 
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${type.toUpperCase()} • Feed: ${w["feedName"]}', 
                            style: const TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                        ),
                        trailing: Row(
                           mainAxisSize: MainAxisSize.min,
                           children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryCyan.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                   icon: const Icon(Icons.edit_rounded, color: AppTheme.primaryCyan), 
                                   onPressed: () => _fillFormForEditing(w)
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                   icon: const Icon(Icons.delete_rounded, color: Colors.redAccent), 
                                   onPressed: () => _showDeleteConfirm(w['id'])
                                ),
                              ),
                           ],
                        ),
                     ),
                  );
               },
             );
  }

  Color _hexToColor(String? hexString) {
     if (hexString == null || hexString.isEmpty) return AppTheme.primaryCyan;
     final buffer = StringBuffer();
     if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
     buffer.write(hexString.replaceFirst('#', ''));
     return Color(int.parse(buffer.toString(), radix: 16));
  }

  Widget _buildGlassSection(String title, List<Widget> children, {Key? key}) {
     return Container(
        key: key,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
           color: AppTheme.cardBaseColor,
           borderRadius: BorderRadius.circular(16)
        ),
        child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
              Text(title, style: const TextStyle(color: AppTheme.primaryCyan, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ...children
           ],
        ),
     );
  }

  Widget _buildTextField(String label, TextEditingController ctrl, IconData icon, {bool isNumber = false, Key? key}) {
     return TextField(
        key: key,
        controller: ctrl,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
           labelText: label,
           labelStyle: const TextStyle(color: Colors.white54),
           prefixIcon: Icon(icon, color: Colors.white54),
           enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white24)),
           focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primaryCyan)),
        ),
     );
  }
}
