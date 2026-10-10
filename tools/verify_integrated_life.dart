// Independent, deterministic whole-life domain integration harness for v0.29.
// No Flutter, pub, widget, browser, screenshot, or release-build validation.
// Run from any directory: <Dart SDK>/bin/dart /path/to/tools/verify_integrated_life.dart
// Combat policy adapts tools/verify_life_campaign.dart; this harness additionally
// uses real DiceService rolls and AgeBoard landings, all season bills and stories.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../lib/domain/models/acceptance_scenarios.dart';
import '../lib/domain/models/age_board.dart';
import '../lib/domain/models/battle.dart';
import '../lib/domain/models/card_battle.dart';
import 'verify_card_battle.dart' show CardCampaignPolicy;
import '../lib/domain/models/board_tile.dart';
import '../lib/domain/models/player.dart';
import '../lib/domain/models/save_data.dart';
import '../lib/domain/models/shop_item.dart';
import '../lib/domain/models/stage.dart';
import '../lib/domain/services/dice_service.dart';
import '../lib/domain/services/job_manager.dart';
import '../lib/domain/services/life_service.dart';
import '../lib/domain/services/shop_service.dart';
import '../lib/domain/services/stage_service.dart';
import '../lib/domain/services/story_service.dart';
import '../lib/domain/services/tile_event_manager.dart';

final projectRoot = File.fromUri(Platform.script).parent.parent.path;
final fixedTime = DateTime.utc(2026, 10, 10);
int checks = 0;
void check(bool condition, String description) {
  checks++;
  if (!condition) throw StateError(description);
}

String snapshot(Player p) => SaveData(p, fixedTime).encode();
Future<String> loadJson(String path) =>
    File('$projectRoot/$path').readAsString();
List<T> catalog<T>(String path, T Function(Map<String, dynamic>) parse) =>
    (jsonDecode(File('$projectRoot/$path').readAsStringSync()) as List)
        .map((e) => parse(Map<String, dynamic>.from(e as Map)))
        .toList();

class IntegratedLife {
  IntegratedLife(this.seed, this.route, {required this.reloadEverySeason});
  final int seed, route;
  final bool reloadEverySeason;
  final life = const LifeService();
  final story = const StoryService();
  final shop = const ShopService();
  late final jobs = JobManager(loadJson: loadJson);
  late final dice = DiceService(random: Random(seed));
  late final events = TileEventManager(
    loadJson: loadJson,
    random: Random(seed * 7 + 3),
  );
  late final encounterRandom = Random(seed * 13 + 5);
  late final combatRandom = Random(seed * 31 + 7);
  late final stages = StageService(
    catalog('assets/data/stages.json', GameStage.fromJson),
  );
  late final enemies = catalog('assets/data/enemies.json', Enemy.fromJson);
  late Set<String> jobIds;
  Player p = const Player(gender: CharacterGender.female);
  String get npcId => ['cen_yu', 'chu_ye', 'luo_qing'][route];
  String preferredBranch(String chain, int step) => route == 0
      ? 'a'
      : route == 1
      ? 'b'
      : (step + ['lantern', 'craft', 'roots'].indexOf(chain)).isEven
      ? 'a'
      : 'b';
  int seasons = 0, boardRolls = 0, saveChecks = 0, idempotenceChecks = 0;
  int grossIncome = 0, directSpending = 0, livingBilled = 0, livingPaid = 0;
  int battleWins = 0, battleLosses = 0, bossWins = 0, combatRounds = 0;
  int dates = 0, staleChoicesRejected = 0, shortfallSeasons = 0;
  final mapTransitions = <String>[];
  final actionCounts = <String, int>{};
  final boardsVisited = <String, int>{};
  final tileCounts = <String, int>{};
  final branches = <String, String>{};
  final trace = <String>[];
  final majorBoundaries = <Map<String, Object?>>[];
  final rollTrace = <Map<String, Object>>[];
  final battleTrace = <Map<String, Object>>[];

  void boundary(String label, [Player? state]) {
    final at = state ?? p;
    majorBoundaries.add({
      'label': label,
      'turn': at.life.turns,
      'age': at.life.age,
      'save': jsonDecode(snapshot(at)),
    });
  }

  void checkpoint(String label) {
    final raw = snapshot(p);
    final restored = SaveData.decode(raw, jobIds).player;
    check(snapshot(restored) == raw, '$seed: save round-trip changed $label');
    final again = story.settleSeason(restored);
    check(
      snapshot(again) == raw,
      '$seed: reload/re-settlement duplicated season fee at $label',
    );
    idempotenceChecks++;
    if (reloadEverySeason) p = restored;
    saveChecks++;
    trace.add('$label\n$raw');
  }

