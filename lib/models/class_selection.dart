import 'package:flutter/foundation.dart';

/// Which character classes are ticked in [GenerationMode.charClass].
@immutable
class ClassSelection {
  const ClassSelection({
    this.digits = false,
    this.lowercase = false,
    this.uppercase = false,
    this.special = false,
  });

  static const ClassSelection none = ClassSelection();

  final bool digits;
  final bool lowercase;
  final bool uppercase;
  final bool special;

  bool get isEmpty => !digits && !lowercase && !uppercase && !special;

  ClassSelection copyWith({
    bool? digits,
    bool? lowercase,
    bool? uppercase,
    bool? special,
  }) => ClassSelection(
    digits: digits ?? this.digits,
    lowercase: lowercase ?? this.lowercase,
    uppercase: uppercase ?? this.uppercase,
    special: special ?? this.special,
  );

  @override
  bool operator ==(Object other) =>
      other is ClassSelection &&
      other.digits == digits &&
      other.lowercase == lowercase &&
      other.uppercase == uppercase &&
      other.special == special;

  @override
  int get hashCode => Object.hash(digits, lowercase, uppercase, special);

  @override
  String toString() =>
      'ClassSelection(digits: $digits, lowercase: $lowercase, '
      'uppercase: $uppercase, special: $special)';
}
