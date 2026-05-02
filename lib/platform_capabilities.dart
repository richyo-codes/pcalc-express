import 'platform_capabilities_stub.dart'
    if (dart.library.io) 'platform_capabilities_io.dart';

bool get isAndroid => platformIsAndroid;
bool get isIOS => platformIsIOS;
bool get isLinux => platformIsLinux;
bool get isWindows => platformIsWindows;
bool get isDesktopPlatform =>
    platformIsLinux || platformIsWindows || platformIsMacOS;
