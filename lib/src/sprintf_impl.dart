import 'formatters/Formatter.dart';
import 'formatters/int_formatter.dart';
import 'formatters/float_formatter.dart';
import 'formatters/string_formatter.dart';

typedef PrintFormatFormatter = Formatter Function(dynamic arg, dynamic options);

class PrintFormat {
  static final RegExp specifier = RegExp(
    r'%(?:(\d+)\$)?([\+\-\#0 ]*)(\d+|\*)?(?:\.(\d+|\*))?([a-z%])',
    caseSensitive: false,
  );

  /// Cached parsed format strings — avoids re-running the regex on repeated
  /// calls with the same format string (the common case in Lua `string.format`).
  static final Map<String, List<RegExpMatch>> _matchCache = {};
  static const int _cacheMaxSize = 128;

  /// Reusable options object — avoids two `Map<String, dynamic>` allocations
  /// per specifier that the original code created.
  final FormatOptions _opts = FormatOptions();

  /// Legacy custom formatters for backwards compatibility.
  final Map<String, PrintFormatFormatter> _customFormatters = {};

  String call(String fmt, List<dynamic> args) {
    // ── Cached regex matches ──────────────────────────────────────────
    var matches = _matchCache[fmt];
    if (matches == null) {
      matches = specifier.allMatches(fmt).toList();
      if (_matchCache.length >= _cacheMaxSize) _matchCache.clear();
      _matchCache[fmt] = matches;
    }

    if (matches.isEmpty) return fmt;

    // ── Build result into StringBuffer ────────────────────────────────
    final buf = StringBuffer();
    var offset = 0;
    var argOffset = 0;

    for (final m in matches) {
      final parameter = m[1];
      final flags = m[2]!;
      final widthStr = m[3];
      final precisionStr = m[4];
      final type = m[5]!;

      // Reset options for this specifier
      _opts.reset();
      _parseFlags(flags);

      // Positional argument?
      var arg = parameter == null ? null : args[int.parse(parameter) - 1];

      // Width from '*' or literal
      if (widthStr != null) {
        _opts.width = widthStr == '*' ? args[argOffset++] : int.parse(widthStr);
      }

      // Precision from '*' or literal
      if (precisionStr != null) {
        _opts.precision =
            precisionStr == '*' ? args[argOffset++] : int.parse(precisionStr);
      }

      // Grab the next argument
      if (arg == null && type != '%') {
        arg = args[argOffset++];
      }

      // Upper-case check — single code unit comparison instead of regex
      final typeCode = type.codeUnitAt(0);
      _opts.isUpper = typeCode >= 0x41 && typeCode <= 0x5A; // A-Z

      String argStr;

      if (type == '%') {
        if (flags.isNotEmpty || widthStr != null || precisionStr != null) {
          throw Exception('"%" does not take any flags');
        }
        argStr = '%';
      } else {
        final typeLower = _opts.isUpper ? type.toLowerCase() : type;
        argStr = _format(typeLower, arg, _opts);
      }

      buf.write(fmt.substring(offset, m.start));
      offset = m.end;
      buf.write(argStr);
    }

    buf.write(fmt.substring(offset));
    return buf.toString();
  }

  // ── Flag parsing ────────────────────────────────────────────────────

  /// Parses flags directly into [_opts] without creating an intermediate Map.
  void _parseFlags(String flags) {
    for (var i = 0; i < flags.length; i++) {
      switch (flags.codeUnitAt(i)) {
        case 0x2B: // '+'
          _opts.sign = '+';
        case 0x30: // '0'
          _opts.paddingChar = '0';
        case 0x20: // ' '
          _opts.addSpace = true;
        case 0x2D: // '-'
          _opts.leftAlign = true;
        case 0x23: // '#'
          _opts.alternateForm = true;
      }
    }
  }

  // ── Dispatch ────────────────────────────────────────────────────────

  String _format(String type, dynamic arg, FormatOptions o) {
    // Check for custom formatters first (legacy support)
    if (_customFormatters.containsKey(type)) {
      final legacyOpts = _toLegacyOptions(type, o);
      return _customFormatters[type]!(arg, legacyOpts).asString();
    }

    switch (type) {
      case 'd' || 'i':
        return formatInt(arg as int, 10, o);
      case 'x':
        return formatInt(arg as int, 16, o);
      case 'o':
        return formatInt(arg as int, 8, o);
      case 'f':
        return formatFloat((arg as num).toDouble(), 'f', o);
      case 'e':
        return formatFloat((arg as num).toDouble(), 'e', o);
      case 'g':
        return formatFloat((arg as num).toDouble(), 'g', o);
      case 's':
        return formatString(arg, o);
      default:
        throw ArgumentError('Unknown format type $type');
    }
  }

  /// Converts [FormatOptions] back to the legacy `Map<String, dynamic>` for
  /// custom formatters registered via [register_specifier].
  Map<String, dynamic> _toLegacyOptions(String type, FormatOptions o) => {
        'is_upper': o.isUpper,
        'width': o.width,
        'precision': o.precision,
        'length': -1,
        'radix': 10,
        'sign': o.sign,
        'specifier_type': type,
        'padding_char': o.paddingChar,
        'add_space': o.addSpace,
        'left_align': o.leftAlign,
        'alternate_form': o.alternateForm,
      };

  // ── Legacy public API ───────────────────────────────────────────────

  void register_specifier(String specifier, PrintFormatFormatter formatter) {
    _customFormatters[specifier] = formatter;
  }

  @Deprecated('Spell error, Use unregister_specifier() instead')
  void unregistier_specifier(String specifier) {
    _customFormatters.remove(specifier);
  }

  void unregister_specifier(String specifier) {
    _customFormatters.remove(specifier);
  }
}
