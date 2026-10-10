// Dependency-free verification for environments without Flutter packages.
// Run from project root: dart tools/verify_life_core.dart
import 'dart:convert';
import 'dart:io';

import '../lib/domain/models/life_progress.dart';
import '../lib/domain/models/player.dart';
import '../lib/domain/models/save_data.dart';
import '../lib/domain/services/life_service.dart';

void runTests() {
  const service = LifeService();
  final jobRows =
      (jsonDecode(File('assets/data/jobs.json').readAsStringSync())
              as Map<String, dynamic>)['jobs']
          as List<dynamic>;
  final jobIds = jobRows.map((row) => row['id'] as String).toSet();
  final date = DateTime.utc(2026, 10, 10);
  String snapshot(Player p) => SaveData(p, date).encode();
  Map<String, dynamic> saveJson(Player p) =>
      jsonDecode(snapshot(p)) as Map<String, dynamic>;
  Player restore(Player p) => SaveData.decode(snapshot(p), jobIds).player;

  group('immutable life state', () {
    test(
      'defaults, seasons, and birthdays use exactly four turns per year',
      () {
        const life = LifeProgress();
        expect(life.turns, 0);
        expect(life.generation, 1);
        expect(life.eq, 50);
        expect([life.stress, life.affection, life.homeLevel], [0, 0, 0]);
        expect(life.jobPractice, isEmpty);
        expect(life.learnedSkills, isEmpty);
        expect(life.inheritedSkill, isNull);
        expect(life.age, 18);
        expect(
          [for (var i = 0; i < 5; i++) life.copyWith(turns: i).season],
          ['春', '夏', '秋', '冬', '春'],
        );
        expect(life.copyWith(turns: 3).age, 18);
        expect(life.copyWith(turns: 4).age, 19);
        expect(life.copyWith(turns: 168).age, 60);
      },
    );

    test(
      'collection inputs and exposed collections cannot mutate a snapshot',
      () {
        final practice = {'student': 3};
        final skills = ['student'];
        final life = const LifeProgress().copyWith(
          jobPractice: practice,
          learnedSkills: skills,
          inheritedSkill: 'student',
        );
        practice['student'] = 99;
        skills.add('hero');
        expect(life.jobPractice, {'student': 3});
        expect(life.learnedSkills, ['student']);
        expect(() => life.jobPractice['student'] = 100, throwsUnsupportedError);
        expect(() => life.learnedSkills.add('hero'), throwsUnsupportedError);
        expect(life.copyWith(stress: 2).inheritedSkill, 'student');
        expect(life.copyWith(clearInheritedSkill: true).inheritedSkill, isNull);
      },
    );

    test('every existing player update preserves its life snapshot', () {
      final life = const LifeProgress(
        turns: 22,
        generation: 2,
        eq: 65,
        stress: 12,
        affection: 40,
        homeLevel: 1,
      ).copyWith(jobPractice: {'student': 3}, learnedSkills: ['student']);
      final p = Player(life: life);
      for (final next in [
        p.copyWith(position: 8),
        p.copyWith(jobId: 'student'),
        p.copyWith(gender: CharacterGender.female),
        p.copyWith(weaponId: 'staff', inventory: {'staff': 1}),
        p.copyWith(clearedStages: 1, stageWins: 2),
        p.apply(const StatDelta(money: -100, intelligence: 5)),
        p.gainExperience(100),
      ]) {
        expect(identical(next.life, life), isTrue);
      }
    });
  });

  group('board turn settlement and passive skills', () {
    test(
      'every activity advances once and does not charge unrelated money',
      () {
        const p = Player(money: 1234, life: LifeProgress(stress: 20));
        for (final activity in LifeService.activities) {
          final next = service.finishTurn(p, activity: activity);
          expect(next.life.turns, 1, reason: activity);
          expect(next.money, 1234, reason: activity);
          expect(next.life.jobPractice.length, activity == 'work' ? 1 : 0);
        }
        expect(p.life.turns, 0);
        final before = snapshot(p);
        expect(
          () => service.finishTurn(p, activity: 'missing'),
          throwsArgumentError,
        );
        expect(snapshot(p), before);
      },
    );

    test('practice teaches a job skill on turn three, exactly once', () {
      var p = const Player(jobId: 'student');
      p = service.finishTurn(p, activity: 'work');
      p = service.finishTurn(p, activity: 'work');
      expect(p.life.jobPractice['student'], 2);
      expect(p.life.learnedSkills, isEmpty);
      expect(p.intelligence, 10);
      p = service.finishTurn(p, activity: 'work');
      expect(p.life.learnedSkills, ['student']);
      expect(p.intelligence, 12);
      for (var i = 0; i < 12; i++) {
        p = service.finishTurn(p, activity: 'work');
      }
      expect(p.life.turns, 15);
      expect(p.life.jobPractice['student'], 15);
      expect(p.life.learnedSkills, ['student']);
      expect(p.intelligence, 12);
    });

    test(
      'each job owns its practice and known skills survive career changes',
      () {
        var p = const Player(jobId: 'student');
        p = service.finishTurn(p, activity: 'work');
        p = p.copyWith(jobId: 'part_timer');
        for (var i = 0; i < 3; i++) {
          p = service.finishTurn(p, activity: 'work');
        }
        expect(p.life.jobPractice, {'student': 1, 'part_timer': 3});
        expect(p.stamina, 12);
        expect(p.intelligence, 10);
        p = p.copyWith(jobId: 'student');
        p = service.finishTurn(p, activity: 'work');
        p = service.finishTurn(p, activity: 'work');
        expect(p.life.learnedSkills, ['part_timer', 'student']);
        expect(p.intelligence, 12);
        expect(p.stamina, 12);
      },
    );

    test('all shipped job IDs have original tier-scaled perk descriptions', () {
      for (final row in jobRows) {
        final id = row['id'] as String;
        final tier = row['tier'] as int;
        final bonus = service.skillBonus(id);
        expect(bonus.money, 0);
        expect(
          bonus.stamina + bonus.intelligence + bonus.charm + bonus.morality,
          tier == 0 ? 1 : tier * 2,
          reason: id,
        );
        expect(service.skillDescription(id), contains(bonus.summary));
      }
      expect(service.skillBonus('student').intelligence, 2);
      expect(service.skillBonus('warrior').stamina, 4);
      expect(service.skillBonus('president').charm, 6);
      expect(service.skillBonus('paladin').morality, 6);
      expect(() => service.skillBonus('unknown'), throwsArgumentError);
    });

    test('meters clamp and homes reduce stress once per board turn', () {
      const p = Player(life: LifeProgress(eq: 99, stress: 99, homeLevel: 2));
      final career = service.finishTurn(p, activity: 'career');
      expect(career.life.eq, 100);
      expect(career.life.stress, 98);
      expect(service.finishTurn(p, activity: 'penalty').life.stress, 100);
      expect(
        service.finishTurn(const Player(), activity: 'luck').life.stress,
        0,
      );
    });

    test('age sixty unlocks reincarnation without locking normal play', () {
      const p = Player(life: LifeProgress(turns: 168));
      expect(service.canReincarnate(p), isTrue);
      expect(service.finishTurn(p, activity: 'work').life.turns, 169);
      expect(service.lifeAction(p, 'rest').life.turns, 169);
    });
  });

  group('life actions', () {
    test('study, exercise and socializing have truthful costs and effects', () {
      const p = Player(life: LifeProgress(stress: 20));
      final study = service.lifeAction(p, 'study');
      expect(
        [study.money, study.intelligence, study.life.stress],
        [800, 15, 23],
      );
      final exercise = service.lifeAction(p, 'exercise');
      expect(
        [exercise.money, exercise.stamina, exercise.life.stress],
        [900, 15, 16],
      );
      final socialize = service.lifeAction(p, 'socialize');
      expect(
        [
          socialize.money,
          socialize.life.affection,
          socialize.life.eq,
          socialize.life.stress,
        ],
        [850, 8, 53, 17],
      );
      for (final next in [study, exercise, socialize]) {
        expect(next.life.turns, 1);
        expect(next.life.jobPractice, isEmpty);
        expect(next.life.learnedSkills, isEmpty);
      }
    });

    test('rest is free and meter changes do not underflow or overflow', () {
      final rested = service.lifeAction(
        const Player(money: 0, life: LifeProgress(stress: 5)),
        'rest',
      );
      expect(rested.money, 0);
      expect(rested.life.stress, 0);
      expect(rested.life.turns, 1);
      final socialized = service.lifeAction(
        const Player(life: LifeProgress(eq: 99, affection: 98)),
        'socialize',
      );
      expect([socialized.life.eq, socialized.life.affection], [100, 100]);
      expect(
        service
            .lifeAction(const Player(life: LifeProgress(stress: 99)), 'study')
            .life
            .stress,
        100,
      );
    });

    test(
      'affordability checks exact thresholds and failures are immutable',
      () {
        for (final entry in {
          'study': 200,
          'exercise': 100,
          'socialize': 150,
          'buyHome': 2500,
        }.entries) {
          final poor = Player(money: entry.value - 1);
          final before = snapshot(poor);
          expect(
            () => service.lifeAction(poor, entry.key),
            throwsStateError,
            reason: entry.key,
          );
          expect(snapshot(poor), before);
          final exact = service.lifeAction(
            Player(money: entry.value),
            entry.key,
          );
          expect(exact.money, 0);
          expect(exact.life.turns, 1);
        }
        const p = Player();
        final before = snapshot(p);
        expect(() => service.lifeAction(p, 'unknown'), throwsArgumentError);
        expect(snapshot(p), before);
      },
    );

    test(
      'homes use staged prices and cannot be purchased beyond level two',
      () {
        var p = const Player(money: 9000);
        expect(service.homeCost(p), 2500);
        p = service.lifeAction(p, 'buyHome');
        expect([p.money, p.life.homeLevel, p.life.turns], [6500, 1, 1]);
        expect(service.homeCost(p), 6500);
        p = service.lifeAction(p, 'buyHome');
        expect([p.money, p.life.homeLevel, p.life.turns], [0, 2, 2]);
        final before = snapshot(p);
        expect(() => service.lifeAction(p, 'buyHome'), throwsStateError);
        expect(snapshot(p), before);
        expect(service.homeCost(p), 0);
      },
    );
  });

  group('reincarnation', () {
    test(
      'requires campaign completion or age sixty and validates selection',
      () {
        const young = Player(life: LifeProgress(turns: 167));
        expect(service.canReincarnate(young), isFalse);
        expect(() => service.reincarnate(young), throwsStateError);
        const complete = Player(clearedStages: 6);
        expect(service.canReincarnate(complete), isTrue);
        final before = snapshot(complete);
        expect(
          () => service.reincarnate(complete, inheritSkill: 'hero'),
          throwsStateError,
        );
        expect(snapshot(complete), before);
        expect(
          service.canReincarnate(const Player(life: LifeProgress(turns: 168))),
          isTrue,
        );
      },
    );

    test('resets world, growth, inventory, equipment and all life meters', () {
      final p = Player(
        clearedStages: 6,
        position: 18,
        stamina: 200,
        intelligence: 200,
        charm: 200,
        morality: 200,
        money: 99999,
        experience: 1500,
        jobId: 'hero',
        gender: CharacterGender.female,
        weaponId: 'staff',
        armorId: 'plate',
        accessoryId: 'ring',
        inventory: const {'staff': 1, 'plate': 1, 'ring': 1, 'potion': 90},
        life:
            const LifeProgress(
              turns: 180,
              generation: 3,
              eq: 90,
              stress: 88,
              affection: 100,
              homeLevel: 2,
            ).copyWith(
              jobPractice: {'hero': 8},
              learnedSkills: ['student', 'hero'],
            ),
      );
      final next = service.reincarnate(p, inheritSkill: 'hero');
      expect(next.gender, CharacterGender.female);
      expect(
        [next.clearedStages, next.stageWins, next.position, next.experience],
        [0, 0, 0, 0],
      );
      expect(next.jobId, 'unemployed');
      expect(
        [next.weaponId, next.armorId, next.accessoryId],
        ['none', 'none', 'none'],
      );
      expect(next.inventory, const Player().inventory);
      expect(next.money, 1000);
      expect(
        [next.stamina, next.intelligence, next.charm, next.morality],
        [10, 10, 10, 16],
      );
      expect(next.life.generation, 4);
      expect(
        [
          next.life.turns,
          next.life.age,
          next.life.eq,
          next.life.stress,
          next.life.affection,
          next.life.homeLevel,
        ],
        [0, 18, 50, 0, 0, 0],
      );
      expect(next.life.learnedSkills, ['hero']);
      expect(next.life.inheritedSkill, 'hero');
      expect(next.life.jobPractice, isEmpty);
      expect(service.canReincarnate(next), isFalse);
      expect(
        () => service.reincarnate(next, inheritSkill: 'hero'),
        throwsStateError,
      );
      expect(p.money, 99999);
      expect(p.life.generation, 3);
    });

    test('every skill grants exactly its advertised perk on inheritance', () {
      for (final id in jobIds) {
        final p = Player(
          clearedStages: 6,
          life: const LifeProgress().copyWith(learnedSkills: [id]),
        );
        final next = service.reincarnate(p, inheritSkill: id);
        final bonus = service.skillBonus(id);
        expect(
          [next.stamina, next.intelligence, next.charm, next.morality],
          [
            10 + bonus.stamina,
            10 + bonus.intelligence,
            10 + bonus.charm,
            10 + bonus.morality,
          ],
          reason: id,
        );
        expect(next.life.learnedSkills, [id]);
      }
    });

    test(
      'inherited perk can cross generations but cannot stack on relearning',
      () {
        final original = Player(
          clearedStages: 6,
          life: const LifeProgress().copyWith(learnedSkills: ['student']),
        );
        var second = service
            .reincarnate(original, inheritSkill: 'student')
            .copyWith(jobId: 'student');
        for (var i = 0; i < 3; i++) {
          second = service.finishTurn(second, activity: 'work');
        }
        expect(second.intelligence, 12);
        final third = service.reincarnate(
          second.copyWith(clearedStages: 6),
          inheritSkill: 'student',
        );
        expect(third.life.generation, 3);
        expect(third.intelligence, 12);
        final noSkill = service.reincarnate(third.copyWith(clearedStages: 6));
        expect(noSkill.intelligence, 10);
        expect(noSkill.life.learnedSkills, isEmpty);
        expect(noSkill.life.inheritedSkill, isNull);
      },
    );
  });

  group('schema seven saves and migration', () {
    test(
      'roundtrip persists every life field and does not reapply bonuses',
      () {
        final p = Player(
          intelligence: 42,
          life:
              const LifeProgress(
                turns: 80,
                generation: 2,
                eq: 77,
                stress: 34,
                affection: 65,
                homeLevel: 2,
              ).copyWith(
                jobPractice: {'student': 9, 'engineer': 2},
                learnedSkills: ['student'],
                inheritedSkill: 'student',
              ),
        );
        expect(saveJson(p)['schemaVersion'], 9);
        final next = restore(p);
        expect(next.life.toJson(), p.life.toJson());
        expect(next.intelligence, 42);
        expect(restore(next).intelligence, 42);
        expect(
          () => next.life.jobPractice['student'] = 100,
          throwsUnsupportedError,
        );
        expect(() => next.life.learnedSkills.clear(), throwsUnsupportedError);
      },
    );

    test('reloading a just-learned skill cannot apply it a second time', () {
      var p = const Player(jobId: 'engineer');
      for (var i = 0; i < 3; i++) p = service.finishTurn(p, activity: 'work');
      expect(p.intelligence, 14);
      p = restore(p);
      p = service.finishTurn(p, activity: 'work');
      expect(p.intelligence, 14);
      expect(p.life.learnedSkills, ['engineer']);
      expect(p.life.jobPractice['engineer'], 4);
    });

    for (var version = 1; version <= 6; version++) {
      test(
        'schema $version migrates with defaults and preserves old stats',
        () {
          final p = <String, dynamic>{
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
          };
          final raw = jsonEncode({
            'schemaVersion': version,
            'savedAt': date.toIso8601String(),
            'player': p,
          });
          final migrated = SaveData.decode(raw, jobIds).player;
          expect(migrated.life.toJson(), const LifeProgress().toJson());
          expect(
            [
              migrated.stamina,
              migrated.intelligence,
              migrated.charm,
              migrated.money,
            ],
            [77, 88, 66, 5432],
          );
          expect(migrated.position, 19);
          expect(migrated.jobId, 'engineer');
          expect(migrated.morality, version >= 3 ? 55 : 10);
          expect(migrated.experience, version >= 2 ? 321 : 0);
          expect(
            migrated.gender,
            version >= 4 ? CharacterGender.female : CharacterGender.male,
          );
          expect(migrated.weaponId, version >= 4 ? 'staff' : 'none');
          expect(migrated.clearedStages, version >= 5 ? 4 : 0);
          expect(migrated.stageWins, version >= 5 ? 2 : 0);
          expect(migrated.armorId, version >= 6 ? 'plate' : 'none');
          expect(migrated.accessoryId, version >= 6 ? 'ring' : 'none');
          expect(snapshot(restore(migrated)), snapshot(migrated));
        },
      );
    }

    test(
      'strictly rejects invalid life scalar types, bounds, and unknown keys',
      () {
        void rejects(String key, Object? value) {
          final raw = saveJson(const Player());
          raw['player']['life'][key] = value;
          expect(
            () => SaveData.decode(jsonEncode(raw), jobIds),
            throwsFormatException,
            reason: '$key = $value',
          );
        }

        for (final key in [
          'turns',
          'generation',
          'eq',
          'stress',
          'affection',
          'homeLevel',
        ]) {
          for (final value in <Object?>[
            null,
            '1',
            true,
            1.5,
            -1,
            LifeProgress.maxCounter + 1,
          ]) {
            rejects(key, value);
          }
        }
        rejects('generation', 0);
        for (final key in ['eq', 'stress', 'affection']) rejects(key, 101);
        rejects('homeLevel', 3);
        rejects('unexpected', 1);
        for (final badLife in <Object?>[null, [], 'life', 1]) {
          final raw = saveJson(const Player());
          raw['player']['life'] = badLife;
          expect(
            () => SaveData.decode(jsonEncode(raw), jobIds),
            throwsFormatException,
          );
        }
        final missing = saveJson(const Player());
        missing['player']['life'].remove('turns');
        expect(
          () => SaveData.decode(jsonEncode(missing), jobIds),
          throwsFormatException,
        );
      },
    );

    test(
      'strictly rejects invalid practice, duplicate skills and inheritance',
      () {
        final corruptions = <String, List<Object?>>{
          'jobPractice': [
            null,
            [],
            {'student': -1},
            {'student': 1.5},
            {'student': '3'},
            {'student': LifeProgress.maxCounter + 1},
            {'unknown': 3},
          ],
          'learnedSkills': [
            null,
            {},
            ['student', 'student'],
            ['unknown'],
            [3],
            [''],
          ],
          'inheritedSkill': [1, false, '', 'unknown', 'student'],
        };
        for (final entry in corruptions.entries) {
          for (final value in entry.value) {
            final raw = saveJson(const Player());
            raw['player']['life'][entry.key] = value;
            expect(
              () => SaveData.decode(jsonEncode(raw), jobIds),
              throwsFormatException,
              reason: '${entry.key} = $value',
            );
          }
        }
      },
    );
  });
}

