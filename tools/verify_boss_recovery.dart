// Retry catch-up is deterministic earned progress, not an automatic boss win.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../lib/domain/models/battle.dart';
import '../lib/domain/models/card_battle.dart';
import 'verify_card_battle.dart' show CardCampaignPolicy;
import '../lib/domain/models/player.dart';
import '../lib/domain/models/life_progress.dart';
import '../lib/domain/models/save_data.dart';
import '../lib/domain/models/stage.dart';
import '../lib/domain/services/stage_service.dart';

void main() {
  final stages = StageService(
    (jsonDecode(File('assets/data/stages.json').readAsStringSync()) as List)
        .map((j) => GameStage.fromJson(Map<String, dynamic>.from(j)))
        .toList(),
  );
  final jobs =
      (jsonDecode(File('assets/data/jobs.json').readAsStringSync())['jobs']
              as List)
          .map((j) => j['id'] as String)
          .toSet();
  var checks = 0, maxRetries = 0;
  void check(bool b, String s) {
    checks++;
    if (!b) throw StateError(s);
  }

  for (var version = 1; version <= 8; version++) {
    final raw = ' {"schemaVersion":$version,"untouched":true} ';
    check(
      legacySnapshotForV28Backup(raw) == raw,
      'legacy raw backup preserves exact bytes',
    );
  }
  check(
    legacySnapshotForV28Backup('{"schemaVersion":9}') == null,
    'new saves do not replace backup',
  );
  check(
    legacySnapshotForV28Backup('broken') == null,
    'malformed snapshot does not throw',
  );
  for (final extremeMeters in [false, true]) {
    for (final seed in [1, 7, 19, 42, 99]) {
      var p = Player(
        money: 0,
        stamina: 0,
        intelligence: 0,
        charm: 0,
        morality: 0,
        inventory: const {},
        turnsPerStage: 4,
        life: extremeMeters
            ? const LifeProgress(eq: 0, stress: 100)
            : const LifeProgress(),
      );
      for (var stage = 1; stage <= 6; stage++) {
        for (var i = 0; i < 4; i++) p = StageService.completeMapTurn(p);
        check(p.bossPending, 'four settled turns must trigger boss');
        var retries = 0;
        while (p.bossPending && retries < 220) {
          final before = p;
          final b = CardBattleSession(
            p,
            stages.current(p).boss,
            random: Random(seed + retries),
          );
          final policy = CardCampaignPolicy();
          policy.fight(b);
          check(
            policy.cardMoves > 0 && policy.impactChecks > 0,
            'boss retry uses cards and deferred impacts',
          );
          check(!b.active, 'battle terminal');
          final reward = b.claim();
          check(reward != null && b.claim() == null, 'one reward only');
          p = stages.settle(
            before
                .apply(reward!)
                .gainExperience(b.earnedExperience)
                .copyWith(inventory: b.remainingInventory),
            b.enemy,
            b.status,
          );
          check(
            p.money ==
                before.money +
                    (b.status == BattleStatus.won
                        ? b.enemy.reward
                        : b.timedOut
                        ? b.resultMoney
                        : 0),
            'no defeat loss or money outside victory/explicit timeout consolation',
          );
          check(p.life.turns == before.life.turns, 'retry does not age player');
          if (b.status == BattleStatus.lost || b.timedOut) {
            check(
              p.clearedStages == before.clearedStages && p.bossPending,
              'defeat never advances',
            );
            check(
              p.stamina == before.stamina + 2 &&
                  p.intelligence == before.intelligence + 2,
              'one catch-up reward',
            );
          }
          final raw = SaveData(p, DateTime.utc(2026)).encode();
          p = SaveData.decode(raw, jobs).player;
          check(
            SaveData(p, DateTime.utc(2026)).encode() == raw,
            'reload adds no reward',
          );
          retries++;
        }
        check(
          p.clearedStages == stage,
          'zero-money/all-zero-stat build (extreme meters: $extremeMeters) eventually wins stage $stage',
        );
        maxRetries = max(maxRetries, retries);
      }
      check(p.campaignComplete, 'six genuine wins');
    }
  }
  print(
    'PASS card boss recovery: $checks checks, 10 zero-money/all-zero-stat six-stage runs (5 with EQ 0/stress 100) at 4 map turns; max $maxRetries attempts in a stage. No Flutter/audio test.',
  );
}
