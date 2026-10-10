import 'package:shared_preferences/shared_preferences.dart';
import '../domain/services/save_store.dart';
import '../domain/models/save_data.dart';

class PreferencesSaveStore implements SaveStore {
  static const key = 'life_graybox.save.v1';
  final SharedPreferencesAsync preferences;
  final String storageKey;
  PreferencesSaveStore({SharedPreferencesAsync? preferences, this.storageKey = key})
    : preferences = preferences ?? SharedPreferencesAsync();
  @override
  Future<String?> read() => preferences.getString(storageKey);
  @override
  Future<void> write(String value) async {
    // A failed backup blocks the write instead of discarding the old save.
    final backupKey = '$storageKey.pre_v028';
    if (await preferences.getString(backupKey) == null) {
      final original = legacySnapshotForV28Backup(await preferences.getString(storageKey));
      if (original != null) await preferences.setString(backupKey, original);
    }
    await preferences.setString(storageKey, value);
  }
}
