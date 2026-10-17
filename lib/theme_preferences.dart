import 'package:flutter/material.dart';
import 'package:pcalc_express/eink_device.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppTheme {
  system,
  light,
  dark,
  eink;

  ThemeMode get materialMode => switch (this) {
    AppTheme.system => ThemeMode.system,
    AppTheme.dark => ThemeMode.dark,
    _ => ThemeMode.light,
  };
}

final themeModeNotifier = ValueNotifier<AppTheme>(AppTheme.system);

final MaterialColor appThemeColor = MaterialColor(
  Colors.red.shade900.toARGB32(),
  <int, Color>{
    50: Colors.red.shade50,
    100: Colors.red.shade100,
    200: Colors.red.shade200,
    300: Colors.red.shade300,
    400: Colors.red.shade400,
    500: Colors.red.shade500,
    600: Colors.red.shade600,
    700: Colors.red.shade700,
    800: Colors.red.shade800,
    900: Colors.red.shade900,
  },
);

bool isEinkTheme(BuildContext context) =>
    Theme.of(context).extension<EinkTheme>() != null;

bool usesEinkBehavior(BuildContext context) =>
    einkDeviceNotifier.value || isEinkTheme(context);

class EinkTheme extends ThemeExtension<EinkTheme> {
  const EinkTheme();
  @override
  EinkTheme copyWith() => this;
  @override
  EinkTheme lerp(covariant EinkTheme? other, double t) => this;
}

ThemeData buildAppLightTheme() => ThemeData(
  primarySwatch: appThemeColor,
  colorScheme: ColorScheme.fromSwatch(primarySwatch: appThemeColor),
  useMaterial3: true,
  inputDecorationTheme: InputDecorationTheme(
    border: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.grey.shade400),
    ),
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.grey.shade400),
    ),
  ),
);

ThemeData buildAppDarkTheme() => ThemeData.dark().copyWith(
  colorScheme: ColorScheme.fromSwatch(
    primarySwatch: appThemeColor,
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
);

ThemeData buildEinkTheme() {
  const colors = ColorScheme.light(
    primary: Colors.black,
    onPrimary: Colors.white,
    primaryContainer: Colors.white,
    onPrimaryContainer: Colors.black,
    secondary: Colors.black,
    onSecondary: Colors.white,
    secondaryContainer: Colors.white,
    onSecondaryContainer: Colors.black,
    tertiary: Colors.black,
    onTertiary: Colors.white,
    tertiaryContainer: Colors.white,
    onTertiaryContainer: Colors.black,
    surface: Colors.white,
    onSurface: Colors.black,
    onSurfaceVariant: Colors.black,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: Colors.white,
    surfaceContainer: Colors.white,
    surfaceContainerHigh: Colors.white,
    surfaceContainerHighest: Colors.white,
    outline: Colors.black,
    outlineVariant: Colors.black,
    error: Colors.black,
    onError: Colors.white,
    errorContainer: Colors.white,
    onErrorContainer: Colors.black,
    surfaceTint: Colors.transparent,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    scaffoldBackgroundColor: Colors.white,
    extensions: const [EinkTheme()],
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
    dividerColor: Colors.black,
    chipTheme: const ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: Colors.black,
      checkmarkColor: Colors.white,
      secondaryLabelStyle: TextStyle(color: Colors.white),
      side: BorderSide(color: Colors.black),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        side: const BorderSide(color: Colors.black),
        minimumSize: const Size(48, 48),
        animationDuration: Duration.zero,
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(side: BorderSide(color: Colors.black)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      modalElevation: 0,
      shape: RoundedRectangleBorder(side: BorderSide(color: Colors.black)),
    ),
  );
}

Future<void> loadThemeMode() async {
  final prefs = await SharedPreferences.getInstance();
  final savedMode = prefs.getString('themeMode');
  final modeString =
      savedMode ?? (einkDeviceNotifier.value ? 'eink' : 'system');
  switch (modeString) {
    case 'light':
      themeModeNotifier.value = AppTheme.light;
      break;
    case 'dark':
      themeModeNotifier.value = AppTheme.dark;
      break;
    case 'eink':
      themeModeNotifier.value = AppTheme.eink;
      break;
    default:
      themeModeNotifier.value = AppTheme.system;
  }
}

Future<void> saveThemeMode(AppTheme mode) async {
  final prefs = await SharedPreferences.getInstance();
  final modeString = mode.name;
  await prefs.setString('themeMode', modeString);
}
