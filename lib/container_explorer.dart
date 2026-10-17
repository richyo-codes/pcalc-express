import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pcalc_expression_engine/pcalc_expression_engine.dart';

import 'format_helper.dart';
import 'result_display.dart';
import 'result_preferences.dart';

/// Static navigation, with no expansion/slide animations (including on e-ink).
class ContainerExplorer extends StatefulWidget {
  const ContainerExplorer({super.key, required this.snapshot});
  final ContainerSnapshot snapshot;

  @override
  State<ContainerExplorer> createState() => _ContainerExplorerState();
}

class _ContainerExplorerState extends State<ContainerExplorer> {
  static const pageSize = 32;
  final _path = <int>[];
  int _page = 0;
  int? _selected;
  String _unit = 'Dec';
  bool _expanded = false;
  String? _copied;
  final _index = TextEditingController();
  String? _indexError;

  ContainerSnapshot get _current {
    var node = widget.snapshot;
    for (final index in _path) {
      node = node.elements[index] as ContainerSnapshot;
    }
    return node;
  }

  @override
  void didUpdateWidget(ContainerExplorer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.snapshot, widget.snapshot)) {
      _path.clear();
      _page = 0;
      _selected = null;
      _copied = null;
      _indexError = null;
      _index.clear();
    }
  }

  @override
  void dispose() {
    _index.dispose();
    super.dispose();
  }

  void _back() => setState(() {
    if (_selected != null) {
      _selected = null;
    } else if (_path.isNotEmpty) {
      final index = _path.removeLast();
      _page = index ~/ pageSize;
    }
    _indexError = null;
    _index.clear();
    _copied = null;
  });

  Future<void> _copy(String label, String value) async {
    try {
      await Clipboard.setData(ClipboardData(text: value));
      if (mounted) setState(() => _copied = label);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(const SnackBar(content: Text('Could not copy result')));
      }
    }
  }

  Widget _detail(ScalarSnapshot value) => ListenableBuilder(
    listenable: Listenable.merge([
      hexGroupDigitsNotifier,
      hexPrefixNotifier,
      floatPrecisionNotifier,
    ]),
    builder: (context, _) {
      final integer = value.bitWidth == null
          ? null
          : BigInt.parse(value.exactValue);
      final bits = integer?.toUnsigned(value.bitWidth!);
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Element [$_selected] · ${value.typeName}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (value.bitWidth != null)
              Text(
                '${value.bitWidth}-bit ${value.isSigned! ? 'signed' : 'unsigned'}',
              ),
            ResultsPanel(
              compact: !_expanded,
              decimal: value.exactValue,
              hexadecimal: bits == null
                  ? '—'
                  : formatHexDisplay(
                      bits
                          .toRadixString(16)
                          .toUpperCase()
                          .padLeft((value.bitWidth! / 4).ceil(), '0'),
                      groupDigits: hexGroupDigitsNotifier.value,
                      showPrefix: hexPrefixNotifier.value,
                    ),
              binary: bits == null
                  ? '—'
                  : bits.toRadixString(2).padLeft(value.bitWidth!, '0'),
              floatingPoint: value.floatingValue == null
                  ? '—'
                  : formatFloatResult(
                      value.floatingValue!,
                      decimalPlaces: floatPrecisionNotifier.value,
                    ),
              hasCalculationError: false,
              selectedLabel: _unit,
              copiedLabel: _copied,
              onSelectedLabelChanged: (unit) => setState(() => _unit = unit),
              onDisplayModeChanged: (mode) => setState(
                () => _expanded = mode == ResultDisplayMode.expanded,
              ),
              onCopy: _copy,
            ),
            const Text(
              '— means that representation is unavailable; integers are never rounded through a double.',
            ),
          ],
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final current = _current;
    final start = _page * pageSize;
    final end = (start + pageSize).clamp(0, current.elements.length);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        final scalar = _selected == null
            ? null
            : current.elements[_selected!] as ScalarSnapshot;
        final listing = Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _index,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Go to index',
                      errorText: _indexError,
                    ),
                    onSubmitted: (_) => _goToIndex(),
                  ),
                ),
                TextButton(onPressed: _goToIndex, child: const Text('Go')),
              ],
            ),
            Expanded(
              child: current.elements.isEmpty
                  ? Center(
                      child: Text(
                        current.totalCount == 0
                            ? 'Empty container'
                            : 'No elements captured',
                      ),
                    )
                  : ListView.builder(
                      key: ValueKey('${_path.join('.')}:$_page'),
                      itemCount: end - start,
                      itemBuilder: (context, offset) {
                        final index = start + offset;
                        final value = current.elements[index];
                        return ListTile(
                          selected: _selected == index,
                          title: Text(
                            '[$index]  ${value is ScalarSnapshot ? value.exactValue : '${(value as ContainerSnapshot).totalCount} elements'}',
                          ),
                          subtitle: Text(value.typeName),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => setState(() {
                            _copied = null;
                            if (value is ContainerSnapshot) {
                              _path.add(index);
                              _page = 0;
                              _selected = null;
                              _index.clear();
                              _indexError = null;
                            } else {
                              _selected = index;
                            }
                          }),
                        );
                      },
                    ),
            ),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Previous page',
                  onPressed: _page == 0
                      ? null
                      : () => setState(() {
                          _page--;
                          _selected = null;
                        }),
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  current.elements.isEmpty
                      ? '0 captured'
                      : '$start–${end - 1} of ${current.elements.length} captured',
                ),
                IconButton(
                  tooltip: 'Next page',
                  onPressed: end >= current.elements.length
                      ? null
                      : () => setState(() {
                          _page++;
                          _selected = null;
                        }),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ],
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (_path.isNotEmpty || _selected != null)
                  IconButton(
                    tooltip: 'Back to container',
                    onPressed: _back,
                    icon: const Icon(Icons.arrow_back),
                  ),
                Text(
                  'Result${_path.map((i) => '[$i]').join()} · ${current.typeName}',
                ),
                TextButton.icon(
                  onPressed: () => _copy(
                    'Container',
                    const JsonEncoder.withIndent('  ')
                        .convert(current.toJson()),
                  ),
                  icon: const Icon(Icons.copy),
                  label: Text(
                    _copied == 'Container' ? 'Copied' : 'Copy snapshot',
                  ),
                ),
              ],
            ),
            Text('${current.totalCount} elements'),
            if (current.isTruncated)
              Text(
                'Partial snapshot: ${current.elements.length} of ${current.totalCount} elements captured. Uncaptured elements cannot be browsed.',
              ),
            const SizedBox(height: 8),
            Expanded(
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: listing),
                        const VerticalDivider(),
                        Expanded(
                          child: scalar == null
                              ? const Center(child: Text('Select an element'))
                              : _detail(scalar),
                        ),
                      ],
                    )
                  : scalar == null
                  ? listing
                  : _detail(scalar),
            ),
          ],
        );
      },
    );
  }

  void _goToIndex() {
    final index = int.tryParse(_index.text);
    setState(() {
      if (index == null || index < 0 || index >= _current.elements.length) {
        _indexError = 'Enter a captured index';
        return;
      }
      _indexError = null;
      _selected = null;
      _page = index ~/ pageSize;
    });
  }
}

Future<void> showContainerExplorer(
  BuildContext context,
  ContainerSnapshot snapshot,
) => showDialog<void>(
  context: context,
  useSafeArea: true,
  animationStyle: AnimationStyle.noAnimation,
  builder: (context) => Dialog.fullscreen(
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Container result'),
        leading: IconButton(
          tooltip: 'Close explorer',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ContainerExplorer(snapshot: snapshot),
      ),
    ),
  ),
);
