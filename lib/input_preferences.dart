import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// defaultTargetPlatform identifies the browser's host OS on the web too.
final useSystemKeyboardNotifier = ValueNotifier<bool>(
  defaultTargetPlatform != TargetPlatform.android &&
      defaultTargetPlatform != TargetPlatform.iOS,
);

Future<void> loadInputPreferences() async {
  final prefs = await SharedPreferences.getInstance();
  useSystemKeyboardNotifier.value =
      prefs.getBool('useSystemKeyboard') ??
      (defaultTargetPlatform != TargetPlatform.android &&
          defaultTargetPlatform != TargetPlatform.iOS);
}

Future<void> saveUseSystemKeyboard(bool enabled) async {
  useSystemKeyboardNotifier.value = enabled;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('useSystemKeyboard', enabled);
}
