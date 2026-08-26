import 'dart:convert';

import 'package:flutter/services.dart';

/// Caps input at [maxBytes] encoded as UTF-8.
///
/// Character count is the wrong measure here: the group name has to fit the
/// BLE scan response, which is a byte budget (spec section 5.1).
class Utf8ByteLimitFormatter extends TextInputFormatter {
  const Utf8ByteLimitFormatter(this.maxBytes);

  final int maxBytes;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (utf8.encode(newValue.text).length <= maxBytes) return newValue;

    // Trim whole code points until the encoding fits, so a multi-byte
    // character is never cut in half. Uses runes rather than
    // `String.characters` to avoid depending on package:characters.
    var text = newValue.text;
    while (text.isNotEmpty && utf8.encode(text).length > maxBytes) {
      final runes = text.runes.toList()..removeLast();
      text = String.fromCharCodes(runes);
    }

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
