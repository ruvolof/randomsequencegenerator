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

  /// Not legacy: the mask mode's `h` token. [hex] stays the uppercase original
  /// the Hexadecimal mode has always used.
  static const String hexLowercase = '0123456789abcdef';

  /// The mask mode's placeholder tokens, and the pool each one draws from. The
  /// single source of truth for the syntax: the parser looks tokens up here and
  /// the on-screen legend is checked against these keys.
  ///
  /// `final` rather than `const` because Dart cannot concatenate the const
  /// pools at compile time.
  static final Map<String, String> maskPools = {
    '#': digit,
    'a': lowercase,
    'A': uppercase,
    '?': lowercase + uppercase,
    '*': digit + lowercase + uppercase,
    'h': hexLowercase,
    'H': hex,
    '%': special,
  };

  /// In a mask, the character that makes the next one a literal.
  static const String maskEscape = r'\';

  /// In a mask, the delimiters of a repetition count — `a{5}`.
  static const String maskRepeatOpen = '{';
  static const String maskRepeatClose = '}';
}
