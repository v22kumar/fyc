import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../storage/secure_storage_helper.dart';

Color _parseColor(String? hexString, String defaultHex) {
  final hex = hexString ?? defaultHex;
  final buffer = StringBuffer();
  if (hex.length == 6 || hex.length == 7) buffer.write('ff');
  buffer.write(hex.replaceFirst('#', ''));
  return Color(int.parse(buffer.toString(), radix: 16));
}

class SemanticColors {
  final Color primary;
  final Color primaryContainer;
  final Color secondary;
  final Color secondaryContainer;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;
  final Color border;
  final Color divider;

  SemanticColors({
    required this.primary,
    required this.primaryContainer,
    required this.secondary,
    required this.secondaryContainer,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.border,
    required this.divider,
  });

  factory SemanticColors.fromJson(Map<String, dynamic> json) {
    return SemanticColors(
      primary: _parseColor(json['primary'], '#0F766E'),
      primaryContainer: _parseColor(json['primaryContainer'], '#CCFBF1'),
      secondary: _parseColor(json['secondary'], '#64748B'),
      secondaryContainer: _parseColor(json['secondaryContainer'], '#E2E8F0'),
      success: _parseColor(json['success'], '#22C55E'),
      warning: _parseColor(json['warning'], '#F59E0B'),
      danger: _parseColor(json['danger'], '#EF4444'),
      info: _parseColor(json['info'], '#3B82F6'),
      background: _parseColor(json['background'], '#FFFFFF'),
      surface: _parseColor(json['surface'], '#F8FAFC'),
      surfaceVariant: _parseColor(json['surfaceVariant'], '#F1F5F9'),
      textPrimary: _parseColor(json['textPrimary'], '#111827'),
      textSecondary: _parseColor(json['textSecondary'], '#6B7280'),
      textDisabled: _parseColor(json['textDisabled'], '#9CA3AF'),
      border: _parseColor(json['border'], '#E5E7EB'),
      divider: _parseColor(json['divider'], '#F1F5F9'),
    );
  }
}

class FeatureColors {
  final Color bloodDonation;
  final Color sports;
  final Color education;
  final Color jobs;
  final Color events;
  final Color volunteer;
  final Color health;
  final Color government;

  FeatureColors({
    required this.bloodDonation,
    required this.sports,
    required this.education,
    required this.jobs,
    required this.events,
    required this.volunteer,
    required this.health,
    required this.government,
  });

  factory FeatureColors.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return FeatureColors(
        bloodDonation: _parseColor(null, '#DC2626'),
        sports: _parseColor(null, '#2563EB'),
        education: _parseColor(null, '#7C3AED'),
        jobs: _parseColor(null, '#059669'),
        events: _parseColor(null, '#EA580C'),
        volunteer: _parseColor(null, '#0EA5E9'),
        health: _parseColor(null, '#EC4899'),
        government: _parseColor(null, '#475569'),
      );
    }
    return FeatureColors(
      bloodDonation: _parseColor(json['bloodDonation'], '#DC2626'),
      sports: _parseColor(json['sports'], '#2563EB'),
      education: _parseColor(json['education'], '#7C3AED'),
      jobs: _parseColor(json['jobs'], '#059669'),
      events: _parseColor(json['events'], '#EA580C'),
      volunteer: _parseColor(json['volunteer'], '#0EA5E9'),
      health: _parseColor(json['health'], '#EC4899'),
      government: _parseColor(json['government'], '#475569'),
    );
  }
}

class RadiusTokens {
  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;

  RadiusTokens({required this.xs, required this.sm, required this.md, required this.lg, required this.xl});

  factory RadiusTokens.fromJson(Map<String, dynamic>? json) {
    if (json == null) return RadiusTokens(xs: 6, sm: 10, md: 14, lg: 18, xl: 24);
    return RadiusTokens(
      xs: (json['xs'] ?? 6).toDouble(),
      sm: (json['sm'] ?? 10).toDouble(),
      md: (json['md'] ?? 14).toDouble(),
      lg: (json['lg'] ?? 18).toDouble(),
      xl: (json['xl'] ?? 24).toDouble(),
    );
  }
}

class SpacingTokens {
  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;

  SpacingTokens({required this.xs, required this.sm, required this.md, required this.lg, required this.xl});

  factory SpacingTokens.fromJson(Map<String, dynamic>? json) {
    if (json == null) return SpacingTokens(xs: 4, sm: 8, md: 16, lg: 24, xl: 32);
    return SpacingTokens(
      xs: (json['xs'] ?? 4).toDouble(),
      sm: (json['sm'] ?? 8).toDouble(),
      md: (json['md'] ?? 16).toDouble(),
      lg: (json['lg'] ?? 24).toDouble(),
      xl: (json['xl'] ?? 32).toDouble(),
    );
  }
}

