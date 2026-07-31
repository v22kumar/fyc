import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../service_locator.dart';
import '../../domain/entities/event_entity.dart';

class EventRegistrationsScreen extends StatefulWidget {
  final EventEntity event;
  final String lang;

  const EventRegistrationsScreen({
    super.key,
    required this.event,
    required this.lang,
  });

  @override
  State<EventRegistrationsScreen> createState() => _EventRegistrationsScreenState();
}

class _EventRegistrationsScreenState extends State<EventRegistrationsScreen> {
  List<dynamic>? _registrations;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final response = await sl<ApiClient>().dio.get('${ApiConstants.events}/${widget.event.id}/registrations');
      if (mounted) {
        setState(() {
          _registrations = response.data as List<dynamic>;
        });
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load registrations. ${e.message}';
        });
      }
    }
  }

  Future<void> _downloadCSV() async {
    final url = Uri.parse('${ApiConstants.events}/${widget.event.id}/registrations.csv');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open CSV link')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ta = widget.lang == 'ta';
    final title = ta && widget.event.titleTa != null ? widget.event.titleTa! : widget.event.titleEn;

    return Scaffold(
      appBar: AppBar(
        title: Text('Registrations', style: const TextStyle(fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Download CSV',
            onPressed: _downloadCSV,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    }
    if (_registrations == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_registrations!.isEmpty) {
      return const Center(child: Text('No registrations yet.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _registrations!.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final reg = _registrations![index] as Map<String, dynamic>;
        final name = reg['name'] as String? ?? 'Unknown';
        final mobile = reg['mobile_number'] as String? ?? '-';
        final gender = reg['gender'] as String? ?? '-';
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('Mobile: $mobile • Gender: $gender'),
          leading: CircleAvatar(
            backgroundColor: AppColors.primary.withOpacity(0.1),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(color: AppColors.primary),
            ),
          ),
        );
      },
    );
  }
}
