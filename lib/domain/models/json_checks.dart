// Strict parsing avoids silently accepting misspelled or malformed game rules.
Map<String, dynamic> jsonObject(Object? value, String path) {
  if (value is! Map<String, dynamic>) throw FormatException('$path must be an object');
  return value;
}
String jsonText(Object? value, String path) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$path must be a non-empty string');
  }
  return value;
}
int jsonInt(Object? value, String path) {
  if (value is! int) throw FormatException('$path must be an integer');
  return value;
}
List<dynamic> jsonList(Object? value, String path) {
  if (value is! List) throw FormatException('$path must be an array');
  return value;
}
void checkKeys(Map<String, dynamic> json, Set<String> keys, String path) {
  if (json.keys.toSet().difference(keys).isNotEmpty ||
      keys.difference(json.keys.toSet()).isNotEmpty) {
    throw FormatException('$path expects exactly: ${keys.join(", ")}');
  }
}
