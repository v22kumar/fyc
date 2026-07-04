import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../bloc/membership_bloc.dart';
import '../bloc/membership_event.dart';
import '../bloc/membership_state.dart';
import '../../domain/entities/membership_entity.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../service_locator.dart';
import 'package:fyc_connect/core/l10n/tr.dart';

class MembershipCardScreen extends StatefulWidget {
  const MembershipCardScreen({super.key});

  @override
  State<MembershipCardScreen> createState() => _MembershipCardScreenState();
}

class _MembershipCardScreenState extends State<MembershipCardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  bool _showBack = false;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutCubic),
    );
    context.read<MembershipBloc>().add(const MembershipCardRequested());
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _flipCard() {
    if (_showBack) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    setState(() => _showBack = !_showBack);
  }

  String get _lang => sl<LocalStorage>().getLang();

  @override
  Widget build(BuildContext context) {
    final isTa = _lang == 'ta';
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          tr(
            en: 'My Membership Card',
            ta: 'என் உறுப்பினர் அட்டை',
            hi: 'मेरा सदस्यता कार्ड',
            ml: 'എന്റെ അംഗത്വ കാർഡ്',
          ),
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: BlocBuilder<MembershipBloc, MembershipState>(
        builder: (context, state) {
          if (state is MembershipLoading || state is MembershipInitial) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          if (state is MembershipFailure) {
            return _NoCardView(message: state.message, isTa: isTa);
          }
          if (state is MembershipLoaded) {
            return _CardView(
              card: state.card,
              isTa: isTa,
              flipAnimation: _flipAnimation,
              showBack: _showBack,
              onFlip: _flipCard,
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _CardView extends StatelessWidget {
  final MembershipEntity card;
  final bool isTa;
  final Animation<double> flipAnimation;
  final bool showBack;
  final VoidCallback onFlip;

  const _CardView({
    required this.card,
    required this.isTa,
    required this.flipAnimation,
    required this.showBack,
    required this.onFlip,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Flip hint
          Text(
            tr(
              en: 'Tap card to flip',
              ta: 'அட்டையை திருப்ப தட்டவும்',
              hi: 'पलटने के लिए कार्ड पर टैप करें',
              ml: 'കാർഡ് മറിക്കാൻ ടാപ്പ് ചെയ്യുക',
            ),
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 12),

          // Animated flip card
          GestureDetector(
            onTap: onFlip,
            child: AnimatedBuilder(
              animation: flipAnimation,
              builder: (context, child) {
                final angle = flipAnimation.value * pi;
                final isFrontVisible = angle < pi / 2;
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(angle),
                  child: isFrontVisible
                      ? _CardFront(card: card, isTa: isTa)
                      : Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()..rotateY(pi),
                          child: _CardBack(card: card, isTa: isTa),
                        ),
                );
              },
            ),
          ),

          const SizedBox(height: 32),
          _StatusBanner(card: card, isTa: isTa),
          const SizedBox(height: 24),
          _DetailsList(card: card, isTa: isTa),
        ],
      ),
    );
  }
}

class _CardFront extends StatelessWidget {
  final MembershipEntity card;
  final bool isTa;

  const _CardFront({required this.card, required this.isTa});

  @override
  Widget build(BuildContext context) {
    final expiry = DateFormat('MMM yyyy').format(card.expiresAt);
    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F5132), Color(0xFF198754), Color(0xFF105936)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F5132).withOpacity(0.6),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Positioned(
            bottom: -20,
            left: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
              ),
            ),
          ),
          // Gold shimmer strip at top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFD97706).withOpacity(0.8),
                    const Color(0xFFFBBF24),
                    const Color(0xFFD97706).withOpacity(0.8),
                  ],
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // FYC Logo
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        'assets/images/fyc_logo_icon.png',
                        width: 48,
                        height: 48,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Text('FYC',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'FRIENDS YOUTH CLUB',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        Text(
                          'நண்பர்கள் இளைஞர் மன்றம்',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 9,
                          ),
                        ),
                        Text(
                          'SINCE 2000 • NAGERCOIL',
                          style: TextStyle(
                            color: const Color(0xFFFBBF24).withOpacity(0.9),
                            fontSize: 8,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  card.displayDesignation(isTa ? 'ta' : 'en').toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFFFBBF24),
                    fontSize: 10,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  card.membershipNumber,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr(
                            en: 'VALID THRU',
                            ta: 'காலாவதி தேதி',
                            hi: 'मान्य अवधि',
                            ml: 'സാധുത വരെ',
                          ),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 8,
                            letterSpacing: 1,
                          ),
                        ),
                        Text(
                          expiry,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: card.isActive && !card.isExpired
                            ? const Color(0xFF10B981).withOpacity(0.2)
                            : const Color(0xFFEF4444).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: card.isActive && !card.isExpired
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        card.isExpired
                            ? tr(
                                en: 'EXPIRED',
                                ta: 'காலாவதியானது',
                                hi: 'समाप्त',
                                ml: 'കാലഹരണപ്പെട്ടു',
                              )
                            : tr(
                                en: 'ACTIVE',
                                ta: 'செயல்படு',
                                hi: 'सक्रिय',
                                ml: 'സജീവം',
                              ),
                        style: TextStyle(
                          color: card.isActive && !card.isExpired
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardBack extends StatelessWidget {
  final MembershipEntity card;
  final bool isTa;

  const _CardBack({required this.card, required this.isTa});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Gold strip at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(20)),
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFD97706).withOpacity(0.8),
                    const Color(0xFFFBBF24),
                    const Color(0xFFD97706).withOpacity(0.8),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // QR Code
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: QrImageView(
                    data: card.qrCodePayload,
                    version: QrVersions.auto,
                    size: 130,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Color(0xFF0F5132),
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Color(0xFF0F5132),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        tr(
                          en: 'Scan this QR code to verify membership authenticity',
                          ta: 'இந்த QR குறியீட்டை ஸ்கேன் செய்து உறுப்பினர்தன்மையை சரிபார்க்கவும்',
                          hi: 'सदस्यता की प्रामाणिकता सत्यापित करने के लिए यह QR कोड स्कैन करें',
                          ml: 'അംഗത്വത്തിന്റെ ആധികാരികത പരിശോധിക്കാൻ ഈ QR കോഡ് സ്കാൻ ചെയ്യുക',
                        ),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'UNITE. PLAY. THRIVE.',
                        style: TextStyle(
                          color: Color(0xFFFBBF24),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'fyc2000.org',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final MembershipEntity card;
  final bool isTa;

  const _StatusBanner({required this.card, required this.isTa});

  @override
  Widget build(BuildContext context) {
    final isValid = card.isActive && !card.isExpired;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: isValid
            ? AppColors.primary.withOpacity(0.15)
            : AppColors.accent.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isValid
              ? AppColors.primary.withOpacity(0.4)
              : AppColors.accent.withOpacity(0.4),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isValid ? Icons.verified : Icons.cancel_outlined,
            color: isValid ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            isValid
                ? tr(
                    en: 'Valid Membership Card',
                    ta: 'செல்லுபடியான உறுப்பினர் அட்டை',
                    hi: 'मान्य सदस्यता कार्ड',
                    ml: 'സാധുവായ അംഗത്വ കാർഡ്',
                  )
                : tr(
                    en: 'Card Expired or Inactive',
                    ta: 'அட்டை காலாவதியானது',
                    hi: 'कार्ड समाप्त या निष्क्रिय',
                    ml: 'കാർഡ് കാലഹരണപ്പെട്ടു അല്ലെങ്കിൽ നിഷ്ക്രിയം',
                  ),
            style: TextStyle(
              color: isValid
                  ? const Color(0xFF10B981)
                  : const Color(0xFFEF4444),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsList extends StatelessWidget {
  final MembershipEntity card;
  final bool isTa;

  const _DetailsList({required this.card, required this.isTa});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM yyyy');
    final rows = [
      (
        tr(
          en: 'Membership No.',
          ta: 'உறுப்பினர் எண்',
          hi: 'सदस्यता संख्या',
          ml: 'അംഗത്വ നമ്പർ',
        ),
        card.membershipNumber
      ),
      (
        tr(
          en: 'Designation',
          ta: 'பதவி',
          hi: 'पदनाम',
          ml: 'പദവി',
        ),
        '${card.designationTa} / ${card.designationEn}'
      ),
      if (card.issuedAt != null)
        (
          tr(
            en: 'Issued On',
            ta: 'வழங்கப்பட்ட தேதி',
            hi: 'जारी तिथि',
            ml: 'നൽകിയ തീയതി',
          ),
          df.format(card.issuedAt!)
        ),
      (
        tr(
          en: 'Valid Until',
          ta: 'காலாவதி தேதி',
          hi: 'मान्य अवधि',
          ml: 'സാധുത വരെ',
        ),
        df.format(card.expiresAt)
      ),
    ];

    return Column(
      children: rows.map((row) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            children: [
              Text(
                row.$1,
                style: const TextStyle(
                    color: Colors.white54, fontSize: 12),
              ),
              const Spacer(),
              Text(
                row.$2,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _NoCardView extends StatelessWidget {
  final String message;
  final bool isTa;

  const _NoCardView({required this.message, required this.isTa});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/fyc_logo_icon.png',
              width: 80,
              height: 80,
              errorBuilder: (_, __, ___) =>
                  const Text('🪪', style: TextStyle(fontSize: 60)),
            ),
            const SizedBox(height: 24),
            Text(
              tr(
                en: 'No Membership Card Found',
                ta: 'உறுப்பினர் அட்டை இல்லை',
                hi: 'कोई सदस्यता कार्ड नहीं मिला',
                ml: 'അംഗത്വ കാർഡ് കണ്ടെത്തിയില്ല',
              ),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Text(
              tr(
                en: 'Contact your administrator to get your digital card issued.',
                ta: 'உங்கள் அட்டைக்காக நிர்வாகியை தொடர்பு கொள்ளுங்கள்.',
                hi: 'अपना डिजिटल कार्ड जारी करवाने के लिए अपने व्यवस्थापक से संपर्क करें।',
                ml: 'നിങ്ങളുടെ ഡിജിറ്റൽ കാർഡ് ലഭിക്കാൻ അഡ്മിനിസ്ട്രേറ്ററെ ബന്ധപ്പെടുക.',
              ),
              style: const TextStyle(color: Colors.white38, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
