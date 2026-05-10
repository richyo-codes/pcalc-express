import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rnd_pcalc_ng/app_brand.dart';
import 'package:rnd_pcalc_ng/platform_capabilities.dart';
import 'package:rnd_pcalc_ng/window_drag_controller.dart';
import 'package:rnd_pcalc_ng/settings_page.dart';

import 'package:tinyexpr_plusplus_ffi/tinyexpr_plusplus_ffi.dart';
import 'package:rnd_pcalc_ng/help_screen.dart';
import 'package:rnd_pcalc_ng/format_helper.dart';

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

class CalcPageIndicator extends StatelessWidget {
  final int pageCount;
  final int currentPage;
  final ValueChanged<int>? onDotTapped;
  final Color activeColor;
  final Color inactiveColor;

  const CalcPageIndicator({
    Key? key,
    required this.pageCount,
    required this.currentPage,
    this.onDotTapped,
    this.activeColor = Colors.red,
    this.inactiveColor = Colors.grey,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        pageCount,
        (index) => GestureDetector(
          onTap: onDotTapped != null ? () => onDotTapped!(index) : null,
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 4),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: currentPage == index ? activeColor : inactiveColor,
            ),
          ),
        ),
      ),
    );
  }
}

class CalcButtonConfig {
  final String displayText;
  final String insertText;
  final String? tooltip;
  final void Function(BuildContext context)? onPressed;

  const CalcButtonConfig({
    required this.displayText,
    String? insertText,
    this.tooltip,
    this.onPressed,
  }) : insertText = insertText ?? displayText;
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

class ProgrammerCalculator extends StatefulWidget {
  const ProgrammerCalculator({super.key});

  @override
  State<ProgrammerCalculator> createState() => _ProgrammerCalculatorState();
}

class _ProgrammerCalculatorState extends State<ProgrammerCalculator> {
  MaterialColor _themeColor = Colors.red;

  @override
  void initState() {
    super.initState();
    // Set dark red as default
    _themeColor = Colors.red;
    if (Colors.red[900] != null) {
      _themeColor = MaterialColor(Colors.red[900]!.value, <int, Color>{
        50: Colors.red[50]!,
        100: Colors.red[100]!,
        200: Colors.red[200]!,
        300: Colors.red[300]!,
        400: Colors.red[400]!,
        500: Colors.red[500]!,
        600: Colors.red[600]!,
        700: Colors.red[700]!,
        800: Colors.red[800]!,
        900: Colors.red[900]!,
      });
    }
  }

  void _updateThemeColor(MaterialColor color) {
    setState(() {
      _themeColor = color;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        primarySwatch: _themeColor,
        colorScheme: ColorScheme.fromSwatch(primarySwatch: _themeColor),
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
        ),
      ),
      darkTheme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: _themeColor,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey.shade600),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey.shade600),
          ),
        ),
      ),
      home: CalculatorScreen(
        onThemeColorChanged: _updateThemeColor,
        themeColor: _themeColor,
      ),
      scrollBehavior: AppScrollBehavior(),
    );
  }
}

