// Future Flutter test entry point for the exact deterministic domain cases.
// This file is parser-checked by the pure-Dart release gate. It must not be
// reported as executed until a separately authorized Flutter test run succeeds.
import 'package:flutter_test/flutter_test.dart';

import '../tools/verify_card_battle.dart' show cardRegressionCases;

void main() {
  for (final entry in cardRegressionCases.entries) {
    test(entry.key, entry.value);
  }
}