  // expectedPreBillMoney is derived from catalog/service action costs before the
  // action; it is not read back from the observed post-settlement money.
  void complete(
    Player before,
    Player after,
    String action,
    int expectedPreBillMoney,
  ) {
    check(
      after.life.turns == before.life.turns + 1,
      '$seed: $action did not spend one season',
    );
    final fee = story.livingCost(after);
    final actualPayment = min(fee, expectedPreBillMoney);
    check(
      after.money == max(0, expectedPreBillMoney - fee),
      '$seed: wrong bill/action money for $action',
    );
    check(
      after.story.lastSettledTurn == after.life.turns,
      '$seed: $action left a season unbilled',
    );
    final delta = expectedPreBillMoney - before.money;
    if (delta >= 0) {
      grossIncome += delta;
    } else {
      directSpending -= delta;
    }
    livingBilled += fee;
    livingPaid += actualPayment;
    if (actualPayment < fee) shortfallSeasons++;
    p = after;
    seasons++;
    actionCounts.update(action, (n) => n + 1, ifAbsent: () => 1);
    check(p.life.turns == seasons, '$seed: action/turn ledger drifted');
    check(
      p.money == 1000 + grossIncome - directSpending - livingPaid,
      '$seed: money ledger drifted',
    );
    check(
      snapshot(story.settleSeason(p)) == snapshot(p),
      '$seed: second settlement charged again',
    );
    idempotenceChecks++;
    checkpoint(action);
    if (AgeBoard.forAge(before.life.age).id != AgeBoard.forAge(p.life.age).id) {
      check(
        p.position == before.position,
        'Age-board transition moved the pawn',
      );
      check(
        [22, 35, 50].contains(p.life.age),
        'Unrecognized age board transition',
      );
      final transition = '${before.life.age}→${p.life.age}';
      mapTransitions.add(transition);
      boundary('before map $transition', before);
      boundary('map $transition');
    }
    check(seasons < 1800, '$seed: legal policy exceeded 1800 seasons');
  }

  void lifeAction(String action) {
    final before = p;
    final cost = switch (action) {
      'study' => 200,
      'exercise' => 100,
      'socialize' => 150,
      'buyHome' => life.homeCost(p),
      _ => 0,
    };
    check(p.money >= cost, 'Policy selected unaffordable $action');
    final next = story.settleSeason(life.lifeAction(p, action));
    complete(before, next, action, before.money - cost);
    if (action == 'buyHome') boundary('home level ${p.life.homeLevel}');
  }

  void relationship(String action) {
    final before = p;
    final info = story.relationshipActionInfo(p, action, npcId: npcId);
    check(info.enabled, 'Illegal $action for $npcId: ${info.blockedReason}');
    final next = story.perform(p, action, npcId: npcId);
    complete(before, next, 'relationship:$action', before.money - info.cost);
    if (action == 'date') dates++;
    if (['commit', 'propose', 'child'].contains(action))
      boundary('$npcId $action');
    for (final other in story.npcs.where((n) => n.id != npcId)) {
      check(
        p.story.affinities[other.id] == 0,
        'Relationship action leaked affinity to another NPC',
      );
    }
  }

  void choose(StoryChapter chapter, {required bool boardLanding}) {
    final wanted = preferredBranch(chapter.chainId, chapter.step);
    final option = chapter.options.singleWhere((o) => o.id == wanted);
    check(option.enabled, 'Policy chose disabled branch ${chapter.id}:$wanted');
    final before = p;
    final next = story.chooseStory(
      p,
      chapter.chainId,
      wanted,
      expectedStep: chapter.step,
    );
    final expectedMoney =
        max(0, before.money + option.effects.money) - option.cost;
    complete(
      before,
      next,
      boardLanding ? 'story:board' : 'story:journal',
      expectedMoney,
    );
    check(
      p.story.storySteps[chapter.chainId] == chapter.step + 1,
      'Story did not advance exactly once',
    );
    branches[chapter.id] = wanted;
    check(
      p.story.storyChoices[chapter.id] == wanted,
      'Story branch record was not persisted',
    );
    check(
      jsonEncode(p.story.storyChoices) == jsonEncode(branches),
      'Stored story choices diverged from decision ledger',
    );
    final afterRaw = snapshot(p);
    var rejected = false;
    try {
      story.chooseStory(p, chapter.chainId, wanted, expectedStep: chapter.step);
    } on StateError {
      rejected = true;
    }
    check(
      rejected && snapshot(p) == afterRaw,
      'Stale chapter replay was not rejected atomically',
    );
    staleChoicesRejected++;
    boundary('story ${chapter.id}:$wanted');
  }

