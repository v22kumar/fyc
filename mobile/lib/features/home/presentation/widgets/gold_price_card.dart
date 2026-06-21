import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/shimmer_box.dart';
import '../../../../service_locator.dart';

/// Today's gold price card (24K and 22K per gram in INR) shown on the home
/// screen. Data is fetched from the backend proxy which caches results for
/// 1 hour.
///
/// Non-critical: loading errors render a graceful "unavailable" message
/// rather than crashing the home screen.
class GoldPriceCard extends StatefulWidget {
  const GoldPriceCard({super.key});

  @override
  State<GoldPriceCard> createState() => _GoldPriceCardState();
}

class _GoldPriceCardState extends State<GoldPriceCard> {
  late Future<_GoldData?> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchGoldPrice();
  }

  Future<_GoldData?> _fetchGoldPrice() async {
    try {
      final response = await sl<ApiClient>().dio.get(ApiConstants.goldPrice);
      final json = response.data as Map<String, dynamic>;
      return _GoldData.fromJson(json);
    } on DioException catch (e) {
      debugPrint('GoldPriceCard: fetch failed — ${e.message}');
      return null;
    } catch (e) {
      debugPrint('GoldPriceCard: unexpected error — $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_GoldData?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _GoldSkeleton();
        }
        final data = snapshot.data;
        if (data == null || data.price24k == null) {
          return const _GoldError();
        }
        return _GoldContent(data: data);
      },
    );
  }
}

// ── Data model ────────────────────────────────────────────────────────────────

class _GoldData {
  final double? price24k;
  final double? price22k;
  final String currency;
  final String updatedAt;

  const _GoldData({
    required this.price24k,
    required this.price22k,
    required this.currency,
    required this.updatedAt,
  });

  factory _GoldData.fromJson(Map<String, dynamic> json) {
    return _GoldData(
      price24k: (json['price_per_gram_24k'] as num?)?.toDouble(),
      price22k: (json['price_per_gram_22k'] as num?)?.toDouble(),
      currency: json['currency'] as String? ?? 'INR',
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }
}

// ── Gold accent color ─────────────────────────────────────────────────────────

const Color _goldColor = Color(0xFFF59E0B); // Amber 500
const Color _goldSurface = Color(0xFFFFFBEB); // Amber 50

// ── Content widget ────────────────────────────────────────────────────────────

class _GoldContent extends StatelessWidget {
  final _GoldData data;
  const _GoldContent({required this.data});

  String _formatPrice(double? price) {
    if (price == null) return '—';
    // Format with Indian number formatting (e.g. ₹7,512.50)
    final intPart = price.floor();
    final decPart = ((price - intPart) * 100).round();
    final formatted = _indianFormat(intPart);
    return '₹$formatted.${decPart.toString().padLeft(2, '0')}';
  }

  String _indianFormat(int n) {
    final s = n.toString();
    if (s.length <= 3) return s;
    // Last 3 digits, then groups of 2
    final last3 = s.substring(s.length - 3);
    final rest = s.substring(0, s.length - 3);
    final buf = StringBuffer();
    for (int i = 0; i < rest.length; i++) {
      if (i != 0 && (rest.length - i) % 2 == 0) buf.write(',');
      buf.write(rest[i]);
    }
    return '${buf.toString()},$last3';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.cSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: context.cBorder),
        boxShadow: context.isDark ? null : AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: _goldSurface,
                  shape: BoxShape.circle,
                ),
                child: const Text('🪙', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Today's Gold Price",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: context.cText,
                      ),
                    ),
                    Text(
                      'Per gram · INR',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: context.cTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _goldSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _goldColor.withOpacity(0.4)),
                ),
                child: const Text(
                  'LIVE',
                  style: TextStyle(
                    color: _goldColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Price rows
          _PriceRow(
            karat: '24K',
            label: 'Pure gold',
            price: _formatPrice(data.price24k),
            isHighlight: true,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: context.cBorder),
          ),
          _PriceRow(
            karat: '22K',
            label: 'Jewellery grade',
            price: _formatPrice(data.price22k),
            isHighlight: false,
          ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String karat;
  final String label;
  final String price;
  final bool isHighlight;

  const _PriceRow({
    required this.karat,
    required this.label,
    required this.price,
    required this.isHighlight,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isHighlight ? _goldColor : _goldSurface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            karat,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isHighlight ? Colors.white : _goldColor,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: context.cTextSecondary,
            ),
          ),
        ),
        Text(
          price,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isHighlight ? _goldColor : context.cText,
          ),
        ),
      ],
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────

class _GoldError extends StatelessWidget {
  const _GoldError();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.cSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: context.cBorder),
        boxShadow: context.isDark ? null : AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: _goldSurface,
              shape: BoxShape.circle,
            ),
            child: const Text('🪙', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Text(
            'Gold price unavailable',
            style: TextStyle(
              fontSize: 14,
              color: context.cTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Loading skeleton ──────────────────────────────────────────────────────────

class _GoldSkeleton extends StatelessWidget {
  const _GoldSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.cSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: context.cBorder),
        boxShadow: context.isDark ? null : AppTheme.cardShadow,
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
                    ShimmerBox(height: 13, width: 140),
                    SizedBox(height: 6),
                    ShimmerBox(height: 10, width: 80),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const ShimmerBox(height: 36),
          const SizedBox(height: 12),
          const ShimmerBox(height: 1),
          const SizedBox(height: 12),
          const ShimmerBox(height: 36),
        ],
      ),
    );
  }
}
