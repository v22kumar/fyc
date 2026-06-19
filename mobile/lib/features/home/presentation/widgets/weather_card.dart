import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../../../service_locator.dart';

// Default to Nagercoil when GPS is unavailable or denied.
const double _defaultLat = 8.1833;
const double _defaultLon = 77.4119;
const String _defaultCity = 'Nagercoil';

class WeatherCard extends StatefulWidget {
  const WeatherCard({super.key});

  @override
  State<WeatherCard> createState() => _WeatherCardState();
}

class _WeatherCardState extends State<WeatherCard> {
  late Future<_WeatherData?> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadWeather();
  }

  Future<_WeatherData?> _loadWeather() async {
    final (lat, lon, cityHint) = await _resolveLocation();
    return _fetchWeather(lat, lon, cityHint);
  }

  /// Returns (lat, lon, cityHint). Falls back to Nagercoil on any failure.
  Future<(double, double, String)> _resolveLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return (_defaultLat, _defaultLon, _defaultCity);

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return (_defaultLat, _defaultLon, _defaultCity);
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return (pos.latitude, pos.longitude, '');
    } catch (_) {
      return (_defaultLat, _defaultLon, _defaultCity);
    }
  }

  Future<_WeatherData?> _fetchWeather(
      double lat, double lon, String cityHint) async {
    try {
      final response = await sl<ApiClient>().dio.get(
        ApiConstants.weatherCurrent,
        queryParameters: {'lat': lat, 'lon': lon},
      );
      final json = response.data as Map<String, dynamic>;
      final data = _WeatherData.fromJson(json);
      // Open-Meteo doesn't reverse-geocode; use GPS city hint if backend returns empty.
      return data.copyWithCity(data.city.isEmpty ? cityHint : data.city);
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
        if (data == null || data.temp == null) return const _WeatherError();
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

  factory _WeatherData.fromJson(Map<String, dynamic> json) => _WeatherData(
        temp: (json['temp'] as num?)?.toDouble(),
        feelsLike: (json['feels_like'] as num?)?.toDouble(),
        description: json['description'] as String? ?? '',
        icon: json['icon'] as String? ?? '',
        city: json['city'] as String? ?? '',
        humidity: json['humidity'] as int?,
        windSpeed: (json['wind_speed'] as num?)?.toDouble(),
      );

  _WeatherData copyWithCity(String newCity) => _WeatherData(
        temp: temp,
        feelsLike: feelsLike,
        description: description,
        icon: icon,
        city: newCity,
        humidity: humidity,
        windSpeed: windSpeed,
      );
}

// ── Content ───────────────────────────────────────────────────────────────────

class _WeatherContent extends StatelessWidget {
  final _WeatherData data;
  const _WeatherContent({required this.data});

  String get _iconUrl => 'https://openweathermap.org/img/wn/${data.icon}@2x.png';

  @override
  Widget build(BuildContext context) {
    final tempStr = data.temp != null ? '${data.temp!.round()}°C' : '--°C';
    final feelsStr = data.feelsLike != null
        ? 'Feels like ${data.feelsLike!.round()}°C'
        : '';
    final desc = data.description.isEmpty
        ? ''
        : data.description[0].toUpperCase() + data.description.substring(1);

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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: AppColors.primarySurface, shape: BoxShape.circle),
                child: const Text('🌤', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.city.isNotEmpty ? data.city : _defaultCity,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary),
                    ),
                    const Text('Current Weather',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                  ],
                ),
              ),
              if (data.icon.isNotEmpty)
                Image.network(_iconUrl,
                    width: 44,
                    height: 44,
                    errorBuilder: (_, __, ___) => const SizedBox(width: 44)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(tempStr,
                  style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      height: 1)),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (desc.isNotEmpty)
                        Text(desc,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary)),
                      if (feelsStr.isNotEmpty)
                        Text(feelsStr,
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
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
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String hint;
  const _StatChip(
      {required this.icon, required this.label, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
        const SizedBox(width: 3),
        Text(hint,
            style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}

// ── Error & Skeleton ──────────────────────────────────────────────────────────

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
                color: AppColors.primarySurface, shape: BoxShape.circle),
            child: const Text('🌤', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          const Text('Weather unavailable',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

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
                  borderRadius: BorderRadius.circular(17)),
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
          const Row(children: [
            ShimmerBox(height: 12, width: 80),
            SizedBox(width: 16),
            ShimmerBox(height: 12, width: 80),
          ]),
        ],
      ),
    );
  }
}
