// Intended for Flutter runtime acceptance. Authored here, not executed in cloud.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_graybox/domain/models/battle.dart';
import 'package:life_graybox/domain/models/card_battle.dart';
import 'package:life_graybox/domain/models/player.dart';
import 'package:life_graybox/presentation/battle/card_battle_screen.dart';

const _enemy = Enemy(
  id: 'card_widget',
  name: '試牌守衛',
  description: '',
  hp: 1000,
  attack: 4,
  reward: 20,
  portrait: 0,
);

void main() {
  Future<void> show(
    WidgetTester tester,
    CardBattleSession battle, {
    Future<bool> Function()? settle,
  }) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: CardBattleScreen(
          session: battle,
          onSound: (_) {},
          onSettle: settle ?? () async => true,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'entry auto-starts once; pause and resume keep a single battle clock',
    (tester) async {
      final battle = CardBattleSession(const Player(), _enemy);
      await show(tester, battle);
      final initial = battle.remainingMilliseconds;
      expect(find.text('開始交鋒'), findsNothing);
      await tester.pump(const Duration(milliseconds: 300));
      expect(battle.remainingMilliseconds, initial - 300);
      await tester.tap(find.byKey(const ValueKey('pause-card-battle')));
      await tester.pump();
      final paused = battle.remainingMilliseconds;
      await tester.pump(const Duration(seconds: 2));
      expect(battle.remainingMilliseconds, paused);
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(const ValueKey('pause-card-battle')));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.byKey(const ValueKey('pause-card-battle')));
        await tester.pump();
      }
      expect(battle.remainingMilliseconds, paused - 300);
      await tester.pumpWidget(const SizedBox());
      final disposed = battle.remainingMilliseconds;
      await tester.pump(const Duration(seconds: 1));
      expect(battle.remainingMilliseconds, disposed);
    },
  );

  testWidgets(
    'selected same-family cards resolve once at contact and input is locked',
    (tester) async {
      final battle = CardBattleSession(const Player(), _enemy);
      await show(tester, battle);
      final first = battle.hand.firstWhere((c) => !c.isModifier);
      await tester.tap(find.byKey(ValueKey('card-${first.id}')));
      await tester.pump();
      final before = battle.enemyHp;
      await tester.tap(find.byKey(const ValueKey('play-cards')));
      await tester.tap(find.byKey(const ValueKey('play-cards')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(battle.enemyHp, before);
      expect(battle.pendingMove, isNotNull);
      await tester.pump(const Duration(milliseconds: 1100));
      expect(battle.enemyHp, lessThan(before));
      expect(battle.round, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'background requires manual resume and does not advance battle clock',
    (tester) async {
      final battle = CardBattleSession(const Player(), _enemy);
      await show(tester, battle);
      await tester.pump(const Duration(milliseconds: 100));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      final paused = battle.remainingMilliseconds;
      await tester.pump(const Duration(seconds: 5));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 1));
      expect(battle.remainingMilliseconds, paused);
      expect(find.text('交鋒已暫停'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('final boss is immediately playable without a start button', (
    tester,
  ) async {
    const boss = Enemy(
      id: 'final',
      name: '命運編織者',
      description: '',
      hp: 1000,
      attack: 4,
      reward: 20,
      portrait: 0,
      bossStage: 6,
    );
    final battle = CardBattleSession(const Player(), boss);
    await show(tester, battle);
    expect(battle.turnMode, isTrue);
    expect(find.text('開始交鋒'), findsNothing);
    expect(find.text('交鋒已暫停'), findsNothing);
    final first = battle.hand.firstWhere((c) => !c.isModifier);
    await tester.tap(find.byKey(ValueKey('card-${first.id}')));
    await tester.pump();
    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('play-cards')),
    );
    expect(button.onPressed, isNotNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('entering in background remains paused until explicit resume', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    final battle = CardBattleSession(const Player(), _enemy);
    await show(tester, battle);
    final initial = battle.remainingMilliseconds;
    await tester.pump(const Duration(seconds: 1));
    expect(battle.remainingMilliseconds, initial);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 1));
    expect(battle.remainingMilliseconds, initial);
    await tester.tap(find.byKey(const ValueKey('pause-card-battle')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(battle.remainingMilliseconds, initial - 100);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'failed settlement stays visible, retries do not grant rewards twice',
    (tester) async {
      final battle = CardBattleSession(const Player(), _enemy)
        ..status = BattleStatus.won;
      var attempts = 0;
      var claims = 0;
      await show(
        tester,
        battle,
        settle: () async {
          attempts++;
          if (battle.claim() != null) claims++;
          return false;
        },
      );
      await tester.tap(find.byKey(const ValueKey('settle-card-battle')));
      await tester.pump();
      expect(find.text('重試存檔並返回'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('settle-card-battle')));
      await tester.pump();
      expect(attempts, 2);
      expect(claims, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('narrow screen keeps card rail and pause controls accessible', (
    tester,
  ) async {
    final battle = CardBattleSession(const Player(), _enemy);
    await show(tester, battle);
    tester.view.physicalSize = const Size(390, 844);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('pause-card-battle')), findsOneWidget);
    expect(find.byKey(const ValueKey('play-cards')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
