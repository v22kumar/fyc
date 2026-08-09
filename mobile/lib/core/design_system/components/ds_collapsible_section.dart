import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// A section with a tappable header that expands/collapses its [child] with a
/// smooth height animation. Used for the Home daily cards (news, kural, info).
class DSCollapsibleSection extends StatefulWidget {
  final String title;
  final IconData? icon;
  final Widget child;
  final bool initiallyExpanded;

  const DSCollapsibleSection({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.initiallyExpanded = true,
  });

  @override
  State<DSCollapsibleSection> createState() => _DSCollapsibleSectionState();
}

class _DSCollapsibleSectionState extends State<DSCollapsibleSection> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: context.cText),
                  ),
                ),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.keyboard_arrow_down_rounded,
                      color: context.cTextSecondary),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: _expanded
              ? widget.child
              : const SizedBox(width: double.infinity, height: 0),
        ),
      ],
    );
  }
}
