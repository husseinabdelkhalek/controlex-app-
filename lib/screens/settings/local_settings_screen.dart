import '../../widgets/app_snackbar.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/local_service.dart';
import '../../core/localization.dart';

class LocalSettingsScreen extends StatefulWidget {
  const LocalSettingsScreen({super.key});

  @override
  State<LocalSettingsScreen> createState() => _LocalSettingsScreenState();
}

class _LocalSettingsScreenState extends State<LocalSettingsScreen> {
  final _nameCtrl = TextEditingController();
  final _commandPathCtrl = TextEditingController();
  final _ipCtrl = TextEditingController();
  final _onCmdCtrl = TextEditingController(text: 'ON');
  final _offCmdCtrl = TextEditingController(text: 'OFF');
  final _minCtrl = TextEditingController(text: '0');
  final _maxCtrl = TextEditingController(text: '100');
  
  String _selectedType = 'Toggle';
  Color _selectedPrimary = AppTheme.primaryCyan;
  bool _requireBiometric = false;
  
  final List<String> _types = ['Toggle', 'Push', 'Slider', 'Terminal', 'ColorPicker'];
  final List<Color> _swatches = [AppTheme.primaryCyan, AppTheme.primaryViolet, Colors.greenAccent, Colors.orangeAccent, Colors.pinkAccent];
  
  List<Map<String, dynamic>> _existingWidgets = [];
  bool _isLoadingList = true;
  String? _editingWidgetId;

  void _onLangChange() => setState(() {});

  @override
  void initState() {
    super.initState();
    AppLocalization.isArabicNotifier.addListener(_onLangChange);
    _ipCtrl.text = LocalService.deviceIp;
    _loadExistingWidgets();
  }

  void _loadExistingWidgets() async {
     setState(() => _isLoadingList = true);
     try {
       final list = await LocalService.getWidgets();
       if (mounted) setState(() { _existingWidgets = list; _isLoadingList = false; });
     } catch(e) {
       if (mounted) setState(() => _isLoadingList = false);
     }
  }

  void _fillFormForEditing(Map<String, dynamic> w) {
     setState(() {
        _editingWidgetId = w['id'];
        _nameCtrl.text = w['name'] ?? '';
        _commandPathCtrl.text = w['feedName'] ?? '';
        
        String t = (w['type'] ?? 'toggle').toString().toLowerCase();
        _selectedType = _types.firstWhere((e) => e.toLowerCase() == t, orElse: () => 'Toggle');
        
        _onCmdCtrl.text = (w['configuration']?['onCommand'] ?? '').toString();
        _offCmdCtrl.text = (w['configuration']?['offCommand'] ?? '').toString();
        _minCtrl.text = (w['configuration']?['min'] ?? 0).toString();
        _maxCtrl.text = (w['configuration']?['max'] ?? 100).toString();
        _requireBiometric = w['configuration']?['biometricEnabled'] ?? false;

        if (w['appearance']?['primaryColor'] != null) {
           String h = w['appearance']['primaryColor'].toString().replaceAll('#', '');
           if (h.length == 6) h = 'FF$h';
           try {
             _selectedPrimary = Color(int.parse(h, radix: 16));
           } catch(_) {}
        }
     });
  }

  void _deleteWidget(String id) async {
     try {
       await LocalService.deleteWidget(id);
       _showToast('تم حذف الأداة بنجاح');
       _loadExistingWidgets();
     } catch (e) {
       _showToast('فشل الحذف');
     }
  }

  void _saveIp() async {
    await LocalService.saveIp(_ipCtrl.text.trim());
    _showToast('${AppLocalization.get('ip_saved')}${_ipCtrl.text.trim()}');
  }

  void _saveWidget() async {
    if (_nameCtrl.text.isEmpty || _commandPathCtrl.text.isEmpty) {
       _showToast('الاسم ومسار الأمر مطلوبان!');
       return;
    }
    if (_ipCtrl.text.trim().isEmpty) {
       _showToast('يرجى إدخال عنوان IP الجهاز أولاً!');
       return;
    }
    // Save IP first
    await LocalService.saveIp(_ipCtrl.text.trim());
    
    try {
       Map<String, dynamic> existingConfig = {};
       if (_editingWidgetId != null) {
          final w = _existingWidgets.firstWhere((e) => e['id'] == _editingWidgetId, orElse: () => <String, dynamic>{});
          if (w.isNotEmpty && w['configuration'] != null) {
             existingConfig = Map<String, dynamic>.from(w['configuration']);
          }
       }

       Map<String, dynamic> data = {
         'name': _nameCtrl.text.trim(),
         'feedName': _commandPathCtrl.text.trim(), // Command path in local mode
         'type': _selectedType.toLowerCase(),
         'primaryColor': '#${_selectedPrimary.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
         'onCommand': _onCmdCtrl.text,
         'offCommand': _offCmdCtrl.text,
         'configuration': {
            ...existingConfig,
            'min': double.tryParse(_minCtrl.text) ?? 0,
            'max': double.tryParse(_maxCtrl.text) ?? 100,
            'step': 1.0,
            'onCommand': _onCmdCtrl.text,
            'offCommand': _offCmdCtrl.text,
            'biometricEnabled': _requireBiometric,
         }
       };
       
       if (_editingWidgetId != null) {
          await LocalService.updateWidget(_editingWidgetId!, data);
          _showToast(AppLocalization.get('widget_updated'));
          setState(() { _editingWidgetId = null; });
       } else {
          await LocalService.createWidget(data);
          _showToast(AppLocalization.get('widget_created'));
       }
       
       _nameCtrl.clear();
       _commandPathCtrl.clear();
       _requireBiometric = false;
       _loadExistingWidgets();
    } catch (e) {
       _showToast('خطأ في حفظ الأداة');
    }
  }

