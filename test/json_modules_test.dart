import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_graybox/application/content_providers.dart';
import 'package:life_graybox/application/player_controller.dart';
import 'package:life_graybox/application/turn_controller.dart';
import 'package:life_graybox/domain/models/player.dart';
import 'package:life_graybox/domain/services/event_manager.dart';
import 'package:life_graybox/domain/services/job_manager.dart';

Future<String> diskLoader(String path) => File(path).readAsString();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled asset paths registered in pubspec', () async {
    final events = jsonDecode(await rootBundle.loadString('assets/data/events.json'));
    final jobs = jsonDecode(await rootBundle.loadString('assets/data/jobs.json'));
    expect(events['events'].length, 10);
    expect(jobs['jobs'].length, 31);
  });

  test('event catalog caches concurrent reads and produces reproducible draws', () async {
    var reads = 0;
    final a = EventManager(loadJson: (path) async {
      reads++;
      return diskLoader(path);
    }, random: Random(42));
    final b = EventManager(loadJson: diskLoader, random: Random(42));
    await Future.wait([a.load(), a.load()]);
    expect(reads, 1);
    for (var i = 0; i < 20; i++) {
      expect((await a.draw()).id, (await b.draw()).id);
    }
    expect(reads, 1);
  });

  test('negative event floors at zero and reports actual effect', () async {
    final manager = EventManager(loadJson: diskLoader);
    final event = (await manager.load()).firstWhere((e) => e.id == 'e08');
    const before = Player(stamina: 1, money: 50);
    final result = manager.apply(before, event);
    expect(result.player.money, 0);
    expect(result.player.stamina, 0);
    expect(result.applied.money, -50);
    expect(result.applied.stamina, -1);
    expect(before.money, 50);
  });

  test('all ten example effects match fixtures', () async {
    final manager = EventManager(loadJson: diskLoader);
    final events = await manager.load();
    final fixtures = jsonDecode(await File('test/fixtures/cases.json').readAsString());
    const p = Player(stamina: 100, intelligence: 100, charm: 100, money: 20000);
    for (final fixture in fixtures['eventCases']) {
      final event = events.firstWhere((e) => e.id == fixture['eventId']);
      final actual = manager.apply(p, event).player;
      expect({'stamina': actual.stamina, 'intelligence': actual.intelligence,
        'charm': actual.charm, 'money': actual.money}, fixture['expected']);
    }
  });

  test('career thresholds, prerequisites and money preserved', () async {
    final jobs = JobManager(loadJson: diskLoader); await jobs.load();
    expect(jobs.evaluate(const Player(jobId:'student',intelligence:50,morality:31),'scholar').allowed,isFalse);
    expect(jobs.evaluate(const Player(jobId:'student',intelligence:51,morality:30),'scholar').allowed,isFalse);
    expect(jobs.evaluate(const Player(jobId:'student',intelligence:51,morality:31),'scholar').allowed,isTrue);
    expect(jobs.evaluate(const Player(),'student').allowed,isTrue);
    expect(jobs.evaluate(const Player(),'part_timer').allowed,isTrue);
    const rich=Player(jobId:'engineer',intelligence:61,charm:46,morality:30,money:5001);
    final changed=jobs.changeJob(rich,'president');
    expect(changed.money,5001); expect(changed.jobId,'president');
    expect(()=>jobs.changeJob(const Player(),'president'),throwsStateError);
  });

  test('tile event waits for choice and commits once', () async {
    final container = ProviderContainer(overrides: [
      jsonLoaderProvider.overrideWithValue(diskLoader),
    ]);
    addTearDown(container.dispose);
    await container.read(contentReadyProvider.future);
    final turns = container.read(turnProvider.notifier);
    final players = container.read(playerProvider.notifier);
    var updates = 0;
    final subscription = container.listen(playerProvider, (_, _) => updates++);
    addTearDown(subscription.close);
    turns.beginTurn();
    turns.finishRoll();
    players.moveTo(0);
    final before = updates;
    final first = turns.land();
    final duplicate = turns.land();
    expect(turns.beginTurn(), isNull);
    await Future.wait([first, duplicate]);
    expect(updates, before);
    expect(container.read(turnProvider).choiceEvent, isNotNull);
    expect(turns.finishChoice('B'), isTrue);
    expect(updates, before + 1);
    final appliedPlayer = container.read(playerProvider);
    expect(turns.finishChoice('A'), isFalse);
    expect(turns.finishChoice('B'), isFalse);
    expect(identical(appliedPlayer, container.read(playerProvider)), isTrue);
    expect(container.read(turnProvider).phase, TurnPhase.idle);
  });

  test('career revalidates at commit instead of trusting UI', () async {
    final container = ProviderContainer(overrides: [
      jsonLoaderProvider.overrideWithValue(diskLoader),
    ]);
    addTearDown(container.dispose);
    await container.read(contentReadyProvider.future);
    final turns = container.read(turnProvider.notifier);
    container.read(playerProvider.notifier).moveTo(4);
    turns.beginTurn();
    turns.finishRoll();
    await turns.land();
    final error = turns.finishResolution(targetJobId: 'mentor');
    expect(error, isNotNull);
    expect(container.read(playerProvider).jobId, 'unemployed');
    expect(container.read(turnProvider).phase, TurnPhase.idle);
  });

  test('invalid and empty event data fail with FormatException; retry is possible', () async {
    var fail = true;
    final manager = EventManager(loadJson: (path) async => fail
      ? '{"schemaVersion":1,"events":[]}' : await diskLoader(path));
    await expectLater(manager.load(), throwsFormatException);
    fail = false;
    expect((await manager.load()).length, 10);
    final raw = jsonDecode(await diskLoader('assets/data/events.json'));
    raw['events'][1]['id'] = raw['events'][0]['id'];
    await expectLater(EventManager(loadJson: (_) async => jsonEncode(raw)).load(),
      throwsFormatException);
  });

  test('invalid job references, cycles and operators are rejected', () async {
    for (final kind in ['reference', 'cycle', 'operator']) {
      final raw = jsonDecode(await diskLoader('assets/data/jobs.json'));
      if (kind == 'reference') raw['jobs'][3]['fromJobIds'] = ['missing'];
      if (kind == 'cycle') raw['jobs'][3]['fromJobIds'] = ['mentor'];
      if (kind == 'operator') raw['jobs'][3]['requirements'][0]['operator'] = 'approximately';
      await expectLater(JobManager(loadJson: (_) async => jsonEncode(raw)).load(),
        throwsFormatException);
    }
  });

  test('failed event load unlocks turn and does not alter stats', () async {
    final container = ProviderContainer(overrides: [
      jsonLoaderProvider.overrideWithValue((_) async => throw const FormatException('bad data')),
    ]);
    addTearDown(container.dispose);
    final turns = container.read(turnProvider.notifier);
    container.read(playerProvider.notifier).moveTo(0);
    final before = container.read(playerProvider);
    turns.beginTurn();
    turns.finishRoll();
    await turns.land();
    expect(container.read(turnProvider).phase, TurnPhase.idle);
    expect(identical(before, container.read(playerProvider)), isTrue);
  });
}
