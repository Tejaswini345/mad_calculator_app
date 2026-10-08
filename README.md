# Calculator App (CSC 6370, Assignment 01)

Flutter calculator: core four-operation flow + graduate pathway.

**Selected graduate features:** Decimal support (required) + Calculation history, Backspace/delete, Multiple operations (chaining).

## Setup

```bash
flutter create calculator_app          
cd calculator_app
rm -f test/widget_test.dart            
flutter pub get
flutter run
```

## Test

```bash
flutter test
```

## APK File

```bash
flutter build apk
```

## Structure

| File | Role |
|---|---|
| `lib/calculator_engine.dart` | All logic and state (no Flutter imports): input, operators, chaining, errors, history |
| `lib/main.dart` | UI only |
| `test/calculator_test.dart` | Unit tests for the engine + two widget tests |

## Behavior notes

- **Evaluation is sequential (left to right):** `8 + 7 × 2 =` gives `30`, not `22`. The running total shows after each operator.
- Numbers are limited to 15 digits; results are rounded to 10 decimal places so `0.1 + 0.2` shows `0.3`. Results of 1e15 or more report "Result too large". Results smaller than 1e-10 round to 0.
- `÷ 0` shows "Cannot divide by zero"; any digit, AC, or backspace recovers.
- Backspace on an empty entry with a pending operator undoes the operator; long-press clears everything. AC keeps history.
- History keeps the latest 100 results; tap one to reuse it.