// Replaces Flutter's generated counter test, which referenced the removed MyApp.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_graybox/domain/models/player.dart';
import 'package:life_graybox/presentation/screens/shop_screen.dart';
void main() {
  testWidgets('shop displays the current balance', (tester) async {
    await tester.pumpWidget(MaterialApp(home: ShopScreen(player: const Player(),
      onAction: (_, __) async => const Player())));
    expect(find.text('人生商店'), findsOneWidget);
    expect(find.textContaining('金錢：\$1000'), findsOneWidget);
  });
}
