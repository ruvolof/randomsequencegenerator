import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/saved_entry.dart';
import 'key_value_store.dart';

/// The saved sequences, held as a JSON list under a single key.
///
/// Nothing is migrated from the legacy app: it wrote a SharedPreferences file
/// named `saved_sequences` with one key per entry, and the Flutter plugin reads
/// a different file, so the old data is invisible by construction.
class SavedStore extends ChangeNotifier {
  SavedStore(this._keyValueStore);

  /// Versioned so a future schema change has somewhere to go.
  static const String storageKey = 'saved_entries_v1';

  final KeyValueStore _keyValueStore;

  List<SavedEntry> _entries = const [];

  /// Sorted by [SavedEntry.createdAt] ascending, with the name as a tiebreak.
  ///
  /// The legacy order was `HashMap` iteration order — effectively random, and
  /// it reshuffled between launches.
  List<SavedEntry> get entries => List.unmodifiable(_entries);

  bool get isEmpty => _entries.isEmpty;

  bool containsName(String name) => _entries.any((entry) => entry.name == name);

  Future<void> load() async {
    String? raw;
    try {
      raw = await _keyValueStore.getString(storageKey);
    } catch (_) {
      // `main` awaits this before `runApp`, so anything thrown here would cost
      // the user the whole app rather than the saved list. The platform call
      // fails in more ways than one type can name — `SharedPreferencesAsync`
      // raises `PlatformException` when the channel is down and `TypeError`
      // when a key holds another type — so the catch is deliberately broad.
      // Starting empty is indistinguishable from having nothing saved; the
      // next write repairs the key.
      raw = null;
    }
    _entries = decode(raw);
    notifyListeners();
  }

  /// Adds [entry], or replaces the existing entry with the same name in place.
  ///
  /// The caller is responsible for confirming an overwrite first.
  Future<void> upsert(SavedEntry entry) {
    final next = [..._entries];
    final index = next.indexWhere((existing) => existing.name == entry.name);
    if (index >= 0) {
      next[index] = entry;
    } else {
      next.add(entry);
    }
    return _commit(next);
  }

  Future<void> deleteByName(String name) {
    final next = _entries.where((entry) => entry.name != name).toList();
    if (next.length == _entries.length) return Future.value();
    return _commit(next);
  }

  Future<void> deleteAll() => _commit(const []);

  Future<void> _commit(List<SavedEntry> next) {
    final sorted = [...next]..sort(_byCreatedAtThenName);
    _entries = sorted;
    // Notify optimistically, then persist: the UI never waits on the disk.
    notifyListeners();
    return _keyValueStore.setString(
      storageKey,
      jsonEncode(sorted.map((entry) => entry.toJson()).toList()),
    );
  }

  static int _byCreatedAtThenName(SavedEntry a, SavedEntry b) {
    final byTime = a.createdAt.compareTo(b.createdAt);
    // Two saves within the same millisecond would otherwise order arbitrarily.
    return byTime != 0 ? byTime : a.name.compareTo(b.name);
  }

  /// Parses the stored JSON, tolerating anything that is not a well-formed list
  /// of entries — null, blank, invalid JSON, a non-list, or entries with the
  /// wrong shape all yield an empty list instead of throwing.
  @visibleForTesting
  static List<SavedEntry> decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return const [];
    }
    if (decoded is! List) return const [];
    final entries = <SavedEntry>[];
    for (final item in decoded) {
      final entry = SavedEntry.tryFromJson(item);
      if (entry != null) entries.add(entry);
    }
    return entries..sort(_byCreatedAtThenName);
  }
}
