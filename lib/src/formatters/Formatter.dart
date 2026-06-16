/// Typed replacement for the old `Map<String, dynamic>` options.
///
/// A single instance is reused per [PrintFormat] to avoid allocation.
class FormatOptions {
  bool isUpper = false;
  int width = -1;
  int precision = -1;
  String sign = '';
  String paddingChar = ' ';
  bool addSpace = false;
  bool leftAlign = false;
  bool alternateForm = false;

  void reset() {
    isUpper = false;
    width = -1;
    precision = -1;
    sign = '';
    paddingChar = ' ';
    addSpace = false;
    leftAlign = false;
    alternateForm = false;
  }
}

/// Legacy base class — kept only so the [PrintFormatFormatter] typedef
/// continues to compile.  New code should not subclass this.
abstract class Formatter {
  var fmt_type;
  var options;
  Formatter(this.fmt_type, this.options);
  String asString();
}
