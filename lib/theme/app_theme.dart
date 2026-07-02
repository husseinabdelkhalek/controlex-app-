import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static final ValueNotifier<String> themeNotifier = ValueNotifier<String>('dark');

  // --- Semantic Colors (Psychological Meaning) ---
  static Color semanticSuccess = const Color(0xFF10B981); // Emerald Green
  static Color semanticError = const Color(0xFFEF4444);   // Soft Red
  static Color semanticWarning = const Color(0xFFF59E0B); // Amber
  static Color semanticInfo = const Color(0xFF3B82F6);    // Blue

  // --- Premium Brand Colors (Website Match) ---
  static Color primaryBrand = const Color(0xFF8A2BE2); // Primary Violet
  static Color secondaryBrand = const Color(0xFF00E5FF); // Primary Cyan

  // --- Backgrounds & Surfaces (Website Match) ---
  static Color backgroundBase = const Color(0xFF0D0C1D); 
  static Color darkBackground = const Color(0xFF0D0C1D); 
  
  // Vibrant Neon Accents (Aliases for backward compatibility)
  static Color primaryCyan = secondaryBrand; 
  static Color darkCyan = const Color(0xFF00ACC1); 
  static Color primaryViolet = primaryBrand; 
  static Color darkViolet = const Color(0xFF6A1B9A); 
  
  // Legacy Accents
  static Color accentNeon = semanticError; 
  static Color neonBlue = primaryBrand;   
  
  // Glassmorphism enhancements
  static Color cardBaseColor = const Color(0xD915132C); // #15132c with 85% opacity
  static Color cardLightColor = const Color(0xFFE2E8F0); 
  
  // Glows and Borders
  static Color glassBorder = const Color(0x4D8A2BE2); // 30% Violet
  static Color glowColor = const Color(0x6600E5FF); // Cyan Glow
  static Color violetGlow = const Color(0x808A2BE2); // Violet Glow
  
  // Texts
  static Color textPrimary = const Color(0xFFF0F8FF); // Snow white
  static Color textSecondary = const Color(0xFFA9A2C8); // Faded violet

  static void switchTheme(String themeName) {
    if (themeName == 'glass') {
      backgroundBase = const Color(0x800D0C1D); 
      darkBackground = const Color(0x800D0C1D);
      cardBaseColor = const Color(0x3315132C); 
      glassBorder = const Color(0x998A2BE2);
      glowColor = const Color(0x9900E5FF);
    } else {
      backgroundBase = const Color(0xFF0D0C1D); 
      darkBackground = const Color(0xFF0D0C1D);
      cardBaseColor = const Color(0xD915132C); 
      glassBorder = const Color(0x4D8A2BE2);
      glowColor = const Color(0x6600E5FF);
    }
    themeNotifier.value = themeName;
  }

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
          side: BorderSide(color: glassBorder, width: 1.5),
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
        iconTheme: IconThemeData(color: primaryCyan, size: 22),
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
