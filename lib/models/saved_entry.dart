import 'package:flutter/foundation.dart';

import 'generation_mode.dart';

/// One stored sequence.
@immutable
class SavedEntry {
  const SavedEntry({
    required this.name,
    required this.sequence,
    required this.createdAt,
    required this.mode,
  });

  final String name;
  final String sequence;
  final DateTime createdAt;
  final GenerationMode mode;

  Map<String, Object?> toJson() => {
    'name': name,
    'sequence': sequence,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'mode': mode.storageKey,
  };

  /// Returns null instead of throwing when a record is missing fields or has
  /// the wrong types, so one corrupt entry cannot take down the whole list.
  static SavedEntry? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final name = json['name'];
    final sequence = json['sequence'];
    final createdAt = json['createdAt'];
    final mode = GenerationMode.tryFromStorageKey(json['mode']);
    if (name is! String || sequence is! String || createdAt is! int) {
      return null;
    }
    if (name.isEmpty || mode == null) return null;
    return SavedEntry(
      name: name,
      sequence: sequence,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
      mode: mode,
    );
  }

  SavedEntry copyWith({
    String? name,
    String? sequence,
    DateTime? createdAt,
    GenerationMode? mode,
  }) => SavedEntry(
    name: name ?? this.name,
    sequence: sequence ?? this.sequence,
    createdAt: createdAt ?? this.createdAt,
    mode: mode ?? this.mode,
  );

  @override
  bool operator ==(Object other) =>
      other is SavedEntry &&
      other.name == name &&
      other.sequence == sequence &&
      other.createdAt == createdAt &&
      other.mode == mode;

  @override
  int get hashCode => Object.hash(name, sequence, createdAt, mode);

  @override
  String toString() =>
      'SavedEntry(name: $name, sequence: $sequence, '
      'createdAt: $createdAt, mode: $mode)';
}
