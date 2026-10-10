import 'package:flutter_test/flutter_test.dart';

import '../tools/verify_story_core.dart' as story_checks;

void main() {
  story_checks.runStoryChecks(register: (name, body) => test(name, body));
}
