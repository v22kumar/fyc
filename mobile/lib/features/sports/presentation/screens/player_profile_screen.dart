import 'package:flutter/material.dart';
import '../../domain/entities/player_entity.dart';

class PlayerProfileScreen extends StatelessWidget {
  final PlayerEntity player;

  const PlayerProfileScreen({
    super.key,
    required this.player,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(player.name),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                child: Text(
                  player.name[0].toUpperCase(),
                  style: const TextStyle(fontSize: 40),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                player.name,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                player.role ?? 'Player',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Statistics',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildStatCard('Matches Played', player.matchesPlayed.toString()),
            _buildStatCard('Runs Scored', player.runsScored.toString()),
            _buildStatCard('Wickets Taken', player.wicketsTaken.toString()),
            _buildStatCard('Awards (MVP)', player.mvpCount.toString()),
            _buildStatCard('Sportsmanship Score', player.sportsmanshipScore.toString()),
            if (player.battingStyle != null || player.bowlingStyle != null) ...[
              const SizedBox(height: 32),
              const Text(
                'Play Style',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (player.battingStyle != null)
                _buildStatCard('Batting Style', player.battingStyle!),
              if (player.bowlingStyle != null)
                _buildStatCard('Bowling Style', player.bowlingStyle!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: ListTile(
        title: Text(label),
        trailing: Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
