import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_graybox/domain/models/shop_item.dart';
import 'package:life_graybox/presentation/art/item_illustration.dart';
import 'package:life_graybox/presentation/theme/game_design.dart';

// Written for the user's normal Flutter test workflow. These are deliberately
// not counted as executed by the offline Dart/model validation process.
void main() {
  testWidgets('every catalogue illustration paints in a small accessible cell', (tester) async {
    for (final item in shopCatalog) {
      await tester.pumpWidget(MaterialApp(theme: GameDesign.theme,
        home: Scaffold(body: Center(child: ItemIllustration(
          itemId: item.id, width: 84, height: 84)))));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: item.id);
      expect(find.byType(ItemIllustration), findsOneWidget);
    }
  });

  testWidgets('empty equipment pedestal paints without looking up an item', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: GameDesign.theme,
      home: const Scaffold(body: ItemIllustration(itemId: 'none'))));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  test('catalogue edition labels are complete', () {
    for (final item in shopCatalog) {
      expect(itemEdition(item), isNotEmpty);
      expect(itemAccent(item).a, 1);
    }
  });
}
