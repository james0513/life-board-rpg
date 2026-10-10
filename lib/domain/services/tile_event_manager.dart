import 'dart:convert';
import 'dart:math';
import '../models/board_tile.dart';
import '../models/tile_event.dart';
import 'json_source.dart';

class TileEventManager {
  TileEventManager({required this.loadJson, Random? random}) : random = random ?? Random();
  final JsonLoader loadJson;
  final Random random;
  Future<List<TileEvent>>? _cache;
  final Map<String, String> _lastDraw = {};
  Future<List<TileEvent>> load() async {
    final pending = _cache ??= _read();
    try { return await pending; }
    catch (_) { if (identical(_cache, pending)) _cache = null; rethrow; }
  }
  Future<List<TileEvent>> _read() async {
    final root = jsonDecode(await loadJson('assets/data/tile_events.json')) as Map;
    if (root['schemaVersion'] != 1) throw const FormatException('Unsupported tile events');
    final events = (root['events'] as List).map((e) => TileEvent.fromJson(
      Map<String, dynamic>.from(e as Map))).toList();
    if (events.map((e) => e.id).toSet().length != events.length ||
        [TileKind.luck, TileKind.penalty, TileKind.work].any((k) => !events.any((e) => e.kind == k))) {
      throw const FormatException('Missing tile category or duplicate event ID');
    }
    return List.unmodifiable(events);
  }
  Future<TileEvent> draw(TileKind kind, {int? stage}) async {
    final candidates = (await load()).where((e) => e.kind == kind && (stage == null || e.stage == null || e.stage == stage)).toList();
    if (candidates.isEmpty) throw StateError('No events for $kind');
    final key = '${stage ?? 0}:${kind.name}';
    if (candidates.length > 1) candidates.removeWhere((e) => e.id == _lastDraw[key]);
    final chosen = candidates[random.nextInt(candidates.length)];
    _lastDraw[key] = chosen.id;
    return chosen;
  }
}