  Future<void> discretionaryActions() async {
    // Legal journal actions only. Jobs, work, shops and battles always require
    // a genuine dice landing. Avoid spending so many early seasons that family
    // creation falls beyond its documented 25–55 age window.
    if (p.life.stress > 45) lifeAction('rest');
    if (p.story.affinities[npcId]! < 16) {
      relationship('talk');
    } else if (dates < 2 && p.money >= 500) {
      relationship('date');
    } else if (p.story.partnerId == null &&
        p.life.age >= 22 &&
        p.story.affinities[npcId]! >= 40) {
      relationship('commit');
    } else if (p.story.affinities[npcId]! < 72) {
      relationship('talk');
    }
    if (p.life.homeLevel == 0 && p.money >= 3000) lifeAction('buyHome');
    if (p.story.partnerId != null &&
        !p.story.married &&
        p.life.homeLevel > 0 &&
        p.story.affinities[npcId]! >= 70 &&
        p.money >= 1400)
      relationship('propose');
    if (p.story.married &&
        p.story.children == 0 &&
        p.life.age >= 25 &&
        p.life.age <= 55 &&
        p.money >= 1000) {
      relationship('child');
    }
    if (p.story.children > 0 &&
        !actionCounts.containsKey('relationship:familyTime') &&
        p.money >= 300) {
      relationship('familyTime');
    }
    if (p.intelligence < 36 && p.money >= 800) lifeAction('study');
    if (p.stamina < 25 && p.money >= 700) lifeAction('exercise');
    if (p.currentStage >= 3 && p.intelligence < 76 && p.money >= 2000)
      lifeAction('study');
    if (p.life.homeLevel == 1 && p.story.children > 0 && p.money >= 11000)
      lifeAction('buyHome');
    // Catch up eligible journal chapters after age 42; before then real luck
    // landings exercise the same first-available-chapter behavior as the UI.
    if (p.life.age >= 42) {
      final ready = story
          .availableStories(p)
          .where(
            (c) => c.options.any(
              (o) => o.id == preferredBranch(c.chainId, c.step) && o.enabled,
            ),
          )
          .toList();
      if (ready.isNotEmpty) choose(ready.first, boardLanding: false);
    }
  }

  Future<void> boardTurn() async {
    check(!p.bossPending, 'Pending boss must be resolved before rolling');
    await resolveBoardTurn();
    p = StageService.completeMapTurn(p);
    checkpoint('completed map landing');
    var attempts = 0;
    while (p.bossPending) {
      await fight(isBoss: true);
      attempts++;
      check(
        attempts < 300,
        '$seed: retry policy stalled; stage ${p.currentStage}, no map bypass allowed',
      );
    }
  }

