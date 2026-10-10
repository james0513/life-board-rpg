import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_graybox/domain/models/player.dart';
import 'package:life_graybox/domain/models/save_data.dart';
import 'package:life_graybox/domain/services/save_repository.dart';
import 'package:life_graybox/domain/services/save_store.dart';

class MemoryStore implements SaveStore {
  String? value;
  bool fail = false;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String text) async {
    if (fail) throw StateError('storage unavailable');
    value = text;
  }
}

void main() {
  const ids = {'unemployed', 'engineer'};
  const player = Player(position: 19, stamina: 15, intelligence: 40,
    charm: 50, money: 8000, jobId: 'engineer');

  test('new install has no save and does not create one during read', () async {
    final store = MemoryStore();
    expect(await SaveRepository(store).load(ids), isNull);
    expect(store.value, isNull);
  });

  test('new repository instance restores complete player snapshot', () async {
    final store = MemoryStore();
    final date = DateTime.utc(2026, 10, 9);
    await SaveRepository(store, now: () => date).save(player);
    final loaded = (await SaveRepository(store).load(ids))!;
    expect(loaded.player.position, 19);
    expect(loaded.player.stamina, 15);
    expect(loaded.player.intelligence, 40);
    expect(loaded.player.charm, 50);
    expect(loaded.player.money, 8000);
    expect(loaded.player.jobId, 'engineer');
    expect(loaded.savedAt, date);
  });

  test('corrupt or unsupported save remains untouched after read failure', () async {
    final store = MemoryStore();
    for (final text in ['bad json', '{"schemaVersion":99,"savedAt":"2026-10-09","player":{}}']) {
      store.value = text;
      await expectLater(SaveRepository(store).load(ids), throwsFormatException);
      expect(store.value, text);
    }
  });

  test('reject out-of-range positions, negative stats, missing jobs and wrong types', () {
    final original = SaveData(player, DateTime.utc(2026)).encode();
    for (final entry in <String, Object>{
      'position': 20, 'money': -1, 'stamina': '10', 'jobId': 'missing',
    }.entries) {
      final data = jsonDecode(original);
      data['player'][entry.key] = entry.value;
      expect(() => SaveData.decode(jsonEncode(data), ids), throwsFormatException);
    }
  });

  test('failed write preserves old snapshot; retry recovers', () async {
    final store = MemoryStore();
    final repo = SaveRepository(store);
    await repo.save(player);
    final old = store.value;
    store.fail = true;
    await expectLater(repo.save(const Player()), throwsStateError);
    expect(store.value, old);
    store.fail = false;
    await repo.save(const Player());
    expect((await repo.load(ids))!.player.position, 0);
  });

  test('reset replaces snapshot with all initial values', () async {
    final store = MemoryStore();
    final repo = SaveRepository(store);
    await repo.save(player);
    await repo.reset();
    final p = (await repo.load(ids))!.player;
    expect([p.position, p.stamina, p.intelligence, p.charm, p.money, p.jobId],
      [0, 10, 10, 10, 1000, 'unemployed']);
  });

  test('writes are ordered so a late older write cannot overwrite reset', () async {
    final store = DelayedStore();
    final repo = SaveRepository(store);
    final first = repo.save(player);
    final reset = repo.reset();
    await Future<void>.delayed(Duration.zero);
    expect(store.calls, 1);
    store.gate.complete();
    await Future.wait([first, reset]);
    expect(store.calls, 2);
    expect((await repo.load(ids))!.player.jobId, 'unemployed');
  });
}

class DelayedStore extends MemoryStore {
  final gate = Completer<void>();
  int calls = 0;
  @override
  Future<void> write(String text) async {
    calls++;
    if (calls == 1) await gate.future;
    await super.write(text);
  }
}
