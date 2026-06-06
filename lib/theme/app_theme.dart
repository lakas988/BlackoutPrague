import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const background = Color(0xFF0B0F14);
  static const secondaryBackground = Color(0xFF121821);
  static const card = Color(0xFF1A2230);
  static const primary = Color(0xFF00D1FF);
  static const primaryLight = Color(0xFF5CE7FF);
  static const emergencyRed = Color(0xFFFF1F1F);
  static const darkEmergencyRed = Color(0xFFB00020);
  static const softRedBackground = Color(0xFF3A1114);
  static const warningOrange = Color(0xFFFF9F43);
  static const safeGreen = Color(0xFF2ED573);
  static const textPrimary = Color(0xFFF4F8FB);
  static const textSecondary = Color(0xFFC7D0DC);
  static const border = Color(0xFF263445);
}

class AppTheme {
  const AppTheme._();

  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.primary,
      secondary: AppColors.primaryLight,
      error: AppColors.emergencyRed,
      surface: AppColors.card,
      onPrimary: AppColors.background,
      onSecondary: AppColors.background,
      onSurface: AppColors.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        centerTitle: false,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.card,
        indicatorColor: AppColors.primary.withValues(alpha: 0.18),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected) ? AppColors.primaryLight : AppColors.textSecondary,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        filled: true,
        fillColor: AppColors.secondaryBackground,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.background,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryLight,
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primaryLight),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? AppColors.primary : AppColors.secondaryBackground,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? AppColors.background : AppColors.textPrimary,
          ),
          side: WidgetStateProperty.all(const BorderSide(color: AppColors.border)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.primary : AppColors.textSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primary.withValues(alpha: 0.35)
              : AppColors.secondaryBackground,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.secondaryBackground,
        selectedColor: AppColors.primary.withValues(alpha: 0.22),
        side: const BorderSide(color: AppColors.border),
        labelStyle: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.card,
        contentTextStyle: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border),
      listTileTheme: const ListTileThemeData(iconColor: AppColors.primaryLight),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.primary),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textPrimary),
        titleLarge: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        titleMedium: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        bodyLarge: TextStyle(height: 1.35, color: AppColors.textPrimary),
        bodyMedium: TextStyle(height: 1.35, color: AppColors.textSecondary),
        bodySmall: TextStyle(height: 1.35, color: AppColors.textSecondary),
      ),
    );
  }
}
