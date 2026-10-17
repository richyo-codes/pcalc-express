import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pcalc_express/calculator_keypad.dart';
import 'package:pcalc_express/theme_preferences.dart';

Future<void> showOperatorPalette({
  required BuildContext context,
  required Map<String, List<CalcButtonConfig>> groups,
  required ValueChanged<CalcButtonConfig> onSelected,
}) {
  return showDialog<void>(
    context: context,
    animationStyle: usesEinkBehavior(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (_) =>
        _OperatorPaletteDialog(groups: groups, onSelected: onSelected),
  );
}

class _OperatorPaletteDialog extends StatefulWidget {
  const _OperatorPaletteDialog({
    required this.groups,
    required this.onSelected,
  });

  final Map<String, List<CalcButtonConfig>> groups;
  final ValueChanged<CalcButtonConfig> onSelected;

  @override
  State<_OperatorPaletteDialog> createState() => _OperatorPaletteDialogState();
}

class _OperatorPaletteDialogState extends State<_OperatorPaletteDialog> {
  late String selectedGroup = widget.groups.keys.first;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outline),
      ),
      child: SizedBox(
        width: 560,
        height: math.min(520, MediaQuery.sizeOf(context).height * 0.75),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Numbers and operators',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close operators',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                children: widget.groups.keys.map((name) {
                  return ChoiceChip(
                    label: Text(name),
                    selected: selectedGroup == name,
                    onSelected: (_) => setState(() => selectedGroup = name),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.groups[selectedGroup]!.map((option) {
                        final singleColumn =
                            constraints.maxWidth < 260 ||
                            MediaQuery.textScalerOf(context).scale(14) > 21;
                        return SizedBox(
                          width: singleColumn
                              ? constraints.maxWidth
                              : (constraints.maxWidth - 8) / 2,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              minimumSize: Size(
                                48,
                                88 * MediaQuery.textScalerOf(context).scale(1),
                              ),
                              padding: const EdgeInsets.all(8),
                              elevation: 0,
                              side: BorderSide(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () {
                              Navigator.of(context).pop();
                              widget.onSelected(option);
                            },
                            child: Column(
                              children: [
                                Text(
                                  option.displayText,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (option.tooltip != null)
                                  SizedBox(
                                    height:
                                        36 *
                                        MediaQuery.textScalerOf(context)
                                            .scale(1),
                                    child: Center(
                                      child: Text(
                                        option.tooltip!,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
