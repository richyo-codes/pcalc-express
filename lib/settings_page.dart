import 'package:flutter/material.dart';
import 'package:rnd_pcalc_ng/app_brand.dart';
import 'package:rnd_pcalc_ng/window_drag_controller.dart';
import 'main.dart'; // Import themeModeNotifier, saveThemeMode

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.themeColor});

  final MaterialColor themeColor;

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  ThemeMode _themeMode = themeModeNotifier.value;
  bool _showCalcButtonsDesktop = false;

  void _setThemeMode(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
      themeModeNotifier.value = mode;
      saveThemeMode(mode); // <-- Persist selection
    });
  }

  @override
  Widget build(BuildContext context) {
    final foregroundColor =
        ThemeData.estimateBrightnessForColor(widget.themeColor) ==
            Brightness.dark
        ? Colors.white
        : Colors.black;

    return FramelessWindowResizeFrame(
      child: Scaffold(
        appBar: WindowChromeHeader(
          title: const AppTitleLabel(section: 'Settings'),
          backgroundColor: widget.themeColor,
          foregroundColor: foregroundColor,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.arrow_back),
                label: const Text('Calculator'),
                onPressed: () {
                  Navigator.pop(context, _showCalcButtonsDesktop);
                },
              ),
              SizedBox(height: 8),
              Text(
                "Theme",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              SwitchListTile(
                title: Text("Show calculator buttons (Desktop only)"),
                value: _showCalcButtonsDesktop,
                onChanged: (value) {
                  setState(() {
                    _showCalcButtonsDesktop = value;
                  });
                },
                subtitle: Text("Always enabled on Android."),
              ),
              SizedBox(height: 16),
              ListTile(
                title: Text("System Default"),
                leading: Radio<ThemeMode>(
                  value: ThemeMode.system,
                  groupValue: _themeMode,
                  onChanged: (value) => _setThemeMode(value!),
                ),
              ),
              ListTile(
                title: Text("Light Mode"),
                leading: Radio<ThemeMode>(
                  value: ThemeMode.light,
                  groupValue: _themeMode,
                  onChanged: (value) => _setThemeMode(value!),
                ),
              ),
              ListTile(
                title: Text("Dark Mode"),
                leading: Radio<ThemeMode>(
                  value: ThemeMode.dark,
                  groupValue: _themeMode,
                  onChanged: (value) => _setThemeMode(value!),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
