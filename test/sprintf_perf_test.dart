// ignore_for_file: avoid_print, unused_field, unnecessary_this
//
// Head-to-head PerfTester benchmark: original sprintf v7.0.0 vs rewrite.
//
// The old implementation is inlined here (renamed Old*) so both run in
// the same process with identical JIT conditions.
//
// Run:
//   dart run test/sprintf_perf_test.dart

import 'dart:math';

import 'package:dart_sprintf/sprintf.dart' as new_impl;

import 'perf_tester.dart';

// ═══════════════════════════════════════════════════════════════════════
//  OLD IMPLEMENTATION — verbatim from v7.0.0, classes renamed with Old*
// ═══════════════════════════════════════════════════════════════════════

abstract class OldFormatter {
  var fmt_type;
  var options;
  OldFormatter(this.fmt_type, this.options);

  static String get_padding(int count, String pad) {
    var padding_piece = pad;
    var padding = StringBuffer();
    while (count > 0) {
      if ((count & 1) == 1) padding.write(padding_piece);
      count >>= 1;
      padding_piece = '${padding_piece}${padding_piece}';
    }
    return padding.toString();
  }

  String asString();
}

class OldIntFormatter extends OldFormatter {
  int _arg;
  static const int MAX_INT = 0x1FFFFFFFFFFFFF;

  OldIntFormatter(this._arg, var fmt_type, var options)
      : super(fmt_type, options);

  @override
  String asString() {
    var ret = '';
    var prefix = '';
    var radix = fmt_type == 'x' ? 16 : (fmt_type == 'o' ? 8 : 10);

    if (_arg < 0) {
      if (radix == 10) {
        _arg = _arg.abs();
        options['sign'] = '-';
      } else {
        _arg = (MAX_INT - (~_arg) & MAX_INT);
      }
    }

    ret = _arg.toRadixString(radix);

    if (options['alternate_form']) {
      if (radix == 16 && _arg != 0) {
        prefix = '0x';
      } else if (radix == 8 && _arg != 0) {
        prefix = '0';
      }
      if (options['sign'] == '+' && radix != 10) {
        options['sign'] = '';
      }
    }

    if ((options['add_space'] &&
        options['sign'] == '' &&
        _arg > -1 &&
        radix == 10)) {
      options['sign'] = ' ';
    }

    if (radix != 10) {
      options['sign'] = '';
    }

    var padding = '';
    var min_digits = options['precision'];
    var min_chars = options['width'];
    var num_length = ret.length;
    var sign_length = options['sign'].length;
    num str_len = 0;

    if (radix == 8 && min_chars <= min_digits) {
      num_length += prefix.length;
    }

    if (min_digits > num_length) {
      padding = OldFormatter.get_padding(min_digits - num_length, '0');
      ret = '${padding}${ret}';
      num_length = ret.length;
      padding = '';
    }

    str_len = num_length + sign_length + prefix.length;
    if (min_chars > str_len) {
      if (options['padding_char'] == '0' && !options['left_align']) {
        padding = OldFormatter.get_padding(min_chars - str_len as int, '0');
      } else {
        padding = OldFormatter.get_padding(min_chars - str_len as int, ' ');
      }
    }

    if (options['left_align']) {
      ret = "${options['sign']}${prefix}${ret}${padding}";
    } else if (options['padding_char'] == '0') {
      ret = "${options['sign']}${prefix}${padding}${ret}";
    } else {
      ret = "${padding}${options['sign']}${prefix}${ret}";
    }

    if (options['is_upper']) {
      ret = ret.toUpperCase();
    }

    return ret;
  }
}

class OldFloatFormatter extends OldFormatter {
  static final _number_rx = RegExp(r'^[\-\+]?(\d+)\.(\d+)$');
  static final _expo_rx = RegExp(r'^[\-\+]?(\d)\.(\d+)e([\-\+]?\d+)$');
  static final _leading_zeroes_rx = RegExp(r'^(0*)[1-9]+');

  double _arg;
  final List<int> _digits = [];
  int _exponent = 0;
  int _decimal = 0;
  bool _is_negative = false;
  bool _has_init = false;
  String? _output;

