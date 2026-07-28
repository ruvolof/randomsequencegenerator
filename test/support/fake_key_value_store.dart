import 'package:random_sequence_generator/services/key_value_store.dart';

/// An in-memory [KeyValueStore], so store tests need no plugin mocking.
class FakeKeyValueStore implements KeyValueStore {
  FakeKeyValueStore([Map<String, String>? initial]) : values = {...?initial};

  final Map<String, String> values;

  /// Every key written, in order — lets a test assert how many times the store
  /// persisted.
  final List<String> writes = [];

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
    writes.add(key);
  }
}
