import 'package:calculator_app/calculator_engine.dart';
import 'package:calculator_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Key script: digits, '.', '+', '-', '*', '/', '=', 'C' (AC), '<' (backspace).
CalculatorEngine run(String keys, [CalculatorEngine? engine]) {
  final e = engine ?? CalculatorEngine();
  for (final k in keys.split('')) {
    switch (k) {
      case '.':
        e.decimal();
      case '+':
        e.chooseOperator(CalculatorEngine.add);
      case '-':
        e.chooseOperator(CalculatorEngine.subtract);
      case '*':
        e.chooseOperator(CalculatorEngine.multiply);
      case '/':
        e.chooseOperator(CalculatorEngine.divide);
      case '=':
        e.equals();
      case 'C':
        e.clearAll();
      case '<':
        e.backspace();
      default:
        e.digit(k);
    }
  }
  return e;
}

void main() {
  group('core arithmetic', () {
    test('8 + 7 = 15', () => expect(run('8+7=').display, '15'));
    test('9 - 14 = -5', () => expect(run('9-14=').display, '-5'));
    test('6 x 0 = 0', () => expect(run('6*0=').display, '0'));
    test('8 / 2 = 4', () => expect(run('8/2=').display, '4'));
    test('leading zeros collapse', () => expect(run('007').display, '7'));
    test('digit limit is 15', () {
      expect(run('1111111111111111').display, '111111111111111');
    });
  });

  group('decimals (graduate requirement)', () {
    test('5.5 + 2.3 = 7.8', () => expect(run('5.5+2.3=').display, '7.8'));
    test('5.5 - 2.3 = 3.2', () => expect(run('5.5-2.3=').display, '3.2'));
    test('2.5 x 4 = 10', () => expect(run('2.5*4=').display, '10'));
    test('1 / 4 = 0.25', () => expect(run('1/4=').display, '0.25'));
    test('0.1 + 0.2 = 0.3 (no float noise)', () {
      expect(run('.1+.2=').display, '0.3');
    });
    test('second decimal point is rejected', () {
      expect(run('1.2.3').display, '1.23');
    });
    test('leading decimal becomes 0.', () => expect(run('.5').display, '0.5'));
    test('decimal after operator starts a new number', () {
      expect(run('3+.5=').display, '3.5');
    });
  });

  group('errors', () {
    test('8 / 0 shows recoverable error', () {
      final e = run('8/0=');
      expect(e.isError, isTrue);
      expect(e.display, CalculatorEngine.divideByZeroMessage);
    });
    test('0 / 0 is also an error', () => expect(run('0/0=').isError, isTrue));
    test('typing a digit recovers from error', () {
      expect(run('8/0=5').display, '5');
      expect(run('8/0=5').isError, isFalse);
    });
    test('AC and backspace recover from error', () {
      expect(run('8/0=C').display, '0');
      expect(run('8/0=<').isError, isFalse);
    });
    test('operators and equals are ignored while in error', () {
      expect(run('8/0=+=').isError, isTrue);
    });
    test('overflow is reported', () {
      final e = run('999999999999999*10=');
      expect(e.isError, isTrue);
      expect(e.display, CalculatorEngine.overflowMessage);
    });
    test('division by zero mid-chain', () {
      // 4 + 5 / -> running total 9, then 9 / 0 fails when "+" is pressed.
      final e = run('4+5/0+');
      expect(e.isError, isTrue);
      expect(e.trail, '4 + 5 ÷ 0 +');
    });
  });

  group('chaining (sequential evaluation)', () {
    test('8 + 7 x 2 = 30, not 22', () => expect(run('8+7*2=').display, '30'));
    test('running total shows after next operator', () {
      final e = run('2+3+');
      expect(e.display, '5');
      expect(e.trail, '2 + 3 +');
    });
    test('long chain', () => expect(run('10-4*3/2=').display, '9'));
    test('repeated operators: last one wins', () {
      expect(run('5+*3=').display, '15');
    });
    test('equals too early does not crash or change state', () {
      final e = run('5+=');
      expect(e.display, '5');
      expect(e.pendingOperator, CalculatorEngine.add);
    });
    test('equals with no operator is a no-op', () => expect(run('7=').display, '7'));
    test('operator first uses 0', () => expect(run('+5=').display, '5'));
    test('digit after result starts a new calculation', () {
      expect(run('2+3=4').display, '4');
    });
    test('operator after result continues from it', () {
      expect(run('2+3=*4=').display, '20');
    });
  });

  group('clear', () {
    test('AC resets everything (no stale operator)', () {
      // 2 + 3 = 5, AC, 4 + 1 = 5 must not reuse the old result/operator.
      final e = run('2+3=C');
      expect(e.display, '0');
      expect(e.pendingOperator, isNull);
      expect(run('4+1=', e).display, '5');
    });
    test('AC clears a pending operation', () {
      expect(run('5+C3=').display, '3');
    });
  });

  group('backspace', () {
    test('removes last digit', () => expect(run('123<').display, '12'));
    test('down to empty shows 0', () => expect(run('1<').display, '0'));
    test('removes a dangling decimal point', () => expect(run('1.<').display, '1'));
    test('on empty entry with nothing pending returns false', () {
      expect(CalculatorEngine().backspace(), isFalse);
    });
    test('undoes a pending operator and reopens the left number', () {
      final e = run('5+<');
      expect(e.pendingOperator, isNull);
      expect(e.display, '5');
      expect(run('3', e).display, '53');
    });
    test('editing a result makes it ordinary input', () {
      expect(run('12+30=<').display, '4');
    });
    test('negative number down to empty', () {
      expect(run('3-5=<').display, '0'); // -2 -> "-" -> empty
    });
  });

  group('history', () {
    test('records finished calculations with full expression', () {
      final e = run('8+7*2=');
      expect(e.history.single.expression, '8 + 7 × 2');
      expect(e.history.single.result, '30');
    });
    test('survives AC, cleared by clearHistory', () {
      final e = run('2+3=C');
      expect(e.history.length, 1);
      e.clearHistory();
      expect(e.history, isEmpty);
    });
    test('errors are not recorded', () => expect(run('8/0=').history, isEmpty));
    test('reuse puts a result back as the current entry', () {
      final e = run('2+3=C');
      e.reuse(e.history.single.result);
      expect(e.display, '5');
      expect(run('+1=', e).display, '6');
    });
    test('reuse fills the second operand when an operator is pending', () {
      final e = run('2+3=C');
      run('9*', e);
      e.reuse('5');
      e.equals();
      expect(e.display, '45');
    });
  });

  testWidgets('UI: 8 / 0 = shows error, then recovers', (tester) async {
    await tester.pumpWidget(const CalculatorApp());
    Future<void> tap(String key) async {
      await tester.tap(find.byKey(ValueKey('key_$key')));
      await tester.pump();
    }

    String shown() => tester.widget<Text>(find.byKey(const ValueKey('display'))).data!;

    await tap('8');
    await tap('div');
    await tap('0');
    await tap('eq');
    expect(shown(), CalculatorEngine.divideByZeroMessage);
    await tap('ac');
    expect(shown(), '0');
    await tap('7');
    await tap('add');
    await tap('5');
    await tap('eq');
    expect(shown(), '12');
  });

  testWidgets('UI: history sheet lists, reuses and clears', (tester) async {
    await tester.pumpWidget(const CalculatorApp());
    Future<void> tap(String key) async {
      await tester.tap(find.byKey(ValueKey('key_$key')));
      await tester.pump();
    }

    for (final k in ['2', 'add', '3', 'eq', 'ac']) {
      await tap(k);
    }
    await tap('history');
    await tester.pumpAndSettle();
    expect(find.text('2 + 3'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('history_0')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const ValueKey('display'))).data, '5');

    await tap('history');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('clear_history')));
    await tester.pumpAndSettle();
    expect(find.text('No calculations yet'), findsOneWidget);
  });
}
