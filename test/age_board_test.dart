import 'package:flutter_test/flutter_test.dart';
import 'package:life_graybox/domain/models/age_board.dart';
import 'package:life_graybox/domain/models/board_tile.dart';
import 'package:life_graybox/domain/models/life_progress.dart';
import 'package:life_graybox/presentation/game/life_game.dart';

List<int> counts(AgeBoard board) => [
  for (final kind in TileKind.values)
    board.tiles.where((tile) => tile.kind == kind).length,
];

void main() {
  test('age boundaries select four original life boards', () {
    for (final entry in {
      18: 'learning',
      21: 'learning',
      22: 'career',
      34: 'career',
      35: 'family',
      49: 'family',
      50: 'legacy',
      60: 'legacy',
      120: 'legacy',
    }.entries) {
      expect(AgeBoard.forAge(entry.key).id, entry.value);
    }
    expect(AgeBoard.all.map((board) => board.id), [
      'learning',
      'career',
      'family',
      'legacy',
    ]);
    expect(AgeBoard.forAge(-1), same(AgeBoard.forAge(18)));
    expect(AgeBoard.forAge(1000000), same(AgeBoard.forAge(50)));
  });

  test('learning retains the exact v0.25 board and shop positions', () {
    expect(AgeBoard.forAge(18).tiles, same(boardTiles));
    expect(AgeBoard.forAge(21).tiles, same(boardTiles));
    expect(counts(AgeBoard.forAge(18)), [2, 4, 4, 4, 4, 2]);
  });

  test('later boards genuinely change the tile distributions', () {
    expect(counts(AgeBoard.forAge(22)), [2, 2, 6, 3, 5, 2]);
    expect(counts(AgeBoard.forAge(35)), [6, 4, 2, 2, 4, 2]);
    expect(counts(AgeBoard.forAge(50)), [5, 2, 3, 3, 5, 2]);
    expect(
      AgeBoard.all.map((board) => counts(board).join(',')).toSet(),
      hasLength(4),
    );
    expect(
      AgeBoard.all
          .map((board) => board.tiles.map((tile) => tile.kind.name).join(','))
          .toSet(),
      hasLength(4),
    );
  });

  test(
    'every age preserves the path, all six types, and access to gameplay',
    () {
      for (var age = 18; age <= 120; age++) {
        final board = AgeBoard.forAge(age);
        expect(board.tiles, hasLength(20), reason: 'age $age');
        expect(
          board.tiles.map((tile) => tile.index),
          List.generate(20, (i) => i),
        );
        expect(
          board.tiles.map((tile) => tile.kind).toSet(),
          TileKind.values.toSet(),
        );
        expect(
          board.tiles
              .where((tile) => tile.kind == TileKind.shop)
              .map((t) => t.index),
          [5, 15],
        );
        expect(counts(board)[TileKind.battle.index], greaterThanOrEqualTo(2));
        expect(counts(board)[TileKind.career.index], greaterThanOrEqualTo(4));
        expect(counts(board)[TileKind.work.index], greaterThanOrEqualTo(2));
        expect(board.visualStage, inInclusiveRange(1, 6));
        expect(board.minimumAge, lessThanOrEqualTo(age));
        if (board.maximumAge != null) {
          expect(board.maximumAge, greaterThanOrEqualTo(age));
        }
        expect(board.title, isNotEmpty);
        expect(board.description, isNotEmpty);
        expect(board.ageRange, isNotEmpty);
      }
    },
  );

  test('life turn boundaries and a new life resolve the correct board', () {
    for (final boundary in [22, 35, 50]) {
      final before = LifeProgress(turns: (boundary - 18) * 4 - 1);
      final after = before.copyWith(turns: before.turns + 1);
      expect(
        AgeBoard.forAge(before.age).id,
        isNot(AgeBoard.forAge(after.age).id),
      );
      expect(after.age, boundary);
    }
    expect(AgeBoard.forAge(const LifeProgress().age).tiles, same(boardTiles));
  });

  test('layouts and stage catalog cannot be mutated', () {
    for (final board in AgeBoard.all) {
      expect(() => board.tiles.clear(), throwsUnsupportedError);
      expect(
        () => board.tiles[0] = const BoardTile(0, TileKind.shop),
        throwsUnsupportedError,
      );
    }
    expect(() => AgeBoard.all.clear(), throwsUnsupportedError);
  });

  test('LifeGame age selects visuals independently from trial progress', () {
    final game = LifeGame(initialPosition: 9, stage: 6);
    expect(game.age, 18);
    expect(game.ageBoard.visualStage, 1);
    expect(game.ageBoard.tiles, same(boardTiles));
    final center = game.pawnCenter(9);
    game.changeAge(22);
    expect(game.ageBoard, same(AgeBoard.forAge(22)));
    expect(game.ageBoard.visualStage, 3);
    expect(game.stage, 6);
    game.changeStage(1);
    expect(game.ageBoard.id, 'career');
    game.changeAge(35);
    expect(game.ageBoard.visualStage, 2);
    game.changeAge(50);
    expect(game.ageBoard.visualStage, 6);
    game.changeAge(18);
    expect(game.ageBoard.tiles, same(boardTiles));
    expect(game.pawnCenter(9), center);
    expect(game.initialPosition, 9);
    expect(LifeGame(initialPosition: 0, age: 49).ageBoard.id, 'family');
  });
}
