import 'package:flutter/material.dart';
import '../../../../core/design_system/components/ds_error_state.dart';
import '../../../../core/l10n/tr.dart';
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
              return DSErrorState(
                message: state.message,
                onRetry: () =>
                    context.read<TeamManagementCubit>().fetchPlayers(),
              );
            } else if (state is TeamManagementLoaded) {
              if (state.players.isEmpty) {
                return Center(child: Text(trId('no_players_registered_yet')));
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
          title: Text(trId('add_player')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: trId('player_name')),
              ),
              TextField(
                controller: roleController,
                decoration: InputDecoration(labelText: trId('role_e_g_batsman_bowler')),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(trId('cancel_2')),
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
              child: Text(trId('add')),
            ),
          ],
        );
      },
    );
  }
}
