part of sprintf;

/// Formats a value for the %s specifier.
String _formatString(dynamic arg, FormatOptions o) {
  var result = arg.toString();

  // Precision truncates the string
  if (o.precision > -1 && o.precision <= result.length) {
    result = result.substring(0, o.precision);
  }

  // Width pads the string (always with spaces for %s)
  if (o.width > result.length) {
    if (o.leftAlign) {
      result = result.padRight(o.width);
    } else {
      result = result.padLeft(o.width);
    }
  }

  return result;
}
