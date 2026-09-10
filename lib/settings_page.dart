import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pcalc_expression_engine/pcalc_expression_engine.dart';
import 'package:pcalc_express/app_brand.dart';
import 'package:pcalc_express/backend_preferences.dart';
import 'package:pcalc_express/theme_preferences.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({
    super.key,
    required this.themeColor,
    required this.showCalcButtonsDesktop,
  });

  final MaterialColor themeColor;
  final bool showCalcButtonsDesktop;

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  ThemeMode _themeMode = themeModeNotifier.value;
  late bool _showCalcButtonsDesktop;
  bool _backendDebugLoggingEnabled = false;
  BackendKind? _backendPreference;
  ClangExpressionLanguage _clangLanguage = ClangExpressionLanguage.cpp20;
  bool _backendLoading = true;
  bool _backendBusy = false;
  String? _backendError;

  @override
  void initState() {
    super.initState();
    _showCalcButtonsDesktop = widget.showCalcButtonsDesktop;
    _loadBackendDebugLoggingEnabled();
    _loadBackendPreference();
    _loadClangLanguage();
  }

  Future<void> _loadBackendDebugLoggingEnabled() async {
    final enabled = await loadBackendDebugLoggingEnabled();
    if (!mounted) {
      return;
    }
    setState(() {
      _backendDebugLoggingEnabled = enabled;
      setBackendDebugLoggingEnabled(enabled);
    });
  }

  Future<void> _loadBackendPreference() async {
    final preference = await loadBackendPreference();
    if (!mounted) {
      return;
    }
    setState(() {
      _backendPreference = preference;
      _backendLoading = false;
    });
  }

  Future<void> _loadClangLanguage() async {
    final language = await loadClangLanguage();
    if (!mounted) {
      return;
    }
    setState(() {
      _clangLanguage = language;
      setClangLanguage(language);
    });
  }

  Future<void> _applyBackendPreference(BackendKind? kind) async {
    final previousPreference = _backendPreference;
    setState(() {
      _backendPreference = kind;
      _backendBusy = true;
      _backendError = null;
    });

    await saveBackendPreference(kind);
    setBackendPreference(kind);

    try {
      await initializeTinyExpr();
      if (!mounted) {
        return;
      }
      setState(() {
        _backendBusy = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setBackendPreference(previousPreference);
      await saveBackendPreference(previousPreference);
      try {
        await initializeTinyExpr();
      } catch (_) {
        // Keep the app usable even if reinitialization fails during fallback.
      }
      setState(() {
        _backendPreference = previousPreference;
        _backendBusy = false;
        _backendError = error.toString();
      });
    }
  }

  Future<void> _applyClangLanguage(ClangExpressionLanguage language) async {
    final previousLanguage = _clangLanguage;
    setState(() {
      _clangLanguage = language;
      _backendBusy = true;
      _backendError = null;
    });
    setClangLanguage(language);

    try {
      await initializeTinyExpr();
      await saveClangLanguage(language);
      if (!mounted) {
        return;
      }
      setState(() {
        _backendBusy = false;
      });
    } catch (error) {
      setClangLanguage(previousLanguage);
      try {
        await initializeTinyExpr();
      } catch (_) {
        // Preserve the existing error while attempting to restore the session.
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _clangLanguage = previousLanguage;
        _backendBusy = false;
        _backendError = error.toString();
      });
    }
  }

  void _setThemeMode(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
      themeModeNotifier.value = mode;
      saveThemeMode(mode);
    });
  }

  Future<void> _setBackendDebugLoggingEnabled(bool enabled) async {
    setState(() {
      _backendDebugLoggingEnabled = enabled;
      setBackendDebugLoggingEnabled(enabled);
    });
    await saveBackendDebugLoggingEnabled(enabled);
  }

  @override
  Widget build(BuildContext context) {
    final foregroundColor =
        ThemeData.estimateBrightnessForColor(widget.themeColor) ==
            Brightness.dark
        ? Colors.white
        : Colors.black;
    final backendInfo = selectedBackendInfo();

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _showCalcButtonsDesktop);
        return false;
      },
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: AppTitleLabel(section: 'Settings'),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () {
                            Navigator.pop(context, _showCalcButtonsDesktop);
                          },
                          icon: Icon(Icons.close, color: foregroundColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Theme',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    RadioListTile<ThemeMode>(
                      title: const Text('System default'),
                      value: ThemeMode.system,
                      groupValue: _themeMode,
                      onChanged: (value) => _setThemeMode(value!),
                    ),
                    RadioListTile<ThemeMode>(
                      title: const Text('Light mode'),
                      value: ThemeMode.light,
                      groupValue: _themeMode,
                      onChanged: (value) => _setThemeMode(value!),
                    ),
                    RadioListTile<ThemeMode>(
                      title: const Text('Dark mode'),
                      value: ThemeMode.dark,
                      groupValue: _themeMode,
                      onChanged: (value) => _setThemeMode(value!),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Layout',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Show calculator buttons (desktop)'),
                      subtitle: const Text('Always enabled on Android.'),
                      value: _showCalcButtonsDesktop,
                      onChanged: (value) {
                        setState(() {
                          _showCalcButtonsDesktop = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Debug backend command logging'),
                      subtitle: const Text(
                        'Print backend command lines and results to the console.',
                      ),
                      value: _backendDebugLoggingEnabled,
                      onChanged: (value) {
                        unawaited(_setBackendDebugLoggingEnabled(value));
                      },
                    ),
                    const SizedBox(height: 12),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('Advanced'),
                      subtitle: const Text(
                        'Expression backend and diagnostics',
                      ),
                      children: [
                        if (_backendLoading)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: LinearProgressIndicator(),
                          )
                        else ...[
                          DropdownButtonFormField<BackendKind?>(
                            value: _backendPreference,
                            decoration: const InputDecoration(
                              labelText: 'Backend override',
                              helperText: 'Auto follows the platform default. Overrides are saved immediately.',
                            ),
                            items: [
                              const DropdownMenuItem<BackendKind?>(
                                value: null,
                                child: Text('Auto'),
                              ),
                              ...availableBackendPreferenceOptions.map(
                                (kind) => DropdownMenuItem<BackendKind?>(
                                  value: kind,
                                  child: Text(backendPreferenceLabel(kind)),
                                ),
                              ),
                            ],
                            onChanged: _backendBusy
                                ? null
                                : (value) {
                                    unawaited(_applyBackendPreference(value));
                                  },
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<ClangExpressionLanguage>(
                            value: _clangLanguage,
                            decoration: const InputDecoration(
                              labelText: 'Clang language standard',
                              helperText: 'Used by the Clang constexpr backend. C++20 is the default.',
                            ),
                            items: selectableClangExpressionLanguages
                                .map(
                                  (language) => DropdownMenuItem(
                                    value: language,
                                    child: Text(language.displayName),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: _backendBusy
                                ? null
                                : (language) {
                                    if (language != null) {
                                      unawaited(_applyClangLanguage(language));
                                    }
                                  },
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Current backend: ${backendInfo.name}\n${backendInfo.description}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (_backendPreference == null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Auto currently resolves to ${backendInfo.name}.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          if (_backendBusy) ...[
                            const SizedBox(height: 12),
                            const LinearProgressIndicator(minHeight: 2),
                          ],
                          if (_backendError != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _backendError!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
