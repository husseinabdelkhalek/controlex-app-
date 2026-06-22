import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Premium Dark-First Backgrounds
  static const Color backgroundBase = Color(0xFF080614); 
  static const Color darkBackground = Color(0xFF080614); 
  
  // Vibrant Neon Accents (Violet & Cyan)
  static const Color primaryCyan = Color(0xFF00E5FF); 
  static const Color darkCyan = Color(0xFF00ACC1); 
  static const Color primaryViolet = Color(0xFF8A2BE2); 
  static const Color darkViolet = Color(0xFF6A1B9A); 
  
  // Legacy Accents (retained for specific components like DrawerHeader)
  static const Color accentNeon = Color(0xFFFF007F); // Neon Pink
  static const Color neonBlue = Color(0xFF3A0CA3);   // Deep Electric Blue
  
  // Glassmorphism enhancements
  // rgba(21, 19, 44, 0.85) => hex A=D9, R=15, G=13, B=2C => 0xD915132C
  static const Color cardBaseColor = Color(0xD915132C); 
  static const Color cardLightColor = Color(0xFFE2E8F0); 
  
  // Glows and Borders
  static const Color glassBorder = Color(0x4D8A2BE2); // 30% Violet
  static const Color glowColor = Color(0x6600E5FF); // Cyan Glow
  static const Color violetGlow = Color(0x808A2BE2); // Violet Glow
  
  // Texts
  static const Color textPrimary = Color(0xFFF0F8FF); // Snow white
  static const Color textSecondary = Color(0xFFA9A2C8); // Faded violet

  static BoxDecoration glassDecoration({
    BorderRadiusGeometry? borderRadius,
    Color? baseColor,
    Color? borderColor,
  }) {
    final resolvedColor = (baseColor ?? cardBaseColor);
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          resolvedColor.withValues(alpha: 0.75),
          resolvedColor.withValues(alpha: 0.45),
        ],
      ),
      borderRadius: borderRadius ?? const BorderRadius.vertical(top: Radius.circular(24)),
      border: Border.all(
        color: borderColor ?? glassBorder,
        width: 1.5,
      ),
    );
  }

  static ThemeData get darkTheme {
    final tajawal = GoogleFonts.tajawalTextTheme();
    
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: primaryCyan,
      scaffoldBackgroundColor: darkBackground,
      fontFamily: GoogleFonts.tajawal().fontFamily,
      dialogTheme: DialogTheme(
        surfaceTintColor: Colors.transparent,
        backgroundColor: cardBaseColor.withValues(alpha: 0.65),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: const BorderSide(color: glassBorder, width: 1.5),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.transparent,
        modalBackgroundColor: Colors.transparent,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0x99080614), 
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: primaryCyan, size: 22),
        titleTextStyle: GoogleFonts.tajawal(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          shadows: [
            Shadow(
              color: primaryCyan.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 0),
            ),
          ],
        ),
        shape: const Border(
          bottom: BorderSide(
            color: Color(0x1F00E5FF), 
            width: 1.2,
          ),
        ),
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.tajawal(color: textPrimary, fontSize: 32, fontWeight: FontWeight.bold),
        displayMedium: GoogleFonts.tajawal(color: textPrimary, fontSize: 24, fontWeight: FontWeight.bold),
        bodyLarge: GoogleFonts.tajawal(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w500),
        bodyMedium: GoogleFonts.tajawal(color: textSecondary, fontSize: 14, fontWeight: FontWeight.w400),
        labelLarge: GoogleFonts.tajawal(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
