/// Calculator logic with no Flutter dependency, so every rule can be unit tested.
///
/// Evaluation strategy: SEQUENTIAL (left to right). Pressing a second operator
/// immediately applies the pending one, so `8 + 7 × 2 =` is `(8 + 7) × 2 = 30`,
/// like a basic desk calculator. The running total is always visible.
///
/// State is deliberately small: the entry being typed, the running total, the
/// pending operator, and an explicit phase (input / result / error). Everything
/// shown on screen (`display`, `trail`) is derived from that state.
library;

/// Which kind of thing the display is currently showing.
enum Phase { input, result, error }

/// A user-facing calculation failure (division by zero, overflow).
class CalcError implements Exception {
  const CalcError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// One finished calculation, e.g. `8 + 7 × 2` → `30`.
class HistoryEntry {
  const HistoryEntry(this.expression, this.result);
  final String expression;
  final String result;
}

class CalculatorEngine {
  // Operator symbols (single characters; the display trail relies on that).
  static const String add = '+';
  static const String subtract = '−';
  static const String multiply = '×';
  static const String divide = '÷';

  static const int maxDigits = 15;
  static const int maxHistory = 100;
  static const double maxMagnitude = 1e15;
  static const String divideByZeroMessage = 'Cannot divide by zero';
  static const String overflowMessage = 'Result too large';

  String _entry = ''; // text the user is typing (or the last result)
  double? _acc; // running total once an operator has been chosen
  String? _op; // pending operator
  String _trail = ''; // e.g. "8 + 7 × " (completed terms)
  String _errorExpr = '';
  String _error = '';
  Phase _phase = Phase.input;
  final List<HistoryEntry> _history = [];

  // ---------------------------------------------------------------- derived

  Phase get phase => _phase;
  bool get isError => _phase == Phase.error;
  String? get pendingOperator => _op;
  List<HistoryEntry> get history => List.unmodifiable(_history);

  /// Main line: error text, current entry, running total, or 0.
  String get display {
    if (_phase == Phase.error) return _error;
    if (_entry.isNotEmpty) return _entry;
    if (_acc != null) return format(_acc!);
    return '0';
  }

  /// Secondary line showing the expression so far.
  String get trail => _phase == Phase.error ? _errorExpr : _trail.trimRight();

  // ---------------------------------------------------------------- actions

  void digit(String d) {
    assert(d.length == 1 && '0123456789'.contains(d));
    if (_phase != Phase.input) _reset(); // typing after a result/error = new calc
    if (_digitCount(_entry) >= maxDigits) return;
    if (_entry == '0') {
      _entry = d; // no leading zeros ("007" -> "7"); "0","0" stays "0"
    } else if (_entry == '-0') {
      _entry = '-$d';
    } else {
      _entry += d;
    }
  }

  void decimal() {
    if (_phase != Phase.input) _reset();
    if (_entry.contains('.')) return; // only one decimal point per number
    if (_entry.isEmpty || _entry == '-') {
      _entry = '${_entry}0.';
    } else {
      _entry += '.';
    }
  }

  void chooseOperator(String sym) {
    if (_phase == Phase.error) return;

    // Continue from a finished result: `2 + 3 = × 4`.
    if (_phase == Phase.result) {
      _acc = _parse(_entry);
      _trail = '${_clean(_entry)} $sym ';
      _op = sym;
      _entry = '';
      _phase = Phase.input;
      return;
    }

    if (_entry.isEmpty) {
      if (_op != null) {
        // Repeated operator: the latest one wins ("5 + ×" == "5 ×").
        _op = sym;
        _trail = '${_trail.substring(0, _trail.length - 2)}$sym ';
      } else {
        // Operator first: treat the missing left side as 0.
        _acc = 0;
        _op = sym;
        _trail = '0 $sym ';
      }
      return;
    }

    final value = _parse(_entry);
    final shown = _clean(_entry);
    try {
      _acc = _op == null ? value : _compute(_acc!, _op!, value);
    } on CalcError catch (e) {
      _fail(e.message, '$_trail$shown $sym');
      return;
    }
    _trail = '$_trail$shown $sym ';
    _op = sym;
    _entry = '';
  }

  void equals() {
    // Ignore "equals too early": nothing pending, or second operand missing.
    if (_phase != Phase.input || _op == null || _entry.isEmpty) return;
    final expr = '$_trail${_clean(_entry)}';
    try {
      final result = _compute(_acc!, _op!, _parse(_entry));
      final text = format(result);
      _history.add(HistoryEntry(expr, text));
      if (_history.length > maxHistory) _history.removeAt(0);
      _reset();
      _entry = text;
      _phase = Phase.result;
      _trail = '$expr =';
    } on CalcError catch (e) {
      _fail(e.message, '$expr =');
    }
  }

  /// All clear: current calculation only. History is kept.
  void clearAll() => _reset();

  /// Deletes the last character. Returns false when there was nothing to delete.
  bool backspace() {
    if (_phase == Phase.error) {
      _reset();
      return true;
    }
    if (_phase == Phase.result) {
      // Editing a result turns it back into ordinary input.
      _phase = Phase.input;
      _trail = '';
      _acc = null;
      _op = null;
    }
    if (_entry.isNotEmpty) {
      _entry = _entry.substring(0, _entry.length - 1);
      if (_entry == '-') _entry = '';
      return true;
    }
    if (_op != null) {
      // Undo the pending operator and reopen the left operand for editing.
      _entry = format(_acc!);
      _acc = null;
      _op = null;
      _trail = '';
      return true;
    }
    return false;
  }

  /// Tap-to-reuse from history: put a past result in as the current entry.
  void reuse(String value) {
    if (_phase != Phase.input || _op == null) _reset();
    _entry = value;
    _phase = Phase.input;
  }

  void clearHistory() => _history.clear();

  // ---------------------------------------------------------------- helpers

  void _reset() {
    _entry = '';
    _acc = null;
    _op = null;
    _trail = '';
    _error = '';
    _errorExpr = '';
    _phase = Phase.input;
  }

  void _fail(String message, String expression) {
    _reset();
    _phase = Phase.error;
    _error = message;
    _errorExpr = expression;
  }

  static int _digitCount(String s) => s.replaceAll(RegExp(r'[^0-9]'), '').length;

  static String _clean(String s) => s.endsWith('.') ? s.substring(0, s.length - 1) : s;

  static double _parse(String s) => double.parse(_clean(s));

  static double _compute(double a, String op, double b) {
    final double r;
    switch (op) {
      case add:
        r = a + b;
      case subtract:
        r = a - b;
      case multiply:
        r = a * b;
      case divide:
        if (b == 0) throw const CalcError(divideByZeroMessage);
        r = a / b;
      default:
        throw StateError('Unknown operator: $op');
    }
    if (!r.isFinite || r.abs() >= maxMagnitude) {
      throw const CalcError(overflowMessage);
    }
    // Round to 10 places so 0.1 + 0.2 shows 0.3 instead of 0.30000000000000004.
    return double.parse(r.toStringAsFixed(10));
  }

  /// Formats a value without trailing zeros or a dangling decimal point.
  static String format(double v) {
    if (v == 0) return '0'; // also avoids "-0"
    var s = v.toStringAsFixed(10);
    if (s.contains('.')) {
      s = s.replaceFirst(RegExp(r'0+$'), '');
      s = s.replaceFirst(RegExp(r'\.$'), '');
    }
    return s;
  }
}