int passed = 0;
int failed = 0;
String groupName = '';
class CoreMatcher {
  final String description;
  final bool Function(dynamic) predicate;
  CoreMatcher(this.description, this.predicate);
}
void group(String name, void Function() body) {
  groupName = name;
  body();
}
void test(String name, void Function() body) {
  try {
    body();
    passed++;
    print('PASS $groupName: $name');
  } catch (e, st) {
    failed++;
    print('FAIL $groupName: $name\n$e\n$st');
  }
}
bool deepEquals(dynamic a, dynamic b) {
  if (a is Map && b is Map) {
    return a.length == b.length && b.keys.every((k) => a.containsKey(k) && deepEquals(a[k], b[k]));
  }
  if (a is Iterable && b is Iterable) {
    final x = a.toList(), y = b.toList();
    return x.length == y.length && List.generate(x.length, (i) => i).every((i) => deepEquals(x[i], y[i]));
  }
  return a == b;
}
void expect(dynamic actual, dynamic expected, {String? reason}) {
  final ok = expected is CoreMatcher ? expected.predicate(actual) : deepEquals(actual, expected);
  if (!ok) throw StateError('Expected ${expected is CoreMatcher ? expected.description : expected}, got $actual. ${reason ?? ""}');
}
CoreMatcher throwsType<T>() => CoreMatcher('throws $T', (dynamic callback) {
  try { (callback as Function)(); } catch (e) { return e is T; }
  return false;
});
final throwsUnsupportedError = throwsType<UnsupportedError>();
final throwsStateError = throwsType<StateError>();
final throwsArgumentError = throwsType<ArgumentError>();
final throwsFormatException = throwsType<FormatException>();
final isNull = CoreMatcher('null', (v) => v == null);
final isTrue = CoreMatcher('true', (v) => v == true);
final isFalse = CoreMatcher('false', (v) => v == false);
final isEmpty = CoreMatcher('empty', (v) => (v as dynamic).isEmpty == true);
CoreMatcher contains(dynamic item) => CoreMatcher('contains $item', (v) => (v as dynamic).contains(item) == true);

void main() { runTests(); print("Pure Dart life checks: $passed passed, $failed failed"); if(failed>0) exit(1); }
