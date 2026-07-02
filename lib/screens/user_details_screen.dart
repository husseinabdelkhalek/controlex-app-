import '../widgets/app_snackbar.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../core/localization.dart';
import '../services/api_service.dart';

class UserDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  
  const UserDetailsScreen({super.key, required this.user});

  @override
  State<UserDetailsScreen> createState() => _UserDetailsScreenState();
}

class _UserDetailsScreenState extends State<UserDetailsScreen> {
  bool _isDeleting = false;

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

  void _showToast(String msg) {
    if (!mounted) return;
    AppSnackbar.showSuccess(context, msg);
  }

  void _deleteUser() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBaseColor,
        title: Text(AppLocalization.isArabicNotifier.value ? 'تأكيد الحذف' : 'Confirm Delete', style: TextStyle(color: Colors.redAccent)),
        content: Text(
          AppLocalization.isArabicNotifier.value 
            ? 'هل أنت متأكد من حذف هذا الحساب نهائياً؟ لا يمكن التراجع عن هذا الإجراء وسيتم حذف جميع بياناته.'
            : 'Are you sure you want to permanently delete this account? This action cannot be undone and all data will be lost.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalization.isArabicNotifier.value ? 'إلغاء' : 'Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalization.isArabicNotifier.value ? 'حذف' : 'Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isDeleting = true);
    try {
      await ApiService.deleteAdminUser(widget.user['id']);
      _showToast(AppLocalization.isArabicNotifier.value ? 'تم حذف الحساب بنجاح' : 'Account deleted successfully');
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _showToast('${AppLocalization.get('error')}: $e');
      setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    
    final deviceInfoRaw = user['deviceInfo'] ?? user['security']?['deviceInfo'];
    String? devicePlatform;
    if (deviceInfoRaw is Map) {
       devicePlatform = deviceInfoRaw['platform'];
    }
    
    if (devicePlatform == null || devicePlatform.isEmpty) {
        if (user['sessions'] is List && (user['sessions'] as List).isNotEmpty) {
           final firstSession = (user['sessions'] as List).first;
           if (firstSession is Map && firstSession['deviceInfo'] is Map) {
               devicePlatform = firstSession['deviceInfo']['platform'];
           }
        }
    }

    final platformStr = user['clientType'] ?? user['platform'] ?? user['source'] ?? devicePlatform ?? (AppLocalization.isArabicNotifier.value ? 'غير محدد' : 'Unknown');

    String backendStr = 'Node.js (Socket.io)';
    if (user['firebaseUrl'] != null && user['firebaseUrl'].toString().isNotEmpty) {
      backendStr = 'Firebase Realtime DB';
    } else if (user['adafruitUsername'] != null && user['adafruitUsername'].toString().isNotEmpty) {
      backendStr = 'Adafruit IO';
    }

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: Text(user['username'] ?? 'User Details', style: TextStyle(fontWeight: FontWeight.bold)),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primaryViolet.withValues(alpha: 0.8), AppTheme.darkBackground],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: CircleAvatar(
                radius: 50,
                backgroundColor: AppTheme.primaryCyan.withValues(alpha: 0.2),
                child: Icon(Icons.person, size: 60, color: AppTheme.primaryCyan),
              ),
            ),
            SizedBox(height: 30),
            _buildDetailItem(
              AppLocalization.isArabicNotifier.value ? 'المنصة (موقع/تطبيق)' : 'Platform',
              platformStr,
              Icons.devices,
            ),
            _buildDetailItem(
              AppLocalization.isArabicNotifier.value ? 'قاعدة البيانات (Database)' : 'Database',
              backendStr,
              Icons.storage,
            ),
            _buildDetailItem(
              AppLocalization.isArabicNotifier.value ? 'تاريخ إنشاء الحساب' : 'Created At',
              _formatDate(user['createdAt']),
              Icons.calendar_today,
            ),
            _buildDetailItem(
              AppLocalization.isArabicNotifier.value ? 'آخر ظهور' : 'Last Online',
              _formatDate(user['lastActive'] ?? user['security']?['lastLogin'] ?? user['lastLogin']),
              Icons.access_time,
            ),
            _buildDetailItem(
              AppLocalization.isArabicNotifier.value ? 'اسم مستخدم Adafruit IO' : 'Adafruit IO Username',
              user['adafruitUsername']?.toString().trim().isEmpty ?? true 
                  ? (AppLocalization.isArabicNotifier.value ? 'غير مربوط' : 'Not linked') 
                  : user['adafruitUsername'],
              Icons.cloud,
            ),
            _buildDetailItem(
              AppLocalization.isArabicNotifier.value ? 'البريد الإلكتروني' : 'Email',
              user['email'] ?? 'N/A',
              Icons.email,
            ),
            _buildDetailItem(
              AppLocalization.isArabicNotifier.value ? 'حالة الحساب' : 'Status',
              user['status'] == 'active' 
                ? (AppLocalization.isArabicNotifier.value ? 'نشط' : 'Active') 
                : (AppLocalization.isArabicNotifier.value ? 'معلق' : 'Suspended'),
              Icons.security,
            ),
            _buildDetailItem(
              AppLocalization.isArabicNotifier.value ? 'الرتبة' : 'Role',
              user['isSuperAdmin'] == true ? 'Super Admin' : (user['role'] ?? 'user'),
              Icons.badge,
            ),
            _buildDetailItem(
              AppLocalization.isArabicNotifier.value ? 'عدد الأدوات' : 'Widgets Count',
              '${user['widgetCount'] ?? 0}',
              Icons.widgets,
            ),
            SizedBox(height: 40),
            
            if (_isDeleting)
              Center(child: CircularProgressIndicator(color: Colors.redAccent))
            else
              ElevatedButton.icon(
                onPressed: _deleteUser,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent.withValues(alpha: 0.15),
                  foregroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.redAccent, width: 1.5),
                  ),
                ),
                icon: Icon(Icons.delete_forever),
                label: Text(
                  AppLocalization.isArabicNotifier.value ? 'حذف الحساب نهائياً' : 'Delete Account Permanently',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBaseColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryCyan.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.primaryCyan, size: 24),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.white54, fontSize: 13)),
                SizedBox(height: 4),
                Text(value, style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
