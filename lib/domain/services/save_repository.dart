import '../models/player.dart';
import '../models/save_data.dart';
import 'save_store.dart';

class SaveRepository {
  final SaveStore store;
  final DateTime Function() now;
  Future<void> _tail = Future<void>.value();
  SaveRepository(this.store, {DateTime Function()? now}) : now = now ?? DateTime.now;

  Future<SaveData?> load(Set<String> validJobIds) async {
    await _tail;
    final raw = await store.read();
    if (raw == null) return null;
    // Malformed saves are surfaced to the UI, never silently overwritten.
    return SaveData.decode(raw, validJobIds);
  }

  Future<void> save(Player player) {
    final encoded = SaveData(player, now()).encode();
    final operation = _tail.then((_) => store.write(encoded));
    // Preserve caller-visible failures while allowing subsequent retry/reset.
    _tail = operation.then<void>((_) {}, onError: (Object e, StackTrace s) {});
    return operation;
  }

  // A single snapshot replacement, not clear-all preferences.
  Future<void> reset() => save(const Player());
}
