import 'package:flutter/foundation.dart';

/// How a generated UUID is rendered in [GenerationMode.uuid].
///
/// The defaults are the canonical RFC 4122 form; ticking [uppercase] and
/// [braces] turns the same value into the Microsoft GUID rendering.
@immutable
class UuidOptions {
  const UuidOptions({
    this.uppercase = false,
    this.hyphens = true,
    this.braces = false,
  });

  static const UuidOptions defaults = UuidOptions();

  final bool uppercase;
  final bool hyphens;
  final bool braces;

  UuidOptions copyWith({bool? uppercase, bool? hyphens, bool? braces}) =>
      UuidOptions(
        uppercase: uppercase ?? this.uppercase,
        hyphens: hyphens ?? this.hyphens,
        braces: braces ?? this.braces,
      );

  @override
  bool operator ==(Object other) =>
      other is UuidOptions &&
      other.uppercase == uppercase &&
      other.hyphens == hyphens &&
      other.braces == braces;

  @override
  int get hashCode => Object.hash(uppercase, hyphens, braces);

  @override
  String toString() =>
      'UuidOptions(uppercase: $uppercase, hyphens: $hyphens, '
      'braces: $braces)';
}
