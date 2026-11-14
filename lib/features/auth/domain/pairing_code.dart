/// TV pairing code input rules (spec-04 §4.3): exactly 6 characters `[a-zA-Z0-9]`, upper-cased before sending.
const pairingCodeLength = 6;

final _pairingCode = RegExp('^[a-zA-Z0-9]{$pairingCodeLength}\$');

/// Returns the code to send, or null when [input] is not a valid code. Surrounding whitespace is ignored.
String? normalizePairingCode(String input) {
  final code = input.trim();
  return _pairingCode.hasMatch(code) ? code.toUpperCase() : null;
}
