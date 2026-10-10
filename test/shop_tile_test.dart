import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_graybox/application/turn_controller.dart';
import 'package:life_graybox/application/player_controller.dart';
import 'package:life_graybox/domain/models/board_tile.dart';
void main() {
  test('shop streets occupy cells 6 and 16 without changing board length', () {
    expect(boardTiles.length,20);
    expect(boardTiles.where((t)=>t.kind==TileKind.shop).map((t)=>t.index),[5,15]);
  });
  test('shop triggers only upon landing and locks dice until leaving', () async {
    final c=ProviderContainer();addTearDown(c.dispose);
    final t=c.read(turnProvider.notifier);
    c.read(playerProvider.notifier).moveTo(5);
    await t.land();expect(c.read(turnProvider).shopChoice,false);
    t.beginTurn();t.finishRoll();
    expect(c.read(turnProvider).shopChoice,false);
    await t.land();expect(c.read(turnProvider).shopChoice,true);
    expect(t.beginTurn(),isNull);
    await t.land();expect(c.read(turnProvider).shopChoice,true);
    t.finishShop();expect(c.read(turnProvider).phase,TurnPhase.idle);
    expect(c.read(turnProvider).shopChoice,false);
    expect(t.beginTurn(),isNotNull);
  });
}
