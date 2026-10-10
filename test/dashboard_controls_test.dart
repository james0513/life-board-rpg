import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_graybox/domain/models/player.dart';
import 'package:life_graybox/presentation/widgets/game_dashboard.dart';

void main() {
  for (final height in [430.0, 620.0]) {
  testWidgets('desktop height $height dice stays right of board with long journal', (tester) async {
    await tester.binding.setSurfaceSize(Size(1000, height));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: GameDashboard(
      player: Player(), job: '學生',
      board: const ColoredBox(key: ValueKey('board'), color: Colors.green),
      controls: SizedBox(height: 230, child: Center(child: FilledButton(onPressed: () {}, child: const Text('擲骰')))),
      history: List.generate(40, (i) => '事件紀錄 $i'),
    ))));
    final dice = find.text('擲骰');
    expect(tester.getCenter(dice).dx, greaterThan(tester.getRect(find.byKey(const ValueKey('board'))).right));
    expect(tester.getRect(dice).bottom, lessThan(height));
    final rect = tester.getRect(find.byKey(const ValueKey('board')));
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(height));
    expect(rect.width, greaterThan(600));
    expect(find.text('本次遊玩 · 最新在上'), findsNothing);
    await tester.ensureVisible(find.byKey(const ValueKey('open-journal')));
    await tester.tap(find.byKey(const ValueKey('open-journal')));
    await tester.pumpAndSettle();
    expect(find.text('本次遊玩 · 最新在上'), findsOneWidget);
    await tester.tap(find.byTooltip('關閉'));
    await tester.pumpAndSettle();
    expect(find.text('本次遊玩 · 最新在上'), findsNothing);
    await tester.ensureVisible(dice);
    await tester.tap(dice);
    expect(tester.takeException(), isNull);
  });
  }
}
