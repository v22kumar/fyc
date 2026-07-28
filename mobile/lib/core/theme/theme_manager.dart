import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../storage/secure_storage_helper.dart';

class SemanticColors {
  final Color primary;
  final Color secondary;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;
  final Color background;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color divider;

  SemanticColors({
    required this.primary,
    required this.secondary,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.divider,
  });

  factory SemanticColors.fromJson(Map<String, dynamic> json) {
    Color parseColor(String hexString) {
      final buffer = StringBuffer();
      if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
      buffer.write(hexString.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    }

    return SemanticColors(
      primary: parseColor(json['primary'] ?? '#0F766E'),
      secondary: parseColor(json['secondary'] ?? '#64748B'),
      success: parseColor(json['success'] ?? '#22C55E'),
      warning: parseColor(json['warning'] ?? '#F59E0B'),
      danger: parseColor(json['danger'] ?? '#EF4444'),
      info: parseColor(json['info'] ?? '#3B82F6'),
      background: parseColor(json['background'] ?? '#FFFFFF'),
      surface: parseColor(json['surface'] ?? '#F8FAFC'),
      textPrimary: parseColor(json['textPrimary'] ?? '#111827'),
      textSecondary: parseColor(json['textSecondary'] ?? '#6B7280'),
      border: parseColor(json['border'] ?? '#E5E7EB'),
      divider: parseColor(json['divider'] ?? '#F1F5F9'),
    );
  }

  factory SemanticColors.defaultColors() {
    return SemanticColors.fromJson({
      "primary": "#0F766E",
      "secondary": "#64748B",
      "success": "#22C55E",
      "warning": "#F59E0B",
      "danger": "#EF4444",
      "info": "#3B82F6",
      "background": "#FFFFFF",
      "surface": "#F8FAFC",
      "textPrimary": "#111827",
      "textSecondary": "#6B7280",
      "border": "#E5E7EB",
      "divider": "#F1F5F9"
    });
  }
}

class ThemeManager {
  static final ThemeManager instance = ThemeManager._internal();
  ThemeManager._internal();

  final ValueNotifier<SemanticColors> notifier = ValueNotifier(SemanticColors.defaultColors());
  int _currentVersion = 0;

  SemanticColors get colors => notifier.value;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Load from cache first
    final cachedTheme = prefs.getString('cached_theme_data');
    if (cachedTheme != null) {
      try {
        final decoded = jsonDecode(cachedTheme);
        _currentVersion = decoded['version'] as int? ?? 0;
        if (decoded['colors'] != null) {
          notifier.value = SemanticColors.fromJson(decoded['colors']);
        }
      } catch (e) {
        debugPrint('Failed to parse cached theme: $e');
      }
    }

    // 2. Fetch fresh theme
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
        final newVersion = data['version'] as int? ?? 1;
        
        if (newVersion > _currentVersion || _currentVersion == 0) {
          _currentVersion = newVersion;
          if (data['colors'] != null) {
            notifier.value = SemanticColors.fromJson(data['colors']);
            prefs.setString('cached_theme_data', response.body);
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to fetch theme: $e');
    }
  }

  /// Triggers a refresh (e.g., after login or daily sync)
  void refreshTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _fetchTheme(prefs);
  }
}