  Future<void> resolveBoardTurn() async {
    final board = AgeBoard.forAge(p.life.age);
    final roll = dice.roll();
    check(roll >= 1 && roll <= 6, 'Invalid dice roll');
    final start = p.position;
    final position = nextPosition(start, roll, count: board.tiles.length);
    p = p.copyWith(
      position: position,
    ); // The only direct progress edit: legal pawn movement.
    final kind = board.tiles[position].kind;
    boardRolls++;
    boardsVisited.update(board.id, (n) => n + 1, ifAbsent: () => 1);
    tileCounts.update(kind.name, (n) => n + 1, ifAbsent: () => 1);
    rollTrace.add({
      'roll': boardRolls,
      'turnBefore': p.life.turns,
      'age': p.life.age,
      'board': board.id,
      'from': start,
      'dice': roll,
      'to': position,
      'tile': kind.name,
    });
    if (kind == TileKind.luck && p.life.turns > 0) {
      final enabled = story
          .availableStories(p)
          .where((c) => c.options.any((o) => o.enabled))
          .toList();
      if (enabled.isNotEmpty) {
        final chapter = enabled.first;
        final wanted = preferredBranch(chapter.chainId, chapter.step);
        final preferred = chapter.options.singleWhere((o) => o.id == wanted);
        // Wait for preferred prerequisites using a legal alternative only when
        // unavoidable. Each actual selected branch is recorded explicitly.
        if (preferred.enabled) {
          choose(chapter, boardLanding: true);
          return;
        }
        final alternative = chapter.options.firstWhere((o) => o.enabled);
        final before = p;
        final next = story.chooseStory(
          p,
          chapter.chainId,
          alternative.id,
          expectedStep: chapter.step,
        );
        complete(
          before,
          next,
          'story:board',
          max(0, before.money + alternative.effects.money) - alternative.cost,
        );
        branches[chapter.id] = alternative.id;
        check(
          p.story.storyChoices[chapter.id] == alternative.id,
          'Fallback branch record was not persisted',
        );
        check(
          jsonEncode(p.story.storyChoices) == jsonEncode(branches),
          'Stored fallback branch diverged from decision ledger',
        );
        final raw = snapshot(p);
        var staleRejected = false;
        try {
          story.chooseStory(
            p,
            chapter.chainId,
            alternative.id,
            expectedStep: chapter.step,
          );
        } on StateError {
          staleRejected = true;
        }
        check(
          staleRejected && snapshot(p) == raw,
          'Stale fallback chapter replay mutated progress',
        );
        staleChoicesRejected++;
        boundary('story ${chapter.id}:${alternative.id} (available fallback)');
        return;
      }
    }
    if (kind == TileKind.battle) {
      await fight();
    } else if (kind == TileKind.career) {
      final before = p;
      String? target;
      if (p.jobId == 'unemployed') target = 'student';
      if (p.jobId == 'student' &&
          p.life.learnedSkills.contains('student') &&
          jobs.evaluate(p, 'engineer').allowed)
        target = 'engineer';
      if (p.jobId == 'engineer' &&
          p.life.learnedSkills.contains('engineer') &&
          jobs.evaluate(p, 'mentor').allowed)
        target = 'mentor';
      final changed = target == null ? p : jobs.changeJob(p, target);
      check(
        changed.money == before.money &&
            changed.stamina == before.stamina &&
            changed.intelligence == before.intelligence &&
            changed.morality == before.morality,
        'Career eligibility deducted stats',
      );
      complete(
        before,
        story.settleSeason(life.finishTurn(changed, activity: 'career')),
        'career',
        before.money,
      );
      if (target != null) boundary('career $target');
    } else if (kind == TileKind.shop) {
      final before = p;
      var next = p;
      final purchases = <String>[];
      void buy(String id, int reserve) {
        final item = shopById(id);
        if (equipmentLockReason(next, item) == null &&
            next.currentStage >= item.unlockStage &&
            (next.inventory[id] ?? 0) == 0 &&
            next.money >= item.price + reserve) {
          next = shop.equip(shop.buy(next, id), id);
          purchases.add(id);
        }
      }

      buy('staff', 200);
      buy('plate', 500);
      buy('ring', 800);
      if (next.currentStage == 6) buy('astral_staff', 2000);
      // Training is a genuine shop purchase, used only for a stalled mentor
      // qualification. Every payment is in the independent ledger.
      if (next.jobId == 'engineer' &&
          next.morality <= 50 &&
          next.money >= 4500) {
        next = shop.buy(next, 'train_morality');
        purchases.add('train_morality');
      }
      final amountBeforeBill = next.money;
      complete(
        before,
        story.settleSeason(life.finishTurn(next, activity: 'shop')),
        'shop',
        amountBeforeBill,
      );
      if (purchases.isNotEmpty) boundary('shop ${purchases.join(',')}');
    } else {
      final event = await events.draw(kind, stage: p.currentStage);
      // Choose an actual A/B option. Prefer income and intelligence, while
      // declining optional event battle chains in these three paths.
      final options =
          event.options.where((o) => o.battleEnemyId == null).toList()..sort(
            (a, b) =>
                (b.effects.money +
                        b.effects.intelligence * 50 +
                        b.effects.stamina * 20)
                    .compareTo(
                      a.effects.money +
                          a.effects.intelligence * 50 +
                          a.effects.stamina * 20,
                    ),
          );
      check(options.isNotEmpty, 'No legal non-chain choice in ${event.id}');
      final choice = options.first;
      final before = p;
      final delta = kind == TileKind.work
          ? jobs.workEffects(p, choice.effects)
          : choice.effects;
      final practiced = (p.life.jobPractice[p.jobId] ?? 0) + 1;
      final knownBefore = p.life.learnedSkills.contains(p.jobId);
      final next = story.settleSeason(
        life.finishTurn(p.apply(delta), activity: kind.name),
      );
      complete(before, next, kind.name, max(0, before.money + delta.money));
      if (kind == TileKind.work) {
        check(
          p.life.jobPractice[p.jobId] == practiced,
          'Work practice was not counted',
        );
        if (!knownBefore && practiced >= 3) {
          check(
            p.life.learnedSkills.contains(p.jobId),
            'Third practice failed to grant skill',
          );
          boundary('learned ${p.jobId}');
        }
      }
    }
  }

