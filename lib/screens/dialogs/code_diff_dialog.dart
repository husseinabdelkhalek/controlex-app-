import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../core/localization.dart';

class CodeDiffDialog extends StatelessWidget {
  final String oldCode;
  final String newCode;
  final String actionDescription;

  const CodeDiffDialog({
    super.key,
    required this.oldCode,
    required this.newCode,
    required this.actionDescription,
  });

  @override
  Widget build(BuildContext context) {
    final isAr = AppLocalization.isArabicNotifier.value;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: GlassCard(
        borderRadius: 24,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 600),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.code_rounded, color: AppTheme.primaryCyan, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isAr ? 'مراجعة تعديل الكود' : 'Review Code Modification',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                isAr ? 'الإجراء: $actionDescription' : 'Action: $actionDescription',
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildCodeBox(isAr ? 'الكود الحالي' : 'Current Code', oldCode, Colors.redAccent.withOpacity(0.1), Colors.redAccent),
                      const SizedBox(height: 16),
                      _buildCodeBox(isAr ? 'الكود الجديد' : 'New Code', newCode, Colors.greenAccent.withOpacity(0.1), Colors.greenAccent),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                    ),
                    child: Text(isAr ? 'رفض' : 'Reject'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryCyan,
                      foregroundColor: const Color(0xFF090A0F),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.check_rounded, size: 20),
                    label: Text(
                      isAr ? 'موافقة وتطبيق' : 'Approve & Apply',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCodeBox(String title, String code, Color bgColor, Color borderColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: borderColor,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bgColor,
            border: Border.all(color: borderColor.withOpacity(0.5)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: SelectableText(
            code.isEmpty ? (AppLocalization.isArabicNotifier.value ? 'لا يوجد كود' : 'No Code') : code,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'monospace',
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
