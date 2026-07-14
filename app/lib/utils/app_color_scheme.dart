import 'package:flutter/material.dart';

/// All color tokens for a single theme.
/// To add a new theme, create another AppColorScheme instance in AppThemes.
class AppColorScheme {
  final String id;
  final String name;

  // Page / scaffold
  final Color background;

  // Primary palette
  final Color primaryYellow;
  final Color darkYellow;
  final Color navigationYellow;

  // Accent palette (used for stat cards, section colors, etc.)
  final Color accentGreen;
  final Color accentPink;
  final Color accentPurple;
  final Color accentBlue;
  final Color lightBlue;

  // Navigation
  final Color navigationBlue;

  // Misc interactive
  final Color tagPurple;
  final Color showAllButton;

  // Text
  final Color textPrimary;
  final Color textSecondary;

  // Borders & shadows (neo-brutalism outlines)
  final Color border;
  final Color shadow;

  const AppColorScheme({
    required this.id,
    required this.name,
    required this.background,
    required this.primaryYellow,
    required this.darkYellow,
    required this.navigationYellow,
    required this.accentGreen,
    required this.accentPink,
    required this.accentPurple,
    required this.accentBlue,
    required this.lightBlue,
    required this.navigationBlue,
    required this.tagPurple,
    required this.showAllButton,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.shadow,
  });
}

/// All available themes. To add a new theme:
///   1. Define a new AppColorScheme constant below.
///   2. Add it to the [all] list.
///   That's it — the settings picker will show it automatically.
class AppThemes {
  AppThemes._();

  static const yellow = AppColorScheme(
    id: 'yellow',
    name: 'Yellow',
    background: Color(0xFFFEEEC3),
    primaryYellow: Color(0xFFFFD966),
    darkYellow: Color(0xFFFCD150),
    navigationYellow: Color(0xFFFED966),
    accentGreen: Color(0xFFD2FFB6),
    accentPink: Color(0xFFFFC0B6),
    accentPurple: Color(0xFFE3B6FF),
    accentBlue: Color(0xFFB6EAFF),
    lightBlue: Color(0xFFC8EBFF),
    navigationBlue: Color(0xFFB4E4FF),
    tagPurple: Color(0xFF9191FF),
    showAllButton: Color(0xFFFFB6B6),
    textPrimary: Colors.black,
    textSecondary: Color(0xFF191C1E),
    border: Colors.black,
    shadow: Colors.black,
  );

  static const mint = AppColorScheme(
    id: 'mint',
    name: 'Mint',
    background: Color(0xFFE6FAF0),
    primaryYellow: Color(0xFF7EE8A2),
    darkYellow: Color(0xFF5FD68A),
    navigationYellow: Color(0xFF7EE8A2),
    accentGreen: Color(0xFFB6FFD6),
    accentPink: Color(0xFFFFB6D9),
    accentPurple: Color(0xFFD4B6FF),
    accentBlue: Color(0xFFB6E4FF),
    lightBlue: Color(0xFFC8F0FF),
    navigationBlue: Color(0xFFB4F0D4),
    tagPurple: Color(0xFF6B6BFF),
    showAllButton: Color(0xFFFFB6CC),
    textPrimary: Colors.black,
    textSecondary: Color(0xFF191C1E),
    border: Colors.black,
    shadow: Colors.black,
  );

  static const lavender = AppColorScheme(
    id: 'lavender',
    name: 'Lavender',
    background: Color(0xFFF0ECFF),
    primaryYellow: Color(0xFFBFB0FF),
    darkYellow: Color(0xFFA899FF),
    navigationYellow: Color(0xFFBFB0FF),
    accentGreen: Color(0xFFB6FFD9),
    accentPink: Color(0xFFFFB6DE),
    accentPurple: Color(0xFFD9B6FF),
    accentBlue: Color(0xFFB6D4FF),
    lightBlue: Color(0xFFC8DBFF),
    navigationBlue: Color(0xFFC0B0FF),
    tagPurple: Color(0xFF7B5FFF),
    showAllButton: Color(0xFFFFB6CC),
    textPrimary: Colors.black,
    textSecondary: Color(0xFF191C1E),
    border: Colors.black,
    shadow: Colors.black,
  );

  /// All themes available in the app. Extend this list to add more.
  static const List<AppColorScheme> all = [yellow, mint, lavender];

  static AppColorScheme fromId(String id) =>
      all.firstWhere((t) => t.id == id, orElse: () => yellow);
}
