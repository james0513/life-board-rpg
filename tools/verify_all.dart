// One local domain-validation command. This does not invoke Flutter or a browser.
import 'dart:io';

void main() {
  final root = File.fromUri(Platform.script).parent.parent.path;
  const scripts = [
    'verify_dart_syntax.dart',
    'verify_life_core.dart',
    'verify_card_battle.dart',
    'verify_life_campaign.dart',
    'verify_age_boards.dart',
    'verify_story_core.dart',
    'verify_review_scenarios.dart',
    'verify_integrated_life.dart',
    'validate_stage_lifecycle.dart',
    'verify_equipment_classes.dart',
    'verify_cast_audio.dart',
    'verify_boss_recovery.dart',
  ];
  for (final script in scripts) {
    stdout.writeln('\n=== $script ===');
    final result = Process.runSync(Platform.resolvedExecutable, [
      'tools/$script',
    ], workingDirectory: root);
    stdout.write(result.stdout);
    stderr.write(result.stderr);
    if (result.exitCode != 0) {
      stderr.writeln('FAILED: $script');
      exit(result.exitCode);
    }
  }
  stdout.writeln(
    '\nPASS: all ${scripts.length} local Dart suites. '
    'Flutter compilation, widget tests and browser verification remain separate.',
  );
}
