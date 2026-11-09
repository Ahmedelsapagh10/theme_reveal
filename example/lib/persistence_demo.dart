import 'package:flutter/material.dart';
import 'package:theme_reveal_kit/theme_reveal_kit.dart';

import 'example_storage.dart';
import 'reveal_preferences.dart';

class PersistenceDemo extends StatefulWidget {
  const PersistenceDemo({
    super.key,
    required this.controller,
    required this.storage,
    required this.preferences,
  });
  final RevealThemeController controller;
  final ExampleThemeStorage storage;
  final RevealPreferences preferences;

  @override
  State<PersistenceDemo> createState() => _PersistenceDemoState();
}

class _PersistenceDemoState extends State<PersistenceDemo> {
  String? _raw;
  String? _error;
  String? _message;
  bool _loading = true;
  bool _busy = false;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
    _refresh();
  }

  @override
  void didUpdateWidget(PersistenceDemo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.storage != widget.storage) {
      oldWidget.controller.removeListener(_refresh);
      widget.controller.addListener(_refresh);
      _refresh();
    }
  }

  Future<void> _refresh() async {
    final revision = ++_revision;
    try {
      await widget.controller.flush();
      final raw = await widget.storage.readRaw();
      if (!mounted || revision != _revision) return;
      setState(() {
        _raw = raw;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (mounted && revision == _revision) {
        setState(() {
          _error = 'Could not read storage: $error';
          _loading = false;
        });
      }
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      await widget.controller.flush();
      if (!mounted) return;
      await action();
      await _refresh();
    } catch (error) {
      if (mounted) setState(() => _error = 'Storage demo failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Persistence lab',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            _loading
                ? 'Reading stored value…'
                : 'Stored value: ${_raw ?? '(not set)'}',
            key: const ValueKey('stored-value'),
          ),
          const Text(
            'These actions use the same preferences key as this app. An invalid value reloads as the configured default mode. Reloading leaves the invalid raw value visible until you save a different mode.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                key: const ValueKey('refresh-storage'),
                onPressed: _busy ? null : _refresh,
                child: const Text('Refresh stored value'),
              ),
              OutlinedButton(
                key: const ValueKey('write-invalid'),
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                        await widget.storage.writeInvalid();
                        if (mounted) {
                          setState(
                            () => _message =
                                'Invalid value written. Reload to observe the safe fallback.',
                          );
                        }
                      }),
                child: const Text('Write invalid value'),
              ),
              Builder(
                builder: (buttonContext) => FilledButton.tonal(
                  key: const ValueKey('reload-storage'),
                  onPressed: _busy
                      ? null
                      : () => _run(() async {
                          final applied = await ThemeRevealViewport.of(context)
                              .reveal(
                                from: buttonContext,
                                shape: widget.preferences.shape,
                                config: widget.preferences.config,
                                onThemeChange:
                                    widget.controller.reloadFromStorage,
                              );
                          if (widget.controller.lastPersistenceError != null) {
                            throw StateError(
                              'Could not reload saved theme: ${widget.controller.lastPersistenceError}',
                            );
                          }
                          if (mounted) {
                            setState(
                              () => _message = applied
                                  ? 'Reloaded safely: ${widget.controller.themeMode.name}'
                                  : 'Reload not applied. Wait for the current reveal and try again.',
                            );
                          }
                        }),
                  child: const Text('Reload saved theme'),
                ),
              ),
            ],
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(),
            ),
          if (_message != null)
            Text(_message!, key: const ValueKey('storage-result')),
          if (_error != null)
            Text(_error!, key: const ValueKey('storage-error')),
        ],
      ),
    ),
  );
}
