import 'Formatter.dart';

/// Formats an integer for %d, %i, %x, %o specifiers.
///
/// Replaces the heap-allocated `IntFormatter` class + `Map<String,dynamic>`
/// with a single static function using typed [FormatOptions] and `padLeft`.
const int intMaxInt = 0x1FFFFFFFFFFFFF; // JS 53-bit limit

String formatInt(int value, int radix, FormatOptions o) {
  var prefix = '';
  var sign = o.sign;

  int v = value;

  if (v < 0) {
    if (radix == 10) {
      v = -v;
      sign = '-';
    } else {
      // Reverse twos complement for non-decimal radixes
      v = (intMaxInt - (~v) & intMaxInt);
    }
  }

  var digits = v.toRadixString(radix);

  // Alternate form: hex prefix
  if (o.alternateForm && radix == 16 && v != 0) {
    prefix = '0x';
    // after checking Non-decimal, the sign is always ''.
    // so ingore it for aggressive performance.
    // if (sign == '+') sign = '';
  }

  // Space flag: "prefixes non-negative signed numbers with a space"
  if (o.addSpace && sign == '' && value >= 0 && radix == 10) {
    sign = ' ';
  }

  // Non-decimal formats don't show sign
  if (radix != 10) {
    sign = '';
  }

  // Precision: minimum number of digits
  if (o.precision > digits.length) {
    digits = digits.padLeft(o.precision, '0');
  }

  // Octal alternate form: ensure leading zero AFTER precision padding.
  // Per C standard, '#' for %o "increases the precision, if and only if
  // necessary, to force the first digit of the result to be a zero".
  if (o.alternateForm && radix == 8 && v != 0) {
    if (digits.isEmpty || digits.codeUnitAt(0) != 0x30 /* '0' */) {
      digits = '0$digits';
    }
  }

  // Width padding
  final contentLen = sign.length + prefix.length + digits.length;
  String result;

  if (o.width > contentLen) {
    final padLen = o.width - contentLen;
    if (o.leftAlign) {
      result = '$sign$prefix$digits'.padRight(o.width);
    } else if (o.paddingChar == '0') {
      result = '$sign$prefix${''.padLeft(padLen, '0')}$digits';
    } else {
      result = '${''.padLeft(padLen)}$sign$prefix$digits';
    }
  } else {
    result = '$sign$prefix$digits';
  }

  if (o.isUpper) {
    result = result.toUpperCase();
  }

  return result;
}
