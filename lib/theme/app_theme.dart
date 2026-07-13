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
  static Color primaryBrand = const Color(0xFF6366F1); // Slate Indigo
  static Color secondaryBrand = const Color(0xFF0EA5E9); // Sky Blue

  // --- Backgrounds & Surfaces (Touch of Purple) ---
  static Color backgroundBase = const Color(0xFF161122); // Deep Purple Dark
  static Color darkBackground = const Color(0xFF161122);
  
  // Vibrant Neon Accents (Aliases for backward compatibility)
  static Color primaryCyan = secondaryBrand; 
  static Color darkCyan = const Color(0xFF0284C7); 
  static Color primaryViolet = primaryBrand; 
  static Color darkViolet = const Color(0xFF4338CA); 
  
  // Legacy Accents
  static Color accentNeon = semanticError; 
  static Color neonBlue = primaryBrand;   
  
  // Glassmorphism enhancements
  static Color cardBaseColor = const Color(0xD91F182B); // Premium deep purple surface with 85% opacity
  static Color cardLightColor = const Color(0xFFE2E8F0); 
  
  // Glows and Borders
  static Color glassBorder = const Color(0x33C7A5FF); // Soft Klivvr Purple Border (20%)
  static Color glowColor = const Color(0x2D0EA5E9); // Soft Sky Glow
  static Color violetGlow = const Color(0x2DC7A5FF); // Soft Purple Glow
  
  // Texts
  static Color textPrimary = const Color(0xFFF8FAFC); // Slate 50
  static Color textSecondary = const Color(0xFF94A3B8); // Slate 400

  static void switchTheme(String themeName) {
    if (themeName == 'glass') {
      backgroundBase = const Color(0x80090A0F); 
      darkBackground = const Color(0x80090A0F);
      cardBaseColor = const Color(0x33131722); 
      glassBorder = const Color(0x736366F1);
      glowColor = const Color(0x660EA5E9);
    } else {
      backgroundBase = const Color(0xFF090A0F); 
      darkBackground = const Color(0xFF090A0F);
      cardBaseColor = const Color(0xD9131722); 
      glassBorder = const Color(0x336366F1);
      glowColor = const Color(0x2D0EA5E9);
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
          resolvedColor.withValues(alpha: 0.85),
          resolvedColor.withValues(alpha: 0.60),
        ],
      ),
      borderRadius: borderRadius ?? const BorderRadius.vertical(top: Radius.circular(24)),
      border: Border.all(
        color: borderColor ?? glassBorder,
        width: 1.5,
      ),
    );
  }

  // --- Centralized Premium Input Decoration ---
  static InputDecoration inputDecoration({
    required String labelText,
    String? hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: TextStyle(color: textSecondary, fontSize: 13),
      hintText: hintText,
      hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
      prefixIcon: Icon(prefixIcon, color: primaryCyan, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: cardBaseColor.withValues(alpha: 0.95), // Blocks the background grid completely!
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: glassBorder.withValues(alpha: 0.3), width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: primaryCyan, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: primaryCyan,
      scaffoldBackgroundColor: darkBackground,
      fontFamily: GoogleFonts.tajawal().fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryCyan,
        brightness: Brightness.dark,
        primary: primaryCyan,
        secondary: primaryViolet,
        surface: cardBaseColor,
        background: darkBackground,
      ),
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      focusColor: Colors.transparent,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBrand,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.tajawal(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryCyan,
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          side: BorderSide(color: glassBorder, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.tajawal(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryCyan,
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          textStyle: GoogleFonts.tajawal(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      tabBarTheme: const TabBarTheme(
        overlayColor: WidgetStatePropertyAll(Colors.transparent),
      ),
      dialogTheme: DialogTheme(
        surfaceTintColor: Colors.transparent,
        backgroundColor: cardBaseColor.withValues(alpha: 0.8),
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
        backgroundColor: const Color(0x9905070D), 
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
        shape: Border(
          bottom: BorderSide(
            color: glassBorder.withValues(alpha: 0.3), 
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
