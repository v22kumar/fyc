import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/issue_complaint_api.dart';
import '../../domain/entities/issue_entity.dart';
import '../bloc/issue_detail_bloc.dart';
import '../bloc/issue_list_bloc.dart';
import '../bloc/issue_list_event.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../service_locator.dart';
import '../../../../core/widgets/success_snackbar.dart';
import 'package:fyc_connect/core/l10n/tr.dart';

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
  bool _forwarding = false;
  String get _lang => sl<LocalStorage>().getLang();

  @override
  void initState() {
    super.initState();
    _currentIssue = widget.issue;
  }

  Future<void> _launch(Uri uri) async {
    try {
      if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _forwardToDepartment() async {
    if (_forwarding) return;
    setState(() => _forwarding = true);
    try {
      final r = await IssueComplaintApi.forward(_currentIssue.id);
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        showDragHandle: true,
        builder: (_) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(r.sent ? Icons.mark_email_read_rounded : Icons.info_outline,
                  color: r.sent ? AppColors.success : AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  r.sent
                      ? '${trId('complaint_emailed_to')} ${r.departmentName ?? ''}'
                      : '${trId('reach_the_department_directly')} — ${r.departmentName ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
            ]),
            if (!r.sent) ...[
              const SizedBox(height: 6),
              Text(trId('no_department_email_set_yet'),
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 14),
              if (r.helpline != null && r.helpline!.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _launch(Uri(scheme: 'tel', path: r.helpline)),
                    icon: const Icon(Icons.call),
                    label: Text('${trId('call')} ${r.helpline}'),
                  ),
                ),
              if (r.portalUrl != null && r.portalUrl!.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _launch(Uri.parse(r.portalUrl!)),
                    icon: const Icon(Icons.open_in_new),
                    label: Text(trId('open_grievance_portal')),
                  ),
                ),
              ],
            ],
          ]),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(trId('action_failed_try_again')), backgroundColor: AppColors.accent),
        );
      }
    } finally {
      if (mounted) setState(() => _forwarding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy, h:mm a');

    return BlocListener<IssueDetailBloc, IssueDetailState>(
      listener: (context, state) {
        if (state is IssueDetailActionSuccess) {
          SuccessSnackbar.show(
            context,
            title: trId('success'),
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
            SnackBar(content: Text(state.message), backgroundColor: AppColors.danger),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(trId('issue_details')),
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The way back into the Complaint Box. This screen shows what
                  // has happened; that one shows what the member can still do
                  // about it — who to ring, what to write, whether to hand it
                  // to the club. Without this link a report is somewhere to
                  // look rather than somewhere to act.
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => context.push(
                        '/complaints/${_currentIssue.id}'
                        '?category=${_currentIssue.category}',
                      ),
                      icon: const Icon(Icons.support_agent_rounded),
                      label: Text(trId('what_next')),
                    ),
                  ),
                  SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(_currentIssue.categoryEmoji, style: TextStyle(fontSize: 40)),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentIssue.categoryLabel(_lang),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              fmt.format(_currentIssue.createdAt.toLocal()),
                              style: TextStyle(color: AppColors.textSecondary.withOpacity(0.6), fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      _StatusBadge(issue: _currentIssue, lang: _lang),
                    ],
                  ),
                  SizedBox(height: 24),
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
                          child: Icon(Icons.broken_image, color: AppColors.textSecondary, size: 50),
                        ),
                      ),
                    ),
                    SizedBox(height: 24),
                  ],
                  Text(
                    trId('description_2'),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    _currentIssue.displayDescription(_lang),
                    style: TextStyle(fontSize: 16, height: 1.5),
                  ),
                  SizedBox(height: 32),
                  Divider(),
                  SizedBox(height: 16),
                  Text(
                    trId('actions'),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  if (_currentIssue.status != 'RESOLVED') ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.check_circle_outline),
                        label: Text(trId('mark_as_resolved')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: AppColors.background,
                          padding: EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: () {
                          context.read<IssueDetailBloc>().add(IssueMarkResolvedRequested(_currentIssue.id));
                        },
                      ),
                    ),
                    SizedBox(height: 16),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: _forwarding
                          ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.background))
                          : Icon(Icons.send_rounded),
                      label: Text(trId('forward_to_department')),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.background,
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: _forwarding ? null : _forwardToDepartment,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    trId('an_ai_drafted_complaint_with_your_location_will_be_sent'),
                    style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 40),
                ],
              ),
            ),
            BlocBuilder<IssueDetailBloc, IssueDetailState>(
              builder: (context, state) {
                if (state is IssueDetailLoading) {
                  return Container(
                    color: Colors.black26,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return SizedBox.shrink();
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
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
