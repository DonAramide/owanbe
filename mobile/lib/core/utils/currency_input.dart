import 'package:flutter/services.dart';

/// Formats digits as Nigerian Naira with thousand separators (no kobo).
String formatNairaDigits(String digits) {
  if (digits.isEmpty) return '';
  final n = int.tryParse(digits) ?? 0;
  return n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
}

/// Display string for naira input fields (no kobo decimals).
String nairaInputFromMinor(int minor) => formatNairaDigits((minor ~/ 100).toString());

/// Parses a formatted naira string to minor units (kobo).
int parseNairaInputToMinor(String text) {
  final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return 0;
  final naira = int.tryParse(digits) ?? 0;
  return naira * 100;
}

/// Keeps only digits and inserts comma separators while typing.
class NairaInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '', selection: TextSelection.collapsed(offset: 0));
    }
    final formatted = formatNairaDigits(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
