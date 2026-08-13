import 'package:flutter/material.dart';

import '../../extensions/eos_context.dart';

class EosSelectField<T> extends StatelessWidget {
  const EosSelectField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
  });

  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    // Avoid DropdownButton assertion when value is missing or duplicated in items.
    final matchCount = value == null ? 0 : items.where((i) => i.value == value).length;
    final effectiveValue = matchCount == 1 ? value : null;

    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: effectiveValue,
          hint: hint != null ? Text(hint!) : null,
          items: items,
          onChanged: onChanged,
          style: context.eosText.bodyLarge,
        ),
      ),
    );
  }
}
