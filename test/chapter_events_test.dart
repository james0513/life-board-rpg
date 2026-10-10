import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_graybox/domain/models/board_tile.dart';
import 'package:life_graybox/domain/services/tile_event_manager.dart';

void main() {
  test('each stage draws only eligible events without immediate repeats', () async {
    final manager = TileEventManager(loadJson: (path) => File(path).readAsString(), random: Random(21));
    final all = await manager.load();
    expect(all.map((e) => e.id).toSet().length, 26);
    for (var stage = 1; stage <= 6; stage++) {
      for (final kind in [TileKind.luck, TileKind.penalty, TileKind.work]) {
        expect(all.where((e) => e.stage == stage && e.kind == kind), isNotEmpty);
        String? previous;
        for (var i = 0; i < 30; i++) {
          final event = await manager.draw(kind, stage: stage);
          expect(event.stage == null || event.stage == stage, isTrue);
          expect(event.kind, kind);
          expect(event.id, isNot(previous));
          previous = event.id;
        }
      }
    }
  });
}
