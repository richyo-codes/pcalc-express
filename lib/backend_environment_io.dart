import 'dart:io';

String? readBackendPreferenceOverride() {
  return Platform.environment['PCALC_BACKEND'];
}
