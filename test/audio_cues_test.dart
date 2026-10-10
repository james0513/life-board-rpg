import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_graybox/domain/models/battle.dart';
import 'package:life_graybox/domain/models/shop_item.dart';
import 'package:life_graybox/presentation/services/battle_audio_cues.dart';

void main() {
  test('all jobs, actions and weapons resolve to an existing sound', () {
    final root = jsonDecode(File('assets/data/jobs.json').readAsStringSync()) as Map<String, dynamic>;
    final jobs = root['jobs'] as List;
    expect(jobs, isNotEmpty);
    for (final job in jobs) {
      for (final action in BattleAction.values) {
        for (final weapon in ['none', ...shopCatalog.where((i) => i.kind == ShopKind.weapon).map((i) => i.id)]) {
          final cue = playerActionCue(action, weapon, job['id'] as String);
          expect(File('assets/audio/sfx/$cue.wav').existsSync(), isTrue, reason: cue);
        }
      }
    }
  });
  test('all chapters use distinct available music', () {
    final tracks = {for (var stage = 1; stage <= 6; stage++) stageMusic(stage)};
    expect(tracks.length, 6);
    for (final track in [...tracks, 'battle', 'boss']) {
      expect(File('assets/audio/music/${track}_loop.wav').existsSync(), isTrue);
    }
    expect(playerActionCue(BattleAction.frost, 'none', 'student'), 'cast_ice');
    expect(playerActionCue(BattleAction.heal, 'none', 'student'), 'cast_heal');
    expect(playerActionCue(BattleAction.burst, 'none', 'student'), 'cast_burst');
  });
}
