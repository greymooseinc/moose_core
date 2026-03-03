import 'package:flutter/widgets.dart';

import 'moose_app_context.dart';

/// Bridges Flutter's [AppLifecycleState] changes to all registered plugins in
/// a [MooseAppContext].
///
/// [MooseLifecycleObserver] implements [WidgetsBindingObserver] and forwards
/// each [didChangeAppLifecycleState] notification to
/// [PluginRegistry.notifyAppLifecycle], which in turn calls
/// [FeaturePlugin.onAppLifecycle] on every registered plugin.
///
/// [MooseScope] creates and manages one observer per context — application code
/// does not need to instantiate this class directly.
///
/// ```dart
/// // MooseScope handles this automatically; shown here for reference only.
/// final observer = MooseLifecycleObserver(appContext: ctx)..attach();
/// // … later, on teardown:
/// observer.detach();
/// ```
///
/// See also:
///
///  * [MooseScope], which owns this observer's lifetime.
///  * [FeaturePlugin.onAppLifecycle], the per-plugin callback invoked by this
///    observer.
class MooseLifecycleObserver with WidgetsBindingObserver {
  /// The application context whose plugins receive lifecycle notifications.
  final MooseAppContext appContext;

  // Whether this observer is currently registered with WidgetsBinding.
  // Guards against double-attach and double-detach.
  bool _attached = false;

  /// Creates a lifecycle observer for [appContext].
  ///
  /// Call [attach] to begin receiving notifications.
  MooseLifecycleObserver({required this.appContext});

  /// Registers this observer with [WidgetsBinding] to start receiving
  /// [AppLifecycleState] notifications.
  ///
  /// A no-op if the observer is already attached. [MooseScope] calls this
  /// inside `initState` and whenever [appContext] is replaced.
  void attach() {
    if (_attached) return;
    WidgetsBinding.instance.addObserver(this);
    _attached = true;
  }

  /// Unregisters this observer from [WidgetsBinding] to stop receiving
  /// [AppLifecycleState] notifications.
  ///
  /// A no-op if the observer is not currently attached. [MooseScope] calls
  /// this in `dispose` and whenever [appContext] is replaced.
  void detach() {
    if (!_attached) return;
    WidgetsBinding.instance.removeObserver(this);
    _attached = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Fire-and-forget: WidgetsBindingObserver callbacks are synchronous, so
    // the async plugin notifications run detached from this call frame.
    appContext.pluginRegistry.notifyAppLifecycle(state);
  }
}
