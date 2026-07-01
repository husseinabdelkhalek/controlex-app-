import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../core/localization.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/glass_popups.dart';

class ManagePagesDialog extends StatefulWidget {
  final List<dynamic> currentPages;

  const ManagePagesDialog({super.key, required this.currentPages});

  @override
  State<ManagePagesDialog> createState() => _ManagePagesDialogState();
}

class _ManagePagesDialogState extends State<ManagePagesDialog> {
  List<dynamic> _pages = [];
  bool _isLoading = false;
  final TextEditingController _nameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _pages = List.from(widget.currentPages);
  }

  Future<void> _savePages() async {
    setState(() => _isLoading = true);
    try {
      final user = await ApiService.userMe();
      final prefs = user['preferences'] ?? {};
      prefs['pages'] = _pages;
      
      await ApiService.updatePreferences(prefs);
      if (mounted) {
        Navigator.pop(context, _pages);
      }
    } catch (e) {
      if (mounted) AppSnackbar.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addPage() {
    _nameCtrl.clear();
    showGlassDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        surfaceTintColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        content: GlassCard(
          borderRadius: 24,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(AppLocalization.isArabicNotifier.value ? 'إضافة صفحة' : 'Add Page', 
                     style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextField(
                  controller: _nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: AppLocalization.isArabicNotifier.value ? 'اسم الصفحة' : 'Page Name',
                    hintStyle: const TextStyle(color: Colors.white54),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.primaryCyan),
                    ),
                    filled: true,
                    fillColor: Colors.black.withValues(alpha: 0.2),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(AppLocalization.get('cancel'), style: const TextStyle(color: Colors.white54)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryCyan,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      onPressed: () {
                        if (_nameCtrl.text.trim().isNotEmpty) {
                          setState(() {
                            _pages.add({
                              'id': 'page_${DateTime.now().millisecondsSinceEpoch}',
                              'name': _nameCtrl.text.trim(),
                            });
                          });
                          Navigator.pop(ctx);
                        }
                      },
                      child: Text(AppLocalization.isArabicNotifier.value ? 'إضافة' : 'Add', 
                                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _editPage(int index) {
    _nameCtrl.text = _pages[index]['name'];
    showGlassDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        surfaceTintColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        content: GlassCard(
          borderRadius: 24,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(AppLocalization.isArabicNotifier.value ? 'تعديل الصفحة' : 'Edit Page', 
                     style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextField(
                  controller: _nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: AppLocalization.isArabicNotifier.value ? 'اسم الصفحة' : 'Page Name',
                    hintStyle: const TextStyle(color: Colors.white54),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.primaryCyan),
                    ),
                    filled: true,
                    fillColor: Colors.black.withValues(alpha: 0.2),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(AppLocalization.get('cancel'), style: const TextStyle(color: Colors.white54)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryCyan,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      onPressed: () {
                        if (_nameCtrl.text.trim().isNotEmpty) {
                          setState(() {
                            _pages[index]['name'] = _nameCtrl.text.trim();
                          });
                          Navigator.pop(ctx);
                        }
                      },
                      child: Text(AppLocalization.isArabicNotifier.value ? 'حفظ' : 'Save', 
                                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _deletePage(int index) {
    setState(() {
      _pages.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: GlassCard(
        borderRadius: 28,
        child: Container(
          padding: const EdgeInsets.all(24),
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            children: [
              // Drag handle indicator aesthetic (even though it's a dialog)
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                AppLocalization.isArabicNotifier.value ? 'إدارة الصفحات' : 'Manage Pages', 
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)
              ),
              const SizedBox(height: 24),
              Expanded(
                child: _pages.isEmpty
                    ? Center(child: Text(AppLocalization.isArabicNotifier.value ? 'لا توجد صفحات' : 'No Pages', style: const TextStyle(color: Colors.white54)))
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: _pages.length,
                        itemBuilder: (context, index) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              title: Text(_pages[index]['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(icon: const Icon(Icons.edit, color: AppTheme.primaryCyan), onPressed: () => _editPage(index)),
                                  IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: () => _deletePage(index)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      elevation: 0,
                    ),
                    onPressed: _addPage,
                    icon: const Icon(Icons.add, color: AppTheme.primaryCyan),
                    label: Text(AppLocalization.isArabicNotifier.value ? 'إضافة' : 'Add', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  _isLoading
                      ? const CircularProgressIndicator(color: AppTheme.primaryCyan)
                      : ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryCyan,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          ),
                          onPressed: _savePages,
                          icon: const Icon(Icons.check, color: Colors.black),
                          label: Text(AppLocalization.get('save'), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                        ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
