// Dependency-free, executable domain tests. No Flutter runtime is required.
// From project root: dart tools/verify_story_core.dart
import 'dart:convert';
import 'dart:io';

import '../lib/domain/models/life_progress.dart';
import '../lib/domain/models/life_story.dart';
import '../lib/domain/models/player.dart';
import '../lib/domain/models/save_data.dart';
import '../lib/domain/services/life_service.dart';
import '../lib/domain/services/story_service.dart';

var storyAssertions = 0;
var storyTests = 0;

void check(bool value, String message) {
  storyAssertions++;
  if (!value) throw StateError(message);
}

void equal(Object? actual, Object? expected, String message) => check(
  jsonEncode(
        actual,
        toEncodable: (value) => value is Enum ? value.name : value.toString(),
      ) ==
      jsonEncode(
        expected,
        toEncodable: (value) => value is Enum ? value.name : value.toString(),
      ),
  '$message: $actual != $expected',
);

void rejects(void Function() action, String message, {Type? kind}) {
  storyAssertions++;
  try {
    action();
  } catch (error) {
    if (kind != null && error.runtimeType != kind) {
      throw StateError(
        '$message: expected $kind, got ${error.runtimeType}: $error',
      );
    }
    return;
  }
  throw StateError('$message: operation unexpectedly succeeded');
}

