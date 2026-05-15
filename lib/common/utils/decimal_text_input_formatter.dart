import 'package:flutter/services.dart';

class DecimalTextInputFormatter extends TextInputFormatter {
  const DecimalTextInputFormatter({required this.decimalDigits});

  final int decimalDigits;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final sanitized = sanitize(newValue.text, decimalDigits: decimalDigits);
    final selectionEnd = newValue.selection.end;
    final safeSelectionEnd = selectionEnd < 0
        ? newValue.text.length
        : selectionEnd.clamp(0, newValue.text.length).toInt();
    final prefix = sanitize(
      newValue.text.substring(0, safeSelectionEnd),
      decimalDigits: decimalDigits,
    );
    return TextEditingValue(
      text: sanitized,
      selection: TextSelection.collapsed(
        offset: prefix.length.clamp(0, sanitized.length).toInt(),
      ),
    );
  }

  static String sanitize(String value, {required int decimalDigits}) {
    final buffer = StringBuffer();
    var hasDecimalPoint = false;
    var decimalCount = 0;

    for (final codeUnit in value.codeUnits) {
      final char = String.fromCharCode(codeUnit);
      if (char == '.') {
        if (hasDecimalPoint) {
          continue;
        }
        hasDecimalPoint = true;
        buffer.write(buffer.isEmpty ? '0.' : '.');
        continue;
      }
      if (codeUnit < 48 || codeUnit > 57) {
        continue;
      }
      if (hasDecimalPoint) {
        if (decimalCount >= decimalDigits) {
          continue;
        }
        decimalCount += 1;
      }
      buffer.write(char);
    }

    return buffer.toString();
  }
}
