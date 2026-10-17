import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pcalc_express/theme_preferences.dart';

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

class CalcPageIndicator extends StatelessWidget {
  const CalcPageIndicator({
    super.key,
    required this.pageCount,
    required this.currentPage,
    this.onDotTapped,
    this.activeColor = Colors.red,
    this.inactiveColor = Colors.grey,
  });

  final int pageCount;
  final int currentPage;
  final ValueChanged<int>? onDotTapped;
  final Color activeColor;
  final Color inactiveColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        pageCount,
        (index) => GestureDetector(
          onTap: onDotTapped != null ? () => onDotTapped!(index) : null,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
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

enum _CalcButtonRole {
  number,
  operator,
  programmer,
  utility,
  destructive,
  equals,
}

class CalculatorButton extends StatelessWidget {
  const CalculatorButton({
    super.key,
    required this.config,
    required this.onPressed,
    required this.width,
    required this.height,
    required this.fontSize,
    this.showTooltip = false,
  });

  final CalcButtonConfig config;
  final ValueChanged<CalcButtonConfig> onPressed;
  final double width;
  final double height;
  final double fontSize;
  final bool showTooltip;

  _CalcButtonRole get _role {
    final label = config.displayText;
    if (label == '=') return _CalcButtonRole.equals;
    if (label == 'AC') return _CalcButtonRole.destructive;
    if (const {'DEL', '←', '→', 'SPACE'}.contains(label)) {
      return _CalcButtonRole.utility;
    }
    if (RegExp(r'^\d$').hasMatch(label) || label == '.') {
      return _CalcButtonRole.number;
    }
    if (const {'+', '-', '*', '/', '(', ')'}.contains(label)) {
      return _CalcButtonRole.operator;
    }
    return _CalcButtonRole.programmer;
  }

  String get _semanticsLabel {
    if (config.tooltip?.isNotEmpty ?? false) return config.tooltip!;
    return switch (config.displayText) {
      'AC' => 'Clear all',
      'DEL' => 'Delete previous character',
      '←' => 'Move cursor left',
      '→' => 'Move cursor right',
      'SPACE' => 'Insert space',
      '=' => 'Calculate',
      '/' => 'Divide',
      '*' => 'Multiply',
      '-' => 'Subtract',
      '+' => 'Add',
      '.' => 'Decimal point',
      '(' => 'Left parenthesis',
      ')' => 'Right parenthesis',
      _ => config.displayText,
    };
  }

  ButtonStyle _style(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final role = _role;
    if (isEinkTheme(context)) {
      final equals = role == _CalcButtonRole.equals;
      return FilledButton.styleFrom(
        backgroundColor: equals ? Colors.black : Colors.white,
        foregroundColor: equals ? Colors.white : Colors.black,
        elevation: 0,
        shadowColor: Colors.transparent,
        overlayColor: Colors.transparent,
        minimumSize: const Size(52, 48),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        animationDuration: Duration.zero,
        side: BorderSide(color: Colors.black, width: equals ? 2 : 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      );
    }
    final isDark = colors.brightness == Brightness.dark;
    final (background, foreground) = switch (role) {
      _CalcButtonRole.number => (const Color(0xFF454545), Colors.white),
      _CalcButtonRole.operator => (
        isDark ? const Color(0xFF5BE7CF) : const Color(0xFFC9F9ED),
        const Color(0xFF10241F),
      ),
      _CalcButtonRole.programmer => (
        isDark ? const Color(0xFF4B435B) : const Color(0xFFE6DCF7),
        isDark ? Colors.white : const Color(0xFF2A2038),
      ),
      _CalcButtonRole.utility => (const Color(0xFF4A4A4A), Colors.white),
      _CalcButtonRole.destructive => (
        isDark ? const Color(0xFFDC3030) : const Color(0xFFFFDED9),
        isDark ? Colors.white : const Color(0xFF8C1810),
      ),
      _CalcButtonRole.equals => (colors.primary, colors.onPrimary),
    };
    final hover = Color.alphaBlend(
      foreground.withValues(alpha: 0.08),
      background,
    );
    final pressed = Color.alphaBlend(
      foreground.withValues(alpha: 0.16),
      background,
    );
    return FilledButton.styleFrom(
      foregroundColor: foreground,
      shadowColor: colors.shadow.withValues(alpha: 0.22),
      minimumSize: const Size(52, 48),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      textStyle: const TextStyle(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
      animationDuration: usesEinkBehavior(context)
          ? Duration.zero
          : const Duration(milliseconds: 100),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ).copyWith(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) return pressed;
        if (states.contains(WidgetState.hovered)) return hover;
        return background;
      }),
      elevation: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) return 0;
        if (states.contains(WidgetState.hovered)) {
          return role == _CalcButtonRole.equals ? 3 : 2;
        }
        return role == _CalcButtonRole.equals ? 2 : 1;
      }),
      side: WidgetStateProperty.resolveWith((states) {
        final focused = states.contains(WidgetState.focused);
        return BorderSide(
          color: foreground.withValues(
            alpha: focused ? 0.72 : (isDark ? 0.34 : 0.28),
          ),
          width: focused ? 2 : 1,
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget button = FilledButton(
      style: _style(context),
      onPressed: () {
        if (config.onPressed case final callback?) {
          callback(context);
        } else {
          onPressed(config);
        }
      },
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Semantics(
          label: _semanticsLabel,
          excludeSemantics: true,
          child: Text(
            config.displayText,
            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
    if (showTooltip && (config.tooltip?.isNotEmpty ?? false)) {
      button = Tooltip(message: config.tooltip!, child: button);
    }
    return SizedBox(
      width: width,
      height: height,
      child: Focus(
        canRequestFocus: false,
        descendantsAreFocusable: false,
        child: button,
      ),
    );
  }
}

class CalculatorButtonGrid extends StatelessWidget {
  const CalculatorButtonGrid({
    super.key,
    required this.rows,
    required this.onPressed,
    required this.compact,
    required this.desktop,
    this.desktopButtonWidth = 88,
    this.desktopButtonHeight = 68,
  });

  final List<List<CalcButtonConfig>> rows;
  final ValueChanged<CalcButtonConfig> onPressed;
  final bool compact;
  final bool desktop;
  final double desktopButtonWidth;
  final double desktopButtonHeight;

  @override
  Widget build(BuildContext context) {
    final columnCount = rows.fold<int>(
      0,
      (max, row) => math.max(max, row.length),
    );
    final columns = columnCount == 0 ? 1 : columnCount;
    final rowCount = rows.isEmpty ? 1 : rows.length;
    final paddedRows = rows
        .map<List<CalcButtonConfig?>>(
          (row) => [
            ...row,
            ...List<CalcButtonConfig?>.filled(columnCount - row.length, null),
          ],
        )
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : columnCount * desktopButtonWidth;
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : rows.length * desktopButtonHeight;
        final cellWidth = (width - spacing * (columns - 1)) / columns;
        final cellHeight = math.max(
          44.0,
          (height - spacing * (rowCount - 1)) / rowCount,
        );
        final fontSize = math.max(14.0, math.min(cellHeight * 0.35, 22.0));

        Widget cell(
          CalcButtonConfig? config,
          double width,
          double height,
          double fontSize,
        ) {
          if (config == null) return SizedBox(width: width, height: height);
          return CalculatorButton(
            config: config,
            onPressed: onPressed,
            width: width,
            height: height,
            fontSize: fontSize,
            showTooltip: desktop,
          );
        }

        if (desktop && !compact) {
          final panelWidth =
              columns * desktopButtonWidth + math.max(0, columns - 1) * spacing;
          return Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: panelWidth,
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
                        for (var index = 0; index < row.length; index++) ...[
                          if (index > 0) const SizedBox(width: spacing),
                          cell(
                            row[index],
                            desktopButtonWidth,
                            desktopButtonHeight,
                            20,
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

        final buttons = paddedRows.expand((row) => row).toList();
        return GridView.builder(
          itemCount: buttons.length,
          shrinkWrap: true,
          physics: cellHeight * rowCount + spacing * (rowCount - 1) > height
              ? const ClampingScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: cellWidth / cellHeight,
          ),
          itemBuilder: (_, index) =>
              cell(buttons[index], cellWidth, cellHeight, fontSize),
        );
      },
    );
  }
}
