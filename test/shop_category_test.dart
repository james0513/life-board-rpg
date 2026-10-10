import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_graybox/domain/models/player.dart';
import 'package:life_graybox/presentation/screens/shop_screen.dart';

void main() {
  testWidgets('shop categories display only matching goods without purchasing on selection', (tester) async {
    var calls = 0;
    final player = Player(money: 5000);
    await tester.pumpWidget(MaterialApp(home: ShopScreen(player: player, onAction: (id, equip) async {
      calls++;
      return player;
    })));
    await tester.scrollUntilVisible(find.byKey(const ValueKey('shop-item-sword')), 240);
    expect(find.byKey(const ValueKey('shop-item-sword')), findsOneWidget);
    for (final pair in [('armor', 'ranger_cloak'), ('accessory', 'ruby_ring'), ('item', 'potion'), ('weapon', 'sword')]) {
      tester.widget<ListView>(find.byType(ListView).first).controller!.jumpTo(0);
      await tester.pump();
      await tester.ensureVisible(find.byKey(ValueKey('shop-category-${pair.$1}')));
      await tester.tap(find.byKey(ValueKey('shop-category-${pair.$1}')));
      await tester.pump();
      await tester.scrollUntilVisible(find.byKey(ValueKey('shop-item-${pair.$2}')), 240);
      expect(find.byKey(ValueKey('shop-item-${pair.$2}')), findsOneWidget);
      if (pair.$1 != 'weapon') expect(find.byKey(const ValueKey('shop-item-sword')), findsNothing);
      if (pair.$1 != 'item') expect(find.byKey(const ValueKey('shop-item-potion')), findsNothing);
      expect(tester.takeException(), isNull);
    }
    expect(calls, 0);
    tester.widget<ListView>(find.byType(ListView).first).controller!.jumpTo(0);
    await tester.pump();
    await tester.ensureVisible(find.text('屬性培養課程'));
    await tester.tap(find.text('屬性培養課程'));
    await tester.pump();
    await tester.scrollUntilVisible(find.byKey(const ValueKey('shop-item-train_stamina')), 240);
    expect(find.byKey(const ValueKey('shop-item-train_stamina')), findsOneWidget);
    expect(find.byKey(const ValueKey('shop-item-sword')), findsNothing);
  });
}
