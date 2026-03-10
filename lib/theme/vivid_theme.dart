import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Vivid Brand Colors — static constants for theme-agnostic colors
/// For themed colors (that change between light/dark), use context.vividColors
class VividColors {
  // Primary Colors (Dark Theme Base) — used for sidebar (always dark)
  static const Color darkNavy = Color(0xFF020010);      // Sidebar bg
  static const Color navy = Color(0xFF050520);           // Sidebar secondary
  static const Color deepBlue = Color(0xFF0A1628);       // Sidebar cards
  static const Color tealBlue = Color(0xFF054D73);       // Sidebar borders
  static const Color cyanBlue = Color(0xFF065E80);       // Sidebar highlights

  // Accent Colors — same in both themes
  static const Color purpleBlue = Color(0xFF1E3A8A);    // Buttons secondary
  static const Color brightBlue = Color(0xFF0550B8);    // Primary actions
  static const Color cyan = Color(0xFF38BEC9);          // AI status/accents
  static const Color white = Color(0xFFFFFFFF);

  // Status Colors — same in both themes
  static const Color statusAI = Color(0xFF38BEC9);      // Cyan - AI Active
  static const Color statusHuman = Color(0xFF0550B8);   // Blue - Human Active
  static const Color statusUrgent = Color(0xFFDC4444);  // Red
  static const Color statusSuccess = Color(0xFF34B869); // Green
  static const Color statusWarning = Color(0xFFD4A528); // Yellow

  // Legacy text colors — kept for sidebar (always dark) usage
  static const Color textPrimary = Color(0xFFE8ECF4);
  static const Color textSecondary = Color(0xFF8B97B0);
  static const Color textMuted = Color(0xFF4A5568);

  // Legacy bubble colors — kept for reference
  static const Color customerBubble = Color(0xFF0A1628);
  static const Color aiBubble = Color(0xFF053D5E);
  static const Color agentBubble = Color(0xFF0550B8);
  static const Color systemBubble = Color(0xFF050520);

  // Gradients
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

// ============================================
// THEMED COLOR SCHEME (ThemeExtension)
// ============================================

/// Colors that change between light and dark mode.
/// Access via context.vividColors
class VividColorScheme extends ThemeExtension<VividColorScheme> {
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color borderSubtle;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color customerBubble;
  final Color aiBubble;
  final Color agentBubble;
  final Color systemBubble;
  final Color agentBubbleText;
  final Color inputFill;
  final Color highlight;
  final Color popupBg;
  final Color popupBorder;
  final Color shadow;

  const VividColorScheme({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.borderSubtle,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.customerBubble,
    required this.aiBubble,
    required this.agentBubble,
    required this.systemBubble,
    required this.agentBubbleText,
    required this.inputFill,
    required this.highlight,
    required this.popupBg,
    required this.popupBorder,
    required this.shadow,
  });

  factory VividColorScheme.dark() => const VividColorScheme(
    background: Color(0xFF020010),
    surface: Color(0xFF050520),
    surfaceAlt: Color(0xFF0A1628),
    border: Color(0x33054D73),       // tealBlue @ 0.2
    borderSubtle: Color(0x1A054D73), // tealBlue @ 0.1
    textPrimary: Color(0xFFE8ECF4),
    textSecondary: Color(0xFF8B97B0),
    textMuted: Color(0xFF4A5568),
    customerBubble: Color(0xFF0A1628),
    aiBubble: Color(0xFF053D5E),
    agentBubble: Color(0xFF0550B8),
    systemBubble: Color(0xFF050520),
    agentBubbleText: Color(0xFFFFFFFF),
    inputFill: Color(0xFF020010),
    highlight: Color(0xFF065E80),
    popupBg: Color(0xFF050520),
    popupBorder: Color(0x4D054D73), // tealBlue @ 0.3
    shadow: Colors.transparent,
  );

  factory VividColorScheme.light() => const VividColorScheme(
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFF8FAFC),
    surfaceAlt: Color(0xFFF1F5F9),
    border: Color(0xFFCBD5E1),
    borderSubtle: Color(0xFFE2E8F0),
    textPrimary: Color(0xFF1E293B),
    textSecondary: Color(0xFF475569),
    textMuted: Color(0xFF94A3B8),
    customerBubble: Color(0xFFF1F5F9),
    aiBubble: Color(0xFFE0F2FE),
    agentBubble: Color(0xFFDBEAFE),
    systemBubble: Color(0xFFF1F5F9),
    agentBubbleText: Color(0xFFFFFFFF),
    inputFill: Color(0xFFFFFFFF),
    highlight: Color(0xFF0550B8),
    popupBg: Color(0xFFFFFFFF),
    popupBorder: Color(0xFFE2E8F0),
    shadow: Color(0x0D000000), // black @ 0.05
  );