  Future<void> fight({bool isBoss = false}) async {
    final before = p;
    final stage = stages.current(p);
    final pool = enemies
        .where((e) => e.minTier <= jobs.byId(p.jobId).tier)
        .toList();
    var enemy = stages.scaleEnemy(
      pool[encounterRandom.nextInt(pool.length)],
      p,
    );
    if (isBoss) {
      check(p.bossPending, 'Early boss');
      enemy = stage.boss;
    }
    if (!stage.bossReady(p) && !p.campaignComplete) {
      check(
        stages.settle(p, stage.boss, BattleStatus.won).clearedStages ==
            p.clearedStages,
        'Premature boss bypassed map-turn prerequisite',
      );
    }
    final b = CardBattleSession(
      p,
      enemy,
      job: jobs.byId(p.jobId),
      random: combatRandom,
    );
    check(b.claim() == null, 'Active battle paid reward');
    final policy = CardCampaignPolicy();
    policy.fight(b);
    check(
      policy.cardMoves > 0 && policy.impactChecks > 0,
      'Integrated life bypassed card selection or delayed impact',
    );
    check(!b.active, 'Combat failed to terminate');
    final reward = b.claim();
    check(
      reward != null && b.claim() == null,
      'Combat reward not exactly-once',
    );
    final terminalRound = b.round;
    check(b.playSelected() == null, 'Terminal battle accepted a card play');
    b.advance(10000);
    check(b.round == terminalRound, 'Terminal battle accepted another attack');
    final changed = before
        .apply(reward!)
        .gainExperience(b.earnedExperience)
        .copyWith(inventory: b.remainingInventory);
    if (isBoss) {
      p = stages.settle(changed, enemy, b.status);
      if (reward.money >= 0) {
        grossIncome += reward.money;
      } else {
        directSpending -= reward.money;
      }
      check(p.life.turns == before.life.turns, 'Boss consumed a second season');
      checkpoint('threshold boss');
    } else {
      final next = stages.settle(
        story.settleSeason(life.finishTurn(changed, activity: 'battle')),
        enemy,
        b.status,
      );
      complete(before, next, 'battle', max(0, before.money + reward.money));
    }
    check(
      p.experience == before.experience + b.earnedExperience,
      'Combat experience applied incorrectly',
    );
    if (b.status == BattleStatus.won) {
      battleWins++;
    } else {
      battleLosses++;
    }
    if (enemy.isBoss && b.status == BattleStatus.won) {
      bossWins++;
      check(
        p.clearedStages == before.clearedStages + 1,
        'Boss failed to advance one trial',
      );
      check(
        stages.settle(p, enemy, b.status).clearedStages == p.clearedStages,
        'Old boss advanced another trial',
      );
      boundary('trial ${enemy.bossStage} complete');
    }
    combatRounds += b.round;
    battleTrace.add({
      'turn': p.life.turns,
      'enemy': enemy.id,
      'stage': before.currentStage,
      'result': b.status.name,
      'rounds': b.round,
      'moneyReward': reward.money,
      'hp': b.hp,
      'maxHp': b.maxHp,
    });
  }

  bool get goalsMet =>
      p.campaignComplete &&
      p.life.age >= 50 &&
      p.story.married &&
      p.story.children > 0 &&
      p.life.homeLevel == 2 &&
      p.money >= 5000 &&
      p.life.learnedSkills.length >= 3 &&
      p.story.storySteps.values.every((n) => n == 3);

