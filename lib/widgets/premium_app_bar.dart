import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class PremiumAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final String? titleText;
  final List<Widget>? actions;
  final Widget? leading;
  final PreferredSizeWidget? bottom;
  final bool centerTitle;

  const PremiumAppBar({
    super.key,
    this.title,
    this.titleText,
    this.actions,
    this.leading,
    this.bottom,
    this.centerTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget? titleWidget = title;

    if (titleWidget == null && titleText != null) {
      // Build a premium gradient title
      titleWidget = ShaderMask(
        shaderCallback: (bounds) => LinearGradient(
          colors: [AppTheme.primaryCyan, AppTheme.primaryViolet],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(bounds),
        child: Text(
          titleText!,
          style: GoogleFonts.tajawal(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: 0.5,
            color: Colors.white, // Required for ShaderMask to paint properly
          ),
        ),
      );
    }

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: centerTitle,
      leading: leading,
      title: titleWidget,
      actions: actions,
      bottom: bottom,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0x99080614), // Semi-transparent background
              border: const Border(
                bottom: BorderSide(
                  color: Color(0x2B00E5FF), // Subtle glowing cyan bottom border
                  width: 1.2,
                ),
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.primaryViolet.withValues(alpha: 0.08),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0.0),
      );
}
