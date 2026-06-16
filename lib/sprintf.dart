/// sprintf implementation for Dart.
///
/// Usage:
///
///     import 'package:dart_sprintf/sprintf.dart';
///     print(sprintf('%s %d', ['foo', 42]));
///
library;

import 'src/sprintf_impl.dart';

export 'src/sprintf_impl.dart' show PrintFormat, PrintFormatFormatter;
export 'src/formatters/Formatter.dart' show Formatter, FormatOptions;

var sprintf = PrintFormat();
