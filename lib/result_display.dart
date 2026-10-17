import 'package:flutter/material.dart';
import 'package:pcalc_express/result_format_controls.dart';
import 'package:pcalc_express/theme_preferences.dart';

enum ResultDisplayMode { adaptive, expanded, compact }

class ResultsPanel extends StatelessWidget {
  const ResultsPanel({
    super.key,
    required this.compact,
    required this.decimal,
    required this.hexadecimal,
    required this.binary,
    required this.floatingPoint,
    required this.hasCalculationError,
    required this.selectedLabel,
    required this.onSelectedLabelChanged,
    required this.onDisplayModeChanged,
    required this.onCopy,
    this.copiedLabel,
  });

  final bool compact;
  final String decimal;
  final String hexadecimal;
  final String binary;
  final String floatingPoint;
  final bool hasCalculationError;
  final String selectedLabel;
  final ValueChanged<String> onSelectedLabelChanged;
  final ValueChanged<ResultDisplayMode> onDisplayModeChanged;
  final void Function(String label, String value) onCopy;
  final String? copiedLabel;

  @override
  Widget build(BuildContext context) {
    if (!compact) {
      return Column(
        children: [
          ResultField(
            label: 'Decimal',
            value: decimal,
            isError: hasCalculationError,
            copied: copiedLabel == 'Decimal',
            onCopy: onCopy,
            labelAction: IconButton(
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 28, height: 28),
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.unfold_less, size: 18),
              tooltip: 'Show one result unit',
              onPressed: () => onDisplayModeChanged(ResultDisplayMode.compact),
            ),
          ),
          ResultField(
            label: 'Hexadecimal',
            value: hexadecimal,
            copied: copiedLabel == 'Hexadecimal',
            onCopy: onCopy,
          ),
          ResultField(
            label: 'Binary',
            value: binary,
            copied: copiedLabel == 'Binary',
            onCopy: onCopy,
          ),
          ResultField(
            label: 'Floating Point',
            value: floatingPoint,
            copied: copiedLabel == 'Floating Point',
            onCopy: onCopy,
          ),
        ],
      );
    }

    final results = <String, String>{
      'Dec': decimal,
      'Hex': hexadecimal,
      'Bin': binary,
      'Float': floatingPoint,
    };
    final selectedValue = results[selectedLabel] ?? '';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final label in results.keys)
              ChoiceChip(
                label: Text(label),
                labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                selected: selectedLabel == label,
                onSelected: (_) => onSelectedLabelChanged(label),
              ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.unfold_more),
              tooltip: 'Show all result units',
              onPressed: () => onDisplayModeChanged(ResultDisplayMode.expanded),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ResultField(
          label: selectedLabel,
          value: selectedValue,
          compact: true,
          isError: hasCalculationError && selectedLabel == 'Dec',
          showLabel: false,
          copied: copiedLabel == selectedLabel,
          onCopy: onCopy,
        ),
      ],
    );
  }
}

class ResultField extends StatelessWidget {
  const ResultField({
    super.key,
    required this.label,
    required this.value,
    required this.onCopy,
    this.compact = false,
    this.isError = false,
    this.showLabel = true,
    this.copied = false,
    this.labelAction,
  });

  final String label;
  final String value;
  final bool compact;
  final bool isError;
  final bool showLabel;
  final bool copied;
  final Widget? labelAction;
  final void Function(String label, String value) onCopy;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = isEinkTheme(context)
        ? Colors.black
        : isError
        ? colorScheme.error
        : const Color(0xFF8A858D);
    final border = OutlineInputBorder(
      borderSide: BorderSide(color: borderColor),
    );
    final enabled = value.isNotEmpty && value != 'Error';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          if (showLabel)
            SizedBox(
              width: compact ? 90 : 110,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: compact ? 14 : 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (labelAction != null) labelAction!,
                ],
              ),
            ),
          Expanded(
            child: MergeSemantics(
              child: Semantics(
                label: '$label result',
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
            ),
          ),
          if (label == 'Hex' || label == 'Hexadecimal') const HexFormatMenu(),
          if (label == 'Float' || label == 'Floating Point')
            const FloatPrecisionMenu(),
          MergeSemantics(
            child: Semantics(
              label: 'Copy $label result',
              button: true,
              enabled: enabled,
              child: Tooltip(
                message: copied ? '$label result copied' : 'Copy $label result',
                excludeFromSemantics: true,
                child: IconButton(
                  icon: Icon(copied ? Icons.check : Icons.copy, size: 20),
                  onPressed: enabled ? () => onCopy(label, value) : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
