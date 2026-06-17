import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Deep Dark Backgrounds (Softer, less harsh)
  static const Color backgroundBase = Color(0xFF07051A); // Slightly softer deep background
  static const Color darkBackground = Color(0xFF0F0C29); 
  
  // Vibrant Neon Accents (Refined)
  static const Color primaryCyan = Color(0xFF00E5FF); // Smoother Cyan
  static const Color primaryViolet = Color(0xFF9D4EDD); // Softer Violet
  static const Color accentNeon = Color(0xFFFF007F); // Neon Pink
  static const Color neonBlue = Color(0xFF3A0CA3);   // Deep Electric Blue

  // Glassmorphism enhancements
  static const Color cardBaseColor = Color(0x1AFFFFFF); // Slightly more visible glass
  static const Color glassBorder = Color(0x33FFFFFF);
  static const Color glowColor = Color(0x6600E5FF);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: primaryCyan,
      scaffoldBackgroundColor: darkBackground,
      fontFamily: GoogleFonts.outfit().fontFamily, // Switch to Outfit for a rounded, modern look
      dialogTheme: DialogTheme(
        surfaceTintColor: Colors.transparent,
        backgroundColor: darkBackground.withOpacity(0.9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.transparent,
        modalBackgroundColor: Colors.transparent,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: primaryCyan),
        titleTextStyle: GoogleFonts.outfit(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.outfit(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
        bodyLarge: GoogleFonts.outfit(color: Colors.white70, fontSize: 16),
        bodyMedium: GoogleFonts.outfit(color: Colors.white54, fontSize: 14),
        labelLarge: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
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

