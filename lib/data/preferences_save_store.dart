import 'package:shared_preferences/shared_preferences.dart';
import '../domain/services/save_store.dart';

class PreferencesSaveStore implements SaveStore {
  static const key = 'life_graybox.save.v1';
  final SharedPreferencesAsync preferences;
  PreferencesSaveStore({SharedPreferencesAsync? preferences})
    : preferences = preferences ?? SharedPreferencesAsync();
  @override
  Future<String?> read() => preferences.getString(key);
  @override
  Future<void> write(String value) => preferences.setString(key, value);
}