  @override
  void dispose() {
    AppLocalization.isArabicNotifier.removeListener(_onLangChange);
    _nameCtrl.dispose();
    _commandPathCtrl.dispose();
    _ipCtrl.dispose();
    _onCmdCtrl.dispose();
    _offCmdCtrl.dispose();
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  void _showToast(String m) => AppSnackbar.showSuccess(context, m);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: Text(_editingWidgetId == null ? AppLocalization.get('local_control') : AppLocalization.get('edit_widget')),
        actions: [
           if (_editingWidgetId != null)
             IconButton(icon: Icon(Icons.close, color: Colors.white), onPressed: () {
                setState(() { _editingWidgetId = null; _requireBiometric = false; });
                _nameCtrl.clear(); _commandPathCtrl.clear();
             }),
           IconButton(icon: Icon(Icons.check, color: AppTheme.primaryCyan, size: 30), onPressed: _saveWidget)
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // IP Section
            _buildGlassSection(AppLocalization.get('device_ip'), [
               Row(
                 children: [
                   Expanded(child: _buildTextField('IP Address (e.g. 192.168.1.100)', _ipCtrl, Icons.wifi)),
                   SizedBox(width: 8),
                   ElevatedButton(
                     style: ElevatedButton.styleFrom(
                       backgroundColor: AppTheme.primaryCyan,
                       foregroundColor: Colors.black,
                       padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                     ),
                     onPressed: _saveIp,
                     child: Text('حفظ', style: TextStyle(fontWeight: FontWeight.bold)),
                   ),
                 ],
               ),
               SizedBox(height: 8),
               FutureBuilder<bool>(
                 future: LocalService.checkConnection(),
                 builder: (ctx, snap) {
                   if (snap.connectionState == ConnectionState.waiting) {
                     return Row(children: [
                       SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryCyan)),
                       SizedBox(width: 8),
                       Text('جاري فحص الاتصال...', style: TextStyle(color: Colors.white54, fontSize: 12)),
                     ]);
                   }
                   final connected = snap.data ?? false;
                   return Row(children: [
                     Icon(connected ? Icons.check_circle : Icons.error, color: connected ? Colors.greenAccent : Colors.redAccent, size: 18),
                     SizedBox(width: 6),
                     Text(connected ? AppLocalization.get('device_connected') : AppLocalization.get('device_disconnected'), style: TextStyle(color: connected ? Colors.greenAccent : Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                   ]);
                 },
               )
            ]),
            SizedBox(height: 16),
            
            // Widget Details
            _buildGlassSection(AppLocalization.get('widget_details'), [
               _buildTextField(AppLocalization.get('widget_name'), _nameCtrl, Icons.widgets),
               SizedBox(height: 12),
               _buildTextField(AppLocalization.get('command_path'), _commandPathCtrl, Icons.terminal, hint: 'مثل: led, motor, relay'),
               SizedBox(height: 12),
                Theme(
                  data: Theme.of(context).copyWith(canvasColor: const Color(0xFF1A1F26)),
                  child: DropdownButtonFormField<String>(
                    value: _selectedType,
                    style: TextStyle(color: AppTheme.primaryCyan, fontWeight: FontWeight.bold, fontSize: 16),
                    icon: Icon(Icons.arrow_drop_down_circle, color: AppTheme.primaryCyan),
                    decoration: InputDecoration(
                        labelText: AppLocalization.get('widget_type'),
                        labelStyle: TextStyle(color: AppTheme.primaryCyan, fontSize: 18, fontWeight: FontWeight.bold),
                        prefixIcon: Icon(Icons.category, color: AppTheme.primaryCyan),
                        filled: true, fillColor: Colors.black26,
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: AppTheme.primaryCyan, width: 1.5)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: AppTheme.primaryCyan, width: 2.5)),
                    ),
                    items: _types.map((type) => DropdownMenuItem(value: type, child: Text(type, style: TextStyle(color: Colors.white, fontSize: 16)))).toList(),
                    onChanged: (val) => setState(() => _selectedType = val!),
                  ),
                )
             ]),
            
            SizedBox(height: 16),
            if (_selectedType == 'Toggle' || _selectedType == 'Push')
               _buildGlassSection(AppLocalization.get('commands'), [
                  _buildTextField(AppLocalization.get('on_command'), _onCmdCtrl, Icons.power),
                  SizedBox(height: 12),
                  if (_selectedType == 'Toggle')
                    _buildTextField('أمر الإيقاف (OFF Command)', _offCmdCtrl, Icons.power_off),
               ]),

            if (_selectedType == 'Slider')
               _buildGlassSection(AppLocalization.get('configuration'), [
                 _buildTextField(AppLocalization.get('min_value'), _minCtrl, Icons.arrow_downward, isNumber: true),
                 SizedBox(height: 12),
                 _buildTextField(AppLocalization.get('max_value'), _maxCtrl, Icons.arrow_upward, isNumber: true),
               ]),
               
            if (_selectedType != 'Slider' && _selectedType != 'ColorPicker') ...[
              SizedBox(height: 16),
              _buildGlassSection(
                AppLocalization.isArabicNotifier.value ? 'إعدادات الحماية (البصمة/الوجه)' : 'Security (Biometrics/Face ID)',
                [
                  SwitchListTile(
                    title: Text(AppLocalization.isArabicNotifier.value ? 'طلب المصادقة قبل الإرسال' : 'Require Authentication before send', style: TextStyle(color: Colors.white, fontSize: 13)),
                    activeColor: AppTheme.primaryCyan,
                    value: _requireBiometric,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) => setState(() => _requireBiometric = val),
                  ),
                ]
              ),
            ],
               
            SizedBox(height: 16),
            _buildGlassSection(AppLocalization.get('appearance'), [
               Text(AppLocalization.get('primary_color'), style: TextStyle(color: Colors.white)),
               SizedBox(height: 8),
               Row(
                 mainAxisAlignment: MainAxisAlignment.spaceAround,
                 children: _swatches.map((color) => GestureDetector(
                    onTap: () => setState(() => _selectedPrimary = color),
                    child: CircleAvatar(
                       backgroundColor: color, radius: 20,
                       child: _selectedPrimary == color ? Icon(Icons.check, color: Colors.black) : null,
                    ),
                 )).toList()
               )
            ]),
            
            SizedBox(height: 32),
            Text(AppLocalization.get('existing_widgets'), style: TextStyle(color: AppTheme.primaryCyan, fontWeight: FontWeight.bold, fontSize: 16)),
            Divider(color: Colors.white24),
            _isLoadingList 
               ? Center(child: CircularProgressIndicator(color: AppTheme.primaryCyan))
               : _existingWidgets.isEmpty 
                  ? Padding(padding: const EdgeInsets.all(16), child: Text(AppLocalization.get('no_widgets_yet'), style: TextStyle(color: Colors.white54)))
                  : ListView.separated(
                       shrinkWrap: true,
                       physics: const NeverScrollableScrollPhysics(),
                       itemCount: _existingWidgets.length,
                       separatorBuilder: (_, __) => Divider(color: Colors.white10),
                       itemBuilder: (context, index) {
                          final w = _existingWidgets[index];
                          final color = _hexToColor(w['appearance']?['primaryColor']);
                          return Container(
                             decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(12),
                             ),
                             child: ListTile(
                                leading: Container(
                                   padding: const EdgeInsets.all(8),
                                   decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
                                   child: Icon(Icons.widgets, color: color, size: 20),
                                ),
                                title: Text(w['name'] ?? '', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                subtitle: Text('${(w["type"] ?? "").toString().toUpperCase()} | /${w["feedName"] ?? ""}', 
                                   style: TextStyle(color: Colors.white38, fontSize: 11)),
                                trailing: Row(
                                   mainAxisSize: MainAxisSize.min,
                                   children: [
                                      IconButton(icon: Icon(Icons.edit_note, color: AppTheme.primaryCyan), onPressed: () => _fillFormForEditing(w)),
                                      IconButton(icon: Icon(Icons.delete_sweep, color: Colors.redAccent), onPressed: () => _deleteWidget(w['id'])),
                                   ],
                                ),
                             ),
                          );
                       },
                     )
          ],
        ),
      ),
    );
  }

  Color _hexToColor(String? hexString) {
     if (hexString == null || hexString.isEmpty) return AppTheme.primaryCyan;
     final buffer = StringBuffer();
     if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
     buffer.write(hexString.replaceFirst('#', ''));
     return Color(int.parse(buffer.toString(), radix: 16));
  }

  Widget _buildGlassSection(String title, List<Widget> children) {
     return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppTheme.cardBaseColor, borderRadius: BorderRadius.circular(16)),
        child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
              Text(title, style: TextStyle(color: AppTheme.primaryCyan, fontWeight: FontWeight.bold)),
              SizedBox(height: 16),
              ...children
           ],
        ),
     );
  }

  Widget _buildTextField(String label, TextEditingController ctrl, IconData icon, {bool isNumber = false, String? hint}) {
     return TextField(
        controller: ctrl,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        style: TextStyle(color: Colors.white),
        decoration: InputDecoration(
           labelText: label,
           hintText: hint,
           hintStyle: TextStyle(color: Colors.white24, fontSize: 12),
           labelStyle: TextStyle(color: Colors.white54),
           prefixIcon: Icon(icon, color: Colors.white54),
           enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white24)),
           focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.primaryCyan)),
        ),
     );
  }
}
