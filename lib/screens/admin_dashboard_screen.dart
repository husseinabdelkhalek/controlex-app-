import '../widgets/app_snackbar.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../core/localization.dart';
import 'user_details_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedViewIndex = 0;
  
  List<dynamic> _users = [];
  List<dynamic> _serverLogs = [];
  List<dynamic> _clientLogs = [];
  List<dynamic> _quotas = [];
  List<dynamic> _bannedDevices = [];
  int _todayDatabaseWrites = 0;
  int _todayDatabaseReads = 0;
  int _todayDatabaseDeletes = 0;
  bool _isLoading = true;
  SharedPreferences? _prefs;


  // Notification form
  final _notifTitleCtrl = TextEditingController();
  final _notifBodyCtrl = TextEditingController();
  String _notifTarget = 'all';

  // Sub-Admin Keys Management
  final _subAdminKeyCtrl = TextEditingController();
  List<dynamic> _subAdminKeys = [];
  bool _isKeysLoading = false;
  bool _hasFetchedKeys = false;

  String _formatDate(dynamic dateVal) {
    if (dateVal == null) return AppLocalization.isArabicNotifier.value ? 'غير معروف' : 'N/A';
    try {
      if (dateVal is String) {
        DateTime? dt = DateTime.tryParse(dateVal);
        if (dt != null) {
          return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
        }
      }
      if (dateVal is Map) {
        int? sec;
        if (dateVal.containsKey('_seconds')) {
          sec = dateVal['_seconds'] as int?;
        } else if (dateVal.containsKey('seconds')) {
          sec = dateVal['seconds'] as int?;
        } else if (dateVal.containsKey('_milliseconds')) {
          return _formatDate(DateTime.fromMillisecondsSinceEpoch(dateVal['_milliseconds'] as int));
        } else if (dateVal.containsKey('milliseconds')) {
          return _formatDate(DateTime.fromMillisecondsSinceEpoch(dateVal['milliseconds'] as int));
        }
        if (sec != null) {
          DateTime dt = DateTime.fromMillisecondsSinceEpoch(sec * 1000);
          return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
        }
      }
      if (dateVal is num) {
        if (dateVal < 10000000000) {
          DateTime dt = DateTime.fromMillisecondsSinceEpoch((dateVal * 1000).toInt());
          return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
        } else {
          DateTime dt = DateTime.fromMillisecondsSinceEpoch(dateVal.toInt());
          return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
        }
      }
      if (dateVal is DateTime) {
        return "${dateVal.year}-${dateVal.month.toString().padLeft(2, '0')}-${dateVal.day.toString().padLeft(2, '0')} ${dateVal.hour.toString().padLeft(2, '0')}:${dateVal.minute.toString().padLeft(2, '0')}";
      }
    } catch (_) {}
    return dateVal.toString().split('T').first;
  }

  void _onLangChange() => setState(() {});

  @override
  void initState() {
    super.initState();
    AppLocalization.isArabicNotifier.addListener(_onLangChange);
    _tabController = TabController(length: 5, vsync: this);
    _initPrefs();
    _loadAllData();
  }

  void _initPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _prefs = prefs;
      });
    }
  }

  @override
  void dispose() {
    AppLocalization.isArabicNotifier.removeListener(_onLangChange);
    _tabController.dispose();
    _notifTitleCtrl.dispose();
    _notifBodyCtrl.dispose();
    _subAdminKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSubAdminKeysOnly() async {
    try {
      final keys = await ApiService.getSubAdminPromoKeys();
      if (mounted) {
        setState(() {
          _subAdminKeys = keys;
        });
      }
    } catch (e) {
      _showToast(AppLocalization.isArabicNotifier.value ? 'خطأ في تحديث الأكواد: $e' : 'Error updating keys: $e');
    }
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        ApiService.getAdminUsers(),
        ApiService.getServerLogs(),
        ApiService.getClientLogs(),
        ApiService.getAdafruitQuotas(),
        ApiService.getBannedDevices(),
        ApiService.getAdminStats(),
        ApiService.getSubAdminPromoKeys(),
      ]);
      if (mounted) {
        setState(() {
          _users = results[0] as List<dynamic>;
          _serverLogs = results[1] as List<dynamic>;
          _clientLogs = results[2] as List<dynamic>;
          _quotas = results[3] as List<dynamic>;
          _bannedDevices = results[4] as List<dynamic>;
          final stats = results[5] as Map<String, dynamic>;
          _todayDatabaseWrites = stats['todayDatabaseWrites'] ?? 0;
          _todayDatabaseReads = stats['todayDatabaseReads'] ?? 0;
          _todayDatabaseDeletes = stats['todayDatabaseDeletes'] ?? 0;
          _subAdminKeys = results[6] as List<dynamic>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showToast('${AppLocalization.get('error_loading_data')}: $e');
      }
    }
  }


  void _showToast(String msg) {
    if (!mounted) return;
    AppSnackbar.showSuccess(context, msg);
  }

  @override
  Widget build(BuildContext context) {
    String title = AppLocalization.get('admin_panel');
    if (_selectedViewIndex == 1) title = AppLocalization.get('users') ?? 'المستخدمين';
    if (_selectedViewIndex == 2) title = AppLocalization.get('logs') ?? 'سجلات النظام';
    if (_selectedViewIndex == 3) title = AppLocalization.get('notifications') ?? 'الإشعارات';
    if (_selectedViewIndex == 4) title = AppLocalization.get('quota') ?? 'حصص Adafruit';
    if (_selectedViewIndex == 5) title = AppLocalization.get('banned_users') ?? 'الأجهزة المحظورة';
    if (_selectedViewIndex == 6) title = AppLocalization.get('admin_automations') ?? 'الأتمتة وتوفير الطاقة';
    if (_selectedViewIndex == 7) title = AppLocalization.isArabicNotifier.value ? 'أكواد الموزعين والشركاء' : 'Sub-Admin Promo Keys';

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        leading: _selectedViewIndex > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => setState(() => _selectedViewIndex = 0),
              )
            : null,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primaryViolet.withValues(alpha: 0.8), AppTheme.darkBackground],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.primaryCyan),
            onPressed: _loadAllData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryCyan))
          : _selectedViewIndex == 0
              ? _buildAdminHomeHub()
              : _buildActiveView(),
    );
  }

  Widget _buildActiveView() {
    switch (_selectedViewIndex) {
      case 1:
        return _buildUsersTab();
      case 2:
        return _buildLogsTab();
      case 3:
        return _buildNotificationsTab();
      case 4:
        return _buildQuotaTab();
      case 5:
        return _buildBansTab();
      case 6:
        return _buildAutomationsAdminTab();
      case 7:
        return _buildSubAdminKeysTab();
      default:
        return _buildAdminHomeHub();
    }
  }

  Widget _buildAdminHomeHub() {
    final totalUsers = _users.length;
    final activeAdmins = _users.where((u) => u['role'] == 'admin').length;
    final serverLogsCount = _serverLogs.length;
    final bannedCount = _bannedDevices.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome / Title Banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryViolet.withValues(alpha: 0.2), AppTheme.primaryCyan.withValues(alpha: 0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.primaryCyan.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryCyan.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.admin_panel_settings, color: AppTheme.primaryCyan, size: 36),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalization.isArabicNotifier.value ? 'لوحة التحكم والعمليات' : 'Control Center & Operations',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppLocalization.isArabicNotifier.value 
                            ? 'إدارة النظام والأمان وحصص الأداة والاتصال في مكان واحد.' 
                            : 'Manage system, security, Adafruit quotas, and bans in one place.',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Overview Stats Grid
          Text(
            AppLocalization.isArabicNotifier.value ? 'نظرة عامة على النظام' : 'System Overview',
            style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              _buildStatCard(
                AppLocalization.isArabicNotifier.value ? 'إجمالي الأعضاء' : 'Total Members', 
                totalUsers.toString(), 
                Icons.people, 
                AppTheme.primaryCyan
              ),
              _buildStatCard(
                AppLocalization.isArabicNotifier.value ? 'المدراء النشطين' : 'Active Admins', 
                activeAdmins.toString(), 
                Icons.verified_user, 
                Colors.greenAccent
              ),
              _buildStatCard(
                AppLocalization.isArabicNotifier.value ? 'أحداث التشغيل' : 'System Logs', 
                serverLogsCount.toString(), 
                Icons.history_toggle_off, 
                Colors.orangeAccent
              ),
              _buildStatCard(
                AppLocalization.isArabicNotifier.value ? 'الأجهزة المحظورة' : 'Banned Devices', 
                bannedCount.toString(), 
                Icons.block, 
                Colors.redAccent
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildFullWidthStatCard(
            AppLocalization.isArabicNotifier.value ? 'إرسالات قاعدة البيانات اليوم' : 'Database Transmissions Today',
            _todayDatabaseWrites.toString(),
            Icons.dns,
            AppTheme.primaryCyan,
          ),
          const SizedBox(height: 28),


          // Operations Menu Grid
          Text(
            AppLocalization.isArabicNotifier.value ? '👥 إدارة المستخدمين والأمان' : '👥 Users & Security',
            style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildOperationTile(
                index: 1,
                title: AppLocalization.get('users') ?? 'إدارة المستخدمين',
                subtitle: AppLocalization.isArabicNotifier.value 
                    ? 'تعديل الصلاحيات، حظر الحسابات، وعرض بيانات المستخدمين النشطين.'
                    : 'Modify roles, manage sessions, and view user info.',
                icon: Icons.people,
                color: AppTheme.primaryCyan,
              ),
              const SizedBox(height: 12),
              _buildOperationTile(
                index: 7,
                title: AppLocalization.isArabicNotifier.value ? 'أكواد الموزعين والشركاء' : 'Sub-Admin Promo Keys',
                subtitle: AppLocalization.isArabicNotifier.value
                    ? 'توليد وإدارة أكواد تسجيل الأدمن الجانبي والموزعين للتحكم بالعملاء.'
                    : 'Generate and manage promotional keys for B2B sub-admin registration.',
                icon: Icons.key_rounded,
                color: const Color(0xFF00FFCC),
              ),
              const SizedBox(height: 12),
              _buildOperationTile(
                index: 5,
                title: AppLocalization.get('banned_users') ?? 'قائمة الأجهزة المحظورة',
                subtitle: AppLocalization.isArabicNotifier.value
                    ? 'إدارة وإلغاء حظر الأجهزة أو عناوين الـ IP الممنوعة.'
                    : 'Manage banned device IDs or custom banned IPs.',
                icon: Icons.block,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 12),
              _buildOperationTile(
                index: 3,
                title: AppLocalization.get('notifications') ?? 'بث الإعلانات والإشعارات',
                subtitle: AppLocalization.isArabicNotifier.value
                    ? 'إرسال إشعارات فورية لجميع المستخدمين أو لمستخدم معين.'
                    : 'Broadcast push notifications to all or target users.',
                icon: Icons.campaign,
                color: AppTheme.primaryViolet,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            AppLocalization.isArabicNotifier.value ? '⚙️ النظام والأداء' : '⚙️ System & Performance',
            style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildOperationTile(
                index: 2,
                title: AppLocalization.get('logs') ?? 'سجلات التشغيل والأخطاء',
                subtitle: AppLocalization.isArabicNotifier.value
                    ? 'مراقبة أحداث السيرفر والطلبات وفحص أخطاء العملاء الفورية.'
                    : 'Monitor server requests and real-time client errors.',
                icon: Icons.terminal,
                color: Colors.orangeAccent,
              ),
              const SizedBox(height: 12),
              _buildOperationTile(
                index: 4,
                title: AppLocalization.get('quota') ?? 'استهلاك وحصص الأداة',
                subtitle: AppLocalization.isArabicNotifier.value
                    ? 'متابعة استهلاك لوحة التحكم وحالة حصص Adafruit IO.'
                    : 'View current Adafruit IO API quotas usage stats.',
                icon: Icons.cloud_sync,
                color: Colors.greenAccent,
              ),
              const SizedBox(height: 12),
              _buildOperationTile(
                index: 6,
                title: AppLocalization.get('admin_automations') ?? 'الأتمتة وتوفير الطاقة',
                subtitle: AppLocalization.isArabicNotifier.value
                    ? AppLocalization.get('admin_automations_subtitle_ar') ?? 'إدارة الأتمتة'
                    : AppLocalization.get('admin_automations_subtitle') ?? 'Manage automations',
                icon: Icons.auto_awesome,
                color: Colors.amberAccent,
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBaseColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value,
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              Icon(icon, color: color.withValues(alpha: 0.8), size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildFullWidthStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBaseColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildOperationTile({
    required int index,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBaseColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.08)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            subtitle,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
          ),
        ),
        trailing: Icon(Icons.chevron_right, color: color.withValues(alpha: 0.6)),
        onTap: () => setState(() => _selectedViewIndex = index),
      ),
    );
  }

  // ==================== TAB 1: USERS ====================
  Widget _buildUsersTab() {
    if (_users.isEmpty) {
      return Center(child: Text(AppLocalization.get('no_users'), style: const TextStyle(color: Colors.white54)));
    }
    return RefreshIndicator(
      onRefresh: _loadAllData,
      color: AppTheme.primaryCyan,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _users.length,
        itemBuilder: (context, index) {
          final user = _users[index];
          final status = user['status'] ?? 'active';
          final role = user['role'] ?? 'user';
          final isActive = status == 'active';
          
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppTheme.cardBaseColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: role == 'admin'
                    ? AppTheme.primaryViolet.withValues(alpha: 0.5)
                    : Colors.white10,
              ),
            ),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: CircleAvatar(
                backgroundColor: role == 'admin' ? AppTheme.primaryViolet : AppTheme.primaryCyan.withValues(alpha: 0.2),
                child: Icon(
                  role == 'admin' ? Icons.shield : Icons.person,
                  color: role == 'admin' ? Colors.white : AppTheme.primaryCyan,
                  size: 20,
                ),
              ),
              title: Align(
                alignment: AlignmentDirectional.centerStart,
                child: InkWell(
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UserDetailsScreen(user: user),
                      ),
                    );
                    if (result == true) {
                      _loadAllData();
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 10.0),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryCyan.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.primaryCyan.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          user['username'] ?? 'Unknown',
                          style: const TextStyle(color: AppTheme.primaryCyan, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.open_in_new, color: AppTheme.primaryCyan, size: 14),
                      ],
                    ),
                  ),
                ),
              ),
              subtitle: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isActive ? AppLocalization.get('active') : AppLocalization.get('suspended'),
                      style: TextStyle(color: isActive ? Colors.greenAccent : Colors.redAccent, fontSize: 11),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: user['isSuperAdmin'] == true 
                          ? Colors.amber.withValues(alpha: 0.2) 
                          : AppTheme.primaryViolet.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: user['isSuperAdmin'] == true ? Border.all(color: Colors.amber.withValues(alpha: 0.5)) : null,
                    ),
                    child: Text(
                      user['isSuperAdmin'] == true ? AppLocalization.get('super_admin') : role, 
                      style: TextStyle(
                        color: user['isSuperAdmin'] == true ? Colors.amberAccent : Colors.white70, 
                        fontSize: 11,
                        fontWeight: user['isSuperAdmin'] == true ? FontWeight.bold : FontWeight.normal,
                      )
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${user['widgetCount'] ?? 0} ${AppLocalization.get('widgets')}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
              iconColor: Colors.white54,
              collapsedIconColor: Colors.white38,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Divider(color: Colors.white12),
                      Text('📧 ${user['email'] ?? ''}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      const SizedBox(height: 8),
                      Text('📅 تاريخ الانضمام: ${_formatDate(user['createdAt'])}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                      Text('⏱️ آخر ظهور: ${_formatDate(user['lastActive'] ?? user['lastLogin'])}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                      Text('🌐 المنصة (موقع/تطبيق): ${user['platform'] ?? user['source'] ?? 'غير محدد'}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionButton(
                              label: isActive ? AppLocalization.get('suspend') : AppLocalization.get('activate'),
                              icon: isActive ? Icons.block : Icons.check_circle,
                              color: isActive ? Colors.orange : Colors.green,
                              onTap: () => _toggleUserStatus(user),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildActionButton(
                              label: AppLocalization.get('sessions'),
                              icon: Icons.devices,
                              color: AppTheme.primaryCyan,
                              onTap: () => _showUserSessions(user),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildActionButton(
                              label: role == 'admin' ? AppLocalization.get('user') : AppLocalization.get('admin'),
                              icon: Icons.swap_horiz,
                              color: AppTheme.primaryViolet,
                              onTap: () => _toggleUserRole(user),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleUserStatus(Map<String, dynamic> user) async {
    final newStatus = (user['status'] ?? 'active') == 'active' ? 'suspended' : 'active';
    try {
      await ApiService.updateUserStatus(user['id'], newStatus);
      _showToast('تم تحديث حالة ${user['username']}');
      _loadAllData();
    } catch (e) {
      _showToast('خطأ: $e');
    }
  }

  void _toggleUserRole(Map<String, dynamic> user) async {
    final currentRole = user['role'] ?? 'user';
    final newRole = currentRole == 'admin' ? 'user' : 'admin';
    try {
      // When promoting to admin, grant all permissions by default
      // so the new admin can actually access the admin dashboard
      final List<String>? permissions = newRole == 'admin'
          ? ['manage_users', 'manage_roles', 'view_logs', 'send_notifications', '*']
          : null;
      await ApiService.updateUserRole(user['id'], newRole, adminPermissions: permissions);
      _showToast('تم تحديث دور ${user['username']} إلى $newRole');
      _loadAllData();
    } catch (e) {
      _showToast('خطأ: $e');
    }
  }

  void _showUserSessions(Map<String, dynamic> user) async {
    try {
      final sessions = await ApiService.getAdminSessions(user['id']);
      if (!mounted) return;
      
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => _SessionsSheet(
          username: user['username'] ?? 'User',
          sessions: sessions,
          onLogout: (sessionId) async {
            try {
              await ApiService.adminLogoutDevice(sessionId);
              _showToast('تم إنهاء الجلسة بنجاح ✅');
              if (context.mounted) Navigator.pop(context);
              _showUserSessions(user); // re-open with refreshed data
            } catch (e) {
              _showToast('خطأ في إنهاء الجلسة: $e');
            }
          },
          onBan: (deviceId, ip, deviceName) async {
            if ((deviceId == null || deviceId.isEmpty) && (ip == null || ip.isEmpty)) {
              _showToast('خطأ: لا يوجد Device ID أو IP للحظر');
              return;
            }
            try {
              await ApiService.banDevice(
                deviceId: deviceId, 
                ip: ip,
                deviceName: deviceName,
                reason: 'محظور من قبل الإدارة لـ ${user['username']}',
              );
              _showToast('تم حظر الجهاز بنجاح 🚫');
              if (context.mounted) Navigator.pop(context);
              _loadAllData();
            } catch (e) {
              _showToast('خطأ في حظر الجهاز: $e');
            }
          },
        ),
      );
    } catch (e) {
      _showToast('خطأ في جلب الجلسات: $e');
    }
  }
  // ==================== TAB 6: AUTOMATIONS & POWER SAVING ====================
  Widget _buildAutomationsAdminTab() {
    return FutureBuilder<List<dynamic>>(
      future: ApiService.getAdminAutomationStats(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryCyan));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text(AppLocalization.get('no_automations'), style: const TextStyle(color: Colors.white54, fontSize: 16)));
        }
        final stats = snapshot.data!;
        // Only show users that have automations or are worth managing
        return RefreshIndicator(
          onRefresh: () async => setState(() {}), // force rebuild
          color: AppTheme.primaryCyan,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: stats.length,
            itemBuilder: (context, index) {
              final user = Map<String, dynamic>.from(stats[index]);
              final totalRules = user['totalRules'] ?? 0;
              final activeRules = user['activeRules'] ?? 0;
              final inactiveRules = user['inactiveRules'] ?? 0;
              bool powerSaving = user['powerSaving'] ?? false;
              final rules = (user['rules'] as List?) ?? [];
              
              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: AppTheme.cardBaseColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: powerSaving 
                        ? Colors.orangeAccent.withValues(alpha: 0.4) 
                        : Colors.white10,
                  ),
                ),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: CircleAvatar(
                    backgroundColor: totalRules > 0 
                        ? AppTheme.primaryCyan.withValues(alpha: 0.2) 
                        : Colors.grey.withValues(alpha: 0.2),
                    child: Icon(
                      Icons.auto_awesome, 
                      color: totalRules > 0 ? AppTheme.primaryCyan : Colors.grey, 
                      size: 20,
                    ),
                  ),
                  title: Text(
                    user['username'] ?? 'Unknown',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  subtitle: Row(
                    children: [
                      _buildMiniChip('$totalRules ${AppLocalization.get('total_automations')}', Colors.white38),
                      const SizedBox(width: 6),
                      if (activeRules > 0) _buildMiniChip('$activeRules ${AppLocalization.get('active_automations')}', Colors.greenAccent),
                      if (activeRules > 0) const SizedBox(width: 6),
                      if (inactiveRules > 0) _buildMiniChip('$inactiveRules ${AppLocalization.get('inactive_automations')}', Colors.redAccent),
                    ],
                  ),
                  iconColor: Colors.white54,
                  collapsedIconColor: Colors.white38,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Divider(color: Colors.white12),
                          Text('📧 ${user['email'] ?? ''}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                          const SizedBox(height: 12),
                          // Power Saving Toggle
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: powerSaving 
                                    ? [Colors.orange.withValues(alpha: 0.15), Colors.orange.withValues(alpha: 0.05)]
                                    : [Colors.green.withValues(alpha: 0.1), Colors.green.withValues(alpha: 0.03)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: powerSaving 
                                    ? Colors.orangeAccent.withValues(alpha: 0.4)
                                    : Colors.greenAccent.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  powerSaving ? Icons.battery_saver : Icons.bolt,
                                  color: powerSaving ? Colors.orangeAccent : Colors.greenAccent,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    AppLocalization.get(powerSaving ? 'power_saving_on' : 'power_saving_off'),
                                    style: TextStyle(
                                      color: powerSaving ? Colors.orangeAccent : Colors.greenAccent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Switch(
                                  value: powerSaving,
                                  activeColor: Colors.orangeAccent,
                                  onChanged: (v) async {
                                    try {
                                      user['powerSaving'] = v; await ApiService.adminTogglePowerSaving(user['userId'] ?? user['id'] ?? '', v);
                                      setState(() {});
                                      _showToast(v 
                                        ? '⚡ ${AppLocalization.get('power_saving_enabled')} - ${user['username']}'
                                        : '${AppLocalization.get('power_saving_disabled')} - ${user['username']}');
                                    } catch (e) {
                                      setState(() { user['powerSaving'] = !v; });
                                      _showToast('خطأ: $e');
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Rules list
                          if (rules.isEmpty)
                            Center(child: Text(AppLocalization.get('no_automations'), style: const TextStyle(color: Colors.white24, fontSize: 12)))
                          else
                            ...rules.map((rule) {
                              final r = Map<String, dynamic>.from(rule);
                              final isActive = r['isActive'] ?? false;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.03),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isActive ? Colors.greenAccent.withValues(alpha: 0.3) : Colors.white10,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8, height: 8,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isActive ? Colors.greenAccent : Colors.redAccent,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            r['name'] ?? '',
                                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'IF ${r['triggerWidgetName']} ${r['condition']} ${r['triggerValue']} → ${r['actionType']}${(r['actionWidgetName'] ?? '').isNotEmpty ? ' (${r['actionWidgetName']})' : ''}',
                                            style: const TextStyle(color: Colors.white38, fontSize: 10),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      isActive ? AppLocalization.get('active_automations') : AppLocalization.get('inactive_automations'),
                                      style: TextStyle(
                                        color: isActive ? Colors.greenAccent : Colors.redAccent,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMiniChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10)),
    );
  }

  // ==================== TAB 2: LOGS ====================
  Widget _buildLogsTab() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardBaseColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              indicatorColor: AppTheme.primaryCyan,
              labelColor: AppTheme.primaryCyan,
              unselectedLabelColor: Colors.white54,
              tabs: [
                Tab(text: AppLocalization.get('system_logs')),
                Tab(text: AppLocalization.get('client_errors')),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildLogsList(_serverLogs, isServer: true),
                _buildLogsList(_clientLogs, isServer: false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsList(List<dynamic> logs, {required bool isServer}) {
    if (logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green.withValues(alpha: 0.5), size: 60),
            const SizedBox(height: 16),
            Text(AppLocalization.get('no_logs'), style: const TextStyle(color: Colors.white54, fontSize: 16)),
          ],
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: logs.length,
        separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
        itemBuilder: (context, index) {
          final log = logs[index];
          final message = isServer ? (log['message'] ?? '') : (log['error'] ?? log['message'] ?? '');
          final timestamp = log['timestamp'] ?? '';
          final type = log['type'] ?? 'ERROR';
          
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: type == 'ERROR' ? Colors.red.withValues(alpha: 0.2) : Colors.yellow.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    type,
                    style: TextStyle(
                      color: type == 'ERROR' ? Colors.redAccent : Colors.yellowAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.toString(),
                        style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace'),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (timestamp.toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            timestamp.toString(),
                            style: const TextStyle(color: Colors.white24, fontSize: 10),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ==================== TAB 3: NOTIFICATIONS ====================
  Widget _buildNotificationsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryViolet.withValues(alpha: 0.3), AppTheme.primaryCyan.withValues(alpha: 0.1)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primaryViolet.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.campaign, color: AppTheme.primaryCyan, size: 32),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppLocalization.get('broadcast_notif'), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(AppLocalization.get('broadcast_desc'), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Target selector
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardBaseColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLocalization.get('target'), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _notifTarget,
                  dropdownColor: AppTheme.cardBaseColor,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    prefixIcon: const Icon(Icons.group, color: AppTheme.primaryCyan),
                  ),
                  items: [
                    DropdownMenuItem(value: 'all', child: Text(AppLocalization.get('all_users'))),
                    ..._users.map((u) => DropdownMenuItem(
                      value: u['id'].toString(),
                      child: Text(u['username'] ?? u['email'] ?? 'Unknown'),
                    )),
                  ],
                  onChanged: (v) => setState(() => _notifTarget = v ?? 'all'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppTheme.cardBaseColor, borderRadius: BorderRadius.circular(16)),
            child: TextField(
              controller: _notifTitleCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: AppLocalization.get('notif_title_hint'),
                hintStyle: const TextStyle(color: Colors.white24),
                prefixIcon: const Icon(Icons.title, color: AppTheme.primaryCyan),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Body
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppTheme.cardBaseColor, borderRadius: BorderRadius.circular(16)),
            child: TextField(
              controller: _notifBodyCtrl,
              style: const TextStyle(color: Colors.white),
              maxLines: 4,
              decoration: InputDecoration(
                hintText: AppLocalization.get('notif_body_hint'),
                hintStyle: const TextStyle(color: Colors.white24),
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 60),
                  child: Icon(Icons.message, color: AppTheme.primaryCyan),
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Send button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryViolet,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 8,
            ),
            icon: const Icon(Icons.send, size: 20),
            label: Text(AppLocalization.get('send_notif'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            onPressed: _sendNotification,
          ),
        ],
      ),
    );
  }

  void _sendNotification() async {
    final title = _notifTitleCtrl.text.trim();
    final body = _notifBodyCtrl.text.trim();
    if (title.isEmpty || body.isEmpty) {
      _showToast('يرجى إدخال العنوان والمحتوى');
      return;
    }
    try {
      await ApiService.sendAdminNotification(title, body, targetUserId: _notifTarget);
      _showToast(AppLocalization.get('notif_sent'));
      _notifTitleCtrl.clear();
      _notifBodyCtrl.clear();
    } catch (e) {
      _showToast('خطأ في الإرسال: $e');
    }
  }

  // ==================== TAB 4: QUOTAS ====================
  Widget _buildQuotaTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Summary cards
          Row(
            children: [
              Expanded(child: _buildStatCard(AppLocalization.isArabicNotifier.value ? 'مستخدمي التطبيق النشطين' : 'Active App Users', _users.where((u) => u['status'] == 'active').length.toString(), Icons.people, AppTheme.primaryCyan)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard(AppLocalization.isArabicNotifier.value ? 'طلبات Adafruit' : 'Adafruit IO Requests', _todayDatabaseWrites.toString(), Icons.cloud_sync, Colors.greenAccent)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildStatCard(AppLocalization.get('system_errors') ?? 'System Errors', _serverLogs.length.toString(), Icons.error_outline, Colors.redAccent)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard(AppLocalization.get('client_errors') ?? 'Client Errors', _clientLogs.length.toString(), Icons.phone_android, Colors.orange)),
            ],
          ),
           const SizedBox(height: 24),

          // Firebase Database Usage (Today) / استهلاك قاعدة بيانات Firebase (اليوم)
          Text(
            AppLocalization.isArabicNotifier.value ? 'استهلاك قاعدة بيانات Firebase (اليوم)' : 'Firebase Database Usage (Today)',
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardBaseColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFirebaseQuotaItem(
                  title: AppLocalization.isArabicNotifier.value ? 'قراءة البيانات (Reads)' : 'Database Reads',
                  used: _todayDatabaseReads,
                  limit: 50000,
                  icon: Icons.read_more_rounded,
                  color: AppTheme.primaryCyan,
                ),
                const SizedBox(height: 16),
                _buildFirebaseQuotaItem(
                  title: AppLocalization.isArabicNotifier.value ? 'كتابة البيانات (Writes)' : 'Database Writes',
                  used: _todayDatabaseWrites,
                  limit: 20000,
                  icon: Icons.edit_note_rounded,
                  color: AppTheme.primaryViolet,
                ),
                const SizedBox(height: 16),
                _buildFirebaseQuotaItem(
                  title: AppLocalization.isArabicNotifier.value ? 'حذف البيانات (Deletes)' : 'Database Deletes',
                  used: _todayDatabaseDeletes,
                  limit: 20000,
                  icon: Icons.delete_sweep_rounded,
                  color: Colors.redAccent,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Adafruit Quotas
          Text(AppLocalization.get('adafruit_quota'), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (_quotas.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: AppTheme.cardBaseColor, borderRadius: BorderRadius.circular(16)),
              child: Center(child: Text(AppLocalization.get('no_quota_data'), style: const TextStyle(color: Colors.white54))),
            )
          else
            ..._quotas.map((q) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardBaseColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cloud, color: AppTheme.primaryCyan, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(q['username'] ?? 'Unknown', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        Text('${AppLocalization.get('remaining')}: ${q['remaining'] ?? 'N/A'}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getQuotaColor(q['remaining']).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${q['remaining'] ?? '?'}',
                      style: TextStyle(color: _getQuotaColor(q['remaining']), fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            )),
        ],
      ),
    );
  }

  // ==================== TAB 5: BANS ====================
  Widget _buildBansTab() {
    if (_bannedDevices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green.withValues(alpha: 0.3), size: 60),
            const SizedBox(height: 16),
            Text(AppLocalization.get('no_banned_devices'), style: const TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadAllData,
      color: AppTheme.primaryCyan,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _bannedDevices.length,
        itemBuilder: (context, index) {
          final ban = _bannedDevices[index];
          final bannedAt = ban['bannedAt'] != null ? ban['bannedAt'].toString().split(' ')[0] : 'غير معروف';
          
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardBaseColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.block, color: Colors.redAccent, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ban['deviceName'] ?? AppLocalization.get('unknown_device'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      if (ban['ip'] != null) Text('IP: ${ban['ip']}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                      Text('${AppLocalization.get('at_date')}: $bannedAt', style: const TextStyle(color: Colors.white24, fontSize: 10)),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    try {
                      await ApiService.unbanDevice(ban['id']);
                      _showToast('✅ تم فك الحظر بنجاح');
                      _loadAllData();
                    } catch (e) {
                      _showToast('خطأ: $e');
                    }
                  },
                  icon: const Icon(Icons.undo, size: 16, color: Colors.greenAccent),
                  label: Text(AppLocalization.get('unban'), style: const TextStyle(color: Colors.greenAccent, fontSize: 12)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  

  Color _getQuotaColor(dynamic remaining) {
    if (remaining == null) return Colors.grey;
    final val = remaining is int ? remaining : int.tryParse(remaining.toString()) ?? 0;
    if (val > 20) return Colors.greenAccent;
    if (val > 5) return Colors.orange;
    return Colors.redAccent;
  }

  Widget _buildFirebaseQuotaItem({
    required String title,
    required int used,
    required int limit,
    required IconData icon,
    required Color color,
  }) {
    final ar = AppLocalization.isArabicNotifier.value;
    final percent = (used / limit).clamp(0.0, 1.0);
    final remaining = (limit - used).clamp(0, limit);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            Text(
              '$used / $limit',
              style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: percent,
            minHeight: 8,
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              (ar ? 'المتبقي: ' : 'Remaining: ') + '$remaining',
              style: TextStyle(color: remaining < (limit * 0.1) ? Colors.redAccent : Colors.white38, fontSize: 11),
            ),
            Text(
              '${(percent * 100).toStringAsFixed(1)}%',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
      ],
    );
  }

  void _showPermissionsSheet(BuildContext context, String code) async {
    final ar = AppLocalization.isArabicNotifier.value;
    final initialPerms = await ApiService.getSubAdminPermissions(code);
    
    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        bool allowSuspend = initialPerms['allowSuspend'] ?? true;
        bool allowBypassQuota = initialPerms['allowBypassQuota'] ?? true;
        int maxClients = initialPerms['maxClients'] ?? 100;
        
        return StatefulBuilder(
          builder: (ctx, setStateSheet) {
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                decoration: const BoxDecoration(
                  color: AppTheme.darkBackground,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  border: Border(top: BorderSide(color: Colors.white10, width: 1.5)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 45,
                        height: 5,
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Icon(Icons.security, color: Color(0xFF00FFCC), size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            ar ? 'تخصيص صلاحيات الموزع ($code)' : 'Distributor Permissions ($code)',
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      ar 
                          ? 'حدد الصلاحيات الممنوحة للتجار المسجلين باستخدام هذا الكود.' 
                          : 'Configure permissions granted to distributors registered via this code.',
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                    const SizedBox(height: 24),
                    
                    // Allow Suspend Switch
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeColor: const Color(0xFF00FFCC),
                      title: Text(
                        ar ? 'السماح بحظر وتعليق العملاء' : 'Allow Client Suspension',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        ar ? 'تمكين الموزع من إيقاف حسابات عملائه مؤقتاً.' : 'Let the merchant suspend his own client accounts.',
                        style: const TextStyle(color: Colors.white38, fontSize: 10),
                      ),
                      value: allowSuspend,
                      onChanged: (val) {
                        setStateSheet(() => allowSuspend = val);
                      },
                    ),
                    const Divider(color: Colors.white10),
                    
                    // Allow Bypass Quota Switch
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeColor: const Color(0xFF00FFCC),
                      title: Text(
                        ar ? 'السماح بتجاوز الحصص الإحصائية' : 'Allow Quota Bypassing',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        ar ? 'تجاوز حدود استهلاك قواعد البيانات والحزم.' : 'Bypass cloud read/write limitation rules.',
                        style: const TextStyle(color: Colors.white38, fontSize: 10),
                      ),
                      value: allowBypassQuota,
                      onChanged: (val) {
                        setStateSheet(() => allowBypassQuota = val);
                      },
                    ),
                    const Divider(color: Colors.white10),
                    
                    // Max Clients slider/input
                    const SizedBox(height: 12),
                    Text(
                      (ar ? 'الحد الأقصى للعملاء: ' : 'Max Clients Count: ') + (maxClients == 1000 ? (ar ? 'غير محدود' : 'Unlimited') : '$maxClients'),
                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    Slider(
                      activeColor: const Color(0xFF00FFCC),
                      inactiveColor: Colors.white10,
                      min: 10,
                      max: 1000,
                      divisions: 99,
                      value: maxClients.toDouble(),
                      onChanged: (val) {
                        setStateSheet(() {
                          maxClients = val.round();
                        });
                      },
                    ),
                    
                    const SizedBox(height: 28),
                    
                    // Save Button
                    SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00FFCC),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () async {
                          await ApiService.saveSubAdminPermissions(code, {
                            'allowSuspend': allowSuspend,
                            'allowBypassQuota': allowBypassQuota,
                            'maxClients': maxClients,
                          });
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            _showToast(ar ? 'تم حفظ الصلاحيات بنجاح! 🔐' : 'Permissions saved successfully! 🔐');
                          }
                        },
                        icon: const Icon(Icons.save, size: 20),
                        label: Text(ar ? 'حفظ وإرسال الصلاحيات' : 'Save Permissions', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSubAdminKeysTab() {
    final ar = AppLocalization.isArabicNotifier.value;

    return StatefulBuilder(
      builder: (context, setStateTab) {
        if (!_hasFetchedKeys && !_isKeysLoading) {
          _isKeysLoading = true;
          ApiService.getSubAdminPromoKeys().then((keys) {
            if (mounted && context.mounted) {
              setState(() {
                _subAdminKeys = keys;
                _isKeysLoading = false;
                _hasFetchedKeys = true;
              });
              setStateTab(() {});
            }
          });
        }

        void addKey() async {
          final code = _subAdminKeyCtrl.text.trim();
          if (code.isEmpty) return;
          setStateTab(() => _isKeysLoading = true);
          try {
            await ApiService.generateSubAdminPromoKey(code);
            _subAdminKeyCtrl.clear();
            final keys = await ApiService.getSubAdminPromoKeys();
            if (mounted) setState(() { _subAdminKeys = keys; _hasFetchedKeys = true; });
            _showToast(ar ? 'تم إنشاء الكود!' : 'Key generated!');
          } catch (e) {
            _showToast('$e');
          } finally {
            if (mounted) setStateTab(() => _isKeysLoading = false);
          }
        }

        void deleteKey(String key) async {
          setStateTab(() => _isKeysLoading = true);
          try {
            await ApiService.deleteSubAdminPromoKey(key);
            final keys = await ApiService.getSubAdminPromoKeys();
            if (mounted) setState(() { _subAdminKeys = keys; });
            _showToast(ar ? 'تم حذف الكود!' : 'Key deleted!');
          } catch (e) {
            _showToast('$e');
          } finally {
            if (mounted) setStateTab(() => _isKeysLoading = false);
          }
        }

        // Build cohorts: map each promo-key to the sub_admin user who used it,
        // then map that sub_admin's subAdminCode to its client users.
        final List<Map<String, dynamic>> distributors = _subAdminKeys.map((item) {
          final promoCode = (item['code'] ?? '').toString();

          // Find sub_admin user who registered with this promo key
          final subAdminUser = _users.firstWhere(
            (u) => u['role'] == 'sub_admin' && (
              // username-based or subAdminCode-based matching
              u['subAdminCode']?.toString().isNotEmpty == true
            ) && _users.any((u2) =>
              u2['role'] == 'sub_admin' &&
              (u2['subAdminCode']?.toString() ?? '').isNotEmpty
            ),
            orElse: () => <String, dynamic>{},
          );

          // Better match: find sub_admin whose account creation promo was this code
          final matchedAdmin = _users.firstWhere(
            (u) => u['role'] == 'sub_admin' && 
                   (u['registeredPromoCode'] == promoCode || u['promoCode'] == promoCode),
            orElse: () => <String, dynamic>{},
          );

          return {
            'promoCode': promoCode,
            'uses': item['uses'] ?? 0,
            'subAdmin': matchedAdmin,
          };
        }).toList();

        // Better approach: group sub_admins by their subAdminCode
        final subAdmins = _users.where((u) => u['role'] == 'sub_admin').toList();

        final Map<String, List<dynamic>> subAdminClientsMap = {};
        int totalLinkedClients = 0;
        final Set<String> uniqueClientEmails = {};

        for (final subAdmin in subAdmins) {
          final subAdminCode = (subAdmin['subAdminCode'] ?? '').toString();
          final subAdminEmail = (subAdmin['email'] ?? '').toString();

          final clients = _users.where((u) =>
            (u['parentAdminCode'] ?? '').toString() == subAdminCode &&
            subAdminCode.isNotEmpty
          ).toList();

          subAdminClientsMap[subAdmin['id']] = clients;
          for (final c in clients) {
            final email = c['email']?.toString().toLowerCase();
            if (email != null && email.isNotEmpty) {
              uniqueClientEmails.add(email);
            }
          }
        }
        totalLinkedClients = uniqueClientEmails.length;

        return CustomScrollView(
          slivers: [
            // ── Header: Generate New Key ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBaseColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF00FFCC).withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        ar ? 'إنشاء كود تفعيل موزع جديد' : 'Generate New Distributor Promo Key',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ar ? 'امنح هذا الكود للتاجر ليُسجّل كأدمن جانبي ويُدير عملاءه.' : 'Give this key to a merchant to register as sub-admin.',
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: TextField(
                            controller: _subAdminKeyCtrl,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: ar ? 'مثال: PARTNER_VIP_2026' : 'E.g., PARTNER_VIP_2026',
                              hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white12)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF00FFCC))),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00FFCC),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          ),
                          onPressed: _isKeysLoading ? null : addKey,
                          child: const Icon(Icons.add, size: 20),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
            ),

            // ── Stats Bar ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(children: [
                  _buildMiniStat(ar ? 'أكواد مفعلة' : 'Active Keys', '${_subAdminKeys.length}', const Color(0xFF00FFCC)),
                  const SizedBox(width: 12),
                  _buildMiniStat(ar ? 'موزعون نشطون' : 'Active Distributors', '${subAdmins.length}', Colors.amberAccent),
                  const SizedBox(width: 12),
                  _buildMiniStat(
                    ar ? 'عملاء مربوطون' : 'Linked Clients',
                    '$totalLinkedClients',
                    Colors.greenAccent,
                  ),
                ]),
              ),
            ),

            // ── Section: Promo Keys (unused/available) ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  ar ? 'أكواد التسجيل المتاحة' : 'Available Registration Keys',
                  style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            if (_isKeysLoading)
              const SliverToBoxAdapter(child: Center(child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: Color(0xFF00FFCC)),
              )))
            else if (_subAdminKeys.isEmpty)
              SliverToBoxAdapter(child: Center(child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(ar ? 'لا توجد أكواد بعد' : 'No promo keys yet', style: const TextStyle(color: Colors.white38)),
              )))
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((ctx, idx) {
                    final item = _subAdminKeys[idx];
                    final code = item['code'] ?? '';
                    final uses = item['uses'] ?? 0;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBaseColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00FFCC).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.vpn_key, color: Color(0xFF00FFCC), size: 16),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(code, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            Text(
                              (ar ? 'استُخدم ' : 'Used ') + '$uses ' + (ar ? 'مرة' : 'time(s)'),
                              style: const TextStyle(color: Colors.white38, fontSize: 11),
                            ),
                          ],
                        )),
                        IconButton(
                          icon: const Icon(Icons.settings_outlined, color: Color(0xFF00FFCC), size: 18),
                          tooltip: ar ? 'تعديل الصلاحيات' : 'Edit Permissions',
                          onPressed: () => _showPermissionsSheet(context, code),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, color: Colors.white54, size: 18),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: code));
                            _showToast(ar ? 'تم النسخ!' : 'Copied!');
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                          onPressed: () => deleteKey(code),
                        ),
                      ]),
                    );
                  }, childCount: _subAdminKeys.length),
                ),
              ),

            // ── Section: Active Distributors with their clients ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  ar ? 'الموزعون النشطون وعملاؤهم' : 'Active Distributors & Their Clients',
                  style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            subAdmins.isEmpty
                ? SliverToBoxAdapter(child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(child: Text(
                      ar ? 'لا يوجد موزعون مسجلون بعد' : 'No distributors registered yet',
                      style: const TextStyle(color: Colors.white38),
                    )),
                  ))
                : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((ctx, idx) {
                        final subAdmin = subAdmins[idx];
                        final subAdminCode = (subAdmin['subAdminCode'] ?? '').toString();
                        final subAdminName = (subAdmin['username'] ?? 'Unknown').toString();
                        final subAdminEmail = (subAdmin['email'] ?? '').toString();
                        final isActive = (subAdmin['status'] ?? 'active') == 'active';

                        // Find all clients linked to this sub-admin
                        final clients = subAdminClientsMap[subAdmin['id']] ?? [];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: AppTheme.cardBaseColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.2)),
                          ),
                          child: ExpansionTile(
                            iconColor: Colors.amberAccent,
                            collapsedIconColor: Colors.white38,
                            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            title: Row(children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.amberAccent.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.storefront_rounded, color: Colors.amberAccent, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(subAdminName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                  Text(subAdminEmail, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                ],
                              )),
                            ]),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Row(children: [
                                _buildBadge(
                                  isActive ? (ar ? 'نشط' : 'Active') : (ar ? 'معلق' : 'Suspended'),
                                  isActive ? Colors.greenAccent : Colors.redAccent,
                                ),
                                const SizedBox(width: 8),
                                _buildBadge('${clients.length} ${ar ? "عميل" : "clients"}', Colors.amberAccent),
                                const SizedBox(width: 8),
                                FutureBuilder<Map<String, dynamic>>(
                                  future: ApiService.getSubAdminPermissions(subAdminCode),
                                  builder: (ctx, snapshot) {
                                    if (snapshot.hasData) {
                                      final max = snapshot.data!['maxClients'] ?? 100;
                                      return _buildBadge(ar ? 'كوبونات: $max' : 'Coupons: $max', Colors.blueAccent);
                                    }
                                    return const SizedBox();
                                  }
                                ),
                                if (subAdminCode.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Flexible(child: Text(
                                    subAdminCode,
                                    style: const TextStyle(color: Colors.white24, fontSize: 9),
                                    overflow: TextOverflow.ellipsis,
                                  )),
                                ],
                              ]),
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    const Divider(color: Colors.white10),

                                    // Action buttons for the distributor itself
                                    Row(children: [
                                      Expanded(child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.amberAccent,
                                          side: const BorderSide(color: Colors.amberAccent),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                        ),
                                        icon: const Icon(Icons.settings, size: 14),
                                        label: Text(ar ? 'الصلاحيات' : 'Permissions', style: const TextStyle(fontSize: 12)),
                                        onPressed: () => _showPermissionsSheet(context, subAdminCode),
                                      )),
                                      const SizedBox(width: 8),
                                      Expanded(child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isActive ? Colors.redAccent.withValues(alpha: 0.15) : Colors.green.withValues(alpha: 0.15),
                                          foregroundColor: isActive ? Colors.redAccent : Colors.greenAccent,
                                          side: BorderSide(color: isActive ? Colors.redAccent : Colors.green),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                        ),
                                        icon: Icon(isActive ? Icons.block : Icons.check_circle_outline, size: 14),
                                        label: Text(
                                          isActive ? (ar ? 'تعليق الموزع' : 'Suspend') : (ar ? 'تفعيل' : 'Activate'),
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        onPressed: () async {
                                          final newStatus = isActive ? 'suspended' : 'active';
                                          try {
                                            await ApiService.updateUserStatus(subAdmin['id'], newStatus);
                                            await _loadAllData();
                                            _showToast(ar ? 'تم تحديث حالة الموزع!' : 'Distributor status updated!');
                                          } catch (e) {
                                            _showToast('$e');
                                          }
                                        },
                                      )),
                                    ]),

                                    // Clients list
                                    if (clients.isEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: Text(
                                          ar ? 'لا يوجد عملاء مرتبطون بهذا الموزع بعد.' : 'No clients linked to this distributor yet.',
                                          style: const TextStyle(color: Colors.white38, fontSize: 12),
                                          textAlign: TextAlign.center,
                                        ),
                                      )
                                    else ...[
                                      const SizedBox(height: 12),
                                      Text(
                                        ar ? 'العملاء المرتبطون (${clients.length})' : 'Linked Clients (${clients.length})',
                                        style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 8),
                                      ...clients.map((client) {
                                        final cName = (client['username'] ?? 'User').toString();
                                        final cEmail = (client['email'] ?? '').toString();
                                        final cStatus = (client['status'] ?? 'active').toString();
                                        final cActive = cStatus == 'active';
                                        return Container(
                                          margin: const EdgeInsets.only(bottom: 8),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.03),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: Colors.white10),
                                          ),
                                          child: Row(children: [
                                            CircleAvatar(
                                              radius: 14,
                                              backgroundColor: cActive ? Colors.greenAccent.withValues(alpha: 0.12) : Colors.redAccent.withValues(alpha: 0.12),
                                              child: Icon(
                                                cActive ? Icons.person : Icons.person_off,
                                                color: cActive ? Colors.greenAccent : Colors.redAccent,
                                                size: 14,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(cName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                                                if (cEmail.isNotEmpty) Text(cEmail, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                                              ],
                                            )),
                                            _buildBadge(
                                              cActive ? (ar ? 'نشط' : 'Active') : (ar ? 'معلق' : 'Suspended'),
                                              cActive ? Colors.greenAccent : Colors.redAccent,
                                            ),
                                            const SizedBox(width: 6),
                                            // Toggle client status
                                            GestureDetector(
                                              onTap: () async {
                                                try {
                                                  await ApiService.updateUserStatus(client['id'], cActive ? 'suspended' : 'active');
                                                  await _loadAllData();
                                                  _showToast(ar ? 'تم تحديث حالة العميل!' : 'Client status updated!');
                                                } catch (e) {
                                                  _showToast('$e');
                                                }
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: cActive ? Colors.redAccent.withValues(alpha: 0.15) : Colors.greenAccent.withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: cActive ? Colors.redAccent.withValues(alpha: 0.4) : Colors.greenAccent.withValues(alpha: 0.4)),
                                                ),
                                                child: Text(
                                                  cActive ? (ar ? 'تعليق' : 'Suspend') : (ar ? 'تفعيل' : 'Activate'),
                                                  style: TextStyle(
                                                    color: cActive ? Colors.redAccent : Colors.greenAccent,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ]),
                                        );
                                      }),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }, childCount: subAdmins.length),
                    ),
                  ),
          ],
        );
      },
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: AppTheme.cardBaseColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

}


