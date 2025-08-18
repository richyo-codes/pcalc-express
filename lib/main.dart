import 'dart:io';

import 'package:expressions/expressions.dart';
import 'package:flutter/material.dart';
import 'package:rnd_pcalc_ng/settings_page.dart';

import 'package:rnd_pcalc_ng/tinyexprpp_fii.dart';
import 'package:ffi/ffi.dart' as ffi;
import 'package:rnd_pcalc_ng/help_screen.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:rnd_pcalc_ng/format_helper.dart';

void main() async {
  // Set window size for Linux desktop
  if (Platform.isLinux) {
    // WidgetsFlutterBinding.ensureInitialized();
    // await windowManager.ensureInitialized();

    // WindowOptions windowOptions = const WindowOptions(
    //   size: Size(620, 800), // Set initial size here
    //   center: true,
    //   backgroundColor: Colors.transparent,
    //   skipTaskbar: false,
    //   titleBarStyle: TitleBarStyle.normal,
    // );
    // windowManager.waitUntilReadyToShow(windowOptions, () async {
    //   await windowManager.show();
    //   await windowManager.focus();
    // });
  }
  runApp(ProgrammerCalculator());
}

bool isValidExpression(String input) {
  try {
    // Parse the expression
    Expression exp = Expression.parse(input);

    // Check if it only contains numbers, basic operators, and defined variables
    Set<String> allowedVars = {"x", "y"};
    List<String> allowedOperators = ["+", "-", "*", "/", "%"];

    bool isValid = exp
        .toString()
        .split(" ")
        .every(
          (token) =>
              allowedVars.contains(token) ||
              allowedOperators.contains(token) ||
              RegExp(r'^\d+(\.\d+)?$').hasMatch(token),
        ); // Numbers allowed

    return isValid;
  } catch (e) {
    return false; // Invalid syntax
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
      ),
      darkTheme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: _themeColor,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: CalculatorScreen(
        onThemeColorChanged: _updateThemeColor,
        themeColor: _themeColor,
      ),
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
      int intValue = result.toInt();
      double floatValue = result.toDouble();

      if (!result.isNaN) {
        setState(() {
          decimalResult = intValue.toString();
          hexResult = formatHexResult(intValue);
          binaryResult = formatBinaryResult(intValue);
          floatResult = floatValue.toString();
          history.add(
            "$input = $decimalResult (Dec) | $floatResult (Float) | $hexResult (Hex) | $binaryResult (Bin)",
          );
        });
      } else {}
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

  // Uniform grid layout, 7 columns for all rows
  final List<List<String>> buttonRows = [
    ['^', '(x)', '(', 'xʸ', 'AC', 'More', ''],
    ['<', '>', '7', '8', '9', '/', 'DEL'],
    ['%', '4', '5', '6', '×', 'ANS', ''],
    ['±', '1', '2', '3', '-', '=', ''],
    ['.', '0', ',', 'EXP', '+', '', ''],
  ];

  // Additional buttons for 'More' page
  final List<List<String>> moreButtonRows = [
    ['sin', 'cos', 'tan', 'log', 'ln', '!', 'π'],
    ['e', 'abs', 'floor', 'ceil', 'round', 'min', 'max'],
    ['deg', 'rad', 'mod', 'sqrt', 'cbrt', 'exp', 'back'],
  ];

  bool showMoreButtons = false;

  Widget buildCalcButtons() {
    final themeColor = widget.themeColor ?? Colors.red;
    final contrastColor =
        ThemeData.estimateBrightnessForColor(themeColor) == Brightness.dark
            ? Colors.white
            : Colors.black;

    final rows = showMoreButtons ? moreButtonRows : buttonRows;
    int maxCols = rows.map((row) => row.length).reduce((a, b) => a > b ? a : b);
    double spacing = 3;
    return LayoutBuilder(
      builder: (context, constraints) {
        double buttonSize =
            (constraints.maxWidth - (maxCols + 1) * spacing) / maxCols;
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
                                    showMoreButtons = true;
                                  } else if (label == 'back') {
                                    showMoreButtons = false;
                                  } else if (label == '=' || label == 'ANS') {
                                    _calculateResult();
                                  } else if (label == 'AC') {
                                    _controller.clear();
                                  } else if (label == 'DEL' ||
                                      label == '<' ||
                                      label == '⌫') {
                                    // Backspace functionality
                                    if (_controller.text.isNotEmpty) {
                                      final text = _controller.text;
                                      final selection = _controller.selection;
                                      if (selection.start != selection.end) {
                                        // Delete selected text
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
                                        // Delete character before cursor
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
                                    // Move cursor right
                                    final selection = _controller.selection;
                                    if (selection.start <
                                        _controller.text.length) {
                                      _controller
                                          .selection = TextSelection.collapsed(
                                        offset: selection.start + 1,
                                      );
                                    }
                                  } else if (label == '^') {
                                    _controller.text += '^';
                                    _controller
                                        .selection = TextSelection.fromPosition(
                                      TextPosition(
                                        offset: _controller.text.length,
                                      ),
                                    );
                                  } else {
                                    _controller.text += label;
                                    _controller
                                        .selection = TextSelection.fromPosition(
                                      TextPosition(
                                        offset: _controller.text.length,
                                      ),
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
                    buildCalcButtons(),
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
