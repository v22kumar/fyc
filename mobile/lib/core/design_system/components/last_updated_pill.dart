import 'package:flutter/material.dart';
import 'package:fyc_connect/core/l10n/tr.dart';
import '../../theme/app_theme.dart';

/// A small "Updated Nm ago" marker for pull-to-refresh surfaces, so a user
/// knows how fresh the data is. Relative, localized.
class LastUpdatedPill extends StatelessWidget {
  final DateTime timestamp;
  const LastUpdatedPill({super.key, required this.timestamp});

  String _label() {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) {
      return tr(
          en: 'Updated just now',
          ta: 'இப்போது புதுப்பிக்கப்பட்டது',
          hi: 'अभी अपडेट किया गया',
          ml: 'ഇപ്പോൾ അപ്ഡേറ്റ് ചെയ്തു');
    }
    if (diff.inHours < 1) {
      final m = diff.inMinutes;
      return tr(
          en: 'Updated ${m}m ago',
          ta: '$m நிமிடங்களுக்கு முன் புதுப்பிக்கப்பட்டது',
          hi: '$m मिनट पहले अपडेट',
          ml: '$m മിനിറ്റ് മുമ്പ് അപ്ഡേറ്റ്');
    }
    if (diff.inDays < 1) {
      final h = diff.inHours;
      return tr(
          en: 'Updated ${h}h ago',
          ta: '$h மணி நேரத்திற்கு முன் புதுப்பிக்கப்பட்டது',
          hi: '$h घंटे पहले अपडेट',
          ml: '$h മണിക്കൂർ മുമ്പ് അപ്ഡേറ്റ്');
    }
    final d = diff.inDays;
    return tr(
        en: 'Updated ${d}d ago',
        ta: '$d நாட்களுக்கு முன் புதுப்பிக்கப்பட்டது',
        hi: '$d दिन पहले अपडेट',
        ml: '$d ദിവസം മുമ്പ് അപ്ഡേറ്റ്');
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.schedule_rounded, size: 13, color: context.cTextSecondary),
        const SizedBox(width: 5),
        Text(_label(),
            style: TextStyle(fontSize: 11.5, color: context.cTextSecondary)),
      ],
    );
  }
}