  OldFloatFormatter(this._arg, var fmt_type, var options)
      : super(fmt_type, options) {
    if (_arg.isNaN) {
      _has_init = true;
      return;
    }
    if (_arg.isInfinite) {
      _is_negative = _arg.isNegative;
      _has_init = true;
      return;
    }
    _arg = _arg.toDouble();
    if (_arg < 0) {
      _is_negative = true;
      _arg = -_arg;
    }

    var arg_str =
        _arg == _arg.truncate() ? _arg.toStringAsFixed(1) : _arg.toString();
    var m1 = _number_rx.firstMatch(arg_str);
    if (m1 != null) {
      var int_part = m1.group(1)!;
      var fraction = m1.group(2)!;
      _decimal = int_part.length;
      _digits.addAll(int_part.split('').map(int.parse));
      _digits.addAll(fraction.split('').map(int.parse));
      if (int_part.length == 1) {
        if (int_part == '0') {
          var lzm = _leading_zeroes_rx.firstMatch(fraction);
          if (lzm != null) {
            var zc = lzm.group(1)!.length;
            _exponent = zc > 0 ? -(zc + 1) : zc - 1;
          } else {
            _exponent = 0;
          }
        } else {
          _exponent = 0;
        }
      } else {
        _exponent = int_part.length - 1;
      }
    } else {
      var m2 = _expo_rx.firstMatch(arg_str);
      if (m2 != null) {
        var int_part = m2.group(1)!;
        var fraction = m2.group(2)!;
        _exponent = int.parse(m2.group(3)!);
        if (_exponent > 0) {
          var diff = _exponent - fraction.length + 1;
          _decimal = _exponent + 1;
          _digits.addAll(int_part.split('').map(int.parse));
          _digits.addAll(fraction.split('').map(int.parse));
          _digits.addAll(
              OldFormatter.get_padding(diff, '0').split('').map(int.parse));
        } else {
          var diff = int_part.length - _exponent - 1;
          _decimal = int_part.length;
          _digits.addAll(
              OldFormatter.get_padding(diff, '0').split('').map(int.parse));
          _digits.addAll(int_part.split('').map(int.parse));
          _digits.addAll(fraction.split('').map(int.parse));
        }
      }
    }
    _has_init = true;
  }

  @override
  String asString() {
    var ret = '';
    if (!_has_init) return ret;
    if (_output != null) return _output!;

    if (options['add_space'] && options['sign'] == '' && _arg >= 0) {
      options['sign'] = ' ';
    }
    if (_arg.isInfinite) {
      if (_arg.isNegative) options['sign'] = '-';
      ret = 'inf';
      options['padding_char'] = ' ';
    }
    if (_arg.isNaN) {
      ret = 'nan';
      options['padding_char'] = ' ';
    }
    if (options['precision'] == -1) {
      options['precision'] = 6;
    } else if (fmt_type == 'g' && options['precision'] == 0) {
      options['precision'] = 1;
    }
    if (_is_negative) options['sign'] = '-';

    if (!(_arg.isInfinite || _arg.isNaN)) {
      if (fmt_type == 'e') {
        ret = asExponential(options['precision'], remove_trailing_zeros: false);
      } else if (fmt_type == 'f') {
        ret = asFixed(options['precision'], remove_trailing_zeros: false);
      } else {
        var _exp = _exponent;
        var sig_digs = options['precision'];
        if (-4 <= _exp && _exp < options['precision']) {
          sig_digs -= _decimal;
          var precision = max<num>(options['precision'] - 1 - _exp, sig_digs);
          ret = asFixed(precision.toInt(),
              remove_trailing_zeros: !options['alternate_form']);
        } else {
          ret = asExponential(options['precision'] - 1,
              remove_trailing_zeros: !options['alternate_form']);
        }
      }
    }

    var min_chars = options['width'];
    var str_len = ret.length + options['sign'].length;
    var padding = '';
    if (min_chars > str_len) {
      if (options['padding_char'] == '0' && !options['left_align']) {
        padding = OldFormatter.get_padding(min_chars - str_len, '0');
      } else {
        padding = OldFormatter.get_padding(min_chars - str_len, ' ');
      }
    }
    if (options['left_align']) {
      ret = "${options['sign']}${ret}${padding}";
    } else if (options['padding_char'] == '0') {
      ret = "${options['sign']}${padding}${ret}";
    } else {
      ret = "${padding}${options['sign']}${ret}";
    }
    if (options['is_upper']) ret = ret.toUpperCase();
    return (_output = ret);
  }