  @override
  VividColorScheme copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? border,
    Color? borderSubtle,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? customerBubble,
    Color? aiBubble,
    Color? agentBubble,
    Color? systemBubble,
    Color? agentBubbleText,
    Color? inputFill,
    Color? highlight,
    Color? popupBg,
    Color? popupBorder,
    Color? shadow,
  }) {
    return VividColorScheme(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      border: border ?? this.border,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      customerBubble: customerBubble ?? this.customerBubble,
      aiBubble: aiBubble ?? this.aiBubble,
      agentBubble: agentBubble ?? this.agentBubble,
      systemBubble: systemBubble ?? this.systemBubble,
      agentBubbleText: agentBubbleText ?? this.agentBubbleText,
      inputFill: inputFill ?? this.inputFill,
      highlight: highlight ?? this.highlight,
      popupBg: popupBg ?? this.popupBg,
      popupBorder: popupBorder ?? this.popupBorder,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  VividColorScheme lerp(covariant VividColorScheme? other, double t) {
    if (other == null) return this;
    return VividColorScheme(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      customerBubble: Color.lerp(customerBubble, other.customerBubble, t)!,
      aiBubble: Color.lerp(aiBubble, other.aiBubble, t)!,
      agentBubble: Color.lerp(agentBubble, other.agentBubble, t)!,
      systemBubble: Color.lerp(systemBubble, other.systemBubble, t)!,
      agentBubbleText: Color.lerp(agentBubbleText, other.agentBubbleText, t)!,
      inputFill: Color.lerp(inputFill, other.inputFill, t)!,
      highlight: Color.lerp(highlight, other.highlight, t)!,
      popupBg: Color.lerp(popupBg, other.popupBg, t)!,
      popupBorder: Color.lerp(popupBorder, other.popupBorder, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

/// Convenience extension to access themed colors from BuildContext
extension VividColorSchemeExt on BuildContext {
  VividColorScheme get vividColors => Theme.of(this).extension<VividColorScheme>()!;
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}

// ============================================
// THEME DATA
// ============================================

/// Vivid Theme Configuration
class VividTheme {
  static ThemeData get darkTheme {
    const vc = VividColorScheme(
      background: Color(0xFF020010),
      surface: Color(0xFF050520),
      surfaceAlt: Color(0xFF0A1628),
      border: Color(0x33054D73),
      borderSubtle: Color(0x1A054D73),
      textPrimary: Color(0xFFE8ECF4),
      textSecondary: Color(0xFF8B97B0),
      textMuted: Color(0xFF4A5568),
      customerBubble: Color(0xFF0A1628),
      aiBubble: Color(0xFF053D5E),
      agentBubble: Color(0xFF0550B8),
      systemBubble: Color(0xFF050520),
      agentBubbleText: Color(0xFFFFFFFF),
      inputFill: Color(0xFF020010),
      highlight: Color(0xFF065E80),
      popupBg: Color(0xFF050520),
      popupBorder: Color(0x4D054D73),
      shadow: Colors.transparent,
    );

    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: VividColors.brightBlue,
      scaffoldBackgroundColor: VividColors.darkNavy,
      extensions: const [vc],

      // Color Scheme
      colorScheme: const ColorScheme.dark(
        primary: VividColors.brightBlue,
        secondary: VividColors.cyan,
        surface: VividColors.navy,
        error: VividColors.statusUrgent,
        onPrimary: VividColors.darkNavy,
        onSecondary: VividColors.darkNavy,
        onSurface: VividColors.textPrimary,
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

  static ThemeData get lightTheme {
    const lightText = Color(0xFF1E293B);
    const lightTextSecondary = Color(0xFF475569);
    const lightTextMuted = Color(0xFF94A3B8);
    const lightSurface = Color(0xFFF8FAFC);
    const lightBorder = Color(0xFFCBD5E1);

    const vc = VividColorScheme(
      background: Color(0xFFFFFFFF),
      surface: lightSurface,
      surfaceAlt: Color(0xFFF1F5F9),
      border: lightBorder,
      borderSubtle: Color(0xFFE2E8F0),
      textPrimary: lightText,
      textSecondary: lightTextSecondary,
      textMuted: lightTextMuted,
      customerBubble: Color(0xFFF1F5F9),
      aiBubble: Color(0xFFE0F2FE),
      agentBubble: Color(0xFFDBEAFE),
      systemBubble: Color(0xFFF1F5F9),
      agentBubbleText: Color(0xFFFFFFFF),
      inputFill: Color(0xFFFFFFFF),
      highlight: Color(0xFF0550B8),
      popupBg: Color(0xFFFFFFFF),
      popupBorder: Color(0xFFE2E8F0),
      shadow: Color(0x0D000000),
    );

    return ThemeData(
      brightness: Brightness.light,
      primaryColor: VividColors.brightBlue,
      scaffoldBackgroundColor: Colors.white,
      extensions: const [vc],

      // Color Scheme
      colorScheme: const ColorScheme.light(
        primary: VividColors.brightBlue,
        secondary: VividColors.cyan,
        surface: lightSurface,
        error: VividColors.statusUrgent,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: lightText,
        onError: Colors.white,
      ),

      // Typography
      textTheme: GoogleFonts.poppinsTextTheme(
        const TextTheme(
          displayLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: lightText,
            letterSpacing: 0.5,
          ),
          displayMedium: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: lightText,
          ),
          titleLarge: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: lightText,
          ),
          titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: lightText,
          ),
          bodyLarge: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.normal,
            color: lightText,
          ),
          bodyMedium: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.normal,
            color: lightTextSecondary,
          ),
          labelLarge: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: lightText,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // AppBar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: lightSurface,
        foregroundColor: lightText,
        elevation: 0,
        centerTitle: false,
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: lightBorder, width: 1),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: const TextStyle(color: lightTextMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: VividColors.brightBlue, width: 1.5),
        ),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: VividColors.brightBlue,
          foregroundColor: Colors.white,
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
          foregroundColor: lightTextSecondary,
          side: const BorderSide(color: lightBorder),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: VividColors.brightBlue,
        ),
      ),

      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: lightBorder,
        thickness: 1,
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: lightText,
        ),
      ),

      // Snackbar Theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1E293B),
        contentTextStyle: GoogleFonts.poppins(
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // Icon Theme
      iconTheme: const IconThemeData(
        color: lightTextSecondary,
        size: 24,
      ),

      // Popup Menu Theme
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: lightBorder),
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
