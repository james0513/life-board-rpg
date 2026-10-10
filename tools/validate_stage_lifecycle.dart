// Pure Dart verification of the fixed completed-map-turn stage lifecycle.
import 'dart:convert';
import 'dart:io';

import '../lib/domain/models/player.dart';
import '../lib/domain/models/stage.dart';
import '../lib/domain/models/save_data.dart';
import '../lib/domain/models/battle.dart';
import '../lib/domain/services/stage_service.dart';
import '../lib/domain/services/life_service.dart';

int checks = 0;
void check(bool test, String label) {
  checks++;
  if (!test) throw StateError(label);
}

void main() {
  final root = File.fromUri(Platform.script).parent.parent.path;
  final service = StageService(
    (jsonDecode(File('$root/assets/data/stages.json').readAsStringSync())
            as List)
        .map((j) => GameStage.fromJson(Map<String, dynamic>.from(j as Map)))
        .toList(),
  );
  const mob = Enemy(
    id: 'test',
    name: 'test',
    description: '',
    hp: 20,
    attack: 3,
    reward: 1,
    portrait: 0,
  );
  for (final length in [4, 8, 12]) {
    var p = service.configureTurns(const Player(), length);
    for (var stage = 1; stage <= 6; stage++) {
      for (var turn = 0; turn < length; turn++) {
        check(!p.bossPending, 'Not pending before final completed turn');
        check(
          service
                  .settle(p, service.current(p).boss, BattleStatus.won)
                  .clearedStages ==
              stage - 1,
          'Early win rejected',
        );
        final ordinary = service.settle(p, mob, BattleStatus.won);
        check(
          ordinary.stageTurns == p.stageTurns,
          'Battle win does not count map turn',
        );
        p = StageService.completeMapTurn(ordinary);
      }
      check(
        p.bossPending && service.current(p).bossReady(p),
        'Boss ready exactly at limit',
      );
      final ageBefore = p.life.turns;
      final encoded = SaveData(p, DateTime.utc(2026)).encode();
      p = SaveData.decode(encoded, {'unemployed'}).player;
      check(
        p.bossPending && p.turnsPerStage == length,
        'Pending/config survives reload',
      );
      check(
        StageService.completeMapTurn(p).stageTurns == length,
        'No map bypass after threshold',
      );
      for (final outcome in [
        BattleStatus.lost,
        BattleStatus.escaped,
        BattleStatus.active,
      ]) {
        final unchanged = service.settle(p, service.current(p).boss, outcome);
        check(
          unchanged.bossPending && unchanged.clearedStages == stage - 1,
          'Only victory advances',
        );
      }
      var blocked = false;
      try {
        service.configureTurns(p, 12);
      } on StateError {
        blocked = true;
      }
      check(blocked, 'Cannot move pending threshold');
      final boss = service.current(p).boss;
      p = service.settle(p, boss, BattleStatus.won);
      check(
        p.stageTurns == 0 && p.clearedStages == stage && p.position == 0,
        'One stage advances and resets map',
      );
      check(
        p.life.turns == ageBefore,
        'Boss retry settlement does not age player',
      );
      check(
        service.settle(p, boss, BattleStatus.won).clearedStages == stage,
        'Duplicate old boss cannot advance',
      );
    }
    check(p.campaignComplete && !p.bossPending, 'Final campaign completes');
    check(
      StageService.completeMapTurn(p).stageTurns == 0,
      'Postgame has no boss counter',
    );
    check(
      const LifeService().reincarnate(p).turnsPerStage == length,
      'Reincarnation retains configured pacing',
    );
  }
  final old = jsonDecode(
    SaveData(const Player(stageWins: 3), DateTime.utc(2026)).encode(),
  ) as Map<String, dynamic>;
  old['schemaVersion'] = 8;
  (old['player'] as Map).remove('stageTurns');
  (old['player'] as Map).remove('turnsPerStage');
  final migrated = SaveData.decode(jsonEncode(old), {'unemployed'}).player;
  check(migrated.bossPending, 'Legacy unlocked boss stays unlocked');
  const p = Player(stageTurns: 3, turnsPerStage: 4);
  check(
    p.apply(const StatDelta(stamina: 2)).stageTurns == 3,
    'Stat mutation preserves counter',
  );
  check(
    p.copyWith(jobId: 'student').turnsPerStage == 4,
    'Job mutation preserves config',
  );
  check(
    const LifeService().lifeAction(p, 'rest').stageTurns == 3,
    'Journal action is not a map turn',
  );
  for (var i = 1; i < 6; i++) {
    final before = service.scaleEnemy(mob, Player(clearedStages: i - 1));
    final after = service.scaleEnemy(mob, Player(clearedStages: i));
    check(
      after.hp > before.hp && after.attack > before.attack,
      'Each stage increases regular monster difficulty',
    );
  }
  final sourceEnemies = (jsonDecode(
    File('$root/assets/data/enemies.json').readAsStringSync(),
  ) as List).map((e) => Enemy.fromJson(Map<String, dynamic>.from(e as Map)));
  for (final enemy in sourceEnemies) {
    for (var stage = 1; stage < 6; stage++) {
      final earlier = service.scaleEnemy(
        enemy,
        Player(clearedStages: stage - 1),
      );
      final later = service.scaleEnemy(enemy, Player(clearedStages: stage));
      check(
        later.hp > earlier.hp && later.attack > earlier.attack,
        'Every real monster grows each stage',
      );
      check(
        later.specialName == enemy.specialName &&
            later.minTier == enemy.minTier &&
            later.maxSp == enemy.maxSp,
        'Scaling preserves enemy combat identity',
      );
    }
  }
  for (final value in [0, 3, 16, -1]) {
    final data = jsonDecode(
      SaveData(const Player(), DateTime.utc(2026)).encode(),
    );
    data['player']['turnsPerStage'] = value;
    var rejected = false;
    try {
      SaveData.decode(jsonEncode(data), {'unemployed'});
    } on FormatException {
      rejected = true;
    }
    check(rejected, 'Invalid pacing setting rejected on load');
  }
  print(
    'PASS $checks stage lifecycle checks: 4/8/12 turns, six bosses, migrations, retries, duplicate guards and scaling.',
  );
}
