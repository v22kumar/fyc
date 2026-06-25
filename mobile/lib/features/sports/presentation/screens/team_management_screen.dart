import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../service_locator.dart';
import '../../domain/repositories/sports_repository.dart';
import '../bloc/team_management_cubit.dart';
import 'player_profile_screen.dart';

class TeamManagementScreen extends StatelessWidget {
  final String teamId;
  final String teamName;

  const TeamManagementScreen({
    super.key,
    required this.teamId,
    required this.teamName,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => TeamManagementCubit(
        sl<SportsRepository>(),
        teamId,
      )..fetchPlayers(),
      child: Scaffold(
        appBar: AppBar(
          title: Text('$teamName Roster'),
        ),
        body: BlocBuilder<TeamManagementCubit, TeamManagementState>(
          builder: (context, state) {
            if (state is TeamManagementLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is TeamManagementFailure) {
              return Center(child: Text('Error: ${state.message}'));
            } else if (state is TeamManagementLoaded) {
              if (state.players.isEmpty) {
                return const Center(child: Text('No players registered yet.'));
              }
              return ListView.builder(
                itemCount: state.players.length,
                itemBuilder: (context, index) {
                  final player = state.players[index];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(player.name[0].toUpperCase()),
                    ),
                    title: Text(player.name),
                    subtitle: Text(player.role ?? 'Player'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PlayerProfileScreen(player: player),
                        ),
                      );
                    },
                  );
                },
              );
            }
            return const SizedBox();
          },
        ),
        floatingActionButton: Builder(
          builder: (context) {
            return FloatingActionButton(
              onPressed: () => _showAddPlayerDialog(context),
              child: const Icon(Icons.add),
            );
          }
        ),
      ),
    );
  }

  void _showAddPlayerDialog(BuildContext context) {
    final nameController = TextEditingController();
    final roleController = TextEditingController();
    final cubit = context.read<TeamManagementCubit>();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Add Player'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Player Name'),
              ),
              TextField(
                controller: roleController,
                decoration: const InputDecoration(labelText: 'Role (e.g. Batsman, Bowler)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  cubit.registerPlayer({
                    'name': nameController.text,
                    'role': roleController.text,
                  });
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}
