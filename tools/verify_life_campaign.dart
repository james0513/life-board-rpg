// Scripted domain campaign checks, not UI or randomized board-path QA.
// Run from project root: dart tools/verify_life_campaign.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../lib/domain/models/battle.dart';
import '../lib/domain/models/card_battle.dart';
import 'verify_card_battle.dart' show CardCampaignPolicy;
import '../lib/domain/models/board_tile.dart';
import '../lib/domain/models/life_progress.dart';
import '../lib/domain/models/player.dart';
import '../lib/domain/models/save_data.dart';
import '../lib/domain/models/shop_item.dart';
import '../lib/domain/models/stage.dart';
import '../lib/domain/services/job_manager.dart';
import '../lib/domain/services/life_service.dart';
import '../lib/domain/services/shop_service.dart';
import '../lib/domain/services/stage_service.dart';
import '../lib/domain/services/tile_event_manager.dart';

const root = '.';
var assertions = 0;
void check(bool condition, String message) {
  assertions++;
  if (!condition) throw StateError(message);
}

Future<String> loadJson(String path) => File('$root/$path').readAsString();

class Campaign {
  final int seed;
  Campaign(this.seed);
  final life = const LifeService();
  final shop = const ShopService();
  late final jobs = JobManager(loadJson: loadJson);
  late final tiles = TileEventManager(loadJson: loadJson, random: Random(seed));
  late final stages = StageService(
    (jsonDecode(File('$root/assets/data/stages.json').readAsStringSync())
            as List)
        .map((e) => GameStage.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
  );
  late final enemies = (jsonDecode(
    File('$root/assets/data/enemies.json').readAsStringSync(),
  ) as List).map((e) => Enemy.fromJson(Map<String, dynamic>.from(e))).toList();
  late final Set<String> jobIds;
  late final battleRandom = Random(seed * 31 + 7);
  Player p = const Player(gender: CharacterGender.female);
  int checkpoints = 0, totalTurns = 0, fights = 0, combatRounds = 0;
  int lifeActions = 0, workTurns = 0, careerTurns = 0, shopTurns = 0;
  int spent = 0, workEarned = 0, fightEarned = 0;
  final learned = <String>[];
  final chapters = <Map<String, Object>>[];

  void checkpoint(String label) {
    final raw = SaveData(p, DateTime.utc(2026, 10, 10)).encode();
    final restored = SaveData.decode(raw, jobIds).player;
    check(
      SaveData(restored, DateTime.utc(2026, 10, 10)).encode() == raw,
      'Seed $seed checkpoint $label changed state or reapplied a bonus',
    );
    p = restored;
    checkpoints++;
  }

  void trackTurn(Player before, Player after, String label) {
    check(
      after.life.turns == before.life.turns + 1,
      '$label must use exactly one turn',
    );
    totalTurns++;
    check(
      after.life.turns == totalTurns,
      '$label life turns drifted from settled actions',
    );
  }

  Future<void> work() async {
    final before = p;
    final event = await tiles.draw(TileKind.work, stage: p.currentStage);
    // Select an actual catalog option that avoids stamina loss, preferring study-related work.
    final choices = [...event.options]
      ..sort(
        (a, b) =>
            (b.effects.intelligence * 1000 +
                    b.effects.stamina * 100 +
                    b.effects.money)
                .compareTo(
                  a.effects.intelligence * 1000 +
                      a.effects.stamina * 100 +
                      a.effects.money,
                ),
      );
    final choice = choices.first;
    check(
      choice.battleEnemyId == null,
      'Selected work is unexpectedly a combat chain',
    );
    final effects = jobs.workEffects(before, choice.effects);
    final practiced = (before.life.jobPractice[before.jobId] ?? 0) + 1;
    final willLearn =
        practiced >= 3 && !before.life.learnedSkills.contains(before.jobId);
    final expected = before
        .apply(effects)
        .apply(willLearn ? life.skillBonus(before.jobId) : const StatDelta());
    p = life.finishTurn(before.apply(effects), activity: 'work');
    check(
      p.money == expected.money &&
          p.stamina == expected.stamina &&
          p.intelligence == expected.intelligence &&
          p.charm == expected.charm &&
          p.morality == expected.morality,
      'Work effects or one-time perk applied incorrectly',
    );
    check(
      p.life.jobPractice[before.jobId] == practiced,
      'Work practice not tracked for current job',
    );
    if (willLearn) {
      check(practiced == 3, 'First perk was not awarded on third practice');
      check(
        p.life.learnedSkills.contains(before.jobId),
        'New job skill missing',
      );
      learned.add(before.jobId);
    }
    workEarned += effects.money;
    workTurns++;
    trackTurn(before, p, 'work');
    check(totalTurns < 1000, 'Campaign preparation exceeded 1000 actions');
    checkpoint('work $workTurns');
  }

  Future<void> ensureMoney(int amount) async {
    while (p.money < amount) await work();
  }

  Future<void> action(String id) async {
    final cost = switch (id) {
      'study' => 200,
      'exercise' => 100,
      'socialize' => 150,
      'buyHome' => life.homeCost(p),
      _ => 0,
    };
    await ensureMoney(cost);
    final before = p;
    p = life.lifeAction(p, id);
    check(
      before.money - p.money == cost,
      'Life action $id charged wrong amount',
    );
    spent += cost;
    lifeActions++;
    trackTurn(before, p, id);
    checkpoint(id);
  }

  Future<void> changeJob(String id) async {
    check(
      jobs.evaluate(p, id).allowed,
      'Career $id not earned: ${jobs.evaluate(p, id).reasons}',
    );
    checkpoint('before $id promotion');
    final before = p;
    final changed = jobs.changeJob(p, id);
    check(
      changed.money == p.money &&
          changed.stamina == p.stamina &&
          changed.intelligence == p.intelligence &&
          changed.morality == p.morality,
      'Promotion incorrectly deducted eligibility stats',
    );
    p = life.finishTurn(changed, activity: 'career');
    careerTurns++;
    trackTurn(before, p, 'career');
    checkpoint('after $id promotion');
    for (var i = 0; i < 3; i++) await work();
    check(
      p.life.learnedSkills.contains(id),
      'Promoted skill missing after three work turns',
    );
  }

  Future<void> buyAndEquip(String id) async {
    final item = shopById(id);
    check(p.currentStage >= item.unlockStage, 'Attempted locked gear purchase');
    await ensureMoney(item.price);
    final before = p;
    p = shop.equip(shop.buy(p, id), id);
    check(
      before.money - p.money == item.price,
      'Shop charged wrong price for $id',
    );
    p = life.finishTurn(p, activity: 'shop');
    spent += item.price;
    shopTurns++;
    trackTurn(before, p, 'shop');
    checkpoint('equipped $id');
  }

  Future<void> fight(Enemy enemy) async {
    while (p.life.stress > 24) await action('rest');
    checkpoint('before fight ${enemy.id}');
    final before = p;
    final b = CardBattleSession(
      p,
      enemy,
      job: jobs.byId(p.jobId),
      random: battleRandom,
    );
    final expectedHp = max(
      1,
      60 +
          min(p.stamina, 200) * 2 +
          equipmentHp(p) +
          (p.life.eq - 50) ~/ 10 -
          p.life.stress ~/ 10 +
          p.life.homeLevel * 3,
    );
    check(b.maxHp == expectedHp, 'Battle maximum HP omitted life effects');
    check(b.claim() == null, 'Active battle paid rewards');
    final policy = CardCampaignPolicy();
    policy.fight(b);
    check(
      policy.cardMoves > 0 && policy.impactChecks > 0,
      'Campaign bypassed card selection or delayed impact',
    );
    check(
      b.status == BattleStatus.won,
      'Seed $seed lost to ${enemy.id}: HP ${b.hp}/${b.maxHp}, enemy ${b.enemyHp}, rounds ${b.round}, job ${p.jobId}',
    );
    final reward = b.claim();
    check(
      reward != null && reward.money == enemy.reward,
      'Victory reward mismatch',
    );
    check(b.claim() == null, 'Victory rewards could be claimed twice');
    final oldRounds = b.round;
    check(b.playSelected() == null, 'Terminal battle accepted a card play');
    b.advance(10000);
    check(b.round == oldRounds, 'Terminal battle accepted another attack');
    final rewarded = before
        .apply(reward!)
        .gainExperience(b.earnedExperience)
        .copyWith(inventory: b.remainingInventory);
    p = enemy.isBoss
        ? rewarded
        : StageService.completeMapTurn(
            life.finishTurn(rewarded, activity: 'battle'),
          );
    p = stages.settle(p, enemy, b.status);
    check(
      p.money == before.money + enemy.reward,
      'Battle or life settlement charged unexpected money',
    );
    check(
      p.experience == before.experience + enemy.experience,
      'Experience applied incorrectly',
    );
    check(
      p.stamina == before.stamina + 3 &&
          p.intelligence == before.intelligence + 2 &&
          p.morality == before.morality + 2,
      'Victory growth missing or repeated',
    );
    if (enemy.isBoss) {
      check(
        p.clearedStages == before.clearedStages + 1 && p.stageWins == 0,
        'Boss did not advance exactly one stage',
      );
      final duplicate = stages.settle(p, enemy, b.status);
      check(
        duplicate.clearedStages == p.clearedStages,
        'Old boss advanced another stage',
      );
    } else {
      check(
        p.clearedStages == before.clearedStages &&
            p.stageWins == before.stageWins + 1,
        'Ordinary victory did not advance boss readiness',
      );
    }
    fights++;
    fightEarned += enemy.reward;
    combatRounds += b.round;
    if (!enemy.isBoss) trackTurn(before, p, 'battle');
    checkpoint('after fight ${enemy.id}');
  }

  Future<Map<String, Object>> run() async {
    await jobs.load();
    jobIds = jobs.jobs.map((j) => j.id).toSet();
    checkpoint('fresh');
    await changeJob('student');
    while (p.intelligence <= 30) await action('study');
    while (p.morality < 15) await work();
    await changeJob('engineer');
    while (p.stamina < 30) await action('exercise');
    while (p.intelligence < 50) await action('study');
    await buyAndEquip('staff');
    await buyAndEquip('plate');
    await buyAndEquip('ring');
    await action('socialize');

    for (var chapter = 1; chapter <= 6; chapter++) {
      check(p.currentStage == chapter, 'Chapter skipped');
      final boss = stages.current(p).boss;
      check(
        !stages.current(p).bossReady(p),
        'Boss ready before configured map turns',
      );
      final premature = stages.settle(p, boss, BattleStatus.won);
      check(
        premature.clearedStages == p.clearedStages,
        'Early boss bypassed configured map turns',
      );
      if (chapter == 2) await action('buyHome');
      if (chapter == 4) await action('buyHome');
      if (chapter == 6) {
        while (p.intelligence <= 70) await action('study');
        // Legitimate paid morality training if work/battle rewards have not met the threshold.
        while (p.morality <= 50) {
          await ensureMoney(300);
          final before = p;
          p = life.finishTurn(shop.buy(p, 'train_morality'), activity: 'shop');
          spent += 300;
          shopTurns++;
          trackTurn(before, p, 'morality training');
          checkpoint('morality training');
        }
        await changeJob('mentor');
        await buyAndEquip('astral_staff');
      }
      final eligible = enemies
          .where((e) => e.minTier <= jobs.byId(p.jobId).tier)
          .toList();
      // Pick three real catalog enemies, stage-scaled by the shipped StageService.
      for (var i = 0; i < 3; i++) {
        final enemy = stages.scaleEnemy(
          eligible[(seed + chapter * 3 + i) % eligible.length],
          p,
        );
        await fight(enemy);
      }
      // Synthetic map settlement probe complements the real seeded board suite.
      while (!p.bossPending) p = StageService.completeMapTurn(p);
      check(
        stages.current(p).bossReady(p),
        'Configured map turns failed to unlock boss',
      );
      await fight(boss);
      chapters.add({
        'stage': chapter,
        'age': p.life.age,
        'turns': p.life.turns,
        'money': p.money,
        'job': p.jobId,
        'stamina': p.stamina,
        'intelligence': p.intelligence,
      });
    }
    check(
      fights == 24 && p.campaignComplete,
      'Campaign did not complete eighteen normals and six bosses',
    );
    check(
      p.money == 1000 + workEarned + fightEarned - spent,
      'Campaign money ledger mismatched',
    );
    check(
      totalTurns ==
          workTurns + lifeActions + careerTurns + shopTurns + fights - 6,
      'Campaign turn ledger mismatched',
    );
    check(
      learned.toSet().length == learned.length,
      'Same skill awarded twice in one life',
    );
    check(
      p.life.learnedSkills.contains('mentor'),
      'Late-game selected inheritance never learned',
    );
    final end = p;
    checkpoint('campaign complete');
    check(
      life.canReincarnate(p),
      'Completed campaign did not unlock reincarnation',
    );
    p = life.reincarnate(p, inheritSkill: 'mentor');
    check(
      p.gender == CharacterGender.female && p.life.generation == 2,
      'Reincarnation lost gender/generation',
    );
    check(
      p.life.turns == 0 &&
          p.life.age == 18 &&
          p.life.homeLevel == 0 &&
          p.life.stress == 0,
      'Reincarnation did not reset life',
    );
    check(
      p.clearedStages == 0 &&
          p.stageWins == 0 &&
          p.position == 0 &&
          p.experience == 0,
      'Reincarnation did not reset world',
    );
    check(
      p.money == 1000 &&
          p.jobId == 'unemployed' &&
          p.intelligence == 16 &&
          p.stamina == 10 &&
          p.charm == 10 &&
          p.morality == 10,
      'Reincarnation perk not applied exactly once',
    );
    check(
      p.life.learnedSkills.length == 1 && p.life.inheritedSkill == 'mentor',
      'Inheritance not isolated',
    );
    check(
      p.weaponId == 'none' &&
          p.armorId == 'none' &&
          p.accessoryId == 'none' &&
          jsonEncode(p.inventory) == jsonEncode(const Player().inventory),
      'Equipment/inventory not reset',
    );
    checkpoint('reincarnated');
    check(p.intelligence == 16, 'Reload reapplied inherited bonus');
    check(
      !life.canReincarnate(p),
      'Fresh second generation may immediately reincarnate',
    );
    var repeatRejected = false;
    try {
      life.reincarnate(p, inheritSkill: 'mentor');
    } on StateError {
      repeatRejected = true;
    }
    check(repeatRejected, 'Repeated reincarnation not rejected');

    return {
      'seed': seed,
      'fights': fights,
      'combatRounds': combatRounds,
      'turns': totalTurns,
      'ageAtCompletion': end.life.age,
      'checkpoints': checkpoints,
      'workTurns': workTurns,
      'lifeActions': lifeActions,
      'careerTurns': careerTurns,
      'shopTurns': shopTurns,
      'earnedFromWork': workEarned,
      'earnedFromFights': fightEarned,
      'spent': spent,
      'endingMoney': end.money,
      'skills': learned,
      'inheritedSkill': p.life.inheritedSkill!,
      'generationTwoIntelligence': p.intelligence,
      'chapters': chapters,
    };
  }
}

void checkHpFormula() {
  const enemy = Enemy(
    id: 'hp_probe',
    name: 'HP probe',
    description: '',
    hp: 1,
    attack: 1,
    reward: 0,
    portrait: 0,
  );
  check(
    CardBattleSession(const Player(), enemy).maxHp == 80,
    'Default player HP changed from original baseline 80',
  );
  check(
    CardBattleSession(
          const Player(life: LifeProgress(eq: 90, stress: 20, homeLevel: 2)),
          enemy,
        ).maxHp ==
        88,
    'Combined EQ/stress/home HP should be 88',
  );
  check(
    CardBattleSession(
          const Player(life: LifeProgress(eq: 0, stress: 100)),
          enemy,
        ).maxHp ==
        65,
    'Worst valid EQ/stress HP should be 65',
  );
  check(
    CardBattleSession(
          const Player(stamina: 0, life: LifeProgress(eq: 0, stress: 100)),
          enemy,
        ).maxHp ==
        45,
    'Zero stamina with worst valid meters should still be survivable',
  );
  check(
    CardBattleSession(
          const Player(life: LifeProgress(homeLevel: 1)),
          enemy,
        ).maxHp ==
        83,
    'Each home level must add 3 HP',
  );
  check(
    CardBattleSession(
          const Player(life: LifeProgress(eq: 41, stress: 9)),
          enemy,
        ).maxHp ==
        80,
    'Meter rounding must truncate toward zero',
  );
}

Future<void> main() async {
  checkHpFormula();
  final runs = <Map<String, Object>>[];
  for (final seed in [1, 7, 19, 42, 99, 123, 2026, 31415, 65535, 99991]) {
    final result = await Campaign(seed).run();
    runs.add(result);
    print(
      'PASS seed $seed: ${result['fights']} wins, ${result['turns']} turns, '
      'age ${result['ageAtCompletion']}, ${result['checkpoints']} verified save boundaries, '
      'generation 2 mentor bonus INT ${result['generationTwoIntelligence']}',
    );
  }
  final report = {
    'mode': 'Pure Dart scripted card-combat campaign; no Flutter widget/dice-board test',
    'assertions': assertions,
    'passedCampaigns': runs.length,
    'totalVictories': runs.fold<int>(0, (sum, r) => sum + (r['fights'] as int)),
    'totalCheckpoints': runs.fold<int>(
      0,
      (sum, r) => sum + (r['checkpoints'] as int),
    ),
    'hpFormulaChecks': 6,
    'runs': runs,
  };
  File('docs/life_campaign_report.json')
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
  print('PASS $assertions assertions; report docs/life_campaign_report.json');
}
