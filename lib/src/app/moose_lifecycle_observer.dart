import 'package:flutter/widgets.dart';

import 'moose_app_context.dart';

/// Bridges Flutter app lifecycle changes to registered moose plugins.
class MooseLifecycleObserver with WidgetsBindingObserver {
  final MooseAppContext appContext;
  bool _attached = false;

  MooseLifecycleObserver({required this.appContext});

  /// Starts observing Flutter lifecycle notifications.
  void attach() {
    if (_attached) return;
    WidgetsBinding.instance.addObserver(this);
    _attached = true;
  }

  /// Stops observing Flutter lifecycle notifications.
  void detach() {
    if (!_attached) return;
    WidgetsBinding.instance.removeObserver(this);
    _attached = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Fire-and-forget: WidgetsBindingObserver callback is synchronous.
    appContext.pluginRegistry.notifyAppLifecycle(state);
  }
}
