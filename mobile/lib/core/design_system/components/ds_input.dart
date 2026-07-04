import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../tokens.dart';

InputDecoration _dsDecoration(
  BuildContext context, {
  String? hint,
  Widget? prefixIcon,
  Widget? suffixIcon,
}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(DSRadius.input),
    borderSide: BorderSide(color: context.dsBorder),
  );
  return InputDecoration(
    hintText: hint,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: context.dsSurface,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: DSSpacing.sm, vertical: 14),
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(borderSide: BorderSide(color: context.dsAccent, width: 1.6)),
  );
}

/// Universal search field — the single search entry point used across the
/// app (spec §9: one search, not many searches).
class DSSearchField extends StatelessWidget {
  final TextEditingController? controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final bool readOnly;

  const DSSearchField({
    super.key,
    this.controller,
    this.hint = 'Search',
    this.onChanged,
    this.onTap,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      onChanged: onChanged,
      decoration: _dsDecoration(context, hint: hint, prefixIcon: const Icon(Icons.search_rounded)),
    );
  }
}

/// A labelled dropdown, generic over the value type.
class DSDropdown<T> extends StatelessWidget {
  final String? label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? hint;

  const DSDropdown({
    super.key,
    this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: context.dsTextSecondary)),
          const SizedBox(height: 6),
        ],
        DropdownButtonFormField<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          decoration: _dsDecoration(context, hint: hint),
        ),
      ],
    );
  }
}

/// OTP entry — a fixed number of single-digit boxes with auto-advance.
class DSOtpField extends StatefulWidget {
  final int length;
  final ValueChanged<String> onCompleted;
  final ValueChanged<String>? onChanged;

  const DSOtpField({super.key, this.length = 6, required this.onCompleted, this.onChanged});

  @override
  State<DSOtpField> createState() => _DSOtpFieldState();
}

class _DSOtpFieldState extends State<DSOtpField> {
  late final List<TextEditingController> _controllers =
      List.generate(widget.length, (_) => TextEditingController());
  late final List<FocusNode> _nodes = List.generate(widget.length, (_) => FocusNode());

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _onChanged(int index, String value) {
    if (value.isNotEmpty && index < widget.length - 1) {
      _nodes[index + 1].requestFocus();
    }
    final code = _controllers.map((c) => c.text).join();
    widget.onChanged?.call(code);
    if (code.length == widget.length) widget.onCompleted(code);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(widget.length, (i) {
        return SizedBox(
          width: 44,
          height: 52,
          child: TextField(
            controller: _controllers[i],
            focusNode: _nodes[i],
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 1,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: Theme.of(context).textTheme.titleLarge,
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: context.dsSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.dsBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.dsAccent, width: 1.6),
              ),
            ),
            onChanged: (v) => _onChanged(i, v),
          ),
        );
      }),
    );
  }
}

/// A tap-to-pick date field. Presentational: the caller supplies
/// [onTap] (typically `showDatePicker`) and the already-formatted [value].
class DSDateField extends StatelessWidget {
  final String? value;
  final String hint;
  final VoidCallback onTap;

  const DSDateField({super.key, this.value, this.hint = 'Select date', required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DSRadius.input),
      child: InputDecorator(
        decoration: _dsDecoration(context, prefixIcon: const Icon(Icons.calendar_today_rounded)),
        child: Text(
          value ?? hint,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: value == null ? context.dsTextSecondary : context.dsText,
              ),
        ),
      ),
    );
  }
}

/// A tap-to-pick location field. Presentational, same contract as
/// [DSDateField] — the caller wires the actual picker/geocoding.
class DSLocationField extends StatelessWidget {
  final String? value;
  final String hint;
  final VoidCallback onTap;

  const DSLocationField({super.key, this.value, this.hint = 'Add location', required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DSRadius.input),
      child: InputDecorator(
        decoration: _dsDecoration(context, prefixIcon: const Icon(Icons.place_rounded)),
        child: Text(
          value ?? hint,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: value == null ? context.dsTextSecondary : context.dsText,
              ),
        ),
      ),
    );
  }
}
