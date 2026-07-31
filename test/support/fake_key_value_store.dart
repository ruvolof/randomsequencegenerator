import 'package:flutter/services.dart';
import 'package:random_sequence_generator/services/key_value_store.dart';

/// An in-memory [KeyValueStore], so store tests need no plugin mocking.
class FakeKeyValueStore implements KeyValueStore {
  FakeKeyValueStore([Map<String, String>? initial]) : values = {...?initial};

  final Map<String, String> values;

  /// Every key written, in order — lets a test assert how many times the store
  /// persisted.
  final List<String> writes = [];

  /// When true, every write fails the way a full or unavailable disk does —
  /// nothing is recorded in [values] or [writes].
  bool failWrites = false;

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> setString(String key, String value) async {
    if (failWrites) {
      throw PlatformException(code: 'io-error', message: 'write failed');
    }
    values[key] = value;
    writes.add(key);
  }
}

/// A [KeyValueStore] whose read fails the way the platform does when the
/// plugin's channel is unavailable.
class ThrowingKeyValueStore implements KeyValueStore {
  @override
  Future<String?> getString(String key) async => throw PlatformException(
    code: 'channel-error',
    message: 'Unable to establish connection on channel.',
  );

  @override
  Future<void> setString(String key, String value) async {}
}
