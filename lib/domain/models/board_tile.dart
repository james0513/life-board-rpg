enum TileKind { luck, penalty, work, battle, career, shop }

class BoardTile {
  final int index;
  final TileKind kind;
  const BoardTile(this.index, this.kind);
}

// Keep 20 stable positions; cells 6 and 16 are shopping streets.
final List<BoardTile> boardTiles = List.unmodifiable(
  List.generate(20, (i) => BoardTile(i, [5, 15].contains(i) ? TileKind.shop : TileKind.values[i % 5])),
);

int nextPosition(int current, int steps, {int count = 20}) =>
    (current + steps) % count;

/// Isometric projection of a 6x6 perimeter, without coupling to Flame.
class BoardPoint {
  final double x, y;
  const BoardPoint(this.x, this.y);
}
final List<BoardPoint> boardCenters = List.unmodifiable([
  for (var x = 0; x < 6; x++) BoardPoint(450.0 + x * 72, 85.0 + x * 36),
  for (var y = 1; y < 6; y++) BoardPoint(810.0 - y * 72, 265.0 + y * 36),
  for (var x = 4; x >= 0; x--) BoardPoint(90.0 + x * 72, 265.0 + x * 36),
  for (var y = 4; y >= 1; y--) BoardPoint(450.0 - y * 72, 85.0 + y * 36),
]);