  Future<Map<String, Object?>> run() async {
    await jobs.load();
    jobIds = jobs.jobs.map((j) => j.id).toSet();
    checkpoint('fresh');
    boundary('fresh');
    while (!goalsMet) {
      await discretionaryActions();
      await boardTurn();
      if (p.life.age > 55 && p.story.children == 0) {
        throw StateError(
          '$seed policy missed the legal child window at turn ${p.life.turns}; cash ${p.money}; home ${p.life.homeLevel}; married ${p.story.married}',
        );
      }
    }
    check(
      bossWins == 6,
      '$seed did not finish all six trials through real battles',
    );
    check(
      boardsVisited.keys.toSet().containsAll(AgeBoard.all.map((b) => b.id)),
      '$seed did not roll on all four real boards',
    );
    check(
      tileCounts.keys.toSet().containsAll(TileKind.values.map((k) => k.name)),
      '$seed missed a tile kind',
    );
    check(branches.length == 9, '$seed did not make all nine story decisions');
    check(
      jsonEncode(mapTransitions) == jsonEncode(['21→22', '34→35', '49→50']),
      'Actual map transitions missing or duplicated',
    );
    check(
      jsonEncode(p.story.storyChoices) == jsonEncode(branches),
      'Final saved branch ledger differs from actual decisions',
    );
    check(
      (actionCounts['story:board'] ?? 0) > 0,
      '$seed missed luck-trigger chapter integration',
    );
    final endingIds = story.eligibleEndings(p).map((e) => e.id).toList();
    check(
      endingIds.toSet().containsAll([
            'trials',
            'scholar',
            'family',
            'prosperity',
            'peaceful',
          ]) &&
          endingIds.length == 5,
      '$seed not eligible for all five endings: $endingIds',
    );
    boundary('five endings eligible');
    final end = p;
    final endingForks = <Map<String, Object?>>[];
    for (final ending in endingIds) {
      final concluded = story.concludeLife(end, ending);
      final recorded = SaveData.decode(snapshot(concluded), jobIds).player;
      check(
        snapshot(recorded) == snapshot(concluded),
        'Ending save failed for $ending',
      );
      check(
        snapshot(story.concludeLife(recorded, ending)) == snapshot(recorded),
        'Ending was not idempotent',
      );
      check(
        recorded.story.history.length == 1 &&
            recorded.story.history.single.id == ending,
        'Incorrect ending history',
      );
      var differentRejected = false;
      try {
        story.concludeLife(
          recorded,
          endingIds.firstWhere((id) => id != ending),
        );
      } on StateError {
        differentRejected = true;
      }
      check(differentRejected, 'Existing ending was overwritten');
      final reborn = story.reincarnate(recorded, inheritSkill: 'student');
      check(
        reborn.life.generation == 2 && reborn.story.history.single.id == ending,
        'Ending fork reincarnation lost history',
      );
      check(
        reborn.story.storyChoices.isEmpty,
        'Ending fork retained branch decisions in next life',
      );
      final restoredReborn = SaveData.decode(snapshot(reborn), jobIds).player;
      check(
        snapshot(restoredReborn) == snapshot(reborn),
        'Ending fork reincarnation save changed semantics',
      );
      endingForks.add({
        'ending': ending,
        'save': jsonDecode(snapshot(recorded)),
        'reincarnatedSave': jsonDecode(snapshot(restoredReborn)),
      });
    }
    final selected = ['family', 'scholar', 'prosperity'][route];
    p = story.concludeLife(p, selected);
    checkpoint('concluded $selected');
    boundary('concluded $selected');
    final inherited = p.life.learnedSkills.contains('mentor')
        ? 'mentor'
        : 'engineer';
    p = story.reincarnate(p, inheritSkill: inherited);
    final expectedFresh = Player(gender: CharacterGender.female)
        .apply(life.skillBonus(inherited));
    check(
      p.life.generation == 2 && p.life.turns == 0 && p.life.age == 18,
      'Reincarnation did not reset life',
    );
    check(
      p.money == 1000 &&
          p.intelligence == expectedFresh.intelligence &&
          p.stamina == expectedFresh.stamina &&
          p.charm == expectedFresh.charm &&
          p.morality == expectedFresh.morality,
      'Inherited bonus was not applied exactly once',
    );
    check(
      p.life.learnedSkills.length == 1 && p.life.inheritedSkill == inherited,
      'Inheritance was not isolated',
    );
    check(
      p.story.history.length == 1 && p.story.history.single.id == selected,
      'Reincarnation lost ending history',
    );
    check(
      p.story.partnerId == null &&
          !p.story.married &&
          p.story.children == 0 &&
          p.story.affinities.values.every((v) => v == 0) &&
          p.story.storySteps.values.every((v) => v == 0) &&
          p.story.storyChoices.isEmpty,
      'Reincarnation retained old relationships/stories',
    );
    check(
      p.clearedStages == 0 &&
          p.stageWins == 0 &&
          p.position == 0 &&
          p.experience == 0 &&
          p.jobId == 'unemployed' &&
          p.weaponId == 'none' &&
          p.armorId == 'none' &&
          p.accessoryId == 'none',
      'Reincarnation did not reset world/equipment',
    );
    check(
      AgeBoard.forAge(p.life.age).id == 'learning',
      'New life did not select initial map',
    );
    checkpoint('reincarnated');
    boundary('reincarnated');
    final freshRaw = snapshot(p);
    var blocked = false;
    try {
      story.reincarnate(p, inheritSkill: inherited);
    } on StateError {
      blocked = true;
    }
    check(
      blocked && snapshot(p) == freshRaw,
      'Immediate repeated reincarnation was not atomic/rejected',
    );
    return {
      'seed': seed,
      'npc': npcId,
      'preferredBranches': route == 0
          ? 'A'
          : route == 1
          ? 'B'
          : 'alternating',
      'actualBranches': branches,
      'mapTransitions': mapTransitions,
      'seasons': seasons,
      'ageAtCompletion': end.life.age,
      'boardRolls': boardRolls,
      'boardsVisited': boardsVisited,
      'tileCounts': tileCounts,
      'actionCounts': actionCounts,
      'battleWins': battleWins,
      'battleLosses': battleLosses,
      'bossWins': bossWins,
      'combatRounds': combatRounds,
      'saveChecks': saveChecks,
      'idempotenceChecks': idempotenceChecks,
      'staleChoicesRejected': staleChoicesRejected,
      'grossIncome': grossIncome,
      'directSpending': directSpending,
      'livingBilled': livingBilled,
      'livingPaid': livingPaid,
      'shortfallSeasons': shortfallSeasons,
      'endingMoney': end.money,
      'learnedSkills': end.life.learnedSkills,
      'eligibleEndings': endingIds,
      'selectedEnding': selected,
      'inheritedSkill': inherited,
      'majorBoundaries': majorBoundaries,
      'endingForks': endingForks,
      'rollTrace': rollTrace,
      'battleTrace': battleTrace,
    };
  }
}

