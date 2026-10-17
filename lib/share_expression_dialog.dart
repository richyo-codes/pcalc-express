import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pcalc_express/theme_preferences.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

const _hostedCalculatorUri = 'https://richyo-codes.github.io/pcalc-express/';

Uri buildSharedExpressionUri(String expression) {
  final base = Uri.parse(_hostedCalculatorUri);
  final trimmed = expression.trim();
  if (trimmed.isEmpty) return base;
  return base.replace(queryParameters: {'expression': trimmed});
}

String? expressionFromLaunchUri(Uri uri) {
  final expression = uri.queryParameters['expression']?.trim();
  return expression == null || expression.isEmpty ? null : expression;
}

Future<void> showShareExpressionDialog({
  required BuildContext context,
  required String expression,
}) async {
  final uri = buildSharedExpressionUri(expression);
  final trimmed = expression.trim();
  final shareText = trimmed.isEmpty
      ? 'PCalc Express programmer calculator\n$uri'
      : '$trimmed\n$uri';

  await showDialog<void>(
    context: context,
    animationStyle: usesEinkBehavior(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Share calculation'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 264,
                height: 264,
                color: Colors.white,
                padding: const EdgeInsets.all(12),
                child: QrImageView(
                  data: uri.toString(),
                  version: QrVersions.auto,
                  size: 240,
                  backgroundColor: Colors.white,
                  errorStateBuilder: (context, error) => const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'This expression is too long for a QR code. Use Copy link or Share.',
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Colors.black,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Scan to open this expression in PCalc Express.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              SelectableText(
                uri.toString(),
                style: Theme.of(dialogContext).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: uri.toString()));
            if (!dialogContext.mounted) return;
            ScaffoldMessenger.of(dialogContext)
                .showSnackBar(const SnackBar(content: Text('Link copied')));
          },
          child: const Text('Copy link'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.share_outlined),
          label: const Text('Share'),
          onPressed: () async {
            final box = dialogContext.findRenderObject() as RenderBox?;
            try {
              await SharePlus.instance.share(
                ShareParams(
                  text: shareText,
                  title: 'PCalc Express calculation',
                  subject: 'PCalc Express calculation',
                  sharePositionOrigin: box == null
                      ? null
                      : box.localToGlobal(Offset.zero) & box.size,
                ),
              );
            } catch (_) {
              if (!dialogContext.mounted) return;
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Sharing is unavailable. Use Copy link instead.',
                  ),
                ),
              );
            }
          },
        ),
      ],
    ),
  );
}
