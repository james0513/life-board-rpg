import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_graybox/domain/models/board_tile.dart';
import 'package:life_graybox/domain/models/player.dart';
import 'package:life_graybox/domain/models/tile_event.dart';
import 'package:life_graybox/domain/services/tile_event_manager.dart';
import 'package:life_graybox/application/content_providers.dart';
import 'package:life_graybox/application/player_controller.dart';
import 'package:life_graybox/application/turn_controller.dart';
import 'package:life_graybox/presentation/widgets/choice_event_dialog.dart';
import 'package:life_graybox/presentation/widgets/dice_display.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<String> loader(String p) => File(p).readAsString();
  ProviderContainer container() => ProviderContainer(overrides: [jsonLoaderProvider.overrideWithValue(loader)]);
  test('20 unique isometric cells form equal diagonal steps including wrap', () {
    expect(boardCenters.length, 20);
    expect(boardCenters.map((p) => '${p.x},${p.y}').toSet().length, 20);
    for (var i=0; i<20; i++) {
      final a = boardCenters[i], b = boardCenters[(i+1)%20];
      expect((a.x-b.x).abs(), 72);
      expect((a.y-b.y).abs(), 36);
      expect(a.x, inInclusiveRange(66,834));
      expect(a.y, inInclusiveRange(39,521));
    }
    for (final kind in TileKind.values) {
      expect(boardTiles.where((t) => t.kind == kind).length, kind == TileKind.shop || kind == TileKind.luck ? 2 : 4);
    }
    expect(nextPosition(19, 6), 5);
  });
  test('rolling locks input and cannot settle before movement', () async {
    final c = container(); addTearDown(c.dispose);
    final t = c.read(turnProvider.notifier);
    expect(t.beginTurn(), inInclusiveRange(1,6));
    expect(c.read(turnProvider).phase, TurnPhase.rolling);
    expect(t.beginTurn(), isNull);
    await t.land();
    expect(c.read(turnProvider).phase, TurnPhase.rolling);
    t.finishRoll();
    expect(c.read(turnProvider).phase, TurnPhase.moving);
  });
  test('all JSON choices agree with tile semantics', () async {
    final events = await TileEventManager(loadJson: loader).load();
    expect(events.length, 26);
    for (final event in events) {
      expect(event.options.map((o) => o.id), ['A','B']);
      for (final o in event.options) {
        if (event.kind == TileKind.penalty) expect(o.effects.money, lessThan(0));
        if (event.kind == TileKind.work) expect(o.effects.money, greaterThan(0));
        if (event.kind == TileKind.luck && event.id != 'lost_wallet') {
          expect(o.effects.toJson().values.every((v) => v >= 0), isTrue);
        }
      }
    }
  });
  test('both A and B apply their own effects once with actual floor at zero', () async {
    for (final position in [0,1,2]) {
      for (final id in ['A','B']) {
        final c = container();
        try {
          c.read(playerProvider.notifier).replace(Player(position: position, money: 10, stamina: 1));
          final t = c.read(turnProvider.notifier);
          t.beginTurn(); t.finishRoll(); await t.land();
          final before = c.read(playerProvider);
          final event = c.read(turnProvider).choiceEvent!;
          final expected = before.apply(event.options.singleWhere((o) => o.id == id).effects);
          expect(t.finishChoice('unknown'), isFalse);
          expect(c.read(playerProvider), same(before));
          expect(t.finishChoice(id), isTrue);
          expect(c.read(playerProvider).money, expected.money);
          expect(c.read(playerProvider).stamina, expected.stamina);
          expect(c.read(playerProvider).intelligence, expected.intelligence);
          expect(c.read(playerProvider).charm, expected.charm);
          expect(c.read(playerProvider).morality, expected.morality);
          expect(t.finishChoice(id), isFalse);
          if (c.read(turnProvider).battleChoice) {
            expect(c.read(turnProvider).battleEnemyId, 'delay');
            t.finishBattle(const StatDelta(), '撤退');
          }
          expect(c.read(turnProvider).phase, TurnPhase.idle);
        } finally { c.dispose(); }
      }
    }
  });
  test('choice data caches and deterministic random respects requested type', () async {
    var reads = 0;
    final manager = TileEventManager(loadJson: (p) {reads++; return loader(p);}, random: Random(9));
    await Future.wait([manager.load(), manager.load()]);
    for (final k in [TileKind.luck,TileKind.penalty,TileKind.work]) {
      expect((await manager.draw(k)).kind, k);
    }
    expect(reads, 1);
  });
  test('new event JSON is bundled', () async {
    final root = jsonDecode(await rootBundle.loadString('assets/data/tile_events.json'));
    expect(root['schemaVersion'], 1);
    expect(root['events'].length, 26);
  });
  testWidgets('choice modal blocks outside dismissal and returns B', (tester) async {
    // UI behavior uses in-memory data: no real file I/O in FakeAsync.
    // JSON parsing and asset loading are covered by the tests above.
    const event = TileEvent('dialog_fixture', '選擇測試', '請選擇 A 或 B。',
      TileKind.luck, [
        TileOption('A', '領取獎金', StatDelta(money: 100)),
        TileOption('B', '參加課程', StatDelta(intelligence: 5)),
      ]);
    String? chosen;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (context) =>
      TextButton(onPressed: () async {
        chosen = await showDialog<String>(context: context, barrierDismissible: false,
          builder: (_) => ChoiceEventDialog(event: event));
      }, child: const Text('開啟'))))));
    await tester.tap(find.text('開啟'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
    await tester.tapAt(const Offset(2,2)); await tester.pumpAndSettle();
    expect(find.byType(ChoiceEventDialog), findsOneWidget);
    await tester.tap(find.textContaining('B　')); await tester.pumpAndSettle();
    expect(chosen, 'B');
    expect(find.byType(ChoiceEventDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('dice renders all six values without layout exceptions', (tester) async {
    for (var n=1; n<=6; n++) {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: DiceDisplay(value:n, rolling:n<6))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
