import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../../../service_locator.dart';

/// Current weather card for Nagercoil shown on the home screen.
///
/// Uses a hardcoded default location (Nagercoil, Tamil Nadu) so no GPS
/// permission is needed. Data is fetched from the backend proxy which
/// caches responses for 30 minutes.
///
/// Non-critical: loading errors render a graceful "unavailable" message
/// rather than crashing the home screen.
class WeatherCard extends StatefulWidget {
  const WeatherCard({super.key});

  @override
  State<WeatherCard> createState() => _WeatherCardState();
}

class _WeatherCardState extends State<WeatherCard> {
  // Nagercoil, Tamil Nadu — hardcoded default; no GPS needed.
  static const double _defaultLat = 8.1833;
  static const double _defaultLon = 77.4119;

  late Future<_WeatherData?> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchWeather();
  }

  Future<_WeatherData?> _fetchWeather() async {
    try {
      final response = await sl<ApiClient>().dio.get(
        ApiConstants.weatherCurrent,
        queryParameters: {'lat': _defaultLat, 'lon': _defaultLon},
      );
      final json = response.data as Map<String, dynamic>;
      return _WeatherData.fromJson(json);
    } on DioException catch (e) {
      debugPrint('WeatherCard: fetch failed — ${e.message}');
      return null;
    } catch (e) {
      debugPrint('WeatherCard: unexpected error — $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_WeatherData?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _WeatherSkeleton();
        }
        final data = snapshot.data;
        if (data == null || data.temp == null) {
          return const _WeatherError();
        }
        return _WeatherContent(data: data);
      },
    );
  }
}

// ── Data model ────────────────────────────────────────────────────────────────

class _WeatherData {
  final double? temp;
  final double? feelsLike;
  final String description;
  final String icon;
  final String city;
  final int? humidity;
  final double? windSpeed;

  const _WeatherData({
    required this.temp,
    required this.feelsLike,
    required this.description,
    required this.icon,
    required this.city,
    required this.humidity,
    required this.windSpeed,
  });

  factory _WeatherData.fromJson(Map<String, dynamic> json) {
    return _WeatherData(
      temp: (json['temp'] as num?)?.toDouble(),
      feelsLike: (json['feels_like'] as num?)?.toDouble(),
      description: json['description'] as String? ?? '',
      icon: json['icon'] as String? ?? '',
      city: json['city'] as String? ?? '',
      humidity: json['humidity'] as int?,
      windSpeed: (json['wind_speed'] as num?)?.toDouble(),
    );
  }
}

// ── Content widget ────────────────────────────────────────────────────────────

class _WeatherContent extends StatelessWidget {
  final _WeatherData data;
  const _WeatherContent({required this.data});

  String get _iconUrl =>
      'https://openweathermap.org/img/wn/${data.icon}@2x.png';

  @override
  Widget build(BuildContext context) {
    final tempStr = data.temp != null
        ? '${data.temp!.round()}°C'
        : '--°C';
    final feelsStr = data.feelsLike != null
        ? 'Feels like ${data.feelsLike!.round()}°C'
        : '';
    final description = _capitalize(data.description);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppColors.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  shape: BoxShape.circle,
                ),
                child: const Text('🌤', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.city.isNotEmpty ? data.city : 'Nagercoil',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Text(
                      'Current Weather',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Weather icon from OpenWeatherMap CDN
              if (data.icon.isNotEmpty)
                Image.network(
                  _iconUrl,
                  width: 44,
                  height: 44,
                  errorBuilder: (_, __, ___) => const SizedBox(width: 44),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Temperature + description
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                tempStr,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  height: 1,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (feelsStr.isNotEmpty)
                        Text(
                          feelsStr,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Humidity + wind speed
          Row(
            children: [
              _StatChip(
                icon: Icons.water_drop_outlined,
                label: data.humidity != null ? '${data.humidity}%' : '--',
                hint: 'Humidity',
              ),
              const SizedBox(width: 16),
              _StatChip(
                icon: Icons.air,
                label: data.windSpeed != null
                    ? '${data.windSpeed!.toStringAsFixed(1)} m/s'
                    : '--',
                hint: 'Wind',
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String hint;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          hint,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────

class _WeatherError extends StatelessWidget {
  const _WeatherError();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppColors.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              shape: BoxShape.circle,
            ),
            child: const Text('🌤', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          const Text(
            'Weather unavailable',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Loading skeleton ──────────────────────────────────────────────────────────

class _WeatherSkeleton extends StatelessWidget {
  const _WeatherSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppColors.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShimmerBox(
                width: 34,
                height: 34,
                borderRadius: BorderRadius.circular(17),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(height: 13, width: 120),
                    SizedBox(height: 6),
                    ShimmerBox(height: 10, width: 80),
                  ],
                ),
              ),
              const ShimmerBox(height: 44, width: 44),
            ],
          ),
          const SizedBox(height: 18),
          const ShimmerBox(height: 36, width: 100),
          const SizedBox(height: 14),
          Row(
            children: [
              const ShimmerBox(height: 12, width: 80),
              const SizedBox(width: 16),
              const ShimmerBox(height: 12, width: 80),
            ],
          ),
        ],
      ),
    );
  }
}
