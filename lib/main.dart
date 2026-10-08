import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'calculator_engine.dart';

void main() => runApp(const CalculatorApp());

class CalculatorApp extends StatelessWidget {
  const CalculatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calculator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
      ),
      home: const CalculatorPage(),
    );
  }
}

class CalculatorPage extends StatefulWidget {
  const CalculatorPage({super.key});

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  // All calculator state lives in the engine; the widget only rebuilds from it.
  final CalculatorEngine _engine = CalculatorEngine();

  void _act(VoidCallback action) {
    HapticFeedback.selectionClick();
    setState(action);
  }

  void _onBackspace() {
    final changed = _engine.backspace();
    if (changed) {
      HapticFeedback.selectionClick();
    } else {
      HapticFeedback.heavyImpact(); // feedback: nothing left to delete
    }
    setState(() {});
  }

  void _onBackspaceLongPress() {
    HapticFeedback.mediumImpact();
    setState(_engine.clearAll);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('Cleared'),
        duration: Duration(milliseconds: 900),
      ));
  }

  void _showHistory() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(builder: (context, setSheetState) {
          final items = _engine.history.reversed.toList(); // newest first
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text('History',
                        style: Theme.of(context).textTheme.titleLarge),
                    trailing: TextButton.icon(
                      key: const ValueKey('clear_history'),
                      onPressed: items.isEmpty
                          ? null
                          : () => setSheetState(_engine.clearHistory),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Clear history'),
                    ),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: items.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(32),
                            child: Text('No calculations yet'),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: items.length,
                            itemBuilder: (context, i) {
                              final item = items[i];
                              return ListTile(
                                key: ValueKey('history_$i'),
                                title: Text(item.expression),
                                subtitle: const Text('Tap to reuse result'),
                                trailing: Text(
                                  '= ${item.result}',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                onTap: () {
                                  Navigator.pop(sheetContext);
                                  _act(() => _engine.reuse(item.result));
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isError = _engine.isError;

    Widget digit(String d, {int flex = 1}) => _CalcButton(
          key: ValueKey('key_$d'),
          label: d,
          semanticLabel: d,
          flex: flex,
          onTap: () => _act(() => _engine.digit(d)),
        );

    Widget op(String sym, String name, String keyName) => _CalcButton(
          key: ValueKey('key_$keyName'),
          label: sym,
          semanticLabel: name,
          kind: _Kind.operator,
          selected: _engine.pendingOperator == sym,
          onTap: () => _act(() => _engine.chooseOperator(sym)),
        );

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              // ---------------------------------------------------- display
              Expanded(
                flex: 2,
                child: Semantics(
                  container: true,
                  liveRegion: true,
                  excludeSemantics: true,
                  label: isError
                      ? 'Error. ${_engine.display}'
                      : '${_engine.trail}. ${_engine.display}',
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.bottomRight,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            _engine.trail,
                            key: const ValueKey('trail'),
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ),
                        const SizedBox(height: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Icon + text so errors never rely on colour alone.
                              if (isError)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Icon(Icons.error_outline,
                                      size: 36, color: scheme.error),
                                ),
                              Text(
                                _engine.display,
                                key: const ValueKey('display'),
                                maxLines: 1,
                                style: Theme.of(context)
                                    .textTheme
                                    .displayLarge
                                    ?.copyWith(
                                      color: isError ? scheme.error : null,
                                      fontSize: isError ? 36 : 64,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // ------------------------------------------------------ keys
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    _row([
                      _CalcButton(
                        key: const ValueKey('key_ac'),
                        label: 'AC',
                        semanticLabel: 'All clear',
                        kind: _Kind.action,
                        onTap: () => _act(_engine.clearAll),
                      ),
                      _CalcButton(
                        key: const ValueKey('key_back'),
                        label: '⌫',
                        icon: Icons.backspace_outlined,
                        semanticLabel: 'Backspace. Long press to clear all',
                        kind: _Kind.action,
                        onTap: _onBackspace,
                        onLongPress: _onBackspaceLongPress,
                      ),
                      _CalcButton(
                        key: const ValueKey('key_history'),
                        label: 'History',
                        icon: Icons.history,
                        semanticLabel: 'History',
                        kind: _Kind.action,
                        onTap: _showHistory,
                      ),
                      op(CalculatorEngine.divide, 'Divide', 'div'),
                    ]),
                    _row([
                      digit('7'),
                      digit('8'),
                      digit('9'),
                      op(CalculatorEngine.multiply, 'Multiply', 'mul'),
                    ]),
                    _row([
                      digit('4'),
                      digit('5'),
                      digit('6'),
                      op(CalculatorEngine.subtract, 'Subtract', 'sub'),
                    ]),
                    _row([
                      digit('1'),
                      digit('2'),
                      digit('3'),
                      op(CalculatorEngine.add, 'Add', 'add'),
                    ]),
                    _row([
                      digit('0'),
                      _CalcButton(
                        key: const ValueKey('key_dot'),
                        label: '.',
                        semanticLabel: 'Decimal point',
                        onTap: () => _act(_engine.decimal),
                      ),
                      _CalcButton(
                        key: const ValueKey('key_eq'),
                        label: '=',
                        semanticLabel: 'Equals',
                        kind: _Kind.equals,
                        flex: 2,
                        onTap: () => _act(_engine.equals),
                      ),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(List<Widget> children) => Expanded(child: Row(children: children));
}

enum _Kind { digit, operator, action, equals }

class _CalcButton extends StatelessWidget {
  const _CalcButton({
    super.key,
    required this.label,
    required this.semanticLabel,
    required this.onTap,
    this.onLongPress,
    this.kind = _Kind.digit,
    this.flex = 1,
    this.selected = false,
    this.icon,
  });

  final String label;
  final String semanticLabel;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final _Kind kind;
  final int flex;
  final bool selected; // pending operator
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final Color bg;
    final Color fg;
    switch (kind) {
      case _Kind.digit:
        bg = s.surfaceContainerHigh;
        fg = s.onSurface;
      case _Kind.operator:
        bg = selected ? s.primary : s.primaryContainer;
        fg = selected ? s.onPrimary : s.onPrimaryContainer;
      case _Kind.action:
        bg = s.secondaryContainer;
        fg = s.onSecondaryContainer;
      case _Kind.equals:
        bg = s.tertiary;
        fg = s.onTertiary;
    }

    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Semantics(
          button: true,
          selected: selected,
          label: semanticLabel,
          onTap: onTap,
          onLongPress: onLongPress,
          excludeSemantics: true,
          child: Material(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              onLongPress: onLongPress,
              child: Container(
                constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                alignment: Alignment.center,
                // Scale text down (not clip) when the user enlarges system text.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: icon != null
                      ? Icon(icon, color: fg, size: 28)
                      : Text(label,
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w500,
                              color: fg)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}