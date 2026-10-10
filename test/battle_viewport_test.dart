// Authored regression coverage; UNRUN here (Flutter runtime unavailable).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_graybox/domain/models/battle.dart';
import 'package:life_graybox/domain/models/card_battle.dart';
import 'package:life_graybox/domain/models/player.dart';
import 'package:life_graybox/presentation/battle/card_battle_screen.dart';
import 'package:life_graybox/presentation/theme/game_design.dart';

void main() {
  const enemy = Enemy(
    id: 'viewport',
    name: '霓虹水母',
    description: '',
    hp: 1000,
    attack: 4,
    reward: 20,
    portrait: 0,
  );
  for (final size in [
    const Size(1917, 853),
    const Size(1917, 471),
    const Size(1280, 570),
    const Size(960, 720),
    const Size(390, 844),
  ]) {
    testWidgets('arena, status and controls coexist at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final battle = CardBattleSession(const Player(), enemy);
      await tester.pumpWidget(
        MaterialApp(
          theme: GameDesign.theme,
          home: CardBattleScreen(
            session: battle,
            onSound: (_) {},
            onSettle: () async => true,
            onToggleSound: () async {},
            soundEnabled: () => true,
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('battle-small-viewport-scroll')),
        findsNothing,
      );
      const visible = [
        'hero-status',
        'enemy-status',
        'battle-arena',
        'battle-hand-panel',
        'battle-selection',
        'play-cards',
        'battle-potion',
        'battle-ether',
        'battle-flee',
        'pause-card-battle',
      ];
      for (final key in visible) {
        final rect = tester.getRect(find.byKey(ValueKey(key)));
        expect(rect.top, greaterThanOrEqualTo(0), reason: key);
        expect(rect.bottom, lessThanOrEqualTo(size.height), reason: key);
        expect(rect.left, greaterThanOrEqualTo(0), reason: key);
        expect(rect.right, lessThanOrEqualTo(size.width), reason: key);
      }
      final arena = tester.getRect(find.byKey(const ValueKey('battle-arena')));
      final hand = tester.getRect(
        find.byKey(const ValueKey('battle-hand-panel')),
      );
      expect(arena.overlaps(hand), isFalse);
      final first = battle.hand.firstWhere((c) => !c.isModifier);
      await tester.tap(find.byKey(ValueKey('card-${first.id}')));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(battle.selectedCardIds, contains(first.id));
      await tester.tap(find.byKey(const ValueKey('pause-card-battle')));
      await tester.pump();
      expect(find.text('交鋒已暫停'), findsOneWidget);
      final paused = battle.remainingMilliseconds;
      await tester.pump(const Duration(seconds: 1));
      expect(battle.remainingMilliseconds, paused);
      await tester.tap(find.byKey(const ValueKey('pause-card-battle')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(battle.remainingMilliseconds, paused - 100);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final size in [const Size(1280, 570), const Size(390, 844)]) {
    testWidgets('1.3x text retains same-screen controls at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: GameDesign.theme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: CardBattleScreen(
            session: CardBattleSession(const Player(), enemy),
            onSound: (_) {},
            onSettle: () async => true,
            onToggleSound: () async {},
            soundEnabled: () => true,
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('battle-small-viewport-scroll')),
        findsNothing,
      );
      for (final key in ['battle-arena', 'battle-hand-panel', 'battle-flee']) {
        final rect = tester.getRect(find.byKey(ValueKey(key)));
        expect(rect.right, lessThanOrEqualTo(size.width));
        expect(rect.bottom, lessThanOrEqualTo(size.height));
      }
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('tiny window explicitly offers readable scrolling fallback', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: GameDesign.theme,
        home: CardBattleScreen(
          session: CardBattleSession(const Player(), enemy),
          onSound: (_) {},
          onSettle: () async => true,
          onToggleSound: () async {},
          soundEnabled: () => true,
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey('battle-small-viewport-scroll')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('pause-card-battle')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