class TypographyTokens {
  final String fontFamily;
  final FontWeight headlineWeight;
  final FontWeight titleWeight;
  final FontWeight bodyWeight;

  TypographyTokens({
    required this.fontFamily,
    required this.headlineWeight,
    required this.titleWeight,
    required this.bodyWeight,
  });

  static FontWeight _parseWeight(int? weight, FontWeight defaultWeight) {
    if (weight == null) return defaultWeight;
    return FontWeight.values.firstWhere(
      (w) => w.value == weight,
      orElse: () => defaultWeight,
    );
  }

  factory TypographyTokens.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return TypographyTokens(
        fontFamily: 'Inter',
        headlineWeight: FontWeight.w700,
        titleWeight: FontWeight.w600,
        bodyWeight: FontWeight.w400,
      );
    }
    return TypographyTokens(
      fontFamily: json['fontFamily'] ?? 'Inter',
      headlineWeight: _parseWeight(json['headlineWeight'], FontWeight.w700),
      titleWeight: _parseWeight(json['titleWeight'], FontWeight.w600),
      bodyWeight: _parseWeight(json['bodyWeight'], FontWeight.w400),
    );
  }
}

class ComponentTokens {
  final Map<String, dynamic> raw;
  ComponentTokens(this.raw);

  factory ComponentTokens.fromJson(Map<String, dynamic>? json) {
    return ComponentTokens(json ?? {});
  }
  
  // Helpers could be added here later, e.g., getButtonRadius()
}

class DesignTokens {
  final SemanticColors colors;
  final FeatureColors featureColors;
  final RadiusTokens radius;
  final SpacingTokens spacing;
  final TypographyTokens typography;
  final ComponentTokens components;

  DesignTokens({
    required this.colors,
    required this.featureColors,
    required this.radius,
    required this.spacing,
    required this.typography,
    required this.components,
  });

  factory DesignTokens.fromJson(Map<String, dynamic> json) {
    return DesignTokens(
      colors: SemanticColors.fromJson(json['colors'] ?? {}),
      featureColors: FeatureColors.fromJson(json['featureColors']),
      radius: RadiusTokens.fromJson(json['radius']),
      spacing: SpacingTokens.fromJson(json['spacing']),
      typography: TypographyTokens.fromJson(json['typography']),
      components: ComponentTokens.fromJson(json['components']),
    );
  }

  factory DesignTokens.defaultTokens() {
    return DesignTokens.fromJson({}); // Uses all fallback values
  }
}

class ThemeManager {
  static final ThemeManager instance = ThemeManager._internal();
  ThemeManager._internal();

  final ValueNotifier<DesignTokens> notifier = ValueNotifier(DesignTokens.defaultTokens());
  int _currentVersion = 0;

  DesignTokens get tokens => notifier.value;

  // For backwards compatibility during transition
  SemanticColors get colors => notifier.value.colors;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    
    final cachedTheme = prefs.getString('cached_theme_data');
    if (cachedTheme != null) {
      try {
        final decoded = jsonDecode(cachedTheme);
        final meta = decoded['meta'] ?? {};
        // Fallback to legacy structure version if meta missing
        _currentVersion = meta['version'] as int? ?? decoded['version'] as int? ?? 0; 
        notifier.value = DesignTokens.fromJson(decoded);
      } catch (e) {
        debugPrint('Failed to parse cached theme: $e');
      }
    }

    _fetchTheme(prefs);
  }

  Future<void> _fetchTheme(SharedPreferences prefs) async {
    try {
      final token = await SecureStorageHelper.getToken();
      final headers = {
        'Content-Type': 'application/json',
        'X-Organization-ID': ApiConstants.organizationId,
      };
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final url = Uri.parse('${ApiConstants.baseUrl}/api/v1/theme');
      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final meta = data['meta'] ?? {};
        final newVersion = meta['version'] as int? ?? data['version'] as int? ?? 1;
        
        if (newVersion > _currentVersion || _currentVersion == 0) {
          _currentVersion = newVersion;
          notifier.value = DesignTokens.fromJson(data);
          prefs.setString('cached_theme_data', response.body);
        }
      }
    } catch (e) {
      debugPrint('Failed to fetch theme: $e');
    }
  }

  void refreshTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _fetchTheme(prefs);
  }
}
