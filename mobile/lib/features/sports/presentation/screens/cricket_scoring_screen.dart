import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../service_locator.dart';
import '../../domain/repositories/sports_repository.dart';
import '../bloc/cricket_scoring_cubit.dart';

class CricketScoringScreen extends StatefulWidget {
  final String fixtureId;

  const CricketScoringScreen({
    super.key,
    required this.fixtureId,
  });

  @override
  State<CricketScoringScreen> createState() => _CricketScoringScreenState();
}

class _CricketScoringScreenState extends State<CricketScoringScreen> {
  String? currentStrikerId;
  String? currentNonStrikerId;
  String? currentBowlerId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CricketScoringCubit(
        sl<SportsRepository>(),
        widget.fixtureId,
      )..fetchMatchState(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Cricket Scoring'),
          actions: [
            BlocBuilder<CricketScoringCubit, CricketScoringState>(
              builder: (context, state) {
                return IconButton(
                  icon: const Icon(Icons.undo),
                  onPressed: () {
                    context.read<CricketScoringCubit>().undoBall();
                  },
                  tooltip: 'Undo Last Ball',
                );
              },
            ),
          ],
        ),
        body: BlocBuilder<CricketScoringCubit, CricketScoringState>(
          builder: (context, state) {
            if (state is CricketScoringLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is CricketScoringFailure) {
              return Center(child: Text('Error: ${state.message}'));
            } else if (state is CricketScoringLoaded) {
              final ms = state.matchState;
              final oversCompleted = ms.balls ~/ 6;
              final ballsInOver = ms.balls % 6;

              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Text(
                              'Score: ${ms.score}/${ms.wickets}',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            Text(
                              'Overs: $oversCompleted.$ballsInOver',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            if (ms.target != null)
                              Text('Target: ${ms.target}'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildPlayerSetupFields(context),
                    const SizedBox(height: 16),
                    const Text('Runs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [0, 1, 2, 3, 4, 6].map((runs) {
                        return ElevatedButton(
                          onPressed: () => _scoreBall(context, runs: runs),
                          child: Text('$runs'),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text('Extras', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ElevatedButton(
                          onPressed: () => _scoreBall(context, extrasType: 'WIDE', extrasRuns: 1),
                          child: const Text('WD'),
                        ),
                        ElevatedButton(
                          onPressed: () => _scoreBall(context, extrasType: 'NO_BALL', extrasRuns: 1),
                          child: const Text('NB'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Wickets', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () => _scoreBall(context, isWicket: true),
                      child: const Text('Wicket', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox();
          },
        ),
      ),
    );
  }

  Widget _buildPlayerSetupFields(BuildContext context) {
    return Column(
      children: [
        TextField(
          decoration: const InputDecoration(labelText: 'Striker ID / Name'),
          onChanged: (val) => currentStrikerId = val,
        ),
        TextField(
          decoration: const InputDecoration(labelText: 'Non-Striker ID / Name'),
          onChanged: (val) => currentNonStrikerId = val,
        ),
        TextField(
          decoration: const InputDecoration(labelText: 'Bowler ID / Name'),
          onChanged: (val) => currentBowlerId = val,
        ),
      ],
    );
  }

  void _scoreBall(
    BuildContext context, {
    int runs = 0,
    String extrasType = 'NONE',
    int extrasRuns = 0,
    bool isWicket = false,
  }) {
    if (currentStrikerId == null || currentNonStrikerId == null || currentBowlerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Striker, Non-Striker, and Bowler first.')),
      );
      return;
    }

    final payload = {
      'striker_id': currentStrikerId,
      'non_striker_id': currentNonStrikerId,
      'bowler_id': currentBowlerId,
      'runs_batter': runs,
      'extras_type': extrasType,
      'extras_runs': extrasRuns,
      'is_wicket': isWicket,
      if (isWicket) 'player_dismissed_id': currentStrikerId,
      if (isWicket) 'wicket_type': 'CAUGHT',
    };

    context.read<CricketScoringCubit>().scoreBall(payload);

    // Strike rotation logic
    if (extrasType == 'NONE' || extrasType == 'NO_BALL') {
      if (runs % 2 != 0) {
        _rotateStrike();
      }
    }
    
    // Check if over completed (if it's a legal delivery)
    if (extrasType == 'NONE' || extrasType == 'BYE' || extrasType == 'LEG_BYE') {
      final state = context.read<CricketScoringCubit>().state;
      if (state is CricketScoringLoaded) {
        final balls = state.matchState.balls + 1;
        if (balls % 6 == 0 && balls > 0) {
          _rotateStrike(); // Rotate strike at end of over
          currentBowlerId = null; // Clear bowler for next over
        }
      }
    }
  }

  void _rotateStrike() {
    setState(() {
      final temp = currentStrikerId;
      currentStrikerId = currentNonStrikerId;
      currentNonStrikerId = temp;
    });
  }
}
