import 'package:flutter/widgets.dart' show StringCharacters;

/// Extracts display initials from a name, handling Arabic and other
/// non-Latin scripts via grapheme clusters.
String getInitials(String? name) {
  if (name == null || name.trim().isEmpty) return '?';
  final trimmed = name.trim();
  final parts = trimmed.split(RegExp(r'\s+'));
  if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
    final first = parts[0].characters.first;
    final second = parts[1].characters.first;
    return '$first$second'.toUpperCase();
  }
  // Single name: take first 1-2 grapheme clusters
  final chars = trimmed.characters;
  if (chars.length >= 2) {
    return chars.take(2).toString().toUpperCase();
  }
  return chars.first.toUpperCase();
}

/// Returns true if the string contains Arabic characters.
bool isArabicText(String text) {
  return RegExp(r'[\u0600-\u06FF]').hasMatch(text);
}
