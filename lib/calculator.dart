import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pcalc_express/app_brand.dart';
import 'package:pcalc_express/calculator_keypad.dart';
import 'package:pcalc_express/operator_palette.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pcalc_express/platform_capabilities.dart';
import 'package:pcalc_express/theme_preferences.dart';
import 'package:pcalc_express/input_preferences.dart';
import 'package:pcalc_express/result_preferences.dart';
import 'package:pcalc_express/result_display.dart';
import 'package:pcalc_express/share_expression_dialog.dart';
import 'package:pcalc_express/window_drag_controller.dart';
import 'package:pcalc_express/settings_page.dart';

import 'package:pcalc_expression_engine/pcalc_expression_engine.dart';

import 'feature_flags.dart';
import 'endian_buttons.dart';
import 'container_explorer.dart';

import 'package:pcalc_express/help_screen.dart';
import 'package:pcalc_express/format_helper.dart';

final Uri _sourceCodeUri = Uri.parse(
  'https://github.com/richyo-codes/pcalc-express',
);

class AppScrollBehavior extends MaterialScrollBehavior {
  // Enable drag with mouse/trackpad on desktop (touch already works on mobile)
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
  };
}

class _FocusExpressionIntent extends Intent {
  const _FocusExpressionIntent();
}

class _CalculateExpressionIntent extends Intent {
  const _CalculateExpressionIntent();
}

final class _BracketAnalysis {
  const _BracketAnalysis({
    required this.pairs,
    required this.unmatchedOffsets,
    required this.activePair,
  });

  final Map<int, int> pairs;
  final Set<int> unmatchedOffsets;
  final Set<int> activePair;

  bool get hasError => unmatchedOffsets.isNotEmpty;
  bool get hasActivePair => activePair.isNotEmpty;

  String get statusMessage {
    if (unmatchedOffsets.isEmpty) {
      return hasActivePair ? 'Matching brackets' : 'Brackets balanced';
    }
    return unmatchedOffsets.length == 1
        ? 'Unmatched bracket'
        : '${unmatchedOffsets.length} unmatched brackets';
  }

  factory _BracketAnalysis.forText(String text, int cursorOffset) {
    final pairs = <int, int>{};
    final unmatched = <int>{};
    final openings = <({int offset, String character})>[];
    const closingFor = {')': '(', ']': '[', '}': '{'};

    for (var index = 0; index < text.length; index++) {
      final character = text[index];
      if (character == '(' || character == '[' || character == '{') {
        openings.add((offset: index, character: character));
        continue;
      }
      final opening = closingFor[character];
      if (opening == null) continue;
      if (openings.isEmpty || openings.last.character != opening) {
        unmatched.add(index);
        continue;
      }
      final matchedOpening = openings.removeLast();
      pairs[matchedOpening.offset] = index;
      pairs[index] = matchedOpening.offset;
    }
    unmatched.addAll(openings.map((bracket) => bracket.offset));

    final activePair = <int>{};
    final candidates = <int>{
      if (cursorOffset >= 0 && cursorOffset < text.length) cursorOffset,
      if (cursorOffset > 0 && cursorOffset <= text.length) cursorOffset - 1,
    };
    for (final candidate in candidates) {
      final matching = pairs[candidate];
      if (matching != null) {
        activePair.add(candidate);
        activePair.add(matching);
        break;
      }
    }

    return _BracketAnalysis(
      pairs: pairs,
      unmatchedOffsets: unmatched,
      activePair: activePair,
    );
  }
}

final class _BracketHighlightingController extends TextEditingController {
  _BracketHighlightingController({super.text});

  // Consume identifiers and quoted literals as complete tokens so their digits
  // and operator characters do not get highlighted as separate expressions.
  static final _tokens = RegExp(
    r'''(?:"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')|(?:0[xX][0-9a-fA-F]+(?:[uUlL]*)|0[bB][01]+(?:[uUlL]*)|0[oO][0-7]+|(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?[fFuUlL]*)|(?:[a-zA-Z_][a-zA-Z_0-9]*)|(?:[+\-*/%&|^~!=<>?:]+)''',
  );

  _BracketAnalysis get bracketAnalysis => _BracketAnalysis.forText(
    text,
    selection.isValid ? selection.extentOffset : text.length,
  );

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final analysis = bracketAnalysis;
    if (text.isEmpty) return TextSpan(style: style);
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final literalColor = isEinkTheme(context)
        ? Colors.black
        : isDark
        ? const Color(0xFFA6C5B0)
        : const Color(0xFF35634A);
    final operatorColor = isEinkTheme(context)
        ? Colors.black
        : isDark
        ? const Color(0xFF9EBBD7)
        : const Color(0xFF345D86);
    final tokenColors = <int, Color>{};
    for (final token in _tokens.allMatches(text)) {
      final value = token.group(0)!;
      final first = value[0];
      final isLiteral =
          RegExp(r'[0-9.]').hasMatch(first) ||
          first == '"' ||
          first == "'" ||
          value == 'true' ||
          value == 'false';
      final isOperator = RegExp(r'[+\-*/%&|^~!=<>?:]').hasMatch(first);
      if (!isLiteral && !isOperator) continue;
      for (var offset = token.start; offset < token.end; offset++) {
        tokenColors[offset] = isLiteral ? literalColor : operatorColor;
      }
    }
    final composing = value.composing;
    final showComposing =
        withComposing &&
        composing.isValid &&
        !composing.isCollapsed &&
        composing.end <= text.length;
    return TextSpan(
      style: style,
      children: [
        for (var index = 0; index < text.length; index++)
          TextSpan(
            text: text[index],
            style: analysis.unmatchedOffsets.contains(index)
                ? TextStyle(
                    color: colors.error,
                    decoration: TextDecoration.underline,
                    decorationColor: colors.error,
                    decorationStyle: TextDecorationStyle.wavy,
                  )
                : analysis.activePair.contains(index)
                ? TextStyle(
                    color: isDark
                        ? const Color(0xFFA8BED5)
                        : const Color(0xFF294D70),
                    decoration: TextDecoration.underline,
                    decorationColor: isDark
                        ? const Color(0xFF587998)
                        : const Color(0xFF5B7B9B),
                    decorationThickness: 1.5,
                  )
                : TextStyle(
                    color: tokenColors[index],
                    decoration:
                        showComposing &&
                            index >= composing.start &&
                            index < composing.end
                        ? TextDecoration.underline
                        : null,
                  ),
          ),
      ],
    );
  }
}

