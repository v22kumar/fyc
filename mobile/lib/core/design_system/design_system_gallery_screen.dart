import 'package:flutter/material.dart';
import 'tokens.dart';
import 'typography.dart';
import 'components/ds_badge.dart';
import 'components/ds_button.dart';
import 'components/ds_card.dart';
import 'components/ds_chip.dart';
import 'components/ds_empty_state.dart';
import 'components/ds_error_state.dart';
import 'components/ds_input.dart';
import 'components/ds_skeleton.dart';
import 'shell/app_shell_v2.dart';

/// Sprint 1 deliverable: a single screen that renders every design-system
/// component in every state, so the library can be reviewed without hunting
/// through feature screens. NOT linked from any production screen or the
/// main nav — reachable only via the `/design-system` route, for design/QA
/// review during this sprint.
class DesignSystemGalleryScreen extends StatefulWidget {
  const DesignSystemGalleryScreen({super.key});

  @override
  State<DesignSystemGalleryScreen> createState() => _DesignSystemGalleryScreenState();
}

class _DesignSystemGalleryScreenState extends State<DesignSystemGalleryScreen> {
  bool _dark = false;
  String _lang = 'en';
  bool _chipSelected = false;
  String? _dropdownValue;
  String? _dateValue;

  ThemeData get _themeData {
    final brightness = _dark ? Brightness.dark : Brightness.light;
    final bg = _dark ? DSColors.backgroundDark : DSColors.backgroundLight;
    final text = _dark ? DSColors.textPrimaryDark : DSColors.textPrimaryLight;
    final secondary = _dark ? DSColors.textSecondaryDark : DSColors.textSecondaryLight;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      textTheme: DSTypography.textTheme(_lang, color: text, secondaryColor: secondary),
      colorScheme: ColorScheme.fromSeed(seedColor: DSColors.navy700, brightness: brightness),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _themeData,
      child: Builder(builder: (context) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Design System Gallery'),
            actions: [
              IconButton(
                tooltip: 'Toggle dark mode',
                icon: Icon(_dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
                onPressed: () => setState(() => _dark = !_dark),
              ),
              PopupMenuButton<String>(
                tooltip: 'Language',
                initialValue: _lang,
                onSelected: (v) => setState(() => _lang = v),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'en', child: Text('EN')),
                  PopupMenuItem(value: 'ta', child: Text('தமிழ்')),
                  PopupMenuItem(value: 'hi', child: Text('हिंदी')),
                  PopupMenuItem(value: 'ml', child: Text('മലയാളം')),
                ],
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(DSSpacing.sm),
            children: [
              const _SectionLabel('Buttons'),
              DSButton.filled(label: 'Filled', onPressed: () {}),
              const SizedBox(height: 8),
              DSButton.outlined(label: 'Outlined', onPressed: () {}),
              const SizedBox(height: 8),
              DSButton.tonal(label: 'Tonal', onPressed: () {}),
              const SizedBox(height: 8),
              DSButton.text(label: 'Text', onPressed: () {}),
              const SizedBox(height: 8),
              DSButton.danger(label: 'Danger', icon: Icons.delete_rounded, onPressed: () {}),
              const SizedBox(height: 8),
              const DSButton(label: 'Loading', onPressed: null, loading: true),
              const SizedBox(height: 8),
              const DSButton(label: 'Disabled', onPressed: null),
              const SizedBox(height: DSSpacing.md),

              const _SectionLabel('Cards'),
              for (final kind in DSCardKind.values) ...[
                DSCard(
                  kind: kind,
                  showAccentBar: true,
                  onTap: () {},
                  child: Row(
                    children: [
                      DSCardIcon(kind: kind),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(kind.name.toUpperCase(), style: Theme.of(context).textTheme.titleMedium),
                            Text('Sample $kind card body copy.', style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: DSSpacing.sm),

              const _SectionLabel('Inputs'),
              const DSSearchField(hint: 'Search members, events, teams…'),
              const SizedBox(height: 12),
              DSDropdown<String>(
                label: 'Category',
                value: _dropdownValue,
                hint: 'Choose one',
                items: const [
                  DropdownMenuItem(value: 'cricket', child: Text('Cricket')),
                  DropdownMenuItem(value: 'events', child: Text('Events')),
                  DropdownMenuItem(value: 'green', child: Text('Green FYC')),
                ],
                onChanged: (v) => setState(() => _dropdownValue = v),
              ),
              const SizedBox(height: 12),
              DSOtpField(length: 6, onCompleted: (_) {}),
              const SizedBox(height: 12),
              DSDateField(
                value: _dateValue,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) setState(() => _dateValue = '${picked.year}-${picked.month}-${picked.day}');
                },
              ),
              const SizedBox(height: 12),
              DSLocationField(onTap: () {}),
              const SizedBox(height: DSSpacing.md),

              const _SectionLabel('Chips'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  DSChip.status('LIVE'),
                  DSChip.status('UPCOMING'),
                  DSChip.status('COMPLETED'),
                  const DSChip(label: 'Cricket', kind: DSChipKind.sport, icon: Icons.sports_cricket_rounded),
                  const DSChip(label: 'O+', kind: DSChipKind.bloodGroup),
                  const DSChip(label: 'Environment', kind: DSChipKind.category),
                  const DSChip(label: 'Manager', kind: DSChipKind.role),
                  DSChip(
                    label: _chipSelected ? 'Selected' : 'Tap me',
                    selected: _chipSelected,
                    onTap: () => setState(() => _chipSelected = !_chipSelected),
                  ),
                ],
              ),
              const SizedBox(height: DSSpacing.md),

              const _SectionLabel('Badges'),
              const Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  DSBadge(kind: DSBadgeKind.live),
                  DSBadge(kind: DSBadgeKind.urgent),
                  DSBadge(kind: DSBadgeKind.isNew),
                  DSBadge(kind: DSBadgeKind.verified),
                  DSBadge(kind: DSBadgeKind.closed),
                  DSBadge(kind: DSBadgeKind.volunteer),
                ],
              ),
              const SizedBox(height: DSSpacing.md),

              const _SectionLabel('Empty state'),
              SizedBox(
                height: 340,
                child: DSEmptyState(
                  icon: Icons.forum_rounded,
                  title: 'No community updates yet.',
                  message: 'Be the first to share something with the community.',
                  primaryLabel: 'Create Post',
                  onPrimary: () {},
                  secondaryLabel: 'Refresh',
                  onSecondary: () {},
                ),
              ),
              const SizedBox(height: DSSpacing.md),

              const _SectionLabel('Skeleton loading'),
              const DSSkeletonList(itemCount: 2),
              const SizedBox(height: DSSpacing.md),

              const _SectionLabel('Error state'),
              SizedBox(
                height: 300,
                child: DSErrorState(
                  message: "We couldn't load your journey.",
                  onRetry: () {},
                  secondaryLabel: 'Go Home',
                  onSecondary: () {},
                ),
              ),
              const SizedBox(height: DSSpacing.md),

              const _SectionLabel('Navigation shell preview'),
              DSButton.outlined(
                label: 'Open Home / Play / Serve / Me shell',
                icon: Icons.dashboard_customize_rounded,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => Theme(data: _themeData, child: const AppShellV2())),
                ),
              ),
              const SizedBox(height: DSSpacing.xl),
            ],
          ),
        );
      }),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: context.dsAccent, letterSpacing: 0.6),
      ),
    );
  }
}
