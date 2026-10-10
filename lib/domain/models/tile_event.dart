import 'board_tile.dart';
import 'player.dart';

class TileOption {
  final String id, label;
  final StatDelta effects;
  final String? battleEnemyId;
  const TileOption(this.id, this.label, this.effects, {this.battleEnemyId});
  factory TileOption.fromJson(Map<String, dynamic> j) {
    if (j['id'] is! String || j['label'] is! String || (j['label'] as String).isEmpty) {
      throw const FormatException('Invalid choice');
    }
    return TileOption(j['id'] as String, j['label'] as String,
      StatDelta.fromJson(Map<String, dynamic>.from(j['effects'] as Map)),
      battleEnemyId: j['battleEnemyId'] as String?);
  }
}
class TileEvent {
  final String id, title, description;
  final TileKind kind;
  final int? stage;
  final List<TileOption> options;
  const TileEvent(this.id, this.title, this.description, this.kind, this.options, {this.stage});
  factory TileEvent.fromJson(Map<String, dynamic> j) {
    final kind = TileKind.values.byName(j['kind'] as String);
    final options = (j['options'] as List).map((o) => TileOption.fromJson(
      Map<String, dynamic>.from(o as Map))).toList();
    if (options.length != 2 || options.map((o) => o.id).toSet().length != 2 ||
        ![TileKind.luck, TileKind.penalty, TileKind.work].contains(kind)) {
      throw const FormatException('Tile event must have two unique choices');
    }
    return TileEvent(j['id'] as String, j['title'] as String,
      j['description'] as String, kind, List.unmodifiable(options), stage: j['stage'] as int?);
  }
}
