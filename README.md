# dart-sprintf

Dart implementation of sprintf.

[![Build Status](https://github.com/NaivG/dart-sprintf/actions/workflows/dart_analyze.yml/badge.svg)](https://github.com/NaivG/dart-sprintf/actions/)

## ChangeLog

[ChangeLog.md](CHANGELOG.md)

## Getting Started

Add the following to your **pubspec.yaml**:

```
dependencies:
  dart_sprintf: "^8.0.0"
```

then run **pub install**.

Next, import dart-sprintf:

```
import 'package:dart_sprintf/sprintf.dart';
```

### Example

```
import 'package:dart_sprintf/sprintf.dart';

void main() {
	print(sprintf("%04i", [-42]));
	print(sprintf("%s %s", ["Hello", "World"]));
	print(sprintf("%#04x", [10]));
}
```

```
-042
Hello World
0x0a
```

## Limitations

- Negative numbers are wrapped as 53-bit ints (the JS safe-integer limit) when formatted as hex or octal.

Differences to C's printf

- When using fixed point printing of numbers with large exponents (e.g. `%f` for 1.79e+308), C's printf introduces errors after ~20 decimal places. Dart-sprintf falls back to scientific notation (e.g. `1.79e+308`).
