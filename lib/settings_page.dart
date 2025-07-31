import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  ThemeMode _themeMode = ThemeMode.system;
  bool _showCalcButtonsDesktop = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Settings"),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context, _showCalcButtonsDesktop);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                onChanged: (value) {
                  setState(() {
                    _themeMode = value!;
                    _applyTheme();
                  });
                },
              ),
            ),
            ListTile(
              title: Text("Light Mode"),
              leading: Radio<ThemeMode>(
                value: ThemeMode.light,
                groupValue: _themeMode,
                onChanged: (value) {
                  setState(() {
                    _themeMode = value!;
                    _applyTheme();
                  });
                },
              ),
            ),
            ListTile(
              title: Text("Dark Mode"),
              leading: Radio<ThemeMode>(
                value: ThemeMode.dark,
                groupValue: _themeMode,
                onChanged: (value) {
                  setState(() {
                    _themeMode = value!;
                    _applyTheme();
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _applyTheme() {
    // Apply the selected theme mode
    final app = context.findAncestorWidgetOfExactType<MaterialApp>();
    if (app != null) {
      //app.themeMode = _themeMode;
    }
  }
}