  String asFixed(int precision, {bool remove_trailing_zeros = true}) {
    var offset = _decimal + precision - 1;
    var extra_zeroes = precision - (_digits.length - offset);
    if (extra_zeroes > 0) {
      _digits.addAll(
          OldFormatter.get_padding(extra_zeroes, '0').split('').map(int.parse));
    }
    _round(offset + 1, offset);
    var ret = _digits.sublist(0, _decimal).fold('', (i, e) => '${i}${e}');
    var trailing_digits = _digits.sublist(_decimal, _decimal + precision);
    if (remove_trailing_zeros)
      trailing_digits = _remove_trailing_zeros(trailing_digits);
    var trailing_zeroes = trailing_digits.fold('', (i, e) => '${i}${e}');
    if (trailing_zeroes.isEmpty) return ret;
    return '${ret}.${trailing_zeroes}';
  }

  String asExponential(int precision, {bool remove_trailing_zeros = true}) {
    var offset = _decimal - _exponent;
    var extra_zeroes = precision - (_digits.length - offset) + 1;
    if (extra_zeroes > 0) {
      _digits.addAll(
          OldFormatter.get_padding(extra_zeroes, '0').split('').map(int.parse));
    }
    _round(offset + precision, offset);
    var ret = _digits[offset - 1].toString();
    var trailing_digits = _digits.sublist(offset, offset + precision);
    var _exp_str = _exponent.abs().toString();
    if (_exponent < 10 && _exponent > -10) _exp_str = '0${_exp_str}';
    _exp_str = (_exponent < 0) ? 'e-${_exp_str}' : 'e+${_exp_str}';
    if (remove_trailing_zeros)
      trailing_digits = _remove_trailing_zeros(trailing_digits);
    if (trailing_digits.isNotEmpty) ret += '.';
    ret = trailing_digits.fold(ret, (i, e) => '${i}${e}');
    return '${ret}${_exp_str}';
  }

  List<int> _remove_trailing_zeros(List<int> trailing_digits) {
    var nzeroes = 0;
    for (var i = trailing_digits.length - 1; i >= 0; i--) {
      if (trailing_digits[i] == 0) {
        nzeroes++;
      } else {
        break;
      }
    }
    return trailing_digits.sublist(0, trailing_digits.length - nzeroes);
  }

  void _round(var rounding_offset, var offset) {
    var carry = 0;
    if (rounding_offset >= _digits.length) return;
    var d = _digits[rounding_offset];
    carry = d >= 5 ? 1 : 0;
    _digits[rounding_offset] = d % 10;
    rounding_offset -= 1;
    while (carry > 0) {
      d = _digits[rounding_offset] + carry;
      if (rounding_offset == 0 && d > 9) {
        _digits.insert(0, 0);
        _decimal += 1;
        rounding_offset += 1;
      }
      carry = d < 10 ? 0 : 1;
      _digits[rounding_offset] = d % 10;
      rounding_offset -= 1;
    }
  }
}

class OldStringFormatter extends OldFormatter {
  var _arg;
  OldStringFormatter(this._arg, var fmt_type, var options)
      : super(fmt_type, options) {
    options['padding_char'] = ' ';
  }

  @override
  String asString() {
    var ret = _arg.toString();
    if (options['precision'] > -1 && options['precision'] <= ret.length) {
      ret = ret.substring(0, options['precision']);
    }
    if (options['width'] > -1) {
      int diff = (options['width'] - ret.length);
      if (diff > 0) {
        var padding = OldFormatter.get_padding(diff, options['padding_char']);
        if (!options['left_align']) {
          ret = '${padding}${ret}';
        } else {
          ret = '${ret}${padding}';
        }
      }
    }
    return ret;
  }
}

typedef OldPrintFormatFormatter = OldFormatter Function(
    dynamic arg, dynamic options);

class OldPrintFormat {
  static final RegExp specifier = RegExp(
      r'%(?:(\d+)\$)?([\+\-\#0 ]*)(\d+|\*)?(?:\.(\d+|\*))?([a-z%])',
      caseSensitive: false);
  static final RegExp uppercase_rx = RegExp(r'[A-Z]', caseSensitive: true);