class CalculatorScreen extends StatefulWidget {
  final bool? showCalcButtonsDesktop;
  final void Function(MaterialColor)? onThemeColorChanged;
  final MaterialColor? themeColor;
  final int initialPanel;
  const CalculatorScreen({
    super.key,
    this.showCalcButtonsDesktop,
    this.onThemeColorChanged,
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

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode(); // Added focus node
  String decimalResult = "";
  String hexResult = "";
  String binaryResult = "";
  String floatResult = "";
  bool hasCalculationError = false;
  List<HistoryEntry> history = [];
  bool showCalcButtons = false;
  String _selectedResultLabel = "Dec";

  late int _currentPanel;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();

    _currentPanel = widget.initialPanel;
    _pageController = PageController(initialPage: widget.initialPanel);

    // Determine if calculator buttons should be shown
    if (isAndroid) {
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
    _controller.dispose();
    _focusNode.dispose(); // Dispose of the focus node
    _pageController.dispose();
    super.dispose();
  }

  void _clearResult() {
    _controller.clear();

    _focusNode.requestFocus();
  }

  void _calculateResult() {
    String input = _controller.text;

    //final inputProcessed = preprocessExpression(input);

    try {
      final result = evaluateExpression(input);

      if (!result.isNaN) {
        double floatValue = result.toDouble();
        int intValue = result.toInt();

        setState(() {
          hasCalculationError = false;
          decimalResult = intValue.toString();
          hexResult = formatHexResult(intValue);
          binaryResult = formatBinaryResult(intValue);
          floatResult = floatValue.toString();
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
      } else {
        final errMsg = getLastErrorMessage().trim();
        final displayError = errMsg.isEmpty
            ? "Expression evaluated to NaN"
            : errMsg;

        setState(() {
          hasCalculationError = true;
          decimalResult = displayError;
          hexResult = "";
          binaryResult = "";
          floatResult = "";
        });
      }
    } catch (e) {
      final displayError = e.toString();
      setState(() {
        hasCalculationError = true;
        decimalResult = displayError;
        hexResult = "";
        binaryResult = "";
        floatResult = "";
      });
    }

    _focusNode.requestFocus();
  }

  // Panels of calculator buttons
  List<List<CalcButtonConfig>> get _generalPanel => [
    [
      const CalcButtonConfig(
        displayText: 'AC',
        tooltip: 'Clear the entire expression',
      ),
      const CalcButtonConfig(
        displayText: 'DEL',
        tooltip: 'Delete the previous character',
      ),
      const CalcButtonConfig(
        displayText: '(',
        tooltip: 'Insert opening parenthesis',
      ),
      const CalcButtonConfig(
        displayText: ')',
        tooltip: 'Insert closing parenthesis',
      ),
    ],
    [
      const CalcButtonConfig(displayText: '7'),
      const CalcButtonConfig(displayText: '8'),
      const CalcButtonConfig(displayText: '9'),
      const CalcButtonConfig(displayText: '/'),
    ],
    [
      const CalcButtonConfig(displayText: '4'),
      const CalcButtonConfig(displayText: '5'),
      const CalcButtonConfig(displayText: '6'),
      const CalcButtonConfig(displayText: '*'),
    ],
    [
      const CalcButtonConfig(displayText: '1'),
      const CalcButtonConfig(displayText: '2'),
      const CalcButtonConfig(displayText: '3'),
      const CalcButtonConfig(displayText: '-'),
    ],
    [
      const CalcButtonConfig(displayText: '0'),
      const CalcButtonConfig(displayText: '.'),
      const CalcButtonConfig(displayText: '='),
      const CalcButtonConfig(displayText: '+'),
    ],
  ];

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

  List<List<CalcButtonConfig>> get _defaultProgrammerPanel => [
    [..._bitwiseOperators],
    [..._logicalOperators],
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
      [
        ..._prefixButtons,
        const CalcButtonConfig(
          displayText: 'ANS',
          tooltip: 'Reuse the previous answer',
        ),
      ],
      [..._bitwiseOperators],
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
    return [_generalPanel, programmerPanel];
  }

  List<CalcButtonConfig> get _wideProgrammerButtons => [
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
    final selectorButtons = <Widget>[];
    for (var index = 0; index < pageNames.length; index++) {
      if (index > 0) {
        selectorButtons.add(const SizedBox(width: 8));
      }
      final isSelected = _currentPanel == index;
      selectorButtons.add(
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isSelected
                  ? (widget.themeColor ?? Colors.red)
                  : Colors.grey[300],
              foregroundColor: isSelected ? Colors.white : Colors.black,
              elevation: isSelected ? 3 : 0,
            ),
            onPressed: () {
              _pageController.animateToPage(
                index,
                duration: Duration(milliseconds: 300),
                curve: Curves.ease,
              );
            },
            child: Text(pageNames[index]),
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
    final int maxRowCount = buttonPanels.fold<int>(
      0,
      (maxRows, panel) => math.max(maxRows, panel.length),
    );
    final viewportHeight = MediaQuery.of(context).size.height;
    final double panelHeight = isCompactLayout
        ? (viewportHeight < 780 ? 330 : 420)
        : maxRowCount * 68.0 + math.max(0, maxRowCount - 1) * 8.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        buildPageSelector(),
        const SizedBox(height: 8),
        SizedBox(
          height: panelHeight,
          child: PageView.builder(
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
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        CalcPageIndicator(
          pageCount: buttonPanels.length,
          currentPage: _currentPanel,
          activeColor: widget.themeColor ?? Colors.red,
          inactiveColor: Colors.grey,
          onDotTapped: (index) {
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
                    _generalPanel,
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

  void _showOperatorPicker({
    required String title,
    required List<CalcButtonConfig> options,
  }) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: options.map((option) {
                    return ElevatedButton(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _handleCalcButtonTap(option);
                      },
                      child: Text(option.displayText),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
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
    if (history.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No history yet')));
      return;
    }
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: 320,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    "Dec: ${entry.decimal} | Hex: ${entry.hex} | Bin: ${entry.binary}",
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: entry.decimal));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Decimal copied')),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
              separatorBuilder: (_, __) => const Divider(height: 8),
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

    if (label == '>') {
      final selection = _controller.selection;
      if (selection.start < _controller.text.length) {
        _controller.selection = TextSelection.collapsed(
          offset: selection.start + 1,
        );
      }
      _focusNode.requestFocus();
      return;
    }

    final text = _controller.text;
    final selection = _controller.selection;
    final newText = text.replaceRange(
      selection.start,
      selection.end,
      button.insertText,
    );
    _controller.text = newText;
    _controller.selection = TextSelection.collapsed(
      offset: selection.start + button.insertText.length,
    );
    _focusNode.requestFocus();
  }

  Widget buildStandaloneCalcButton(
    CalcButtonConfig button, {
    required double width,
    required double height,
    required double fontSize,
  }) {
    final themeColor = widget.themeColor ?? Colors.red;
    final contrastColor =
        ThemeData.estimateBrightnessForColor(themeColor) == Brightness.dark
        ? Colors.white
        : Colors.black;

    Widget calcButton = ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: themeColor,
        foregroundColor: contrastColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        elevation: 2,
      ),
      onPressed: () {
        if (button.onPressed != null) {
          button.onPressed!(context);
        } else {
          _handleCalcButtonTap(button);
        }
      },
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          button.displayText,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: contrastColor,
          ),
        ),
      ),
    );

    if (_isDesktopPlatform && (button.tooltip?.isNotEmpty ?? false)) {
      calcButton = Tooltip(message: button.tooltip!, child: calcButton);
    }

    return SizedBox(width: width, height: height, child: calcButton);
  }

  Widget buildCalcButtonsPanel(
    List<List<CalcButtonConfig>> rows, {
    required bool isCompactLayout,
    double desktopButtonWidth = 88,
    double desktopButtonHeight = 68,
  }) {
    final themeColor = widget.themeColor ?? Colors.red;
    final contrastColor =
        ThemeData.estimateBrightnessForColor(themeColor) == Brightness.dark
        ? Colors.white
        : Colors.black;

    final columnCount = rows.fold<int>(
      0,
      (max, row) => math.max(max, row.length),
    );
    final rowCount = rows.length;
    final effectiveColumnCount = columnCount == 0 ? 1 : columnCount;
    final effectiveRowCount = rowCount == 0 ? 1 : rowCount;

    final paddedRows = rows
        .map<List<CalcButtonConfig?>>(
          (row) => row.length == columnCount
              ? row.cast<CalcButtonConfig?>()
              : [
                  ...row,
                  ...List<CalcButtonConfig?>.filled(
                    columnCount - row.length,
                    null,
                  ),
                ],
        )
        .toList();

    final flattenedButtons = paddedRows.expand((row) => row).toList();
    final isDesktopPlatform = _isDesktopPlatform;

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : columnCount * desktopButtonWidth;
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : rowCount * desktopButtonHeight;

        final usableWidth = width - spacing * (effectiveColumnCount - 1);
        final usableHeight = height - spacing * (effectiveRowCount - 1);
        final cellWidth = usableWidth / effectiveColumnCount;
        final cellHeight = usableHeight / effectiveRowCount;
        final aspectRatio = cellHeight > 0 ? cellWidth / cellHeight : 1.1;
        final double baseFontSize = cellHeight > 0
            ? math.max(14.0, math.min(cellHeight * 0.35, 22.0))
            : 18.0;

        Widget buildButtonCell(
          CalcButtonConfig? button, {
          required double width,
          required double height,
          required double fontSize,
        }) {
          if (button == null) {
            return SizedBox(width: width, height: height);
          }

          Widget calcButton = ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: themeColor,
              foregroundColor: contrastColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              elevation: 2,
            ),
            onPressed: () {
              if (button.onPressed != null) {
                button.onPressed!(context);
              } else {
                _handleCalcButtonTap(button);
              }
            },
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                button.displayText,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  color: contrastColor,
                ),
              ),
            ),
          );

          if (isDesktopPlatform && (button.tooltip?.isNotEmpty ?? false)) {
            calcButton = Tooltip(message: button.tooltip!, child: calcButton);
          }

          return SizedBox(width: width, height: height, child: calcButton);
        }

