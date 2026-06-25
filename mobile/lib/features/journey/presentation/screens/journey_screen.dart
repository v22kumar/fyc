import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/journey_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../service_locator.dart';

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
        title: Text(_lang == 'ta' ? 'என் பயணம்' : 'My Journey'),
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
                          title: _lang == 'ta' ? 'நிகழ்வுகள்' : 'Events Attended',
                          value: j.eventsAttended.toString(),
                        ),
                        _ImpactCard(
                          icon: Icons.check_circle,
                          color: Colors.green,
                          title: _lang == 'ta' ? 'புகார்கள்' : 'Issues Resolved',
                          value: j.issuesHelped.toString(),
                        ),
                        _ImpactCard(
                          icon: Icons.park,
                          color: Colors.teal,
                          title: _lang == 'ta' ? 'மரங்கள்' : 'Trees Planted',
                          value: j.treesPlanted.toString(),
                        ),
                        _ImpactCard(
                          icon: Icons.water_drop,
                          color: Colors.redAccent,
                          title: _lang == 'ta' ? 'இரத்ததானம்' : 'Blood Donations',
                          value: j.bloodDonations.toString(),
                        ),
                        _ImpactCard(
                          icon: Icons.sports_soccer,
                          color: Colors.orange,
                          title: _lang == 'ta' ? 'விளையாட்டு' : 'Sports Matches',
                          value: j.sportsMatchesPlayed.toString(),
                        ),
                        _ImpactCard(
                          icon: Icons.timer,
                          color: Colors.blueAccent,
                          title: _lang == 'ta' ? 'நேரம்' : 'Volunteer Hours',
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
                      child: Text(_lang == 'ta' ? 'மீண்டும் முயற்சி' : 'Retry'),
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
            _lang == 'ta' ? 'உங்கள் சமூகத் தாக்கம்' : 'Your Community Impact',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _lang == 'ta'
                ? 'உங்கள் பங்களிப்புகள் நமது சமூகத்தை மாற்றுகின்றன!'
                : 'Your contributions are making a real difference!',
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
              color: AppColors.text,
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
