/// The legacy character pools, verbatim.
///
/// The non-alphabetical order of the letter pools is intentional: they follow
/// the QWERTY keyboard, exactly as the Java constants did.
abstract final class CharPools {
  static const String binary = '01';
  static const String hex = '0123456789ABCDEF';
  static const String digit = '0123456789';
  static const String lowercase = 'qwertyuiopasdfghjklzxcvbnm';
  static const String uppercase = 'QWERTYUIOPASDFGHJKLZXCVBNM';

  /// Raw so the leading `$` is not read as string interpolation.
  static const String special = r'$%&()=?@#<>_£[]*';
}