        if (isDesktopPlatform && !isCompactLayout) {
          final desktopPanelWidth =
              effectiveColumnCount * desktopButtonWidth +
              math.max(0, effectiveColumnCount - 1) * spacing;

          return Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: desktopPanelWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(paddedRows.length, (rowIndex) {
                  final row = paddedRows[rowIndex];
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: rowIndex == paddedRows.length - 1 ? 0 : spacing,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (int index = 0; index < row.length; index++) ...[
                          if (index > 0) const SizedBox(width: spacing),
                          buildButtonCell(
                            row[index],
                            width: desktopButtonWidth,
                            height: desktopButtonHeight,
                            fontSize: 20,
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ),
            ),
          );
        }

        return GridView.builder(
          itemCount: flattenedButtons.length,
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: effectiveColumnCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: aspectRatio,
          ),
          itemBuilder: (context, index) {
            return buildButtonCell(
              flattenedButtons[index],
              width: cellWidth,
              height: cellHeight,
              fontSize: baseFontSize,
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final useWideLayout = _usesWideLayoutPlatform;
    final bool useCompactResults = size.width < 520 || !useWideLayout;
    final bool useCompactButtons =
        size.width < 520 || size.height < 720 || !useWideLayout;
    final buttonPanels = _buildButtonPanels(useCompactButtons);

    // Small "C" button to the right of the text input
    final Widget inlineCalcButton = IconButton(
      icon: Text(
        "C",
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
      tooltip: "Calculate",
      onPressed: _calculateResult,
    );

    final Widget inlineClearButton = IconButton(
      icon: Text(
        "🗑️",
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
      tooltip: "Clear",
      onPressed: _clearResult,
    );

    Widget buildResultField(
      String label,
      String value, {
      bool compact = false,
      bool isError = false,
    }) {
      final colorScheme = Theme.of(context).colorScheme;
      final border = OutlineInputBorder(
        borderSide: BorderSide(
          color: isError ? colorScheme.error : Theme.of(context).dividerColor,
        ),
      );

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          children: [
            SizedBox(
              width: compact ? 90 : 110,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: compact ? 14 : 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: InputDecorator(
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    vertical: compact ? 6 : 8,
                    horizontal: compact ? 6 : 8,
                  ),
                  border: border,
                  enabledBorder: border,
                ),
                child: SelectableText(
                  value,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: compact ? 14 : 16,
                    color: isError ? colorScheme.error : null,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.copy, size: 20),
              tooltip: 'Copy',
              onPressed: value.isNotEmpty && value != 'Error'
                  ? () {
                      Clipboard.setData(ClipboardData(text: value));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Copied to clipboard')),
                      );
                    }
                  : null,
            ),
          ],
        ),
      );
    }

    Widget buildResultsSection(bool isCompactLayout) {
      final results = <String, String>{
        "Dec": decimalResult,
        "Hex": hexResult,
        "Bin": binaryResult,
        "Float": floatResult,
      };

      if (!isCompactLayout) {
        return Column(
          children: [
            buildResultField(
              "Decimal",
              decimalResult,
              isError: hasCalculationError,
            ),
            buildResultField("Hexadecimal", hexResult),
            buildResultField("Binary", binaryResult),
            buildResultField("Floating Point", floatResult),
          ],
        );
      }

      final selectedValue = results[_selectedResultLabel] ?? "";

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: results.keys.map((label) {
              return ChoiceChip(
                label: Text(label),
                labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                selected: _selectedResultLabel == label,
                onSelected: (_) {
                  setState(() {
                    _selectedResultLabel = label;
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 4),
          buildResultField(
            _selectedResultLabel,
            selectedValue,
            compact: true,
            isError: hasCalculationError && _selectedResultLabel == "Dec",
          ),
        ],
      );
    }

    final headerActions = [
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
        icon: Icons.settings,
        tooltip: 'Settings',
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SettingsPage(
                themeColor: widget.themeColor ?? Colors.red,
                //onThemeColorChanged: widget.onThemeColorChanged,
                //currentThemeColor: widget.themeColor ?? Colors.red,
              ),
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

    return FramelessWindowResizeFrame(
      child: Scaffold(
        appBar: WindowChromeHeader(
          title: const Text(
            appTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          backgroundColor: widget.themeColor ?? Colors.red,
          foregroundColor:
              ThemeData.estimateBrightnessForColor(
                    widget.themeColor ?? Colors.red,
                  ) ==
                  Brightness.dark
              ? Colors.white
              : Colors.black,
          actions: headerActions,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Expanded(
                child: Column(
                  children: [
                    SizedBox(
                      height: 56, // Give the row a fixed height
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              focusNode: _focusNode,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: "Enter Expression",
                              ),
                              style: TextStyle(fontSize: 20),
                              readOnly:
                                  isAndroid, // Disable keyboard on Android
                              showCursor: true,
                              enableInteractiveSelection: true,
                              onTap: () {
                                if (isAndroid) {
                                  // Keep focus so user can use app keypad
                                  _focusNode.requestFocus();
                                }
                              },
                              onSubmitted: (_) => _calculateResult(),
                            ),
                          ),
                          inlineCalcButton, //
                          inlineClearButton,
                          if (isAndroid || isIOS) ...[
                            IconButton(
                              icon: const Icon(Icons.arrow_left),
                              tooltip: 'Move cursor left',
                              onPressed: () => _moveCursor(-1),
                            ),
                            IconButton(
                              icon: const Icon(Icons.arrow_right),
                              tooltip: 'Move cursor right',
                              onPressed: () => _moveCursor(1),
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(height: 16),
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
                      if (useCompactButtons)
                        buildCalcButtonsPageView(
                          buttonPanels,
                          useCompactButtons,
                        )
                      else
                        buildWideCalcButtonsBoard(),
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
    );
  }
}