  final Map<String, OldPrintFormatFormatter> _formatters = {
    'i': (arg, options) => OldIntFormatter(arg, 'i', options),
    'd': (arg, options) => OldIntFormatter(arg, 'd', options),
    'x': (arg, options) => OldIntFormatter(arg, 'x', options),
    'X': (arg, options) => OldIntFormatter(arg, 'x', options),
    'o': (arg, options) => OldIntFormatter(arg, 'o', options),
    'O': (arg, options) => OldIntFormatter(arg, 'o', options),
    'e': (arg, options) => OldFloatFormatter(arg, 'e', options),
    'E': (arg, options) => OldFloatFormatter(arg, 'e', options),
    'f': (arg, options) => OldFloatFormatter(arg, 'f', options),
    'F': (arg, options) => OldFloatFormatter(arg, 'f', options),
    'g': (arg, options) => OldFloatFormatter(arg, 'g', options),
    'G': (arg, options) => OldFloatFormatter(arg, 'g', options),
    's': (arg, options) => OldStringFormatter(arg, 's', options),
  };

  String call(String fmt, var args) {
    var ret = '';
    var offset = 0;
    var arg_offset = 0;
    if (args is! List) throw ArgumentError('Expecting list as second argument');

    for (var m in specifier.allMatches(fmt)) {
      var _parameter = m[1];
      var _flags = m[2]!;
      var _width = m[3];
      var _precision = m[4];
      var _type = m[5]!;
      var _arg_str = '';
      var _options = {
        'is_upper': false,
        'width': -1,
        'precision': -1,
        'length': -1,
        'radix': 10,
        'sign': '',
        'specifier_type': _type,
      };
      _parse_flags(_flags).forEach((var k, var v) {
        _options[k] = v;
      });
      var _arg = _parameter == null ? null : args[int.parse(_parameter) - 1];
      if (_width != null) {
        _options['width'] =
            (_width == '*' ? args[arg_offset++] : int.parse(_width));
      }
      if (_precision != null) {
        _options['precision'] =
            (_precision == '*' ? args[arg_offset++] : int.parse(_precision));
      }
      if (_arg == null && _type != '%') _arg = args[arg_offset++];
      _options['is_upper'] = uppercase_rx.hasMatch(_type);
      if (_type == '%') {
        if (_flags.isNotEmpty || _width != null || _precision != null) {
          throw Exception('"%" does not take any flags');
        }
        _arg_str = '%';
      } else if (_formatters.containsKey(_type)) {
        _arg_str = _formatters[_type]!(_arg, _options).asString();
      } else {
        throw ArgumentError('Unknown format type ${_type}');
      }
      ret += fmt.substring(offset, m.start);
      offset = m.end;
      ret += _arg_str;
    }
    return ret += fmt.substring(offset);
  }

  Map _parse_flags(String flags) {
    return {
      'sign': flags.contains('+') ? '+' : '',
      'padding_char': flags.contains('0') ? '0' : ' ',
      'add_space': flags.contains(' '),
      'left_align': flags.contains('-'),
      'alternate_form': flags.contains('#'),
    };
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  BENCHMARK
// ═══════════════════════════════════════════════════════════════════════

final _oldSprintf = OldPrintFormat();
final _newSprintf = new_impl.PrintFormat();

typedef _WorkItem = (String fmt, List<dynamic> args, int iters);

const _workload = <_WorkItem>[
  ('%d', [12345], 100000),
  ('%06d', [12345], 100000),
  ('%dd %dh %dm %2ds', [7, 23, 59, 4], 50000),
  ('%x', [255], 100000),
  ('%f', [3.14159], 50000),
  ('%.2f', [3.14159], 50000),
  ('%e', [3.14159], 50000),
  ('%g', [3.14159], 50000),
  ('%s', ['hello world'], 100000),
  ('%-20s', ['hello'], 100000),
  ('name=%s id=%d val=%.2f', ['hello', 42, 1.5], 50000),
];

String _runOld(List<_WorkItem> work) {
  final buf = StringBuffer();
  for (final (fmt, args, iters) in work) {
    for (int i = 0; i < iters; i++) buf.write(_oldSprintf.call(fmt, args));
  }
  return buf.toString();
}

String _runNew(List<_WorkItem> work) {
  final buf = StringBuffer();
  for (final (fmt, args, iters) in work) {
    for (int i = 0; i < iters; i++) buf.write(_newSprintf.call(fmt, args));
  }
  return buf.toString();
}

void main() async {
  final tester = PerfTester<List<_WorkItem>, String>(
    testName: 'sprintf: original v7.0.0  vs  rewrite',
    testCases: [_workload],
    implementation1: _runOld,
    implementation2: _runNew,
    impl1Name: 'original',
    impl2Name: 'rewrite',
  );

  await tester.run(
    warmupRuns: 5,
    benchmarkRuns: 30,
    profile: false,
  );
}
