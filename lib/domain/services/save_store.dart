abstract interface class SaveStore {
  Future<String?> read();
  Future<void> write(String value);
}
