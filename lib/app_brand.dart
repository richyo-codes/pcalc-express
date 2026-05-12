import 'package:flutter/material.dart';

const String appTitle = 'pcalc express';
const String appDescription = 'Programmer-focused expression calculator.';
const String appIconAsset = 'assets/icons/app_icon.png';

class AppTitleLabel extends StatelessWidget {
  const AppTitleLabel({super.key, this.section});

  final String? section;

  @override
  Widget build(BuildContext context) {
    final title = section == null ? appTitle : '$appTitle / $section';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.asset(
            appIconAsset,
            width: 20,
            height: 20,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
