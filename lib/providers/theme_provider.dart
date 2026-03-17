import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;
  bool _sidebarExpanded = true;

  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;
  bool get sidebarExpanded => _sidebarExpanded;

  ThemeProvider() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final isDarkStored = prefs.getBool('isDarkMode') ?? true;
    _themeMode = isDarkStored ? ThemeMode.dark : ThemeMode.light;
    _sidebarExpanded = prefs.getBool('sidebarExpanded') ?? true;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _themeMode = isDark ? ThemeMode.light : ThemeMode.dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDark);
    notifyListeners();
  }

  Future<void> toggleSidebar() async {
    _sidebarExpanded = !_sidebarExpanded;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sidebarExpanded', _sidebarExpanded);
    notifyListeners();
  }
}
