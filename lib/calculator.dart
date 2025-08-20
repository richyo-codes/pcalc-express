import 'dart:io';

import 'package:expressions/expressions.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:rnd_pcalc_ng/calculator.dart';
import 'package:rnd_pcalc_ng/settings_page.dart';

import 'package:rnd_pcalc_ng/tinyexprpp_fii.dart';
import 'package:ffi/ffi.dart' as ffi;
import 'package:rnd_pcalc_ng/help_screen.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
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
  const CalculatorScreen({
    super.key,
    this.showCalcButtonsDesktop,
    this.onThemeColorChanged,
    this.themeColor,
  });

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

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode(); // Added focus node
  String decimalResult = "";
  String hexResult = "";
  String binaryResult = "";
  String floatResult = "";
  List<String> history = [];
  bool showHistory = false;
  bool showCalcButtons = false;

  int _currentPanel = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();

    // Determine if calculator buttons should be shown
    if (Platform.isAndroid) {
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
          decimalResult = intValue.toString();
          hexResult = formatHexResult(intValue);
          binaryResult = formatBinaryResult(intValue);
          floatResult = floatValue.toString();
          history.add(
            "$input = $decimalResult (Dec) | $floatResult (Float) | $hexResult (Hex) | $binaryResult (Bin)",
          );
        });
      } else {
        final errMsg = getLastErrorMessage();

        setState(() {
          decimalResult = errMsg;
          hexResult = "";
          binaryResult = "";
          floatResult = "";
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $errMsg')));

        setState(() {
          decimalResult = "Error";
          hexResult = "Error";
          binaryResult = "Error";
          floatResult = "Error";
        });
      }
    } catch (e) {
      setState(() {
        decimalResult = "Error";
        hexResult = "Error";
        binaryResult = "Error";
        floatResult = "Error";
      });
    }

    _focusNode.requestFocus();
  }

  // Panels of calculator buttons
  final List<List<List<String>>> buttonPanels = [
    // General Buttons Page
    [
      ['(', ')', 'AC', 'DEL'],
      ['7', '8', '9', '/'],
      ['4', '5', '6', '*'],
      ['1', '2', '3', '-'],
      ['0', '.', '=', '+'],
    ],
    // Programmer Buttons Page
    [
      ['AND', 'OR', 'XOR', 'NOT'],
      ['<<', '>>', 'MOD', '%'],
      ['BIN', 'OCT', 'DEC', 'HEX'],
      ['0x', '0b', '0o', 'ANS'],
      ['back', '', '', ''],
    ],
  ];

  // Page names for selector
  final List<String> pageNames = ['General', 'Programmer'];

  // Widget for page selector buttons
  Widget buildPageSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(pageNames.length, (index) {
        final isSelected = _currentPanel == index;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isSelected
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
        );
      }),
    );
  }

  Widget buildCalcButtonsPageView() {
    return Column(
      children: [
        buildPageSelector(),
        SizedBox(height: 8),
        SizedBox(
          height: 420,
          child: PageView.builder(
            controller: _pageController,
            itemCount: buttonPanels.length,
            onPageChanged: (index) {
              setState(() {
                _currentPanel = index;
              });
            },
            itemBuilder: (context, index) {
              return buildCalcButtonsPanel(buttonPanels[index]);
            },
          ),
        ),
        SizedBox(height: 8),
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

  Widget buildCalcButtonsPanel(List<List<String>> rows) {
    final themeColor = widget.themeColor ?? Colors.red;
    final contrastColor =
        ThemeData.estimateBrightnessForColor(themeColor) == Brightness.dark
            ? Colors.white
            : Colors.black;

    int maxCols = rows.map((row) => row.length).reduce((a, b) => a > b ? a : b);
    double spacing = 3;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Constrain button size to be more reasonable
        // Minimum button size of 40, maximum of 80
        double buttonSize =
            (constraints.maxWidth - (maxCols + 1) * spacing) / maxCols;
        buttonSize = buttonSize.clamp(40.0, 80.0);

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children:
              rows.map((row) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children:
                      row.map((label) {
                        if (label.isEmpty) {
                          return SizedBox(
                            width: buttonSize + spacing,
                            height: buttonSize + spacing,
                          );
                        }
                        return Padding(
                          padding: EdgeInsets.all(spacing / 2),
                          child: SizedBox(
                            width: buttonSize,
                            height: buttonSize,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: themeColor,
                                foregroundColor: contrastColor,
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 2,
                              ),
                              onPressed: () {
                                setState(() {
                                  if (label == 'More') {
                                    _pageController.animateToPage(
                                      1,
                                      duration: Duration(milliseconds: 300),
                                      curve: Curves.ease,
                                    );
                                  } else if (label == 'back') {
                                    _pageController.animateToPage(
                                      0,
                                      duration: Duration(milliseconds: 300),
                                      curve: Curves.ease,
                                    );
                                  } else if (label == '=' || label == 'ANS') {
                                    _calculateResult();
                                  } else if (label == 'AC') {
                                    _controller.clear();
                                  } else if (label == 'DEL' ||
                                      label == '<' ||
                                      label == '⌫') {
                                    if (_controller.text.isNotEmpty) {
                                      final text = _controller.text;
                                      final selection = _controller.selection;
                                      if (selection.start != selection.end) {
                                        final newText = text.replaceRange(
                                          selection.start,
                                          selection.end,
                                          '',
                                        );
                                        _controller.text = newText;
                                        _controller.selection =
                                            TextSelection.collapsed(
                                              offset: selection.start,
                                            );
                                      } else if (selection.start > 0) {
                                        final newText = text.replaceRange(
                                          selection.start - 1,
                                          selection.start,
                                          '',
                                        );
                                        _controller.text = newText;
                                        _controller.selection =
                                            TextSelection.collapsed(
                                              offset: selection.start - 1,
                                            );
                                      }
                                    }
                                  } else if (label == '>') {
                                    final selection = _controller.selection;
                                    if (selection.start <
                                        _controller.text.length) {
                                      _controller
                                          .selection = TextSelection.collapsed(
                                        offset: selection.start + 1,
                                      );
                                    }
                                  } else if (label == '^') {
                                    // Insert ^ at current cursor position
                                    final text = _controller.text;
                                    final selection = _controller.selection;
                                    final newText = text.replaceRange(
                                      selection.start,
                                      selection.end,
                                      '^',
                                    );
                                    _controller.text = newText;
                                    // Set cursor position after the inserted text
                                    _controller
                                        .selection = TextSelection.collapsed(
                                      offset: selection.start + 1,
                                    );
                                  } else {
                                    // Insert text at current cursor position
                                    final text = _controller.text;
                                    final selection = _controller.selection;
                                    final newText = text.replaceRange(
                                      selection.start,
                                      selection.end,
                                      label,
                                    );
                                    _controller.text = newText;
                                    // Set cursor position after the inserted text
                                    _controller
                                        .selection = TextSelection.collapsed(
                                      offset: selection.start + label.length,
                                    );
                                  }
                                });
                              },
                              child: Center(
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: buttonSize * 0.25,
                                    fontWeight: FontWeight.w900,
                                    color: contrastColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                );
              }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculate button: square, bottom right, "C" symbol
    final Widget calcButton = SizedBox(
      width: 56,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: EdgeInsets.zero,
        ),
        onPressed: _calculateResult,
        child: Text(
          "C",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );

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

    Widget buildResultField(String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          children: [
            SizedBox(
              width: 110,
              child: Text(
                label,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: TextField(
                controller: TextEditingController(text: value),
                readOnly: true,
                style: TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 8,
                  ),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.copy, size: 20),
              tooltip: 'Copy',
              onPressed:
                  value.isNotEmpty && value != 'Error'
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

    return Scaffold(
      appBar: AppBar(
        title: Text("Programmer Calculator"),
        backgroundColor: widget.themeColor ?? Colors.red,
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            tooltip: 'Add Variable',
            onPressed: _showAddVariableDialog,
          ),
          IconButton(
            icon: Icon(Icons.help_outline),
            tooltip: 'Help',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => HelpScreen()),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => SettingsPage(
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
                                Platform
                                    .isAndroid, // Disable keyboard on Android
                            showCursor: true,
                            enableInteractiveSelection: true,
                            onTap: () {
                              if (Platform.isAndroid) {
                                // Keep focus so user can use app keypad
                                _focusNode.requestFocus();
                              }
                            },
                            onSubmitted: (_) => _calculateResult(),
                          ),
                        ),
                        inlineCalcButton, //
                        inlineClearButton,
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                  buildResultField("Decimal", decimalResult),
                  buildResultField("Hexadecimal", hexResult),
                  buildResultField("Binary", binaryResult),
                  buildResultField("Floating Point", floatResult),
                  SizedBox(height: 10),
                  if (showCalcButtons) ...[
                    buildCalcButtonsPageView(),
                    SizedBox(height: 10),
                  ],
                  // Remove separate C button, = is now in main grid
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        showHistory = !showHistory;
                      });
                    },
                    child: Text(showHistory ? "Hide History" : "Show History"),
                  ),
                  if (showHistory)
                    Expanded(
                      child: ListView.builder(
                        itemCount: history.length,
                        itemBuilder: (context, index) {
                          return ListTile(title: Text(history[index]));
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
