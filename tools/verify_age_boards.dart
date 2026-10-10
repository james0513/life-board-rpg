// Pure Dart domain validation; no Flutter SDK, packages, or assets required.
// Run from the project root: dart tools/verify_age_boards.dart
import '../lib/domain/models/age_board.dart';
import '../lib/domain/models/board_tile.dart';
import '../lib/domain/models/life_progress.dart';

int checks = 0;

void check(bool condition, String message) {
  checks++;
  if (!condition) throw StateError(message);
}

List<int> counts(AgeBoard board) => [
  for (final kind in TileKind.values)
    board.tiles.where((tile) => tile.kind == kind).length,
];

String signature(AgeBoard board) =>
    board.tiles.map((tile) => '${tile.index}:${tile.kind.name}').join('|');

void checkImmutable(void Function() mutate, String message) {
  var rejected = false;
  try {
    mutate();
  } on UnsupportedError {
    rejected = true;
  }
  check(rejected, message);
}

void main() {
  final original = signature(AgeBoard.forAge(18));
  final expectedCounts = {
    'learning': [2, 4, 4, 4, 4, 2],
    'career': [2, 2, 6, 3, 5, 2],
    'family': [6, 4, 2, 2, 4, 2],
    'legacy': [5, 2, 3, 3, 5, 2],
  };

  for (var age = 18; age <= 120; age++) {
    final board = AgeBoard.forAge(age);
    final expectedId = age < 22
        ? 'learning'
        : age < 35
        ? 'career'
        : age < 50
        ? 'family'
        : 'legacy';
    check(board.id == expectedId, 'Wrong board for age $age');
    check(board.tiles.length == 20, 'Wrong tile count at age $age');
    check(board.minimumAge <= age, 'Minimum age at age $age');
    check(
      board.maximumAge == null || board.maximumAge! >= age,
      'Maximum age at age $age',
    );
    check(
      board.visualStage >= 1 && board.visualStage <= 6,
      'Unbundled artwork at age $age',
    );
    check(
      board.title.isNotEmpty &&
          board.description.isNotEmpty &&
          board.ageRange.isNotEmpty,
      'Missing age-stage explanation at age $age',
    );
    for (var index = 0; index < 20; index++) {
      final tile = board.tiles[index];
      check(tile.index == index, 'Position $index moved at age $age');
      check(
        (tile.kind == TileKind.shop) == (index == 5 || index == 15),
        'Shop positions changed at age $age, index $index',
      );
      check(nextPosition(index, 20) == index, 'The board path stopped looping');
    }
    final distribution = counts(board);
    for (final kind in TileKind.values) {
      check(distribution[kind.index] > 0, 'Missing ${kind.name} at age $age');
      check(
        distribution[kind.index] == expectedCounts[board.id]![kind.index],
        'Incorrect ${kind.name} distribution at age $age',
      );
    }
    check(
      distribution[TileKind.battle.index] >= 2,
      'Combat unavailable at age $age',
    );
    check(
      distribution[TileKind.career.index] >= 4,
      'Career access too rare at age $age',
    );
    check(
      distribution[TileKind.work.index] >= 2,
      'Work unavailable at age $age',
    );
    if (age < 22) {
      check(
        identical(board.tiles, boardTiles),
        'The original v0.25 board was replaced',
      );
    }
  }

  check(AgeBoard.all.length == 4, 'There must be four original life boards');
  check(
    AgeBoard.all.map(signature).toSet().length == 4,
    'Layouts must genuinely differ',
  );
  check(
    AgeBoard.all.map((board) => counts(board).join(',')).toSet().length == 4,
    'Tile distributions must genuinely differ',
  );
  check(
    AgeBoard.all.map((board) => board.visualStage).toSet().length == 4,
    'Each life board needs distinct bundled artwork',
  );
  check(
    identical(AgeBoard.forAge(-1), AgeBoard.forAge(18)),
    'Low-age fallback failed',
  );
  check(
    identical(AgeBoard.forAge(1000000), AgeBoard.forAge(50)),
    'Legacy age cap found',
  );

  for (final boundary in [22, 35, 50]) {
    final before = LifeProgress(turns: (boundary - 18) * 4 - 1);
    final after = before.copyWith(turns: before.turns + 1);
    check(
      before.age == boundary - 1 && after.age == boundary,
      'Life age boundary $boundary',
    );
    check(
      AgeBoard.forAge(before.age).id != AgeBoard.forAge(after.age).id,
      'Board did not change on birthday $boundary',
    );
  }

  for (final board in AgeBoard.all) {
    final prior = signature(board);
    checkImmutable(
      () => board.tiles.clear(),
      '${board.id} layout can be cleared',
    );
    checkImmutable(
      () => board.tiles[0] = const BoardTile(0, TileKind.shop),
      '${board.id} tile can be changed',
    );
    check(signature(board) == prior, 'An immutable board changed');
    print(
      '${board.id}: ${board.ageRange}; visual=${board.visualStage}; counts=${counts(board)}',
    );
  }
  checkImmutable(
    () => AgeBoard.all.clear(),
    'Age-stage catalog can be cleared',
  );
  check(
    signature(AgeBoard.forAge(const LifeProgress().age)) == original,
    'A new life did not return to the original board',
  );
  print(
    'PASS: $checks checks across every age 18–120, boundaries, layouts, and new-life reset.',
  );
}
