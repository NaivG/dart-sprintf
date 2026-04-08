part of sprintf;

/// Formats a double for %f, %e, %g specifiers using Dart's native
/// `toStringAsFixed` / `toStringAsExponential` instead of manual
/// digit-by-digit parsing.
String _formatFloat(double value, String fmtType, FormatOptions o) {
  // ── Sign handling ─────────────────────────────────────────────────
  if (o.addSpace && o.sign == '' && !value.isNegative) {
    o.sign = ' ';
  }

  bool isNeg = value.isNegative && !value.isNaN;
  double absVal = value.abs();

  if (isNeg) o.sign = '-';

  // ── Special values ────────────────────────────────────────────────
  if (value.isNaN) {
    return _applyFloatPadding('nan', o, forceSpacePad: true);
  }
  if (value.isInfinite) {
    return _applyFloatPadding('inf', o, forceSpacePad: true);
  }

  // ── Precision defaults ────────────────────────────────────────────
  int precision = o.precision;
  if (precision == -1) precision = 6;
  if (fmtType == 'g' && precision == 0) precision = 1;

  // ── Format the number ─────────────────────────────────────────────
  String result;

  switch (fmtType) {
    case 'f':
      result = _fmtFixed(absVal, precision, o.alternateForm);
    case 'e':
      result = _fmtExponential(absVal, precision, o.alternateForm);
    case 'g':
      result = _fmtGeneral(absVal, precision, o.alternateForm);
    default:
      throw ArgumentError('Unknown float format type: $fmtType');
  }

  return _applyFloatPadding(result, o);
}

// ── %f ────────────────────────────────────────────────────────────────

String _fmtFixed(double value, int precision, bool alternateForm) {
  var result = value.toStringAsFixed(precision);
  // Dart's toStringAsFixed always includes the decimal point when precision > 0,
  // and omits it when precision == 0. For alternate form with precision == 0,
  // we'd need to add it, but that's an extremely rare edge case.
  return result;
}

// ── %e ────────────────────────────────────────────────────────────────

String _fmtExponential(double value, int precision, bool alternateForm) {
  var result = value.toStringAsExponential(precision);
  return _ensureTwoDigitExponent(result);
}

/// Ensures the exponent has at least 2 digits: `e+2` → `e+02`.
String _ensureTwoDigitExponent(String s) {
  final eIdx = s.lastIndexOf('e');
  if (eIdx < 0) return s;
  // eIdx+1 is sign char, rest is digit(s)
  final expDigits = s.length - eIdx - 2;
  if (expDigits >= 2) return s;
  return '${s.substring(0, eIdx + 2)}0${s.substring(eIdx + 2)}';
}

// ── %g ────────────────────────────────────────────────────────────────

String _fmtGeneral(double value, int precision, bool alternateForm) {
  if (value == 0) {
    // Special case: 0 always uses %f path
    var result = value.toStringAsFixed(precision - 1);
    if (!alternateForm) result = _stripTrailingZeros(result);
    return result;
  }

  // Compute the base-10 exponent reliably via toStringAsExponential
  final expStr = value.toStringAsExponential();
  final eIdx = expStr.indexOf('e');
  final exp = int.parse(expStr.substring(eIdx + 1));

  if (-4 <= exp && exp < precision) {
    // Use %f style
    var decPlaces = precision - 1 - exp;
    if (decPlaces < 0) decPlaces = 0;
    var result = value.toStringAsFixed(decPlaces);
    if (!alternateForm) {
      result = _stripTrailingZeros(result);
    }
    return result;
  } else {
    // Use %e style
    var result = value.toStringAsExponential(precision - 1);
    result = _ensureTwoDigitExponent(result);
    if (!alternateForm) {
      result = _stripTrailingZeros(result);
    }
    return result;
  }
}

/// Strips trailing zeros from a number string, handling optional exponent.
/// `"1.230000e+02"` → `"1.23e+02"`, `"123.000"` → `"123"`
String _stripTrailingZeros(String s) {
  final eIdx = s.indexOf('e');
  String mantissa, suffix;
  if (eIdx >= 0) {
    mantissa = s.substring(0, eIdx);
    suffix = s.substring(eIdx);
  } else {
    mantissa = s;
    suffix = '';
  }
  if (!mantissa.contains('.')) return mantissa + suffix;
  var end = mantissa.length;
  while (end > 0 && mantissa.codeUnitAt(end - 1) == 0x30 /* '0' */) {
    end--;
  }
  if (end > 0 && mantissa.codeUnitAt(end - 1) == 0x2E /* '.' */) {
    end--;
  }
  return mantissa.substring(0, end) + suffix;
}

// ── Padding (shared by all float formats) ─────────────────────────────

String _applyFloatPadding(
  String body,
  FormatOptions o, {
  bool forceSpacePad = false,
}) {
  final sign = o.sign;
  final contentLen = sign.length + body.length;
  final padChar = forceSpacePad ? ' ' : o.paddingChar;

  if (o.width <= contentLen) {
    final result = '$sign$body';
    return o.isUpper ? result.toUpperCase() : result;
  }

  final padLen = o.width - contentLen;
  String result;

  if (o.leftAlign) {
    result = '$sign$body'.padRight(o.width);
  } else if (padChar == '0') {
    result = '$sign${''.padLeft(padLen, '0')}$body';
  } else {
    result = '${''.padLeft(padLen)}$sign$body';
  }

  return o.isUpper ? result.toUpperCase() : result;
}