class HistoryEntry {
  final String expression;
  final String decimal;
  final String hex;
  final String binary;
  final String floatValue;

  const HistoryEntry({
    required this.expression,
    required this.decimal,
    required this.hex,
    required this.binary,
    required this.floatValue,
  });
}

class CalculatorScreen extends StatefulWidget {
  final bool? showCalcButtonsDesktop;
  final MaterialColor? themeColor;
  final int initialPanel;
  const CalculatorScreen({
    super.key,
    this.showCalcButtonsDesktop,
    this.themeColor,
    this.initialPanel = 0,
  }) : assert(initialPanel >= 0 && initialPanel <= 1);

  @override
  _CalculatorScreenState createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  void _showAddVariableDialog() {
    final nameController = TextEditingController();
    final valueController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add Custom Variable'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'Variable Name'),
              ),
              TextField(
                controller: valueController,
                decoration: InputDecoration(labelText: 'Value'),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                final value = double.tryParse(valueController.text.trim());
                if (name.isNotEmpty && value != null) {
                  // Call FFI to set variable
                  //setCustomVariable(name, value);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Variable "$name" set to $value')),
                  );
                }
              },
              child: Text('Add'),
            ),
          ],
        );
      },
    );
  }

  bool get _isDesktopPlatform => isDesktopPlatform;
  bool get _usesWideLayoutPlatform =>
      _isDesktopPlatform || (!isAndroid && !isIOS);

  late final _BracketHighlightingController _controller;
  final FocusNode _focusNode = FocusNode(); // Added focus node
  late _BracketAnalysis _bracketAnalysis;
  String decimalResult = "";
  String _rawHexResult = "";
  String get hexResult => formatHexDisplay(
    _rawHexResult,
    groupDigits: hexGroupDigitsNotifier.value,
    showPrefix: hexPrefixNotifier.value,
  );
  String binaryResult = "";
  String floatResult = "";
  double? _lastNumericResult;
  ContainerSnapshot? _containerResult;

  void _refreshFloatPrecision() {
    if (!mounted) return;
    setState(() {
      if (_lastNumericResult != null && floatResult.isNotEmpty) {
        floatResult = formatFloatResult(
          _lastNumericResult!,
          decimalPlaces: floatPrecisionNotifier.value,
        );
      }
    });
  }

  bool hasCalculationError = false;
  List<HistoryEntry> history = [];
  bool showCalcButtons = false;
  bool _expressionExpanded = false;
  double? _expressionEditorHeight;
  String? _copiedResultLabel;
  String _selectedResultLabel = "Dec";
  ResultDisplayMode _resultDisplayMode = ResultDisplayMode.adaptive;

  late int _currentPanel;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();

    _controller = _BracketHighlightingController(
      text: expressionFromLaunchUri(Uri.base) ?? '',
    );
    _bracketAnalysis = _controller.bracketAnalysis;
    _controller.addListener(_updateBracketAnalysis);
    useSystemKeyboardNotifier.addListener(_updateInputMode);
    floatPrecisionNotifier.addListener(_refreshFloatPrecision);
    hexGroupDigitsNotifier.addListener(_refreshFloatPrecision);
    hexPrefixNotifier.addListener(_refreshFloatPrecision);

    _currentPanel = widget.initialPanel;
    _pageController = PageController(initialPage: widget.initialPanel);

    // Determine if calculator buttons should be shown
    if (isAndroid || isIOS || kIsWeb) {
      showCalcButtons = true;
    } else {
      showCalcButtons = widget.showCalcButtonsDesktop ?? false;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus(); // Set focus to the TextField by default
    });
  }

  @override
  void dispose() {
    useSystemKeyboardNotifier.removeListener(_updateInputMode);
    floatPrecisionNotifier.removeListener(_refreshFloatPrecision);
    hexGroupDigitsNotifier.removeListener(_refreshFloatPrecision);
    hexPrefixNotifier.removeListener(_refreshFloatPrecision);
    _controller.removeListener(_updateBracketAnalysis);
    _controller.dispose();
    _focusNode.dispose(); // Dispose of the focus node
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _copyResult(String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) {
      return;
    }

    setState(() => _copiedResultLabel = label);
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (mounted && _copiedResultLabel == label) {
      setState(() => _copiedResultLabel = null);
    }
  }

  void _updateInputMode() {
    if (!useSystemKeyboardNotifier.value) {
      SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    }
    setState(() {});
  }

  void _updateBracketAnalysis() {
    final analysis = _controller.bracketAnalysis;
    if (mounted) {
      setState(() {
        _bracketAnalysis = analysis;
      });
    }
  }

  void _clearResult() {
    _controller.clear();

    _focusNode.requestFocus();
  }

  void _focusExpression() {
    if (!_controller.selection.isValid) {
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    }
    _focusNode.requestFocus();
  }

  void _calculateResult() {
    String input = _controller.text;

    //final inputProcessed = preprocessExpression(input);

    try {
      final result = evaluateExpression(input);

      if (!result.isError && result.container != null) {
        setState(() {
          _containerResult = result.container;
          hasCalculationError = false;
          decimalResult = result.displayText;
          _rawHexResult = binaryResult = floatResult = '';
          _lastNumericResult = null;
        });
        return;
      }
      _containerResult = null;

      if (result.isError || !result.hasNumericValue) {
        final errMsg =
            result.errorMessage?.trim() ?? getLastErrorMessage().trim();
        final displayError = errMsg.isEmpty ? result.displayText : errMsg;

        setState(() {
          hasCalculationError = true;
          decimalResult = displayError;
          _rawHexResult = "";
          binaryResult = "";
          floatResult = "";
        });
        return;
      }

      final numericValue = result.numericValue!;
      final integerValue = result.integerValue ?? numericValue.truncate();
      final bitWidth = result.bitWidth ?? 32;

      setState(() {
        hasCalculationError = false;
        decimalResult = integerValue.toString();
        _rawHexResult = formatHexResult(
          integerValue,
          bitWidth: bitWidth,
          isSigned: result.isSigned ?? true,
        );
        binaryResult = formatBinaryResult(
          integerValue,
          bitWidth: bitWidth,
          isSigned: result.isSigned ?? true,
        );
        _lastNumericResult = numericValue;
        floatResult = formatFloatResult(
          numericValue,
          decimalPlaces: floatPrecisionNotifier.value,
        );
        history.add(
          HistoryEntry(
            expression: input,
            decimal: decimalResult,
            hex: hexResult,
            binary: binaryResult,
            floatValue: floatResult,
          ),
        );
      });
    } catch (e) {
      _containerResult = null;
      final displayError = e.toString();
      setState(() {
        hasCalculationError = true;
        decimalResult = displayError;
        _rawHexResult = "";
        binaryResult = "";
        floatResult = "";
      });
    }

    _focusNode.requestFocus();
  }

  // Panels of calculator buttons
  bool get _mobileKeypad => MediaQuery.sizeOf(context).width < 600;

  List<List<CalcButtonConfig>> get _generalPanel =>
      _generalPanelForWidth(MediaQuery.sizeOf(context).width - 32);

  List<List<CalcButtonConfig>> _generalPanelForWidth(double width) {
    if (width >= 480) {
      return [
        const [
          CalcButtonConfig(
            displayText: 'AC',
            tooltip: 'Clear the entire expression',
          ),
          CalcButtonConfig(
            displayText: '(',
            tooltip: 'Insert opening parenthesis',
          ),
          CalcButtonConfig(
            displayText: ')',
            tooltip: 'Insert closing parenthesis',
          ),
          CalcButtonConfig(displayText: '←', tooltip: 'Move cursor left'),
          CalcButtonConfig(displayText: '→', tooltip: 'Move cursor right'),
          CalcButtonConfig(
            displayText: 'DEL',
            tooltip: 'Delete the previous character',
          ),
        ],
        [
          const CalcButtonConfig(
            displayText: '0x',
            tooltip: 'Hexadecimal prefix',
          ),
          const CalcButtonConfig(displayText: '0b', tooltip: 'Binary prefix'),
          const CalcButtonConfig(displayText: '<<', tooltip: 'Shift left'),
          const CalcButtonConfig(displayText: '>>', tooltip: 'Shift right'),
          const CalcButtonConfig(displayText: '&', tooltip: 'Bitwise AND'),
          CalcButtonConfig(
            displayText: 'More ▾',
            tooltip: 'Numbers and operators',
            onPressed: (_) => _showOperatorPicker(),
          ),
        ],
        const [
          CalcButtonConfig(displayText: '7'),
          CalcButtonConfig(displayText: '8'),
          CalcButtonConfig(displayText: '9'),
          CalcButtonConfig(displayText: '/'),
          CalcButtonConfig(displayText: '|', tooltip: 'Bitwise OR'),
          CalcButtonConfig(displayText: '^', tooltip: 'Bitwise XOR'),
        ],
        const [
          CalcButtonConfig(displayText: '4'),
          CalcButtonConfig(displayText: '5'),
          CalcButtonConfig(displayText: '6'),
          CalcButtonConfig(displayText: '*'),
          CalcButtonConfig(displayText: '~', tooltip: 'Bitwise NOT'),
          CalcButtonConfig(displayText: '%', tooltip: 'Remainder'),
        ],
        const [
          CalcButtonConfig(displayText: '1'),
          CalcButtonConfig(displayText: '2'),
          CalcButtonConfig(displayText: '3'),
          CalcButtonConfig(displayText: '-'),
          CalcButtonConfig(displayText: '+'),
          CalcButtonConfig(displayText: '0o', tooltip: 'Octal prefix'),
        ],
        const [
          CalcButtonConfig(displayText: '0'),
          CalcButtonConfig(displayText: '.'),
          CalcButtonConfig(displayText: ',', tooltip: 'Separate arguments'),
          CalcButtonConfig(
            displayText: 'ANS',
            tooltip: 'Reuse the previous answer',
          ),
          CalcButtonConfig(
            displayText: 'SPACE',
            insertText: ' ',
            tooltip: 'Insert space',
          ),
          CalcButtonConfig(displayText: '=', tooltip: 'Calculate'),
        ],
      ];
    }

    return [
      const [
        CalcButtonConfig(
          displayText: 'AC',
          tooltip: 'Clear the entire expression',
        ),
        CalcButtonConfig(displayText: '←', tooltip: 'Move cursor left'),
        CalcButtonConfig(displayText: '→', tooltip: 'Move cursor right'),
        CalcButtonConfig(
          displayText: 'DEL',
          tooltip: 'Delete the previous character',
        ),
      ],
      [
        const CalcButtonConfig(
          displayText: '(',
          tooltip: 'Insert opening parenthesis',
        ),
        const CalcButtonConfig(
          displayText: ')',
          tooltip: 'Insert closing parenthesis',
        ),
        const CalcButtonConfig(displayText: '/', tooltip: 'Divide'),
        CalcButtonConfig(
          displayText: 'More ▾',
          tooltip: 'Numbers and operators',
          onPressed: (_) => _showOperatorPicker(),
        ),
      ],
      const [
        CalcButtonConfig(displayText: '7'),
        CalcButtonConfig(displayText: '8'),
        CalcButtonConfig(displayText: '9'),
        CalcButtonConfig(displayText: '*'),
      ],
      const [
        CalcButtonConfig(displayText: '4'),
        CalcButtonConfig(displayText: '5'),
        CalcButtonConfig(displayText: '6'),
        CalcButtonConfig(displayText: '-'),
      ],
      const [
        CalcButtonConfig(displayText: '1'),
        CalcButtonConfig(displayText: '2'),
        CalcButtonConfig(displayText: '3'),
        CalcButtonConfig(displayText: '+'),
      ],
      const [
        CalcButtonConfig(displayText: '0'),
        CalcButtonConfig(displayText: '.'),
        CalcButtonConfig(
          displayText: 'SPACE',
          insertText: ' ',
          tooltip: 'Insert space',
        ),
        CalcButtonConfig(displayText: '=', tooltip: 'Calculate'),
      ],
    ];
  }

  List<CalcButtonConfig> get _bitwiseOperators => const [
    CalcButtonConfig(displayText: '&', tooltip: 'Bitwise AND'),
    CalcButtonConfig(displayText: '|', tooltip: 'Bitwise OR'),
    CalcButtonConfig(displayText: '^', tooltip: 'Bitwise XOR'),
    CalcButtonConfig(displayText: '~', tooltip: 'Bitwise NOT'),
  ];

  List<CalcButtonConfig> get _logicalOperators => const [
    CalcButtonConfig(displayText: '&&', tooltip: 'Logical AND'),
    CalcButtonConfig(displayText: '||', tooltip: 'Logical OR'),
    CalcButtonConfig(displayText: '!', tooltip: 'Logical NOT'),
    CalcButtonConfig(displayText: '!=', tooltip: 'Not equal comparison'),
  ];

  List<CalcButtonConfig> get _hexDigitButtons => const [
    CalcButtonConfig(displayText: 'A', tooltip: 'Hexadecimal digit A'),
    CalcButtonConfig(displayText: 'B', tooltip: 'Hexadecimal digit B'),
    CalcButtonConfig(displayText: 'C', tooltip: 'Hexadecimal digit C'),
    CalcButtonConfig(displayText: 'D', tooltip: 'Hexadecimal digit D'),
    CalcButtonConfig(displayText: 'E', tooltip: 'Hexadecimal digit E'),
    CalcButtonConfig(displayText: 'F', tooltip: 'Hexadecimal digit F'),
  ];

  List<List<CalcButtonConfig>> get _defaultProgrammerPanel => [
    [..._hexDigitButtons.take(4)],
    [..._hexDigitButtons.skip(4), ..._bitwiseOperators.take(2)],
    [..._bitwiseOperators.skip(2), ..._logicalOperators.take(2)],
    [..._logicalOperators.skip(2)],
    [
      const CalcButtonConfig(displayText: '<<', tooltip: 'Shift left'),
      const CalcButtonConfig(displayText: '>>', tooltip: 'Shift right'),
      const CalcButtonConfig(displayText: 'MOD', tooltip: 'Modulo operation'),
      const CalcButtonConfig(displayText: '%', tooltip: 'Percentage operator'),
    ],
    [const CalcButtonConfig(displayText: 'POW', tooltip: 'Power function')],
    [
      const CalcButtonConfig(displayText: '0x', tooltip: 'Hexadecimal prefix'),
      const CalcButtonConfig(displayText: '0b', tooltip: 'Binary prefix'),
      const CalcButtonConfig(displayText: '0o', tooltip: 'Octal prefix'),
      const CalcButtonConfig(
        displayText: 'ANS',
        tooltip: 'Reuse the previous answer',
      ),
    ],
  ];

  List<CalcButtonConfig> get _prefixButtons => const [
    CalcButtonConfig(displayText: '0x', tooltip: 'Hexadecimal prefix'),
    CalcButtonConfig(displayText: '0b', tooltip: 'Binary prefix'),
    CalcButtonConfig(displayText: '0o', tooltip: 'Octal prefix'),
  ];

  List<List<CalcButtonConfig>> _compactProgrammerPanel() {
    return [
      [..._hexDigitButtons.take(4)],
      [..._hexDigitButtons.skip(4), ..._prefixButtons.take(2)],
      [
        ..._prefixButtons.skip(2),
        const CalcButtonConfig(
          displayText: 'ANS',
          tooltip: 'Reuse the previous answer',
        ),
        ..._bitwiseOperators.take(2),
      ],
      [..._bitwiseOperators.skip(2)],
      [
        const CalcButtonConfig(displayText: '<<', tooltip: 'Shift left'),
        const CalcButtonConfig(displayText: '>>', tooltip: 'Shift right'),
        const CalcButtonConfig(displayText: 'MOD', tooltip: 'Modulo operation'),
        const CalcButtonConfig(
          displayText: '%',
          tooltip: 'Percentage operator',
        ),
      ],
      [
        const CalcButtonConfig(displayText: 'POW', tooltip: 'Power function'),
        const CalcButtonConfig(displayText: '&&', tooltip: 'Logical AND'),
        const CalcButtonConfig(displayText: '||', tooltip: 'Logical OR'),
        const CalcButtonConfig(
          displayText: '!=',
          tooltip: 'Not equal comparison',
        ),
      ],
    ];
  }

  List<List<List<CalcButtonConfig>>> _buildButtonPanels(bool isCompactLayout) {
    final programmerPanel = isCompactLayout
        ? _compactProgrammerPanel()
        : _defaultProgrammerPanel;
    if (_mobileKeypad) {
      programmerPanel.insert(0, _generalPanel.first);
      programmerPanel.add(const [
        CalcButtonConfig(
          displayText: '(',
          tooltip: 'Insert opening parenthesis',
        ),
        CalcButtonConfig(
          displayText: ')',
          tooltip: 'Insert closing parenthesis',
        ),
        CalcButtonConfig(displayText: 'SPACE', insertText: ' '),
        CalcButtonConfig(displayText: '=', tooltip: 'Calculate'),
      ]);
    }
    return [_generalPanel, programmerPanel];
  }

  List<CalcButtonConfig> get _wideProgrammerButtons => [
    ..._hexDigitButtons,
    ..._prefixButtons,
    const CalcButtonConfig(
      displayText: 'ANS',
      tooltip: 'Reuse the previous answer',
    ),
    ..._bitwiseOperators,
    const CalcButtonConfig(displayText: '<<', tooltip: 'Shift left'),
    const CalcButtonConfig(displayText: '>>', tooltip: 'Shift right'),
    const CalcButtonConfig(displayText: 'MOD', tooltip: 'Modulo operation'),
    const CalcButtonConfig(displayText: '%', tooltip: 'Percentage operator'),
    const CalcButtonConfig(displayText: 'POW', tooltip: 'Power function'),
    ..._logicalOperators,
  ];

  // Page names for selector
  final List<String> pageNames = ['General', 'Programmer'];

  // Widget for page selector buttons
  Widget buildPageSelector() {
    final colors = Theme.of(context).colorScheme;
    final isDark = colors.brightness == Brightness.dark;
    final eink = usesEinkBehavior(context);
    final inactiveBackground = eink
        ? Colors.white
        : isDark
        ? const Color(0xFF3F3F3F)
        : const Color(0xFFE9E6EC);
    final inactiveForeground = eink
        ? Colors.black
        : isDark
        ? Colors.white
        : const Color(0xFF27232B);
    final inactiveBorder = eink ? Colors.black : const Color(0xFF8A858D);
    final selectorButtons = <Widget>[];
    for (var index = 0; index < pageNames.length; index++) {
      if (index > 0) {
        selectorButtons.add(const SizedBox(width: 8));
      }
      final isSelected = _currentPanel == index;
      selectorButtons.add(
        Expanded(
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: isSelected ? colors.primary : inactiveBackground,
              foregroundColor: isSelected
                  ? colors.onPrimary
                  : inactiveForeground,
              elevation: eink
                  ? 0
                  : isSelected
                  ? 2
                  : 0,
              minimumSize: const Size.fromHeight(40),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              textStyle: TextStyle(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                letterSpacing: 0.1,
              ),
              animationDuration: eink
                  ? Duration.zero
                  : const Duration(milliseconds: 110),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: isSelected ? colors.primary : inactiveBorder,
                ),
              ),
            ),
            onPressed: () {
              if (eink) {
                _pageController.jumpToPage(index);
                return;
              }
              _pageController.animateToPage(
                index,
                duration: Duration(milliseconds: 300),
                curve: Curves.ease,
              );
            },
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSelected) ...[
                    const Icon(Icons.check, size: 17),
                    const SizedBox(width: 6),
                  ],
                  Text(pageNames[index]),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: selectorButtons,
    );
  }

  Widget buildCalcButtonsPageView(
    List<List<List<CalcButtonConfig>>> buttonPanels,
    bool isCompactLayout,
  ) {
    return Column(
      children: [
        buildPageSelector(),
        const SizedBox(height: 8),
        Expanded(
          child: PageView.builder(
            physics: usesEinkBehavior(context)
                ? const NeverScrollableScrollPhysics()
                : null,
            controller: _pageController,
            itemCount: buttonPanels.length,
            onPageChanged: (index) {
              setState(() {
                _currentPanel = index;
              });
            },
            itemBuilder: (context, index) {
              return buildCalcButtonsPanel(
                buttonPanels[index],
                isCompactLayout: isCompactLayout,
                includeHexDigits: index == 0,
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        CalcPageIndicator(
          pageCount: buttonPanels.length,
          currentPage: _currentPanel,
          activeColor: usesEinkBehavior(context)
              ? Colors.black
              : widget.themeColor ?? Colors.red,
          inactiveColor: Colors.grey,
          onDotTapped: (index) {
            if (usesEinkBehavior(context)) {
              _pageController.jumpToPage(index);
              return;
            }
            _pageController.animateToPage(
              index,
              duration: Duration(milliseconds: 300),
              curve: Curves.ease,
            );
          },
        ),
      ],
    );
  }

  Widget buildWideCalcButtonsBoard() {
    final programmerButtons = _wideProgrammerButtons;

    return LayoutBuilder(
      builder: (context, constraints) {
        final useMergedBoard = constraints.maxWidth >= 720;
        if (!useMergedBoard) {
          return buildCalcButtonsPageView(_buildButtonPanels(false), false);
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 376,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'General',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  buildCalcButtonsPanel(
                    _generalPanelForWidth(376),
                    isCompactLayout: false,
                    desktopButtonWidth: 86,
                    desktopButtonHeight: 62,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Programmer',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: programmerButtons.map((button) {
                      final isLongLabel = button.displayText.length >= 3;
                      return buildStandaloneCalcButton(
                        button,
                        width: isLongLabel ? 72 : 56,
                        height: 44,
                        fontSize: isLongLabel ? 15 : 17,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _showOperatorPicker() {
    showOperatorPalette(
      context: context,
      groups: <String, List<CalcButtonConfig>>{
        'Numbers': [..._prefixButtons, ..._hexDigitButtons],
        'Bitwise': [
          ..._bitwiseOperators,
          const CalcButtonConfig(displayText: '<<', tooltip: 'Shift left'),
          const CalcButtonConfig(displayText: '>>', tooltip: 'Shift right'),
        ],
        'Logic': _logicalOperators,
        if (selectedBackendInfo().kind == BackendKind.clangConstexpr &&
            const [
              ClangExpressionLanguage.cpp,
              ClangExpressionLanguage.cpp17,
              ClangExpressionLanguage.cpp20,
              ClangExpressionLanguage.cpp23,
            ].contains(clangLanguage))
          'Endian': endianButtons,
        'Math': const [
          CalcButtonConfig(displayText: '%', tooltip: 'Remainder'),
          CalcButtonConfig(displayText: '(', tooltip: 'Opening parenthesis'),
          CalcButtonConfig(displayText: ')', tooltip: 'Closing parenthesis'),
          CalcButtonConfig(displayText: ',', tooltip: 'Separate arguments'),
        ],
      },
      onSelected: _handleCalcButtonTap,
    );
  }

  void _reuseHistoryEntry(HistoryEntry entry) {
    _controller.text = entry.expression;
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
    _focusNode.requestFocus();
  }

  void _openHistorySheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * 0.6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'History',
                          style: Theme.of(sheetContext).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close history',
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(sheetContext).pop(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: history.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'No calculations yet.\nSuccessful results will appear here during this session.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          itemCount: history.length,
                          itemBuilder: (context, index) {
                            final entry = history[history.length - 1 - index];
                            return ListTile(
                              onTap: () {
                                Navigator.of(sheetContext).pop();
                                _reuseHistoryEntry(entry);
                              },
                              title: Text(entry.expression),
                              subtitle: Text(
                                'Dec: ${entry.decimal}\nHex: ${entry.hex}\nBin: ${entry.binary}\nFloat: ${entry.floatValue}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.content_paste),
                                    tooltip: 'Reuse expression',
                                    onPressed: () {
                                      Navigator.of(sheetContext).pop();
                                      _reuseHistoryEntry(entry);
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.copy),
                                    tooltip: 'Copy decimal result',
                                    onPressed: () => Clipboard.setData(
                                      ClipboardData(text: entry.decimal),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                          separatorBuilder: (_, __) => const Divider(height: 8),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _moveCursor(int delta) {
    final text = _controller.text;
    final selection = _controller.selection;
    final baseOffset = selection.baseOffset == -1
        ? text.length
        : selection.baseOffset;
    final extentOffset = selection.extentOffset == -1
        ? text.length
        : selection.extentOffset;
    final newOffset = (delta.isNegative ? extentOffset : baseOffset) + delta;
    final clamped = newOffset.clamp(0, text.length);
    _controller.selection = TextSelection.collapsed(offset: clamped);
    _focusNode.requestFocus();
  }

  void _handleCalcButtonTap(CalcButtonConfig button) {
    final label = button.displayText;
    if (label == '←') {
      _moveCursor(-1);
      return;
    }
    if (label == '→') {
      _moveCursor(1);
      return;
    }
    if (label == '=' || label == 'ANS') {
      _calculateResult();
      return;
    }

    if (label == 'AC') {
      _controller.clear();
      _focusNode.requestFocus();
      return;
    }

    if (label == 'DEL' || label == '<' || label == '⌫') {
      if (_controller.text.isEmpty) {
        return;
      }
      final text = _controller.text;
      final selection = _controller.selection;
      if (selection.start != selection.end) {
        final newText = text.replaceRange(selection.start, selection.end, '');
        _controller.text = newText;
        _controller.selection = TextSelection.collapsed(
          offset: selection.start,
        );
      } else if (selection.start > 0) {
        final newText = text.replaceRange(
          selection.start - 1,
          selection.start,
          '',
        );
        _controller.text = newText;
        _controller.selection = TextSelection.collapsed(
          offset: selection.start - 1,
        );
      }
      _focusNode.requestFocus();
      return;
    }

    final value = _controller.value;
    final text = value.text;
    final selection = value.selection;
    final start = selection.isValid
        ? selection.start.clamp(0, text.length)
        : text.length;
    final end = selection.isValid
        ? selection.end.clamp(start, text.length)
        : start;
    final newText = text.replaceRange(start, end, button.insertText);
    final cursorOffset = start + button.insertText.length;

    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursorOffset),
      composing: TextRange.empty,
    );
    _focusNode.requestFocus();
  }

  Widget buildStandaloneCalcButton(
    CalcButtonConfig button, {
    required double width,
    required double height,
    required double fontSize,
  }) {
    return CalculatorButton(
      config: button,
      onPressed: _handleCalcButtonTap,
      width: width,
      height: height,
      fontSize: fontSize,
      showTooltip: _isDesktopPlatform,
    );
  }

  Widget buildCalcButtonsPanel(
    List<List<CalcButtonConfig>> rows, {
    required bool isCompactLayout,
    bool includeHexDigits = false,
    double desktopButtonWidth = 88,
    double desktopButtonHeight = 68,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Add a hex row only when all seven rows retain comfortable targets.
        final minimumRowHeight = 48 * MediaQuery.textScalerOf(context).scale(1);
        final showHexDigits =
            includeHexDigits &&
            constraints.maxWidth >= 480 &&
            constraints.maxHeight >= 7 * minimumRowHeight + 6 * 8;
        return CalculatorButtonGrid(
          rows: showHexDigits
              ? [rows.first, _hexDigitButtons, ...rows.skip(1)]
              : rows,
          onPressed: _handleCalcButtonTap,
          compact: isCompactLayout,
          desktop: _isDesktopPlatform,
          desktopButtonWidth: desktopButtonWidth,
          desktopButtonHeight: desktopButtonHeight,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final useWideLayout = _usesWideLayoutPlatform;
    final adaptiveResultsExpanded =
        useWideLayout || (size.width >= 360 && size.height >= 760);
    final bool useCompactResults = switch (_resultDisplayMode) {
      ResultDisplayMode.adaptive => !adaptiveResultsExpanded,
      ResultDisplayMode.expanded => false,
      ResultDisplayMode.compact => true,
    };
    final bool useCompactButtons =
        // The merged board needs 720px plus the body's horizontal padding.
        size.width < 752 || size.height < 720 || !useWideLayout;
    final availableHeight =
        size.height - MediaQuery.viewInsetsOf(context).bottom;
    // Reserve space for the results, window chrome, keypad selector and at
    // least one usable row of keys. Remaining keypad rows can scroll.
    final reservedHeight = showCalcButtons
        ? (useCompactResults ? 400.0 : 520.0)
        : 200.0;
    final maxEditorHeight = math
        .min(availableHeight * 0.6, availableHeight - reservedHeight)
        .clamp(80.0, 480.0)
        .toDouble();
    final defaultEditorHeight = (availableHeight * 0.22)
        .clamp(80.0, math.min(176.0, maxEditorHeight))
        .toDouble();
    final editorHeight = (_expressionEditorHeight ?? defaultEditorHeight).clamp(
      80.0,
      maxEditorHeight,
    );
    void resizeEditor(double delta) {
      setState(() {
        _expressionEditorHeight =
            ((_expressionEditorHeight ?? defaultEditorHeight).clamp(
                      80.0,
                      maxEditorHeight,
                    ) +
                    delta)
                .clamp(80.0, maxEditorHeight)
                .toDouble();
      });
    }

    final buttonPanels = _buildButtonPanels(useCompactButtons);
    final Widget inlineCalcButton = MergeSemantics(
      child: Semantics(
        label: 'Calculate',
        button: true,
        child: IconButton.filled(
          icon: const Icon(Icons.calculate_outlined),
          tooltip: 'Calculate',
          onPressed: _calculateResult,
        ),
      ),
    );

    final Widget inlineClearButton = MergeSemantics(
      child: Semantics(
        label: 'Clear expression',
        button: true,
        child: IconButton.filledTonal(
          icon: const Icon(Icons.delete_sweep_outlined),
          tooltip: 'Clear expression',
          onPressed: _clearResult,
        ),
      ),
    );

    final expressionBorderColor = isEinkTheme(context)
        ? Colors.black
        : _bracketAnalysis.hasError
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF8A858D)
        : const Color(0xFF6F6A73);
    final expressionBorder = OutlineInputBorder(
      borderSide: BorderSide(color: expressionBorderColor),
    );

    Widget buildResultsSection(bool compact) {
      if (_containerResult case final snapshot?) {
        return Card(
          child: ListTile(
            title: Text(snapshot.typeName),
            subtitle: Text(
              '${snapshot.totalCount} elements'
              '${snapshot.isTruncated ? ' · partial snapshot' : ''} · Explore contents',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showContainerExplorer(context, snapshot),
          ),
        );
      }
      return ResultsPanel(
        compact: compact,
        decimal: decimalResult,
        hexadecimal: hexResult,
        binary: binaryResult,
        floatingPoint: floatResult,
        hasCalculationError: hasCalculationError,
        selectedLabel: _selectedResultLabel,
        copiedLabel: _copiedResultLabel,
        onSelectedLabelChanged: (label) {
          setState(() => _selectedResultLabel = label);
        },
        onDisplayModeChanged: (mode) {
          setState(() => _resultDisplayMode = mode);
        },
        onCopy: (label, value) => unawaited(_copyResult(label, value)),
      );
    }

    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final headerActions = [
      WindowChromeActionButton(
        icon: Icons.share_outlined,
        tooltip: 'Share calculation',
        onPressed: () => showShareExpressionDialog(
          context: context,
          expression: _controller.text,
        ),
      ),
      WindowChromeActionButton(
        icon: Icons.history,
        tooltip: 'History',
        onPressed: _openHistorySheet,
      ),
      if (enableCustomVariables)
        WindowChromeActionButton(
          icon: Icons.add,
          tooltip: 'Add Variable',
          onPressed: _showAddVariableDialog,
        ),
      WindowChromeActionButton(
        icon: Icons.help_outline,
        tooltip: 'Help',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  HelpScreen(themeColor: widget.themeColor ?? Colors.red),
            ),
          );
        },
      ),
      WindowChromeActionButton(
        icon: Icons.code,
        tooltip: 'Source code (AGPLv3)',
        onPressed: () async {
          await launchUrl(_sourceCodeUri, mode: LaunchMode.externalApplication);
        },
      ),
      WindowChromeActionButton(
        icon: Icons.dialpad_outlined,
        tooltip: showCalcButtons
            ? 'Hide calculator buttons'
            : 'Show calculator buttons',
        onPressed: () {
          setState(() {
            showCalcButtons = !showCalcButtons;
          });
        },
      ),
      WindowChromeActionButton(
        icon: isDarkTheme
            ? Icons.light_mode_outlined
            : Icons.dark_mode_outlined,
        tooltip: isDarkTheme ? 'Switch to light theme' : 'Switch to dark theme',
        onPressed: () async {
          final mode = isDarkTheme ? AppTheme.light : AppTheme.dark;
          themeModeNotifier.value = mode;
          await saveThemeMode(mode);
        },
      ),
      WindowChromeActionButton(
        icon: Icons.settings,
        tooltip: 'Settings',
        onPressed: () async {
          final result = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => SettingsDialog(
              themeColor: widget.themeColor ?? Colors.red,
              showCalcButtonsDesktop: showCalcButtons,
            ),
          );
          if (result is bool) {
            setState(() {
              showCalcButtons = result;
            });
          }
        },
      ),
    ];

    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter, control: true):
            _CalculateExpressionIntent(),
        SingleActivator(LogicalKeyboardKey.enter, meta: true):
            _CalculateExpressionIntent(),
        SingleActivator(LogicalKeyboardKey.keyE, control: true):
            _FocusExpressionIntent(),
      },
      child: Actions(
        actions: {
          _CalculateExpressionIntent:
              CallbackAction<_CalculateExpressionIntent>(
                onInvoke: (_) {
                  _calculateResult();
                  return null;
                },
              ),
          _FocusExpressionIntent: CallbackAction<_FocusExpressionIntent>(
            onInvoke: (_) {
              _focusExpression();
              return null;
            },
          ),
        },
        child: FramelessWindowResizeFrame(
          child: Scaffold(
            appBar: WindowChromeHeader(
              title: const AppTitleLabel(),
              backgroundColor: Theme.of(context).colorScheme.surface,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              actions: [
                MenuAnchor(
                  menuChildren: headerActions.map((action) {
                    final button = action;
                    return MenuItemButton(
                      leadingIcon: Icon(button.icon),
                      onPressed: button.onPressed,
                      child: Text(button.tooltip),
                    );
                  }).toList(),
                  builder: (context, controller, child) =>
                      WindowChromeActionButton(
                        icon: Icons.menu,
                        tooltip: 'Application menu',
                        onPressed: () => controller.isOpen
                            ? controller.close()
                            : controller.open(),
                      ),
                ),
              ],
            ),
            body: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        SizedBox(
                          height: _expressionExpanded ? editorHeight : 56,
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _controller,
                                  focusNode: _focusNode,
                                  decoration: InputDecoration(
                                    border: expressionBorder,
                                    enabledBorder: expressionBorder,
                                    focusedBorder: expressionBorder,
                                    floatingLabelStyle: TextStyle(
                                      color: expressionBorderColor,
                                    ),
                                    labelText: "Enter Expression",
                                    suffixIcon: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (_bracketAnalysis.hasError ||
                                            _bracketAnalysis.hasActivePair)
                                          Tooltip(
                                            message:
                                                _bracketAnalysis.statusMessage,
                                            child: Icon(
                                              _bracketAnalysis.hasError
                                                  ? Icons.error_outline
                                                  : Icons.link,
                                              color: expressionBorderColor,
                                            ),
                                          ),
                                        if (_expressionExpanded)
                                          MergeSemantics(
                                            child: Semantics(
                                              label: 'Insert newline',
                                              button: true,
                                              child: IconButton(
                                                tooltip: 'Insert newline',
                                                icon: const Icon(
                                                  Icons.keyboard_return,
                                                ),
                                                onPressed: () =>
                                                    _handleCalcButtonTap(
                                                      const CalcButtonConfig(
                                                        displayText: 'Newline',
                                                        insertText: '\n',
                                                      ),
                                                    ),
                                              ),
                                            ),
                                          ),
                                        MergeSemantics(
                                          child: Semantics(
                                            label: _expressionExpanded
                                                ? 'Collapse expression editor'
                                                : 'Expand expression editor',
                                            button: true,
                                            child: IconButton(
                                              tooltip: _expressionExpanded
                                                  ? 'Collapse expression editor'
                                                  : 'Expand expression editor',
                                              icon: Icon(
                                                _expressionExpanded
                                                    ? Icons.unfold_less
                                                    : Icons.unfold_more,
                                              ),
                                              onPressed: () {
                                                setState(() {
                                                  _expressionExpanded =
                                                      !_expressionExpanded;
                                                });
                                                _focusNode.requestFocus();
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  style: TextStyle(fontSize: 20),
                                  maxLines: _expressionExpanded ? null : 1,
                                  expands: _expressionExpanded,
                                  textAlignVertical: _expressionExpanded
                                      ? TextAlignVertical.top
                                      : TextAlignVertical.center,
                                  textInputAction: _expressionExpanded
                                      ? TextInputAction.newline
                                      : TextInputAction.done,
                                  keyboardType: useSystemKeyboardNotifier.value
                                      ? (_expressionExpanded
                                            ? TextInputType.multiline
                                            : TextInputType.text)
                                      : TextInputType.none,
                                  showCursor: true,
                                  selectAllOnFocus: false,
                                  enableInteractiveSelection: true,
                                  onTap: () {
                                    if (isAndroid) {
                                      // Keep focus so user can use app keypad
                                      _focusNode.requestFocus();
                                    }
                                  },
                                  onSubmitted: _expressionExpanded
                                      ? null
                                      : (_) => _calculateResult(),
                                ),
                              ),
                              if (!_mobileKeypad || !showCalcButtons) ...[
                                inlineCalcButton,
                                inlineClearButton,
                                MergeSemantics(
                                  child: Semantics(
                                    label: 'Move cursor left',
                                    button: true,
                                    child: IconButton.filledTonal(
                                      icon: const Icon(Icons.arrow_left),
                                      tooltip: 'Move cursor left',
                                      onPressed: () => _moveCursor(-1),
                                    ),
                                  ),
                                ),
                                MergeSemantics(
                                  child: Semantics(
                                    label: 'Move cursor right',
                                    button: true,
                                    child: IconButton.filledTonal(
                                      icon: const Icon(Icons.arrow_right),
                                      tooltip: 'Move cursor right',
                                      onPressed: () => _moveCursor(1),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (_expressionExpanded)
                          TextFieldTapRegion(
                            child: Semantics(
                              label: 'Expression editor height',
                              value: '${editorHeight.round()} pixels',
                              increasedValue: editorHeight < maxEditorHeight
                                  ? '${math.min(editorHeight + 24, maxEditorHeight).round()} pixels'
                                  : null,
                              decreasedValue: editorHeight > 80
                                  ? '${math.max(editorHeight - 24, 80).round()} pixels'
                                  : null,
                              onIncrease: editorHeight < maxEditorHeight
                                  ? () => resizeEditor(24)
                                  : null,
                              onDecrease: editorHeight > 80
                                  ? () => resizeEditor(-24)
                                  : null,
                              child: Tooltip(
                                message: 'Drag to resize expression editor',
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.resizeUpDown,
                                  child: GestureDetector(
                                    key: const ValueKey(
                                      'expression-resize-handle',
                                    ),
                                    behavior: HitTestBehavior.opaque,
                                    onVerticalDragUpdate: (details) =>
                                        resizeEditor(details.delta.dy),
                                    child: SizedBox(
                                      height: 24,
                                      width: double.infinity,
                                      child: Center(
                                        child: Container(
                                          width: 36,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .outlineVariant,
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                        else
                          const SizedBox(height: 16),
                        if (showCalcButtons)
                          Align(
                            alignment: Alignment.topLeft,
                            child: buildResultsSection(useCompactResults),
                          )
                        else
                          Flexible(
                            fit: FlexFit.tight,
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: buildResultsSection(useCompactResults),
                            ),
                          ),
                        const SizedBox(height: 10),
                        if (showCalcButtons) ...[
                          Expanded(
                            child: useCompactButtons
                                ? buildCalcButtonsPageView(
                                    buttonPanels,
                                    useCompactButtons,
                                  )
                                : SingleChildScrollView(
                                    child: buildWideCalcButtonsBoard(),
                                  ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
