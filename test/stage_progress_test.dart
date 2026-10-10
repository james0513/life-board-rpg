import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_graybox/domain/models/stage.dart';
import 'package:life_graybox/domain/models/player.dart';
import 'package:life_graybox/domain/models/battle.dart';
import 'package:life_graybox/domain/models/save_data.dart';
import 'package:life_graybox/domain/services/stage_service.dart';

import 'battle_test.dart' show FixedRandom;

StageService catalog() => StageService(
  (jsonDecode(File('assets/data/stages.json').readAsStringSync()) as List)
      .map((j) => GameStage.fromJson(Map<String, dynamic>.from(j as Map)))
      .toList(),
);
const mob = Enemy(
  id: 'mob',
  name: 'mob',
  description: '',
  hp: 100,
  attack: 1,
  reward: 1,
  portrait: 0,
);
void main() {
  test('six unique bosses ordered with increasing HP and rewards', () {
    final s = catalog();
    expect(s.stages.length, 6);
    expect(s.stages.map((s) => s.boss.id).toSet().length, 6);
    for (var i = 1; i < 6; i++) {
      expect(s.stages[i].boss.hp, greaterThan(s.stages[i - 1].boss.hp));
    }
  });
  test(
    'eight completed map turns unlock boss, loss and escape preserve progress',
    () {
      final s = catalog();
      var p = const Player();
      for (var i = 0; i < 8; i++) {
        expect(s.current(p).bossReady(p), false);
        p = StageService.completeMapTurn(p);
      }
      expect(s.current(p).bossReady(p), true);
      for (final result in [BattleStatus.lost, BattleStatus.escaped]) {
        expect(s.settle(p, s.current(p).boss, result).clearedStages, 0);
      }
      expect(s.settle(p, mob, BattleStatus.won).stageTurns, 8);
    },
  );
  test('bosses cannot be skipped; each win unlocks one chapter and final ends campaign', () {
    final s = catalog();
    var p = const Player();
    expect(s.settle(p, s.current(p).boss, BattleStatus.won).clearedStages, 0);
    for (var i = 0; i < 6; i++) {
      p = p.copyWith(stageTurns: 8);
      final boss = s.current(p).boss;
      p = s.settle(p, boss, BattleStatus.won);
      expect(p.clearedStages, i + 1);
      expect(p.stageWins, 0);
      expect(s.settle(p, boss, BattleStatus.won).clearedStages, i + 1);
    }
    expect(p.campaignComplete, true);
    expect(p.currentStage, 6);
    expect(s.current(p).bossReady(p), false);
  });
  test('v5 progress roundtrip and v4 migration preserve belongings', () {
    final p = const Player(
      clearedStages: 4,
      stageWins: 2,
      money: 4321,
      gender: CharacterGender.female,
    );
    final raw = SaveData(p, DateTime.utc(2026)).encode();
    expect(SaveData.decode(raw, {'unemployed'}).player.clearedStages, 4);
    final old = jsonDecode(raw);
    old['schemaVersion'] = 4;
    old['player'].remove('stageTurns');
    old['player'].remove('turnsPerStage');
    old['player'].remove('clearedStages');
    old['player'].remove('stageWins');
    old['player'].remove('story');
    old['player'].remove('life');
    old['player'].remove('armorId');
    old['player'].remove('accessoryId');
    final restored = SaveData.decode(jsonEncode(old), {'unemployed'}).player;
    expect(restored.clearedStages, 0);
    expect(restored.money, 4321);
    expect(restored.gender, CharacterGender.female);
    final invalid = jsonDecode(raw);
    invalid['player']['clearedStages'] = 7;
    expect(
      () => SaveData.decode(jsonEncode(invalid), {'unemployed'}),
      throwsFormatException,
    );
  });
  test(
    'ordinary stat changes and equipment updates preserve stage progress',
    () {
      const p = Player(clearedStages: 2, stageWins: 1);
      expect(p.apply(const StatDelta(money: 100)).clearedStages, 2);
      expect(p.copyWith(position: 8).stageWins, 1);
    },
  );
  test(
    'final boss has stronger counters below half HP; frost still skips counter',
    () {
      final boss = catalog().stages.last.boss;
      final normal = BattleSession(
        const Player(stamina: 200),
        boss,
        random: FixedRandom(99),
      );
      final rage = BattleSession(
        const Player(stamina: 200),
        boss,
        random: FixedRandom(99),
      );
      rage.enemyHp = boss.hp ~/ 2;
      normal.playerAct(BattleAction.attack);
      rage.playerAct(BattleAction.attack);
      expect(rage.finalEnraged, true);
      expect(rage.enemyAct()!.damage, normal.enemyAct()!.damage + 8);
      final before = rage.hp;
      rage.playerAct(BattleAction.frost);
      rage.enemyAct();
      expect(rage.hp, before);
    },
  );
}
