import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_graybox/presentation/widgets/card_battle_tutorial.dart';

void main() {
  testWidgets(
    'tutorial opens independently and returns safely on narrow screens',
    (tester) async {
      tester.view.physicalSize = const Size(390, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const CardBattleTutorialDialog(),
                ),
                child: const Text('開啟教學'),
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.text('開啟教學'));
        await tester.pumpAndSettle();
        expect(find.text('戰鬥卡牌教學'), findsOneWidget);
        expect(find.text('一般交鋒'), findsOneWidget);
        expect(find.text('終章試煉'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('返回棋盤'));
        await tester.pumpAndSettle();
        expect(find.byType(CardBattleTutorialDialog), findsNothing);
        expect(find.text('開啟教學'), findsOneWidget);
      }
    },
  );
}
