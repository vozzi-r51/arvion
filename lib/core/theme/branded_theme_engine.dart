import 'package:flutter/material.dart';

/// Config-Driven White-Label / Multi-Brand Engine.
/// Allows customization of colors, typography, border radii, and logo branding.
class BrandConfig {
  final String appName;
  final String logoAsset;
  final Color primaryColor;
  final Color secondaryColor;
  final Color surfaceColor;
  final String fontFamily;
  final double borderRadius;

  const BrandConfig({
    required this.appName,
    required this.logoAsset,
    required this.primaryColor,
    required this.secondaryColor,
    required this.surfaceColor,
    this.fontFamily = 'Inter',
    this.borderRadius = 12.0,
  });

  /// Default ARVION Brand Preset.
  static const arvionDefault = BrandConfig(
    appName: 'ARVION ERP',
    logoAsset: 'assets/logo.png',
    primaryColor: Color(0xFF1E3A8A), // Deep Royal Navy
    secondaryColor: Color(0xFF0D9488), // Teal Accent
    surfaceColor: Color(0xFFF8FAFC),
  );

  /// Enterprise Dark Emerald Preset.
  static const enterpriseEmerald = BrandConfig(
    appName: 'DukanEdge Enterprise',
    logoAsset: 'assets/logo_enterprise.png',
    primaryColor: Color(0xFF065F46), // Emerald
    secondaryColor: Color(0xFFD97706), // Amber
    surfaceColor: Color(0xFFF0FDF4),
  );
}

class BrandedThemeEngine {
  final BrandConfig config;

  BrandedThemeEngine({this.config = BrandConfig.arvionDefault});

  /// Generates full Light ThemeData from BrandConfig.
  ThemeData buildLightTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: config.primaryColor,
      primary: config.primaryColor,
      secondary: config.secondaryColor,
      surface: config.surfaceColor,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: config.fontFamily,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(config.borderRadius),
          side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(config.borderRadius),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
      ),
    );
  }

  /// Generates full Dark ThemeData from BrandConfig.
  ThemeData buildDarkTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: config.primaryColor,
      primary: config.primaryColor,
      secondary: config.secondaryColor,
      surface: const Color(0xFF0F172A),
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: config.fontFamily,
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(config.borderRadius),
          side: const BorderSide(color: Colors.white10),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E293B),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(config.borderRadius),
          borderSide: const BorderSide(color: Colors.white24),
        ),
      ),
    );
  }
}
