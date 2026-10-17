import 'package:flutter/material.dart';
import 'package:pcalc_express/result_preferences.dart';
import 'package:pcalc_express/theme_preferences.dart';

class HexFormatMenu extends StatelessWidget {
  const HexFormatMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: 'Hexadecimal formatting',
      icon: const Icon(Icons.tune, size: 20),
      popUpAnimationStyle: usesEinkBehavior(context)
          ? AnimationStyle.noAnimation
          : null,
      onSelected: (option) {
        if (option == -1) {
          saveHexPrefix(!hexPrefixNotifier.value);
        } else {
          saveHexGroupDigits(option);
        }
      },
      itemBuilder: (context) => [
        CheckedPopupMenuItem(
          value: -1,
          checked: hexPrefixNotifier.value,
          child: const Text('Show 0x prefix'),
        ),
        const PopupMenuDivider(),
        for (final entry in const {
          0: 'No spacing',
          2: 'Bytes · AA BB CC DD',
          4: '16-bit words · AABB CCDD',
          8: '32-bit words · AABBCCDD',
        }.entries)
          CheckedPopupMenuItem(
            value: entry.key,
            checked: hexGroupDigitsNotifier.value == entry.key,
            child: Text(entry.value),
          ),
      ],
    );
  }
}

class FloatPrecisionMenu extends StatelessWidget {
  const FloatPrecisionMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: 'Floating point precision',
      icon: const Icon(Icons.tune, size: 20),
      initialValue: floatPrecisionNotifier.value ?? -1,
      popUpAnimationStyle: usesEinkBehavior(context)
          ? AnimationStyle.noAnimation
          : null,
      onSelected: (places) => saveFloatPrecision(places == -1 ? null : places),
      itemBuilder: (context) => floatPrecisionOptions.map((places) {
        return CheckedPopupMenuItem<int>(
          value: places ?? -1,
          checked: floatPrecisionNotifier.value == places,
          child: Text(
            places == null ? 'Auto precision' : '$places decimal places',
          ),
        );
      }).toList(),
    );
  }
}
