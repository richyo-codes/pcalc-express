import 'package:flutter/material.dart';
import 'package:pcalc_expression_engine/pcalc_expression_engine.dart';
import 'package:pcalc_express/backend_preferences.dart';
import 'package:pcalc_express/calculator.dart';

class BackendSetupGate extends StatefulWidget {
  const BackendSetupGate({
    super.key,
    required this.showSetupWizard,
    required this.initialPreference,
  });

  final bool showSetupWizard;
  final BackendKind? initialPreference;

  @override
  State<BackendSetupGate> createState() => _BackendSetupGateState();
}

class _BackendSetupGateState extends State<BackendSetupGate> {
  bool _wizardShown = false;
  bool _backendApplied = false;

  @override
  void initState() {
    super.initState();
    if (widget.showSetupWizard) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showWizard());
    }
  }

  Future<void> _showWizard() async {
    if (!mounted || _wizardShown) {
      return;
    }
    _wizardShown = true;

    final completed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          BackendSetupWizard(initialPreference: widget.initialPreference),
    );
    if (completed == true && mounted) {
      setState(() => _backendApplied = true);
    }
  }

  @override
  Widget build(BuildContext context) =>
      ProgrammerCalculator(key: ValueKey(_backendApplied));
}

class BackendSetupWizard extends StatefulWidget {
  const BackendSetupWizard({super.key, required this.initialPreference});

  final BackendKind? initialPreference;

  @override
  State<BackendSetupWizard> createState() => _BackendSetupWizardState();
}

class _BackendSetupWizardState extends State<BackendSetupWizard> {
  late BackendKind? _selectedPreference;
  bool _isApplying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedPreference = widget.initialPreference;
  }

  Future<void> _applySelection() async {
    final previousPreference = widget.initialPreference;
    setState(() {
      _isApplying = true;
      _error = null;
    });

    setBackendPreference(_selectedPreference);
    try {
      await initializeTinyExpr();
      await saveBackendPreference(_selectedPreference);
      await markBackendSetupCompleted();
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      setBackendPreference(previousPreference);
      try {
        await initializeTinyExpr();
      } catch (_) {
        // Preserve the original error while making a best-effort fallback.
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _isApplying = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableBackends = availableBackendPreferenceOptions;

    return PopScope(
      canPop: false,
      child: Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose your math backend',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'More than one evaluator is available on this computer. '
                  'You can change this later in Settings.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                IgnorePointer(
                  ignoring: _isApplying,
                  child: RadioGroup<BackendKind?>(
                    groupValue: _selectedPreference,
                    onChanged: (value) {
                      setState(() => _selectedPreference = value);
                    },
                    child: Column(
                      children: [
                        RadioListTile<BackendKind?>(
                          contentPadding: EdgeInsets.zero,
                          value: null,
                          title: const Text('Auto (recommended)'),
                          subtitle: Text(backendPreferenceHelpText(null)),
                        ),
                        ...availableBackends.map(
                          (kind) => RadioListTile<BackendKind?>(
                            contentPadding: EdgeInsets.zero,
                            value: kind,
                            title: Text(backendPreferenceLabel(kind)),
                            subtitle: Text(backendPreferenceHelpText(kind)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: _isApplying ? null : _applySelection,
                    child: _isApplying
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Continue'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
