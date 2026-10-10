import 'dart:convert';
import 'dart:math';
import '../models/json_checks.dart';
import '../models/life_event.dart';
import '../models/player.dart';
import 'json_source.dart';

class EventManager {
  final JsonLoader loadJson;
  final Random random;
  Future<List<LifeEvent>>? _cache;
  EventManager({required this.loadJson, Random? random}) : random = random ?? Random();

  Future<List<LifeEvent>> load() async {
    final pending = _cache ??= _read();
    try { return await pending; }
    catch (_) { if (identical(_cache, pending)) _cache = null; rethrow; }
  }
  Future<List<LifeEvent>> _read() async {
    final root = jsonObject(jsonDecode(await loadJson('assets/data/events.json')), 'events file');
    checkKeys(root, {'schemaVersion', 'events'}, 'events file');
    if (jsonInt(root['schemaVersion'], 'schemaVersion') != 1) {
      throw const FormatException('Unsupported events schemaVersion');
    }
    final events = jsonList(root['events'], 'events')
      .map((e) => LifeEvent.fromJson(jsonObject(e, 'event'))).toList();
    if (events.isEmpty || events.map((e) => e.id).toSet().length != events.length) {
      throw const FormatException('Events must be nonempty with unique IDs');
    }
    return List.unmodifiable(events);
  }
  Future<LifeEvent> draw() async {
    final events = await load();
    return events[random.nextInt(events.length)];
  }
  // Returns immutable data; the application controller commits it to Riverpod.
  EventOutcome apply(Player player, LifeEvent event) {
    final updated = player.apply(event.effects);
    return EventOutcome(event, updated, StatDelta(
      stamina: updated.stamina - player.stamina,
      intelligence: updated.intelligence - player.intelligence,
      charm: updated.charm - player.charm,
      morality: updated.morality - player.morality,
      money: updated.money - player.money));
  }
}
