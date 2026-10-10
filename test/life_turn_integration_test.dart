import 'dart:io';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_graybox/application/content_providers.dart';
import 'package:life_graybox/application/player_controller.dart';
import 'package:life_graybox/application/turn_controller.dart';
import 'package:life_graybox/domain/models/battle.dart';
import 'package:life_graybox/domain/models/life_progress.dart';
import 'package:life_graybox/domain/models/player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  ProviderContainer gameAt(int position) {
    final c = ProviderContainer(overrides: [
      jsonLoaderProvider.overrideWithValue((path) => File(path).readAsString()),
    ]);
    c.read(playerProvider.notifier).replace(Player(position: position));
    addTearDown(c.dispose);
    return c;
  }

  Future<TurnController> land(ProviderContainer c) async {
    final t = c.read(turnProvider.notifier);
    t.beginTurn();
    t.finishRoll();
    await t.land();
    return t;
  }

  test('rolling/moving/loading never consume a season', () async {
    final c = gameAt(0);
    await land(c);
    expect(c.read(playerProvider).life.turns, 0);
  });

  test('a choice with optional battle consumes exactly one season', () async {
    for (final position in [0, 1, 2]) {
      final c = gameAt(position);
      final t = await land(c);
      final option = c.read(turnProvider).choiceEvent!.options.first;
      expect(t.finishChoice('missing'), false);
      expect(c.read(playerProvider).life.turns, 0);
      expect(t.finishChoice(option.id), true);
      expect(t.finishChoice(option.id), false);
      if (option.battleEnemyId != null) {
        expect(c.read(playerProvider).life.turns, 0);
        t.finishBattle(const StatDelta(), '撤退');
      }
      expect(c.read(playerProvider).life.turns, 1);
      t.finishBattle(const StatDelta(money: 200), '重複');
      expect(c.read(playerProvider).life.turns, 1);
    }
  });

  test('shop, battle and career each finish once', () async {
    for (final position in [5, 3, 4]) {
      final c = gameAt(position);
      final t = await land(c);
      void finish() {
        if (position == 5) t.finishShop();
        if (position == 3) t.finishBattle(const StatDelta(), '完成');
        if (position == 4) t.finishResolution();
      }
      finish(); finish();
      expect(c.read(playerProvider).life.turns, 1);
      expect(c.read(turnProvider).phase, TurnPhase.idle);
    }
  });

  test('EQ stress and housing change battle HP but default keeps balance', () {
    const enemy = Enemy(id: 'test', name: 'test', description: '', hp: 20,
      attack: 1, reward: 0, portrait: 0);
    final baseline = BattleSession(const Player(), enemy, random: Random(1));
    final tired = BattleSession(const Player(life: LifeProgress(stress: 100)), enemy);
    final settled = BattleSession(const Player(life: LifeProgress(eq: 100, homeLevel: 2)), enemy);
    expect(baseline.maxHp, 80);
    expect(tired.maxHp, 70);
    expect(settled.maxHp, 91);
  });
}
