import 'package:shared_preferences/shared_preferences.dart';

/// The seam between [SavedStore] and the platform.
///
/// Everything above this interface is plain Dart, so unit tests need no plugin
/// mocking — they inject an in-memory implementation instead.
abstract interface class KeyValueStore {
  Future<String?> getString(String key);

  Future<void> setString(String key, String value);
}

/// The real implementation, backed by `SharedPreferencesAsync` — the
/// non-deprecated 2.5.x API, which is DataStore-backed on Android.
class SharedPreferencesKeyValueStore implements KeyValueStore {
  SharedPreferencesKeyValueStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> getString(String key) => _preferences.getString(key);

  @override
  Future<void> setString(String key, String value) =>
      _preferences.setString(key, value);
}
