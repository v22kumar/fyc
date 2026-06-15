import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/storage/local_storage.dart';
import '../../../service_locator.dart';

class ComingSoonScreen extends StatelessWidget {
  final String title;
  final String emoji;
  final String? subtitleTa;
  final String? subtitleEn;

  const ComingSoonScreen({
    super.key,
    required this.title,
    required this.emoji,
    this.subtitleTa,
    this.subtitleEn,
  });

  @override
  Widget build(BuildContext context) {
    final lang = sl<LocalStorage>().getLang();
    final subtitle = lang == 'ta'
        ? (subtitleTa ?? subtitleEn ?? 'விரைவில் வருகிறது. தொடர்ந்து பின்தொடரவும்!')
        : (subtitleEn ?? 'This feature is coming soon. Stay tuned!');

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 72)),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              OutlinedButton(
                onPressed: () => context.pop(),
                child: Text(lang == 'ta' ? 'திரும்பு' : 'Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
