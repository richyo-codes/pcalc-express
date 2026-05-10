import 'package:flutter/material.dart';
import 'package:rnd_pcalc_ng/app_brand.dart';
import 'package:rnd_pcalc_ng/window_drag_controller.dart';
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
          title: const Text(
            '$appTitle / Help',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          backgroundColor: themeColor,
          foregroundColor: foregroundColor,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, size: 18),
            tooltip: 'Back to calculator',
            color: foregroundColor,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
            visualDensity: VisualDensity.compact,
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