Future<void> main() async {
  final runs = <Map<String, Object?>>[];
  for (var route = 0; route < 3; route++) {
    final seed = [7, 42, 2026][route];
    final continuous = IntegratedLife(seed, route, reloadEverySeason: false);
    final result = await continuous.run();
    final restored = IntegratedLife(seed, route, reloadEverySeason: true);
    await restored.run();
    check(
      continuous.trace.length == restored.trace.length,
      'Replay length changed for seed $seed',
    );
    for (var i = 0; i < continuous.trace.length; i++) {
      check(
        continuous.trace[i] == restored.trace[i],
        'Continuous/reloaded replay diverged at seed $seed checkpoint $i',
      );
    }
    check(
      jsonEncode(continuous.rollTrace) == jsonEncode(restored.rollTrace),
      'Seeded dice replay diverged',
    );
    result['replayMatched'] = true;
    result['comparedSemanticSnapshots'] = continuous.trace.length;
    runs.add(result);
    print(
      'PASS $seed / ${result['npc']}: ${result['seasons']} seasons, ${result['boardRolls']} real dice rolls, '
      '${result['bossWins']} bosses, money ${result['endingMoney']}, ${result['saveChecks']} save/replay checkpoints',
    );
  }
  final jobManager = JobManager(loadJson: loadJson);
  await jobManager.load();
  final jobIds = jobManager.jobs.map((j) => j.id).toSet();
  final acceptance = <Map<String, Object?>>[];
  for (final entry in acceptanceScenarioLabels.entries) {
    final original = acceptanceScenario(entry.key);
    final restored = SaveData.decode(snapshot(original), jobIds).player;
    check(
      snapshot(original) == snapshot(restored),
      'Acceptance scenario failed round-trip: ${entry.key}',
    );
    check(
      snapshot(const StoryService().settleSeason(restored)) ==
          snapshot(restored),
      'Acceptance scenario charged historical living fees',
    );
    acceptance.add({
      'id': entry.key,
      'label': entry.value,
      'age': original.life.age,
      'roundTrip': true,
      'save': jsonDecode(snapshot(original)),
    });
  }
  check(acceptance.length == 4, 'Four acceptance fixtures required');
  check(!acceptanceMode, 'Harness must run in normal default mode');
  final storeSource = File('$projectRoot/lib/data/preferences_save_store.dart')
      .readAsStringSync();
  final match = RegExp(r"static const key = '([^']+)'").firstMatch(storeSource);
  check(
    match != null && match.group(1) != acceptanceSaveKey,
    'Normal/sandbox save keys collide',
  );
  final providerSource = File(
    '$projectRoot/lib/application/save_providers.dart',
  ).readAsStringSync();
  check(
    RegExp(
      r'acceptanceMode\s*\?\s*acceptanceSaveKey\s*:\s*PreferencesSaveStore\.key',
    ).hasMatch(providerSource),
    'Save provider does not select the isolated sandbox key',
  );
  // Explicit synthetic probes, separate from fresh-play campaigns. They cover
  // insufficient money with one and three overdue seasons, including reload.
  final feeProbes = <Map<String, Object?>>[];
  for (final overdue in [1, 3]) {
    final fixture = acceptanceScenario('family');
    final owing = fixture
        .apply(StatDelta(money: 5 - fixture.money))
        .copyWith(
          life: fixture.life.copyWith(turns: fixture.life.turns + overdue),
        );
    final settled = const StoryService().settleSeason(owing);
    check(
      settled.money == 0 && settled.life.stress == overdue * 8,
      'Insufficient living funds failed to clamp money/add per-season stress',
    );
    check(
      settled.story.lastSettledTurn == settled.life.turns,
      'Overdue fee remained unsettled',
    );
    final raw = snapshot(settled);
    final loaded = SaveData.decode(raw, jobIds).player;
    check(
      snapshot(const StoryService().settleSeason(loaded)) == raw,
      'Reload duplicated an insufficient-funds bill',
    );
    feeProbes.add({
      'synthetic': true,
      'overdueSeasons': overdue,
      'openingMoney': 5,
      'feePerSeason': const StoryService().livingCost(owing),
      'endingMoney': settled.money,
      'endingStress': settled.life.stress,
      'reloadIdempotent': true,
    });
  }
  final branchCoverage = <String>{};
  for (final run in runs) {
    for (final entry
        in (run['actualBranches'] as Map<String, String>).entries) {
      branchCoverage.add('${entry.key}:${entry.value}');
    }
  }
  final unvisitedBranches = [
    for (final chain in const StoryService().storyChains)
      for (final chapter in chain.chapters)
        for (final option in chapter.options)
          if (!branchCoverage.contains('${chapter.id}:${option.id}'))
            '${chapter.id}:${option.id}',
  ];
  final report = <String, Object?>{
    'version': '0.29',
    'status': 'passed',
    'assertions': checks,
    'execution': 'Pure Dart SDK only. No Flutter or pub commands.',
    'method':
        'Three fresh female-player lives with legal seasonal journal actions and real seeded dice/age-board landings. '
        'Each is replayed continuously and with SaveData encode/decode after every season; RNG streams are held identically in both runs, not claimed persisted by the game.',
    'coverage': [
      'all four real age boards',
      'actual 21→22, 34→35, 49→50 transitions',
      'all six tile categories',
      'nine sequential story choices and persisted branch records per route',
      'all three adult NPC affinity/date/commit/marriage/child routes',
      'housing levels 1 and 2',
      'all season fees reconciled and idempotent after reload',
      'job promotions and learned skills',
      'six actual card-combat trial bosses per route, auto-triggered after eight completed map turns',
      'actual hand selection, single contact-frame resolution and independent-gauge progression',
      'pending-boss retry without dice bypass or extra season; loss recovery persists',
      'all five endings and reincarnation-history forks from each legal final state',
      'one selected immutable ending history and legal reincarnation per route',
      'four explicitly injected acceptance fixtures and separate normal/sandbox keys',
    ],
    'untested': [
      'Flutter widgets and Riverpod controller execution',
      'browser/rendering/animation/audio',
      'native SharedPreferences persistence or process restarts',
      'optional event-to-battle chains',
      'all combat strategies and all career branches',
      'statistical balance across arbitrary/random player policies',
    ],
    'normalSaveKey': match!.group(1),
    'acceptanceSaveKey': acceptanceSaveKey,
    'normalModeDefault': !acceptanceMode,
    'uniqueFreshLifeRoutes': runs.length,
    'freshLifeBranchAlternativesCovered': branchCoverage.toList()..sort(),
    'freshLifeBranchAlternativesUnvisited': unvisitedBranches,
    'syntheticSeasonFeeProbes': feeProbes,
    'executedLifeSimulationsIncludingReplay': runs.length * 2,
    'acceptanceScenarios': acceptance,
    'runs': runs,
  };
  File('$projectRoot/docs/integrated_life_report.json')
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
  print('PASS $checks assertions. Report: docs/integrated_life_report.json');
}
