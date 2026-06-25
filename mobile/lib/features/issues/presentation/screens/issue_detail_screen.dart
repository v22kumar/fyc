import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/issue_entity.dart';
import '../bloc/issue_detail_bloc.dart';
import '../bloc/issue_list_bloc.dart';
import '../bloc/issue_list_event.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../service_locator.dart';
import '../../../../core/widgets/success_snackbar.dart';

class IssueDetailScreen extends StatelessWidget {
  final IssueEntity issue;

  const IssueDetailScreen({super.key, required this.issue});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<IssueDetailBloc>(),
      child: _IssueDetailView(issue: issue),
    );
  }
}

class _IssueDetailView extends StatefulWidget {
  final IssueEntity issue;
  const _IssueDetailView({required this.issue});

  @override
  State<_IssueDetailView> createState() => _IssueDetailViewState();
}

class _IssueDetailViewState extends State<_IssueDetailView> {
  late IssueEntity _currentIssue;
  String get _lang => sl<LocalStorage>().getLang();

  @override
  void initState() {
    super.initState();
    _currentIssue = widget.issue;
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy, h:mm a');

    return BlocListener<IssueDetailBloc, IssueDetailState>(
      listener: (context, state) {
        if (state is IssueDetailActionSuccess) {
          SuccessSnackbar.show(
            context,
            title: _lang == 'ta' ? 'வெற்றி' : 'Success',
            message: state.message,
          );
          if (state.updatedIssue != null) {
            setState(() {
              _currentIssue = state.updatedIssue!;
            });
            // Refresh list screen
            context.read<IssueListBloc>().add(const IssueListFetchRequested());
          }
        } else if (state is IssueDetailActionFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_lang == 'ta' ? 'புகார் விவரம்' : 'Issue Details'),
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(_currentIssue.categoryEmoji, style: const TextStyle(fontSize: 40)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentIssue.categoryLabel(_lang),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              fmt.format(_currentIssue.createdAt.toLocal()),
                              style: TextStyle(color: Colors.grey[600], fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      _StatusBadge(issue: _currentIssue, lang: _lang),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (_currentIssue.photoUrl != null && _currentIssue.photoUrl!.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radiusBtn),
                      child: Image.network(
                        _currentIssue.photoUrl!,
                        width: double.infinity,
                        height: 250,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 250,
                          color: AppColors.background,
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image, color: Colors.grey, size: 50),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  Text(
                    _lang == 'ta' ? 'விளக்கம்' : 'Description',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currentIssue.displayDescription(_lang),
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  ),
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 16),
                  Text(
                    _lang == 'ta' ? 'செயல்கள்' : 'Actions',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  if (_currentIssue.status != 'RESOLVED') ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle_outline),
                        label: Text(_lang == 'ta' ? 'தீர்க்கப்பட்டது என குறிக்கவும்' : 'Mark as RESOLVED'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: () {
                          context.read<IssueDetailBloc>().add(IssueMarkResolvedRequested(_currentIssue.id));
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.email_outlined),
                      label: Text(_lang == 'ta' ? 'மின்னஞ்சல் அனுப்பியதை பதிவு செய்' : 'Log Email Sent to Authorities'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () {
                        context.read<IssueDetailBloc>().add(IssueLogEmailRequested(_currentIssue.id));
                      },
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
            BlocBuilder<IssueDetailBloc, IssueDetailState>(
              builder: (context, state) {
                if (state is IssueDetailLoading) {
                  return Container(
                    color: Colors.black26,
                    child: const Center(child: CircularProgressIndicator()),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final IssueEntity issue;
  final String lang;

  const _StatusBadge({required this.issue, required this.lang});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: issue.statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: issue.statusColor),
      ),
      child: Text(
        issue.statusLabel(lang),
        style: TextStyle(
          color: issue.statusColor,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
