import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Vivid Brand Colors from Brand Guidelines 2025
class VividColors {
  // Primary Colors (Dark Theme Base) - DARKER
  static const Color darkNavy = Color(0xFF020010);      // Main background (almost black)
  static const Color navy = Color(0xFF050520);          // Secondary background
  static const Color deepBlue = Color(0xFF0A1628);      // Cards/panels
  static const Color tealBlue = Color(0xFF054D73);      // Borders/accents (muted)
  static const Color cyanBlue = Color(0xFF065E80);      // Highlights (muted)

  // Accent Colors - MUTED
  static const Color purpleBlue = Color(0xFF1E3A8A);    // Buttons secondary
  static const Color brightBlue = Color(0xFF0550B8);    // Primary actions (darker)
  static const Color cyan = Color(0xFF38BEC9);          // AI status/accents (muted)
  static const Color white = Color(0xFFFFFFFF);

  // Status Colors - slightly muted
  static const Color statusAI = Color(0xFF38BEC9);      // Muted Cyan - AI Active
  static const Color statusHuman = Color(0xFF0550B8);   // Darker Blue - Human Active  
  static const Color statusUrgent = Color(0xFFDC4444);  // Muted Red
  static const Color statusSuccess = Color(0xFF34B869); // Muted Green
  static const Color statusWarning = Color(0xFFD4A528); // Muted Yellow

  // Text Colors
  static const Color textPrimary = Color(0xFFE8ECF4);   // Slightly off-white
  static const Color textSecondary = Color(0xFF8B97B0);
  static const Color textMuted = Color(0xFF4A5568);

  // Message Bubble Colors - DARKER
  static const Color customerBubble = Color(0xFF0A1628);
  static const Color aiBubble = Color(0xFF053D5E);
  static const Color agentBubble = Color(0xFF0550B8);
  static const Color systemBubble = Color(0xFF050520);

  // Gradients - MUTED
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brightBlue, cyan],
  );

  static const LinearGradient darkGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [darkNavy, navy],
  );

  static const LinearGradient logoGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0550B8), Color(0xFF38BEC9)],
  );
}

/// Vivid Theme Configuration
class VividTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: VividColors.brightBlue,
      scaffoldBackgroundColor: VividColors.darkNavy,
      
      // Color Scheme
      colorScheme: const ColorScheme.dark(
        primary: VividColors.brightBlue,
        secondary: VividColors.cyan,
        surface: VividColors.navy,
        background: VividColors.darkNavy,
        error: VividColors.statusUrgent,
        onPrimary: VividColors.darkNavy,
        onSecondary: VividColors.darkNavy,
        onSurface: VividColors.textPrimary,
        onBackground: VividColors.textPrimary,
        onError: VividColors.white,
      ),

      // Typography - Using Poppins
      textTheme: GoogleFonts.poppinsTextTheme(
        const TextTheme(
          displayLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: VividColors.textPrimary,
            letterSpacing: 0.5,
          ),
          displayMedium: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: VividColors.textPrimary,
          ),
          titleLarge: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: VividColors.textPrimary,
          ),
          titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: VividColors.textPrimary,
          ),
          bodyLarge: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.normal,
            color: VividColors.textPrimary,
          ),
          bodyMedium: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.normal,
            color: VividColors.textSecondary,
          ),
          labelLarge: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: VividColors.textPrimary,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // AppBar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: VividColors.navy,
        foregroundColor: VividColors.textPrimary,
        elevation: 0,
        centerTitle: false,
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: VividColors.navy,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: VividColors.tealBlue.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: VividColors.darkNavy,
        hintStyle: const TextStyle(color: VividColors.textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: VividColors.tealBlue.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: VividColors.tealBlue.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: VividColors.cyan, width: 1.5),
        ),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: VividColors.brightBlue,
          foregroundColor: VividColors.darkNavy,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: VividColors.textSecondary,
          side: BorderSide(color: VividColors.tealBlue.withOpacity(0.5)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: VividColors.cyan,
        ),
      ),

      // Divider Theme
      dividerTheme: DividerThemeData(
        color: VividColors.tealBlue.withOpacity(0.2),
        thickness: 1,
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: VividColors.navy,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: VividColors.textPrimary,
        ),
      ),

      // Snackbar Theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: VividColors.deepBlue,
        contentTextStyle: GoogleFonts.poppins(
          color: VividColors.textPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // Icon Theme
      iconTheme: const IconThemeData(
        color: VividColors.textSecondary,
        size: 24,
      ),

      // Popup Menu Theme
      popupMenuTheme: PopupMenuThemeData(
        color: VividColors.navy,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: VividColors.tealBlue.withOpacity(0.3)),
        ),
      ),
    );
  }
}

/// Custom Vivid Widgets
class VividWidgets {
  /// Gradient Container
  static Widget gradientContainer({
    required Widget child,
    double? width,
    double? height,
    EdgeInsets? padding,
    BorderRadius? borderRadius,
  }) {
    return Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        gradient: VividColors.primaryGradient,
        borderRadius: borderRadius ?? BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: VividColors.brightBlue.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  /// Status Badge
  static Widget statusBadge({
    required String label,
    required Color color,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Vivid Icon (for sidebar, dashboard)
  static Widget icon({double size = 44}) {
    return Image.asset(
      'assets/images/vivid_icon.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }

  /// Vivid Full Logo (for login screen)
  static Widget logo({double? width, double? height}) {
    return Image.asset(
      'assets/images/vivid_logo.png',
      width: width,
      height: height,
      fit: BoxFit.contain,
    );
  }
}