/// Flutter test delegates to the same cases so package and standalone coverage
/// cannot silently drift. Each registered case is isolated and deterministic.
void runStoryChecks({void Function(String, void Function())? register}) {
  const service = StoryService();
  const life = LifeService();
  final jobs =
      ((jsonDecode(File('assets/data/jobs.json').readAsStringSync())
                  as Map<String, dynamic>)['jobs']
              as List)
          .map((row) => row['id'] as String)
          .toSet();
  final date = DateTime.utc(2026, 10, 10);
  String snapshot(Player p) => SaveData(p, date).encode();
  Map<String, dynamic> saveJson(Player p) =>
      jsonDecode(snapshot(p)) as Map<String, dynamic>;
  Player restore(Player p) => SaveData.decode(snapshot(p), jobs).player;
  void test(String name, void Function() body) {
    void run() {
      body();
      storyTests++;
    }

    if (register != null) {
      register(name, run);
    } else {
      run();
      print('PASS $name');
    }
  }

  Player adult({
    int age = 40,
    int money = 5000,
    int home = 1,
    int eq = 70,
    int stress = 30,
    int intelligence = 30,
    List<String> skills = const ['student', 'engineer', 'mentor'],
    String? partner = 'cen_yu',
    bool married = true,
    int children = 0,
    int affinity = 80,
    Map<String, int>? steps,
    int generation = 1,
  }) {
    final turns = (age - 18) * 4;
    final state = LifeStory(lastSettledTurn: turns).copyWith(
      affinities: {
        'cen_yu': affinity,
        'chu_ye': affinity,
        'luo_qing': affinity,
      },
      partnerId: partner,
      married: married,
      children: children,
      storySteps: steps,
    );
    return Player(
      money: money,
      intelligence: intelligence,
      story: state,
      life: LifeProgress(
        turns: turns,
        homeLevel: home,
        eq: eq,
        stress: stress,
        generation: generation,
      ).copyWith(learnedSkills: skills),
    );
  }

  void unchangedFailure(
    Player p,
    void Function() action,
    String message, {
    Type? kind,
  }) {
    final before = snapshot(p);
    rejects(action, message, kind: kind);
    equal(snapshot(p), before, '$message preserves original');
  }

  test('fresh story has immutable complete NPC and chain counters', () {
    const story = LifeStory();
    equal(story.affinities, {
      'cen_yu': 0,
      'chu_ye': 0,
      'luo_qing': 0,
    }, 'default affinities');
    equal(story.storySteps, {
      'lantern': 0,
      'craft': 0,
      'roots': 0,
    }, 'default chains');
    equal(
      [
        story.partnerId,
        story.married,
        story.children,
        story.lastSettledTurn,
        story.currentEndingId,
      ],
      [null, false, 0, 0, null],
      'default scalar fields',
    );
    check(story.history.isEmpty, 'default history is empty');
    final affinities = {...story.affinities, 'cen_yu': 8};
    final steps = {...story.storySteps, 'lantern': 1};
    final records = <EndingRecord>[];
    final copy = story.copyWith(
      affinities: affinities,
      storySteps: steps,
      history: records,
    );
    affinities['cen_yu'] = 90;
    steps['lantern'] = 3;
    records.add(
      const EndingRecord(
        generation: 1,
        age: 60,
        id: 'peaceful',
        jobId: 'student',
        money: 0,
        learnedCount: 0,
      ),
    );
    equal(copy.affinities['cen_yu'], 8, 'input map copied');
    equal(copy.storySteps['lantern'], 1, 'step map copied');
    check(copy.history.isEmpty, 'input history copied');
    rejects(
      () => copy.affinities['cen_yu'] = 99,
      'exposed affinity map immutable',
      kind: UnsupportedError,
    );
    rejects(
      () => copy.storySteps.clear(),
      'exposed chain map immutable',
      kind: UnsupportedError,
    );
    rejects(
      () => copy.history.clear(),
      'exposed history immutable',
      kind: UnsupportedError,
    );
  });

  test('story branch records are immutable, survive saving and contextualize the next chapter', () {
    final original = adult();
    final a = service.chooseStory(original, 'lantern', 'a', expectedStep: 0);
    final b = service.chooseStory(original, 'lantern', 'b', expectedStep: 0);
    equal(a.story.storyChoices, {'lantern_0': 'a'}, 'branch A recorded');
    equal(b.story.storyChoices, {'lantern_0': 'b'}, 'branch B recorded');
    check(
      a.morality != b.morality && a.charm != b.charm,
      'branch changes actual stats',
    );
    final aChapter = service
        .availableStories(a)
        .singleWhere((c) => c.chainId == 'lantern');
    final bChapter = service
        .availableStories(b)
        .singleWhere((c) => c.chainId == 'lantern');
    check(
      aChapter.description.contains('親自幫忙'),
      'A continuation remembers actual choice',
    );
    check(
      bChapter.description.contains('贊助燈具'),
      'B continuation remembers actual choice',
    );
    equal(
      restore(a).story.storyChoices,
      a.story.storyChoices,
      'choices persist',
    );
    rejects(
      () => a.story.storyChoices.clear(),
      'choice records immutable',
      kind: UnsupportedError,
    );
    final input = {'lantern_0': 'b'};
    final copy = a.story.copyWith(storyChoices: input);
    input['lantern_0'] = 'a';
    equal(copy.storyChoices['lantern_0'], 'b', 'input choices copied');
    for (final choices in <Map<String, String>>[
      {'lantern_0': 'c'},
      {'lantern_1': 'a'},
      {'lantern_00': 'a'},
      {'unknown_0': 'b'},
    ]) {
      rejects(
        () => a.story.copyWith(storyChoices: choices),
        'invalid choices rejected',
        kind: FormatException,
      );
    }
    // Synthetic scenario fixtures may have a completed step without inventing
    // historical decisions. Every normal service choice records its branch.
    final fixture = const LifeStory().copyWith(
      storySteps: {'lantern': 3, 'craft': 3, 'roots': 3},
    );
    check(fixture.storyChoices.isEmpty, 'synthetic history may remain unknown');
    final reborn = service.reincarnate(a.copyWith(clearedStages: 6));
    check(
      reborn.story.storyChoices.isEmpty,
      'new generation clears old decisions',
    );
  });

  test('every ordinary Player update retains the exact story snapshot', () {
    final p = adult(children: 2, steps: {'lantern': 1, 'craft': 2, 'roots': 3});
    for (final next in [
      p.copyWith(position: 4),
      p.copyWith(jobId: 'student'),
      p.copyWith(weaponId: 'staff', inventory: {'staff': 1}),
      p.copyWith(gender: CharacterGender.female),
      p.copyWith(clearedStages: 2),
      p.apply(const StatDelta(money: -500, stamina: 4)),
      p.gainExperience(20),
      life.finishTurn(p, activity: 'work'),
      life.lifeAction(p, 'rest'),
    ]) {
      check(identical(next.story, p.story), 'Player update lost story');
    }
  });

  test(
    'catalog has three original adult NPCs and three three-chapter A/B chains',
    () {
      equal(
        service.npcs.map((n) => n.id).toSet().length,
        3,
        'three unique NPCs',
      );
      check(
        service.npcs.every((n) => n.description.contains('成年')),
        'NPCs explicitly adults',
      );
      equal(
        service.storyChains.map((c) => c.id).toSet().length,
        3,
        'three unique chains',
      );
      for (final chain in service.storyChains) {
        equal(chain.chapters.length, 3, '${chain.id} three chapters');
        for (var i = 0; i < 3; i++) {
          equal(chain.chapters[i].chainId, chain.id, 'chapter owner');
          equal(chain.chapters[i].step, i, 'chapter index');
          equal(chain.chapters[i].options.map((o) => o.id).toList(), [
            'a',
            'b',
          ], 'A/B choice IDs');
        }
      }
      final visible = service.availableStories(const Player());
      equal(visible.length, 3, 'next chapters visible including future goals');
      check(
        visible
            .singleWhere((c) => c.chainId == 'roots')
            .options
            .every((o) => !o.enabled),
        'age22 chain locked',
      );
      rejects(
        () => visible.clear(),
        'visible chapter list immutable',
        kind: UnsupportedError,
      );
      rejects(
        () => visible.first.options.clear(),
        'evaluated options immutable',
        kind: UnsupportedError,
      );
    },
  );

  for (final branch in ['a', 'b']) {
    test(
      'all three chains branch $branch settle exactly once and reject stale choices',
      () {
        var p = adult();
        for (final chain in service.storyChains) {
          for (var step = 0; step < 3; step++) {
            final before = p;
            final option = chain.chapters[step].options.singleWhere(
              (o) => o.id == branch,
            );
            p = service.chooseStory(p, chain.id, branch, expectedStep: step);
            equal(
              p.story.storySteps[chain.id],
              step + 1,
              'persistent chain step',
            );
            equal(p.life.turns, before.life.turns + 1, 'one season');
            equal(p.story.lastSettledTurn, p.life.turns, 'same season settled');
            equal(
              p.money,
              before.money +
                  option.effects.money -
                  option.cost -
                  service.livingCost(before),
              'choice fee/effect/season charged once',
            );
            equal(
              p.life.eq,
              (before.life.eq + option.eq).clamp(0, 100),
              'advertised EQ',
            );
            equal(
              p.life.stress,
              (before.life.stress + option.stress).clamp(0, 100),
              'advertised stress',
            );
            final after = p;
            unchangedFailure(
              after,
              () => service.chooseStory(
                after,
                chain.id,
                branch,
                expectedStep: step,
              ),
              'stale resolution',
              kind: StateError,
            );
            check(
              identical(service.settleSeason(p), p),
              'duplicate settlement no-op',
            );
            p = restore(p);
          }
        }
        check(
          service.availableStories(p).isEmpty,
          'all chain chapters finished',
        );
        unchangedFailure(
          p,
          () => service.chooseStory(p, 'lantern', branch, expectedStep: 3),
          'completed chain',
          kind: StateError,
        );
      },
    );
  }

  test(
    'story gate boundaries use pre-action age, EQ, skill, home and marriage',
    () {
      final cases = <(Player, String, int, String)>[
        (adult(age: 21), 'roots', 0, 'b'),
        (
          adult(eq: 54, steps: {'lantern': 1, 'craft': 0, 'roots': 0}),
          'lantern',
          1,
          'a',
        ),
        (
          adult(
            intelligence: 17,
            steps: {'lantern': 0, 'craft': 1, 'roots': 0},
          ),
          'craft',
          1,
          'a',
        ),
        (
          adult(skills: [], steps: {'lantern': 0, 'craft': 1, 'roots': 0}),
          'craft',
          1,
          'b',
        ),
        (
          adult(home: 0, steps: {'lantern': 0, 'craft': 0, 'roots': 1}),
          'roots',
          1,
          'a',
        ),
        (
          adult(
            partner: null,
            married: false,
            steps: {'lantern': 0, 'craft': 0, 'roots': 2},
          ),
          'roots',
          2,
          'a',
        ),
      ];
      for (final (p, chain, step, choice) in cases) {
        final option = service
            .availableStories(p)
            .singleWhere((c) => c.chainId == chain)
            .options
            .singleWhere((o) => o.id == choice);
        check(
          !option.enabled && option.blockedReason != null,
          '$chain gate visible',
        );
        unchangedFailure(
          p,
          () => service.chooseStory(p, chain, choice, expectedStep: step),
          '$chain gate',
          kind: StateError,
        );
      }
      check(
        service
            .availableStories(adult(age: 22))
            .singleWhere((c) => c.chainId == 'roots')
            .options
            .last
            .enabled,
        'exact age22 accepted',
      );
      final exactEq = adult(
        eq: 55,
        steps: {'lantern': 1, 'craft': 0, 'roots': 0},
      );
      service.chooseStory(exactEq, 'lantern', 'a', expectedStep: 1);
      final exactInt = adult(
        intelligence: 18,
        steps: {'lantern': 0, 'craft': 1, 'roots': 0},
      );
      service.chooseStory(exactInt, 'craft', 'a', expectedStep: 1);
      unchangedFailure(
        adult(),
        () => service.chooseStory(adult(), 'missing', 'a', expectedStep: 0),
        'unknown chain',
        kind: ArgumentError,
      );
      unchangedFailure(
        adult(),
        () =>
            service.chooseStory(adult(), 'lantern', 'missing', expectedStep: 0),
        'unknown option',
        kind: ArgumentError,
      );
    },
  );

  test('all story choice fees reject one short and permit exact balance', () {
    for (final chain in service.storyChains) {
      for (final chapter in chain.chapters) {
        for (final choice in chapter.options.where((o) => o.cost > 0)) {
          final steps = {
            ...const LifeStory().storySteps,
            chain.id: chapter.step,
          };
          final poor = adult(money: choice.cost - 1, steps: steps);
          unchangedFailure(
            poor,
            () => service.chooseStory(
              poor,
              chain.id,
              choice.id,
              expectedStep: chapter.step,
            ),
            '${chapter.id}${choice.id} insufficient fee',
            kind: StateError,
          );
          final exact = adult(money: choice.cost, steps: steps);
          final next = service.chooseStory(
            exact,
            chain.id,
            choice.id,
            expectedStep: chapter.step,
          );
          equal(
            next.money,
            0,
            'exact choice fee leaves no negative balance after living cost',
          );
          equal(
            next.life.stress,
            (exact.life.stress + choice.stress + 8).clamp(0, 100),
            'shortfall stress after exact fee',
          );
        }
      }
    }
  });

  test('meeting, dates, commitment, marriage and chosen parenthood form valid transitions', () {
    var p = adult(
      age: 22,
      money: 10000,
      home: 0,
      partner: null,
      married: false,
      affinity: 0,
      skills: [],
    );
    for (var i = 0; i < 2; i++) p = service.perform(p, 'talk', npcId: 'cen_yu');
    equal(p.story.affinities['cen_yu'], 16, 'two chats unlock dates');
    p = service.perform(p, 'date', npcId: 'cen_yu');
    p = service.perform(p, 'date', npcId: 'cen_yu');
    equal(p.story.affinities['cen_yu'], 40, 'two dates reach commitment');
    p = service.perform(p, 'commit', npcId: 'cen_yu');
    equal(p.story.partnerId, 'cen_yu', 'chosen adult partner');
    check(
      !p.story.married && p.story.children == 0,
      'commitment no autonomous marriage or child',
    );
    p = service.settleSeason(life.lifeAction(p, 'buyHome'));
    for (var i = 0; i < 3; i++) p = service.perform(p, 'date');
    final beforeMarriage = p;
    p = service.perform(p, 'propose');
    check(p.story.married, 'proposal changes marriage');
    equal(beforeMarriage.money - p.money, 1210, 'proposal plus home upkeep');
    check(p.story.children == 0, 'marriage never auto-creates child');
    while (p.life.age < 25)
      p = service.settleSeason(life.lifeAction(p, 'rest'));
    final beforeChild = p;
    p = service.perform(p, 'child');
    equal(p.story.children, 1, 'explicit action creates one child');
    equal(
      beforeChild.money - p.money,
      825,
      'child fee plus new household upkeep',
    );
    p = service.perform(p, 'child');
    equal(p.story.children, 2, 'second explicit child');
    final family = p;
    p = service.perform(p, 'familyTime');
    equal(p.life.eq, (family.life.eq + 4).clamp(0, 100), 'family improves EQ');
    equal(
      p.life.stress,
      (family.life.stress - 10).clamp(0, 100),
      'family reduces stress',
    );
    equal(
      p.money,
      family.money - 40 - 40,
      'family action plus home and two children',
    );
    final current = p;
    unchangedFailure(
      current,
      () => service.perform(current, 'child'),
      'third child blocked',
      kind: StateError,
    );
    equal(restore(p).story.toJson(), p.story.toJson(), 'family persists');
  });

  test('relationship invalid transitions preserve the player', () {
    final cases = <(Player, String, String?)>[
      (const Player(), 'talk', null),
      (adult(affinity: 15, partner: null, married: false), 'date', 'cen_yu'),
      (adult(age: 21, partner: null, married: false), 'commit', 'cen_yu'),
      (adult(affinity: 39, partner: null, married: false), 'commit', 'cen_yu'),
      (adult(), 'commit', 'chu_ye'),
      (adult(), 'date', 'chu_ye'),
      (adult(partner: null, married: false), 'propose', 'cen_yu'),
      (adult(affinity: 69, married: false), 'propose', null),
      (adult(home: 0, married: false), 'propose', null),
      (adult(), 'propose', null),
      (adult(married: false), 'child', null),
      (adult(age: 24), 'child', null),
      (adult(age: 56), 'child', null),
      (adult(children: 2), 'child', null),
      (adult(), 'child', 'chu_ye'),
      (adult(partner: null, married: false), 'familyTime', 'cen_yu'),
      (adult(), 'familyTime', 'chu_ye'),
    ];
    for (final (p, action, target) in cases) {
      final info = service.relationshipActionInfo(p, action, npcId: target);
      check(
        !info.enabled && info.blockedReason != null,
        '$action reason shown',
      );
      unchangedFailure(
        p,
        () => service.perform(p, action, npcId: target),
        '$action invalid transition',
        kind: StateError,
      );
    }
    unchangedFailure(
      adult(),
      () => service.perform(adult(), 'missing'),
      'unknown action',
      kind: ArgumentError,
    );
    unchangedFailure(
      adult(),
      () => service.perform(adult(), 'talk', npcId: 'unknown'),
      'unknown adult',
      kind: ArgumentError,
    );
    // Conversation remains platonic and allowed with any adult after commitment.
    final chatted = service.perform(adult(), 'talk', npcId: 'chu_ye');
    equal(chatted.story.partnerId, 'cen_yu', 'chat cannot switch partner');
  });

  test('all relationship fee boundaries and exact child ages are enforced', () {
    for (final action in StoryService.actions) {
      final template = adult(
        age: action == 'child' ? 25 : 40,
        partner: action == 'commit' ? null : 'cen_yu',
        married: action != 'propose' && action != 'commit',
      );
      final cost = service
          .relationshipActionInfo(template, action, npcId: 'cen_yu')
          .cost;
      if (cost > 0) {
        final poor = template.apply(
          StatDelta(money: -template.money + cost - 1),
        );
        unchangedFailure(
          poor,
          () => service.perform(poor, action, npcId: 'cen_yu'),
          '$action fee boundary',
          kind: StateError,
        );
      }
      final exact = template.apply(StatDelta(money: -template.money + cost));
      final next = service.perform(exact, action, npcId: 'cen_yu');
      equal(next.money, 0, '$action no negative money');
      equal(
        next.life.turns,
        exact.life.turns + 1,
        '$action consumes one season',
      );
      equal(
        next.story.lastSettledTurn,
        next.life.turns,
        '$action living cost settled',
      );
      check(
        service
            .relationshipActionInfo(template, action, npcId: 'cen_yu')
            .description
            .contains('1 季'),
        'action discloses season',
      );
    }
    check(
      service.relationshipActionInfo(adult(age: 25), 'child').enabled,
      'child exact age25',
    );
    check(
      service.relationshipActionInfo(adult(age: 55), 'child').enabled,
      'child exact age55',
    );
    check(
      service
          .relationshipActionInfo(
            adult(age: 22, partner: null, married: false, affinity: 40),
            'commit',
            npcId: 'cen_yu',
          )
          .enabled,
      'exact age22/affinity40 commit',
    );
    check(
      service
          .relationshipActionInfo(
            adult(married: false, affinity: 70),
            'propose',
          )
          .enabled,
      'exact affinity70 proposal',
    );
  });

  test('season settlement charges every pending season once, with bounded shortfall stress', () {
    var p = adult(money: 500, home: 2, children: 2);
    equal(service.livingCost(p), 50, 'home+child formula');
    check(
      service.livingCostDescription(p).contains('50'),
      'finance description current total',
    );
    p = p.copyWith(life: p.life.copyWith(turns: p.life.turns + 3));
    final settled = service.settleSeason(p);
    equal(settled.money, 350, 'three pending seasons');
    equal(settled.life.stress, p.life.stress, 'funded seasons no stress');
    check(
      identical(service.settleSeason(settled), settled),
      'repeat settlement identical',
    );
    final reloaded = restore(settled);
    check(
      identical(service.settleSeason(reloaded), reloaded),
      'save/reload cannot charge twice',
    );
    final poor = p.apply(const StatDelta(money: -440));
    final short = service.settleSeason(poor);
    equal(short.money, 0, 'shortfall floors money');
    equal(
      short.life.stress,
      poor.life.stress + 16,
      '60 funds one of three50 seasons',
    );
    final exact = p.apply(const StatDelta(money: -350));
    equal(
      service.settleSeason(exact).life.stress,
      p.life.stress,
      'exact total bill no shortfall',
    );
    final longGap = const Player(
      money: 0,
      life: LifeProgress(turns: 1000000, homeLevel: 2),
    );
    equal(
      service.settleSeason(longGap).life.stress,
      100,
      'huge catchup clamps stress',
    );
    equal(
      service.settleSeason(longGap).story.lastSettledTurn,
      1000000,
      'huge catchup settles to currentturn',
    );
    final free = const Player(life: LifeProgress(turns: 100));
    equal(
      service.settleSeason(free).money,
      1000,
      'zero household cost no bill',
    );
    equal(
      service.settleSeason(free).story.lastSettledTurn,
      100,
      'zero cost still marked settled',
    );
    rejects(
      () => service.settleSeason(
        const Player(story: LifeStory(lastSettledTurn: 1)),
      ),
      'future marker rejected',
      kind: StateError,
    );
  });

  test(
    'age sixty and six-stage endings enforce categories with peaceful fallback',
    () {
      check(
        service.eligibleEndings(adult(age: 59)).isEmpty,
        'age59 unfinished life no ending',
      );
      equal(
        service
            .eligibleEndings(
              adult(
                age: 60,
                skills: [],
                partner: null,
                married: false,
                home: 0,
              ),
            )
            .map((e) => e.id)
            .toList(),
        ['peaceful'],
        'always peaceful fallback',
      );
      final complete = adult(home: 2, children: 1).copyWith(clearedStages: 6);
      equal(service.eligibleEndings(complete).map((e) => e.id).toList(), [
        'trials',
        'scholar',
        'family',
        'prosperity',
        'peaceful',
      ], 'all five earned categories');
      check(
        !service
            .eligibleEndings(adult(age: 60, home: 2, money: 4999))
            .any((e) => e.id == 'prosperity'),
        'prosperity money lower boundary',
      );
      check(
        service
            .eligibleEndings(adult(age: 60, home: 2, money: 5000))
            .any((e) => e.id == 'prosperity'),
        'prosperity exact money',
      );
      check(
        !service
            .eligibleEndings(adult(age: 60, skills: ['student', 'engineer']))
            .any((e) => e.id == 'scholar'),
        'scholar needs three',
      );
      check(
        !service.eligibleEndings(adult(age: 60)).any((e) => e.id == 'family'),
        'marriage alone not family ending',
      );
      for (final ending in service.endings)
        check(
          ending.requirement.isNotEmpty && ending.description.isNotEmpty,
          'ending requirements exposed',
        );
      unchangedFailure(
        adult(),
        () => service.concludeLife(adult(), 'peaceful'),
        'premature conclusion',
        kind: StateError,
      );
      unchangedFailure(
        complete,
        () => service.concludeLife(complete, 'missing'),
        'unknown ending',
        kind: ArgumentError,
      );
    },
  );

  test('ending snapshots are frozen once per generation without bonuses and allow continued play', () {
    final p = adult(age: 60, children: 1, home: 2).copyWith(jobId: 'mentor');
    final ended = service.concludeLife(p, 'family');
    equal(ended.story.currentEndingId, 'family', 'selected ending');
    equal(ended.story.history.single.toJson(), {
      'generation': 1,
      'age': 60,
      'id': 'family',
      'jobId': 'mentor',
      'money': 5000,
      'learnedCount': 3,
    }, 'full frozen snapshot');
    equal(
      [ended.money, ended.intelligence, ended.life.turns],
      [p.money, p.intelligence, p.life.turns],
      'no reward or turn awarded',
    );
    check(
      identical(service.concludeLife(ended, 'family'), ended),
      'same conclusion no-op',
    );
    unchangedFailure(
      ended,
      () => service.concludeLife(ended, 'scholar'),
      'alternate conclusion cannot rewrite',
      kind: StateError,
    );
    var continued = service.settleSeason(
      life.finishTurn(
        ended.apply(const StatDelta(money: 500)),
        activity: 'work',
      ),
    );
    continued = service.perform(continued, 'familyTime');
    equal(
      continued.story.history.single.toJson(),
      ended.story.history.single.toJson(),
      'later work and family do not rewrite snapshot',
    );
    continued = restore(continued);
    equal(
      continued.story.history.single.toJson(),
      ended.story.history.single.toJson(),
      'snapshot survives save',
    );
    check(
      identical(service.concludeLife(continued, 'family'), continued),
      'repeat after continuing still no-op',
    );
  });

  test('reincarnation validates skill first, records default ending, resets story and keeps history', () {
    final p =
        adult(
          age: 60,
          children: 2,
          steps: {'lantern': 3, 'craft': 2, 'roots': 1},
        ).copyWith(
          gender: CharacterGender.female,
          jobId: 'mentor',
          weaponId: 'staff',
          inventory: {'staff': 1},
        );
    unchangedFailure(
      p,
      () => service.reincarnate(p, inheritSkill: 'hero'),
      'unearned inheritance',
      kind: StateError,
    );
    final next = service.reincarnate(p, inheritSkill: 'mentor');
    equal(next.life.generation, 2, 'generation increments');
    equal(next.gender, CharacterGender.female, 'gender retained');
    equal(next.intelligence, 16, 'selected perk applied once');
    equal(next.life.learnedSkills, ['mentor'], 'only inherited skill');
    equal(
      next.story.history.single.id,
      'scholar',
      'sensible eligible default recorded',
    );
    equal(next.story.history.single.age, 60, 'past life age');
    equal(
      [
        next.story.partnerId,
        next.story.married,
        next.story.children,
        next.story.lastSettledTurn,
        next.story.currentEndingId,
      ],
      [null, false, 0, 0, null],
      'relationships, marker and ending reset',
    );
    equal(
      next.story.affinities,
      const LifeStory().affinities,
      'NPC affinities reset',
    );
    equal(next.story.storySteps, const LifeStory().storySteps, 'chains reset');
    equal(
      [next.money, next.weaponId, next.life.homeLevel, next.life.turns],
      [1000, 'none', 0, 0],
      'base reset preserved',
    );
    final loaded = restore(next);
    equal(loaded.intelligence, 16, 'reload does not reapply perk');
    check(
      identical(service.settleSeason(loaded), loaded),
      'fresh generation never billed for old turns',
    );
    unchangedFailure(
      loaded,
      () => service.reincarnate(loaded, inheritSkill: 'mentor'),
      'repeat early reincarnation',
      kind: StateError,
    );
    final ended = service.concludeLife(p, 'family');
    final carried = service.reincarnate(ended);
    equal(
      carried.story.history.length,
      1,
      'already concluded not recorded twice',
    );
    equal(carried.story.history.single.id, 'family', 'chosen ending retained');
  });

  test('thirty-generation cap discards oldest records and preserves chronological frozen history', () {
    var p = adult(age: 60, skills: [], partner: null, married: false);
    for (var i = 1; i <= 35; i++) {
      p = service.reincarnate(p.copyWith(clearedStages: 6));
      equal(p.life.generation, i + 1, 'generation iteration');
      equal(p.story.history.length, i.clamp(0, 30), 'history cap');
      equal(p.story.history.last.generation, i, 'latest generation');
      p = restore(p);
    }
    equal(p.story.history.first.generation, 6, 'five oldest dropped');
    equal(p.story.history.last.generation, 35, 'most recent kept');
    check(p.story.currentEndingId == null, 'fresh life no conclusion');
  });

  for (var version = 1; version <= 7; version++) {
    test(
      'schema $version migration preserves legacy stats, equipment and life without retroactive fees',
      () {
        final oldLife =
            const LifeProgress(
              turns: 91,
              generation: 3,
              homeLevel: 2,
              eq: 71,
              stress: 33,
              affection: 66,
            ).copyWith(
              jobPractice: {'student': 5},
              learnedSkills: ['student'],
              inheritedSkill: 'student',
            );
        final fields = <String, dynamic>{
          'position': 19,
          'stamina': 77,
          'intelligence': 88,
          'charm': 66,
          'money': 5432,
          'jobId': version < 3 ? 'junior_engineer' : 'engineer',
          if (version >= 2) 'experience': 321,
          if (version >= 3) 'morality': 55,
          if (version >= 4) ...{
            'gender': 'female',
            'weaponId': 'staff',
            'inventory': {'staff': 1, 'plate': 1, 'ring': 1, 'potion': 4},
          },
          if (version >= 5) ...{'clearedStages': 4, 'stageWins': 2},
          if (version >= 6) ...{'armorId': 'plate', 'accessoryId': 'ring'},
          if (version >= 7) 'life': oldLife.toJson(),
        };
        final migrated = SaveData.decode(
          jsonEncode({
            'schemaVersion': version,
            'savedAt': date.toIso8601String(),
            'player': fields,
          }),
          jobs,
        ).player;
        equal(
          [
            migrated.stamina,
            migrated.intelligence,
            migrated.charm,
            migrated.money,
          ],
          [77, 88, 66, 5432],
          'legacy core stats',
        );
        equal(migrated.position, 19, 'legacy board position');
        equal(migrated.jobId, 'engineer', 'legacy job mapping');
        equal(migrated.morality, version >= 3 ? 55 : 10, 'legacy morality');
        equal(migrated.experience, version >= 2 ? 321 : 0, 'legacy experience');
        equal(
          migrated.weaponId,
          version >= 4 ? 'staff' : 'none',
          'legacy weapon',
        );
        equal(
          migrated.gender.name,
          version >= 4 ? 'female' : 'male',
          'legacy gender',
        );
        equal(
          migrated.armorId,
          version >= 6 ? 'plate' : 'none',
          'legacy armor',
        );
        equal(
          migrated.accessoryId,
          version >= 6 ? 'ring' : 'none',
          'legacy accessory',
        );
        equal(
          migrated.clearedStages,
          version >= 5 ? 4 : 0,
          'legacy cleared stages',
        );
        equal(
          migrated.stageWins,
          version >= 5 ? 2 : 0,
          'legacy partial stage wins',
        );
        equal(
          migrated.life.toJson(),
          version >= 7 ? oldLife.toJson() : const LifeProgress().toJson(),
          'legacy life intact',
        );
        equal(
          migrated.story.lastSettledTurn,
          version >= 7 ? 91 : 0,
          'migration no backfill marker',
        );
        check(
          identical(service.settleSeason(migrated), migrated),
          'no retroactive cost on migration',
        );
        final next = service.settleSeason(
          life.finishTurn(migrated, activity: 'shop'),
        );
        equal(
          next.money,
          migrated.money - (version >= 7 ? 20 : 0),
          'only newly completed season billed',
        );
        equal(saveJson(migrated)['schemaVersion'], 9, 'reencode upgrades to8');
        equal(
          snapshot(restore(migrated)),
          snapshot(migrated),
          'migration stable roundtrip',
        );
      },
    );
  }

  test('schema eight roundtrip preserves all fields and never reapplies story effects', () {
    var p = adult(
      age: 60,
      children: 2,
      steps: {'lantern': 2, 'craft': 3, 'roots': 1},
    ).copyWith(clearedStages: 6);
    p = service.concludeLife(p, 'family');
    equal(saveJson(p)['schemaVersion'], 9, 'schema8 encoded');
    final loaded = restore(p);
    equal(snapshot(loaded), snapshot(p), 'full save identical');
    equal(snapshot(restore(loaded)), snapshot(p), 'second load identical');
    rejects(
      () => loaded.story.affinities.clear(),
      'loaded map immutable',
      kind: UnsupportedError,
    );
    rejects(
      () => loaded.story.history.clear(),
      'loaded history immutable',
      kind: UnsupportedError,
    );
  });

  test('schema eight strictly rejects malformed scalars, maps, IDs and relationship states', () {
    final corruptions = <String, List<Object?>>{
      'affinities': [
        null,
        [],
        {},
        {'cen_yu': 0, 'chu_ye': 0, 'missing': 0},
        {'cen_yu': -1, 'chu_ye': 0, 'luo_qing': 0},
        {'cen_yu': 101, 'chu_ye': 0, 'luo_qing': 0},
        {'cen_yu': '8', 'chu_ye': 0, 'luo_qing': 0},
      ],
      'storySteps': [
        null,
        [],
        {},
        {'lantern': 4, 'craft': 0, 'roots': 0},
        {'lantern': -1, 'craft': 0, 'roots': 0},
        {'lantern': true, 'craft': 0, 'roots': 0},
      ],
      'storyChoices': [
        null,
        [],
        {'missing_0': 'a'},
        {'lantern_0': 'a'},
        {'lantern_0': 'c'},
        {'lantern_3': 'a'},
        {'lantern_00': 'a'},
        {'craft_1': 3},
      ],
      'partnerId': ['', 'unknown', false, 1],
      'married': [null, 1, 'false', true],
      'children': [-1, 1, 3, false, '1', 1.5],
      'lastSettledTurn': [-1, 1, 1000001, null, false, '0'],
      'history': [
        null,
        {},
        [null],
        [1],
      ],
      'currentEndingId': ['', false, 'unknown', 'peaceful'],
    };
    for (final entry in corruptions.entries) {
      for (final value in entry.value) {
        final raw = saveJson(const Player());
        raw['player']['story'][entry.key] = value;
        rejects(
          () => SaveData.decode(jsonEncode(raw), jobs),
          '${entry.key}=$value',
          kind: FormatException,
        );
      }
    }
    for (final key
        in (saveJson(const Player())['player']['story'] as Map).keys) {
      final raw = saveJson(const Player());
      raw['player']['story'].remove(key);
      rejects(
        () => SaveData.decode(jsonEncode(raw), jobs),
        'missing story key $key',
        kind: FormatException,
      );
    }
    final extra = saveJson(const Player());
    extra['player']['story']['extra'] = 1;
    rejects(
      () => SaveData.decode(jsonEncode(extra), jobs),
      'unexpected story key',
      kind: FormatException,
    );
    final missing = saveJson(const Player());
    missing['player'].remove('story');
    rejects(
      () => SaveData.decode(jsonEncode(missing), jobs),
      'missing schema8 story',
      kind: FormatException,
    );
    final future = saveJson(const Player());
    future['schemaVersion'] = 10;
    rejects(
      () => SaveData.decode(jsonEncode(future), jobs),
      'future schema',
      kind: FormatException,
    );
  });

  test('schema eight rejects inconsistent, duplicated, future or oversized ending history', () {
    final ended = service.concludeLife(adult(age: 60), 'scholar');
    final corruptions = <void Function(Map<String, dynamic>)>[
      (s) => s['history'][0]['generation'] = 2,
      (s) => s['history'][0]['generation'] = 0,
      (s) => s['history'][0]['age'] = 61,
      (s) => s['history'][0]['age'] = 17,
      (s) => s['history'][0]['id'] = 'unknown',
      (s) => s['history'][0]['jobId'] = 'unknown',
      (s) => s['history'][0]['money'] = -1,
      (s) => s['history'][0]['learnedCount'] = -1,
      (s) => s['history'][0]['money'] = 1.5,
      (s) => s['history'][0]['extra'] = true,
      (s) => s['history'].add(Map<String, dynamic>.from(s['history'][0])),
      (s) => s['currentEndingId'] = 'peaceful',
      (s) => s['currentEndingId'] = null,
      (s) => s['history'] = [],
      (s) => s['history'] = List.generate(
        31,
        (i) => {
          ...s['history'][0] as Map<String, dynamic>,
          'generation': i + 1,
        },
      ),
    ];
    for (var i = 0; i < corruptions.length; i++) {
      final raw = saveJson(ended);
      corruptions[i](raw['player']['story'] as Map<String, dynamic>);
      rejects(
        () => SaveData.decode(jsonEncode(raw), jobs),
        'bad history variant$i',
        kind: FormatException,
      );
    }
  });

  test('turn and generation limits reject all pending actions without partial updates', () {
    final base = adult();
    final capped = base.copyWith(
      life: base.life.copyWith(turns: LifeProgress.maxCounter),
      story: base.story.copyWith(lastSettledTurn: LifeProgress.maxCounter),
    );
    unchangedFailure(
      capped,
      () => service.perform(capped, 'talk'),
      'turn cap relationship',
      kind: StateError,
    );
    unchangedFailure(
      capped,
      () => service.chooseStory(capped, 'lantern', 'a', expectedStep: 0),
      'turn cap story',
      kind: StateError,
    );
    final generationCap = adult(age: 60, generation: LifeProgress.maxCounter);
    unchangedFailure(
      generationCap,
      () => service.reincarnate(generationCap),
      'generation cap',
      kind: StateError,
    );
  });
}

void main() {
  runStoryChecks();
  print(
    'PASS $storyTests story test cases, $storyAssertions assertions; pure Dart only.',
  );
}
