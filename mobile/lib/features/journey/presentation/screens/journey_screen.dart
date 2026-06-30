import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/journey_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../service_locator.dart';
import 'package:fyc_connect/core/l10n/tr.dart';

class JourneyScreen extends StatefulWidget {
  const JourneyScreen({super.key});

  @override
  State<JourneyScreen> createState() => _JourneyScreenState();
}

class _JourneyScreenState extends State<JourneyScreen> {
  String get _lang => sl<LocalStorage>().getLang();

  @override
  void initState() {
    super.initState();
    context.read<JourneyBloc>().add(const JourneyFetchRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(en: 'My Journey', ta: 'என் பயணம்', hi: 'मेरी यात्रा', ml: 'എന്റെ യാത്ര')),
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.2],
          ),
        ),
        child: BlocBuilder<JourneyBloc, JourneyState>(
          builder: (context, state) {
            if (state is JourneyLoading || state is JourneyInitial) {
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            } else if (state is JourneyLoaded) {
              final j = state.journey;
              return RefreshIndicator(
                onRefresh: () async {
                  context.read<JourneyBloc>().add(const JourneyFetchRequested());
                },
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _ImpactCard(
                          icon: Icons.event,
                          color: Colors.purple,
                          title: tr(en: 'Events Attended', ta: 'நிகழ்வுகள்', hi: 'शामिल कार्यक्रम', ml: 'പങ്കെടുത്ത പരിപാടികൾ'),
                          value: j.eventsAttended.toString(),
                        ),
                        _ImpactCard(
                          icon: Icons.check_circle,
                          color: Colors.green,
                          title: tr(en: 'Issues Resolved', ta: 'புகார்கள்', hi: 'हल किए मुद्दे', ml: 'പരിഹരിച്ച പ്രശ്നങ്ങൾ'),
                          value: j.issuesHelped.toString(),
                        ),
                        _ImpactCard(
                          icon: Icons.park,
                          color: Colors.teal,
                          title: tr(en: 'Trees Planted', ta: 'மரங்கள்', hi: 'लगाए पेड़', ml: 'നട്ട മരങ്ങൾ'),
                          value: j.treesPlanted.toString(),
                        ),
                        _ImpactCard(
                          icon: Icons.water_drop,
                          color: Colors.redAccent,
                          title: tr(en: 'Blood Donations', ta: 'இரத்ததானம்', hi: 'रक्तदान', ml: 'രക്തദാനങ്ങൾ'),
                          value: j.bloodDonations.toString(),
                        ),
                        _ImpactCard(
                          icon: Icons.sports_soccer,
                          color: Colors.orange,
                          title: tr(en: 'Sports Matches', ta: 'விளையாட்டு', hi: 'खेल मैच', ml: 'കായിക മത്സരങ്ങൾ'),
                          value: j.sportsMatchesPlayed.toString(),
                        ),
                        _ImpactCard(
                          icon: Icons.timer,
                          color: Colors.blueAccent,
                          title: tr(en: 'Volunteer Hours', ta: 'நேரம்', hi: 'सेवा घंटे', ml: 'വൊളന്റിയർ മണിക്കൂറുകൾ'),
                          value: '${j.volunteerHours}h',
                        ),
                      ],
                    ),
                  ],
                ),
              );
            } else if (state is JourneyFailure) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                    const SizedBox(height: 16),
                    Text(state.message, style: const TextStyle(color: Colors.black54)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        context.read<JourneyBloc>().add(const JourneyFetchRequested());
                      },
                      child: Text(tr(en: 'Retry', ta: 'மீண்டும் முயற்சி', hi: 'पुनः प्रयास', ml: 'വീണ്ടും ശ്രമിക്കുക')),
                    )
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 40,
            backgroundColor: AppColors.background,
            child: Icon(Icons.emoji_events, size: 40, color: Colors.amber),
          ),
          const SizedBox(height: 16),
          Text(
            tr(en: 'Your Community Impact', ta: 'உங்கள் சமூகத் தாக்கம்', hi: 'आपका सामुदायिक प्रभाव', ml: 'നിങ്ങളുടെ സമൂഹ സ്വാധീനം'),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            tr(en: 'Your contributions are making a real difference!', ta: 'உங்கள் பங்களிப்புகள் நமது சமூகத்தை மாற்றுகின்றன!', hi: 'आपके योगदान वास्तविक बदलाव ला रहे हैं!', ml: 'നിങ്ങളുടെ സംഭാവനകൾ യഥാർത്ഥ മാറ്റം വരുത്തുന്നു!'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

class _ImpactCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String value;

  const _ImpactCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
