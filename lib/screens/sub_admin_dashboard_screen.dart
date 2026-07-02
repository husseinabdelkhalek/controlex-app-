import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_theme.dart';
import '../widgets/premium_app_bar.dart';
import '../services/api_service.dart';
import '../core/localization.dart';
import '../widgets/app_snackbar.dart';

class SubAdminDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> userProfile;

  const SubAdminDashboardScreen({super.key, required this.userProfile});

  @override
  State<SubAdminDashboardScreen> createState() => _SubAdminDashboardScreenState();
}

class _SubAdminDashboardScreenState extends State<SubAdminDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedViewIndex = 0;
  bool _isLoading = true;
  List<dynamic> _clients = [];
  late String _subAdminCode;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final rawCode = widget.userProfile['subAdminCode'];
    final email = widget.userProfile['email']?.toString().toLowerCase();
    final isMainAdmin = email == 'hussianabdk577@gmail.com';
    _subAdminCode = (rawCode == null || rawCode.toString().trim().isEmpty)
        ? (isMainAdmin ? 'MERCHANT_ADMIN_TEST' : 'CODE_MERCHANT_DEFAULT')
        : rawCode.toString();
    _loadGroupData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadGroupData() async {
    setState(() => _isLoading = true);
    try {
      final clientsData = await ApiService.getMerchantClients(_subAdminCode);
      if (mounted) {
        setState(() {
          _clients = clientsData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppSnackbar.showError(context, e);
      }
    }
  }

  void _toggleClientStatus(Map<String, dynamic> client) async {
    final perms = await ApiService.getSubAdminPermissions(_subAdminCode);
    final allowSuspend = perms['allowSuspend'] ?? true;
    if (!allowSuspend) {
      if (mounted) {
        AppSnackbar.showError(
          context,
          AppLocalization.isArabicNotifier.value
              ? 'عذراً، الإدارة الرئيسية قامت بتعطيل صلاحية حظر العملاء لحسابك الموزع!'
              : 'Sorry, the main Super Admin has disabled client suspension permissions for your distributor account!',
        );
      }
      return;
    }

    final currentStatus = client['status'] ?? 'active';
    final newStatus = currentStatus == 'active' ? 'suspended' : 'active';
    setState(() => _isLoading = true);
    try {
      await ApiService.toggleMerchantClientStatus(_subAdminCode, client['id'], newStatus);
      if (mounted) {
        AppSnackbar.showSuccess(
          context,
          AppLocalization.isArabicNotifier.value
              ? 'تم تحديث حالة المستخدم بنجاح ✅'
              : 'User status updated successfully ✅',
        );
      }
      _loadGroupData();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) AppSnackbar.showError(context, e);
    }
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _subAdminCode));
    AppSnackbar.showSuccess(
      context,
      AppLocalization.isArabicNotifier.value
          ? 'تم نسخ كود التفعيل إلى الحافظة 📋'
          : 'Activation code copied to clipboard 📋',
    );
  }

  @override
  Widget build(BuildContext context) {
    final ar = AppLocalization.isArabicNotifier.value;
    String screenTitle = ar ? 'لوحة تحكم الموزع' : 'Distributor Dashboard';
    if (_selectedViewIndex == 1) screenTitle = ar ? 'إدارة العملاء' : 'Manage Clients';
    if (_selectedViewIndex == 2) screenTitle = ar ? 'رمز الاتصال QR' : 'Invite QR Code';

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: PremiumAppBar(
        titleText: screenTitle,
        leading: _selectedViewIndex > 0
            ? IconButton(
                icon: Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => setState(() => _selectedViewIndex = 0),
              )
            : null,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Color(0xFF00FFCC)),
            onPressed: _loadGroupData,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Color(0xFF00FFCC)))
          : _selectedViewIndex == 0
              ? _buildOverviewTab()
              : _selectedViewIndex == 1
                  ? _buildClientsTab()
                  : _buildQrTab(),
    );
  }

  // ==================== VIEW 1: OVERVIEW ====================
  Widget _buildOverviewTab() {
    final ar = AppLocalization.isArabicNotifier.value;
    final totalClients = _clients.length;
    final activeClients = _clients.where((c) => c['status'] == 'active').length;
    final suspendedClients = totalClients - activeClients;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sub-Admin Brand Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF00FFCC).withValues(alpha: 0.15), Colors.white.withValues(alpha: 0.02)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF00FFCC).withValues(alpha: 0.25), width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FFCC).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00FFCC).withValues(alpha: 0.1),
                        blurRadius: 10,
                      )
                    ]
                  ),
                  child: Icon(Icons.storefront_rounded, color: Color(0xFF00FFCC), size: 36),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.userProfile['username'] ?? 'موزع معتمد',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00FFCC).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          ar ? 'شريك موزع معتمد' : 'Authorized Merchant Partner',
                          style: TextStyle(color: Color(0xFF00FFCC), fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 24),

          // Invite Key Quick Box
          Text(
            ar ? 'كود اتصال العملاء الخاص بك' : 'Your Customer Inviting Code',
            style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardBaseColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                Icon(Icons.key, color: Color(0xFF00FFCC), size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _subAdminCode,
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.copy, color: Colors.white70, size: 20),
                  onPressed: _copyToClipboard,
                ),
              ],
            ),
          ),
          SizedBox(height: 24),

          // Overview Stats Grid
          Text(
            ar ? 'إحصائيات المجموعة' : 'Group Statistics',
            style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _buildStatCard(
                ar ? 'إجمالي العملاء' : 'Total Customers',
                totalClients.toString(),
                Icons.people,
                const Color(0xFF00E5FF),
              ),
              _buildStatCard(
                ar ? 'العملاء النشطين' : 'Active Members',
                activeClients.toString(),
                Icons.check_circle_outline,
                const Color(0xFF00FF87),
              ),
              _buildStatCard(
                ar ? 'حسابات معلقة' : 'Suspended accounts',
                suspendedClients.toString(),
                Icons.block,
                const Color(0xFFFF0055),
              ),
              _buildStatCard(
                ar ? 'مجموع القنوات' : 'Connected Channels',
                _clients.fold(0, (prev, element) => prev + (element['widgetCount'] as int? ?? 0)).toString(),
                Icons.sensors_rounded,
                const Color(0xFFFFB300),
              ),
            ],
          ),
          SizedBox(height: 28),

          // Action Shortcuts Menu
          Text(
            ar ? 'العمليات المتاحة' : 'Distributor Operations',
            style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          _buildOperationTile(
            index: 1,
            title: ar ? 'إدارة وحظر العملاء' : 'Manage & Suspend Customers',
            subtitle: ar ? 'تفعيل أو إيقاف حسابات العملاء المسجلين تحت مجموعتك.' : 'Activate or halt users registered under your key.',
            icon: Icons.people_outline,
            color: const Color(0xFF00FFCC),
          ),
          SizedBox(height: 12),
          _buildOperationTile(
            index: 2,
            title: ar ? 'توليد ومشاركة كود الـ QR' : 'Deploy Invitation QR Code',
            subtitle: ar ? 'عرض رمز الاستجابة السريعة لمسحه الفوري من قبل عملائك الجدد.' : 'Display scan-and-register matrix for new clients.',
            icon: Icons.qr_code_2_rounded,
            color: const Color(0xFF00E5FF),
          ),
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
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Icon(icon, color: color, size: 18),
            ],
          ),
          SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(
          title,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            subtitle,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
          ),
        ),
        trailing: Icon(Icons.chevron_right, color: color.withValues(alpha: 0.6)),
        onTap: () => setState(() => _selectedViewIndex = index),
      ),
    );
  }

  // ==================== VIEW 2: CLIENTS ====================
  Widget _buildClientsTab() {
    final ar = AppLocalization.isArabicNotifier.value;
    if (_clients.isEmpty) {
      return Center(
        child: Text(
          ar ? 'لا يوجد عملاء مسجلين تحت كودك بعد!' : 'No clients registered under your code yet!',
          style: TextStyle(color: Colors.white38, fontSize: 14),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _clients.length,
      itemBuilder: (context, index) {
        final client = _clients[index];
        final isActive = client['status'] == 'active';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppTheme.cardBaseColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white10),
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: CircleAvatar(
              backgroundColor: isActive ? const Color(0xFF00FFCC).withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
              child: Icon(
                isActive ? Icons.person : Icons.person_off_rounded,
                color: isActive ? const Color(0xFF00FFCC) : Colors.redAccent,
                size: 20,
              ),
            ),
            title: Text(
              client['username'] ?? 'User',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isActive ? (ar ? 'نشط' : 'Active') : (ar ? 'معلق' : 'Suspended'),
                    style: TextStyle(color: isActive ? Colors.greenAccent : Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  '${client['widgetCount'] ?? 0} ${ar ? 'أداة ذكية' : 'Widgets'}',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Divider(color: Colors.white12),
                    Row(
                      children: [
                        Icon(Icons.email_outlined, color: Colors.white38, size: 14),
                        SizedBox(width: 8),
                        Text(
                          client['email'] ?? '',
                          style: TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                      ],
                    ),
                    SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isActive ? Colors.redAccent.withValues(alpha: 0.15) : Colors.green.withValues(alpha: 0.15),
                              foregroundColor: isActive ? Colors.redAccent : Colors.greenAccent,
                              side: BorderSide(color: isActive ? Colors.redAccent : Colors.green),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: Icon(isActive ? Icons.block : Icons.check_circle_outline, size: 16),
                            label: Text(
                              isActive ? (ar ? 'تعليق الحساب' : 'Suspend Account') : (ar ? 'تفعيل الحساب' : 'Activate Account'),
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            onPressed: () => _toggleClientStatus(client),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }

  // ==================== VIEW 3: QR GENERATOR ====================
  Widget _buildQrTab() {
    final ar = AppLocalization.isArabicNotifier.value;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            ar ? 'كود الانضمام للمشرف' : 'Distributor Connection Code',
            style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 4),
          Text(
            ar
                ? 'اجعل عملائك يمسحون هذا الرمز لتثبيت الإعدادات والتحكم بالملفات فورياً.'
                : 'Share this scan code for quick and automated client configurations.',
            style: TextStyle(color: Colors.white38, fontSize: 11),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 28),

          // High fidelity Vector neon QR Code painting container
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.cardBaseColor,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFF00FFCC).withValues(alpha: 0.2), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00FFCC).withValues(alpha: 0.05),
                  blurRadius: 20,
                  spreadRadius: 2,
                )
              ]
            ),
            child: Column(
              children: [
                QrImageView(
                  data: _subAdminCode,
                  version: QrVersions.auto,
                  size: 220,
                  gapless: false,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Color(0xFF00E5FF),
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.circle,
                    color: Color(0xFF00FFCC),
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  _subAdminCode,
                  style: TextStyle(color: Color(0xFF00FFCC), fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
              ],
            ),
          ),
          SizedBox(height: 32),

          // Operations Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FFCC),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: Icon(Icons.copy, size: 18),
                  label: Text(
                    ar ? 'نسخ الكود' : 'Copy Code',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: _copyToClipboard,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: Icon(Icons.share, size: 18),
                  label: Text(
                    ar ? 'مشاركة QR' : 'Share QR',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    final ar = AppLocalization.isArabicNotifier.value;
                    Share.share(
                      ar
                          ? 'انضم إلي كموزع في تطبيق ControlEx! كود التفعيل الخاص بي هو: $_subAdminCode'
                          : 'Join me as a customer on ControlEx! My distributor activation code is: $_subAdminCode',
                      subject: ar ? 'كود انضمام موزع ControlEx' : 'ControlEx Distributor Connection Code',
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


