import 'package:flutter/material.dart';
import 'package:pcalc_express/app_brand.dart';
import 'package:pcalc_express/window_drag_controller.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key, required this.themeColor});

  final MaterialColor themeColor;

  static const String _helpUrl =
      'https://github.com/Blake-Madden/tinyexpr-plusplus/blob/tinyexpr%2B%2B/docs/TinyExpr%2B%2BReferenceManual.pdf';

  @override
  Widget build(BuildContext context) {
    final foregroundColor =
        ThemeData.estimateBrightnessForColor(themeColor) == Brightness.dark
        ? Colors.white
        : Colors.black;

    return FramelessWindowResizeFrame(
      child: Scaffold(
        appBar: WindowChromeHeader(
          title: const AppTitleLabel(section: 'Help'),
          backgroundColor: themeColor,
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
                onPressed: () => Navigator.pop(context),
              ),
              SizedBox(height: 8),
              Text(
                'Help & Reference',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text(
                'For a full list of supported operators, functions, and syntax, see the TinyExpr++ Reference Manual:',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 16),
              ElevatedButton.icon(
                icon: Icon(Icons.open_in_new),
                label: Text('Open Reference Manual'),
                onPressed: () async {
                  final uri = Uri.parse(_helpUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
              SizedBox(height: 32),
              Text(
                'Tips:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                '- Use C-style operators (e.g., "+", "-", "*", "/", "%", "&", "|", "^", "~", "<<", ">>").',
              ),
              Text('- Supports integer and floating-point calculations.'),
              Text(
                '- See Settings to enable/disable calculator buttons on desktop.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
