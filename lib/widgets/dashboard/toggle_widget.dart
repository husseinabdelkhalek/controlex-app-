import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../glass_card.dart';
import '../../theme/app_theme.dart';

class DashboardToggleWidget extends StatelessWidget {
  final dynamic config;
  final String id;
  final String title;
  final IconData icon;
  final bool value;
  final Color color;
  final bool isEditMode;
  final VoidCallback onToggle;

  const DashboardToggleWidget({
    super.key,
    required this.config,
    required this.id,
    required this.title,
    required this.icon,
    required this.value,
    required this.color,
    required this.isEditMode,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (builderContext, constraints) {
      final size = constraints.biggest.shortestSide;
      return GestureDetector(
        onTap: isEditMode ? null : onToggle,
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
}
