import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_graybox/data/preferences_save_store.dart';
import 'package:life_graybox/domain/models/acceptance_scenarios.dart';
import 'package:life_graybox/domain/models/save_data.dart';

void main() {
  test('sandbox key differs from unchanged production save key', () {
    expect(PreferencesSaveStore.key, 'life_graybox.save.v1');
    expect(acceptanceSaveKey, isNot(PreferencesSaveStore.key));
  });
  test('all sandbox fixtures are valid schema8 saves', () {
    final rows = (jsonDecode(File('assets/data/jobs.json').readAsStringSync()) as Map)['jobs'] as List;
    final ids = rows.map((row) => row['id'] as String).toSet();
    for (final id in acceptanceScenarioLabels.keys) {
      final player = acceptanceScenario(id);
      final restored = SaveData.decode(SaveData(player, DateTime.utc(2026)).encode(), ids).player;
      expect(restored.life.age, player.life.age);
      expect(restored.story.children, player.story.children);
      expect(restored.clearedStages, player.clearedStages);
    }
  });
}
