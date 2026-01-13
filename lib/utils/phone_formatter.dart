import 'dart:math';
import 'package:flutter/services.dart';

class PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }

    final maxDigits = digits.startsWith('0') ? 11 : 10;
    final trimmed = digits.substring(0, min(digits.length, maxDigits));

    final buffer = StringBuffer();
    int idx = 0;
    if (trimmed.startsWith('0')) {
      buffer.write('0');
      idx = 1;
      if (trimmed.length > 1) buffer.write(' ');
    }

    final groups = [3, 3, 2, 2];
    int groupIndex = 0;
    while (idx < trimmed.length && groupIndex < groups.length) {
      final size = groups[groupIndex];
      final end = min(idx + size, trimmed.length);
      buffer.write(trimmed.substring(idx, end));
      idx = end;
      groupIndex++;
      if (idx < trimmed.length) buffer.write(' ');
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

String normalizePhoneNumber(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 11 && digits.startsWith('0')) {
    return digits.substring(1);
  }
  return digits;
}
