import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _deviceDisplayChannel = MethodChannel('app/device_display');

final einkDeviceNotifier = ValueNotifier<bool>(false);

Future<void> detectEinkDevice() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    einkDeviceNotifier.value =
        await _deviceDisplayChannel.invokeMethod<bool>('isEinkDevice') ?? false;
  } on MissingPluginException {
    einkDeviceNotifier.value = false;
  } on PlatformException {
    einkDeviceNotifier.value = false;
  }
}