// ==================== Sessions Bottom Sheet ====================
class _SessionsSheet extends StatelessWidget {
  final String username;
  final List<dynamic> sessions;
  final Function(String sessionId) onLogout;
  final Function(String? deviceId, String? ip, String? deviceName) onBan;

  const _SessionsSheet({
    required this.username,
    required this.sessions,
    required this.onLogout,
    required this.onBan,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      decoration: const BoxDecoration(
        color: AppTheme.darkBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.devices, color: AppTheme.primaryCyan),
                const SizedBox(width: 12),
                Text('جلسات $username', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          // Sessions list
          Flexible(
            child: sessions.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(40),
                    child: Text('لا توجد جلسات نشطة', style: TextStyle(color: Colors.white54)),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final s = sessions[index];
                      final deviceInfo = s['deviceInfo'] ?? {};
                      final deviceName = deviceInfo['deviceName'] ?? deviceInfo['userAgent'] ?? 'Unknown Device';
                      final deviceId = deviceInfo['deviceId'] ?? s['deviceId'];
                      final ip = deviceInfo['ip'] ?? s['ip'] ?? '';
                      final platform = deviceInfo['platform'] ?? '';
                      
                      IconData deviceIcon = Icons.laptop;
                      if (platform.toString().toLowerCase().contains('android')) {
                        deviceIcon = Icons.phone_android;
                      } else if (platform.toString().toLowerCase().contains('ios')) {
                        deviceIcon = Icons.phone_iphone;
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBaseColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(deviceIcon, color: AppTheme.primaryCyan, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    deviceName.toString().length > 40 
                                        ? '${deviceName.toString().substring(0, 40)}...' 
                                        : deviceName.toString(),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                            if (ip.toString().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text('IP: $ip', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                            ],
                            if (deviceId != null) ...[
                              const SizedBox(height: 2),
                              Text('Device: ${deviceId.toString().substring(0, (deviceId.toString().length > 20 ? 20 : deviceId.toString().length))}...', style: const TextStyle(color: Colors.white24, fontSize: 10)),
                            ],
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.orange,
                                      side: const BorderSide(color: Colors.orange),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                    ),
                                    icon: const Icon(Icons.logout, size: 16),
                                    label: const Text('طرد', style: TextStyle(fontSize: 12)),
                                    onPressed: () => onLogout(s['id']),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.redAccent,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                    ),
                                    icon: const Icon(Icons.block, size: 16),
                                    label: const Text('حظر', style: TextStyle(fontSize: 12)),
                                    onPressed: () => onBan(deviceId?.toString(), ip.toString(), deviceName.toString()),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}


