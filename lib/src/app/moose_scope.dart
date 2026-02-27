import 'dart:async';

import 'package:flutter/widgets.dart';

import '../actions/action_registry.dart';
import '../adapter/adapter_registry.dart';
import '../cache/cache_manager.dart';
import '../config/config_manager.dart';
import '../events/event_bus.dart';
import '../events/hook_registry.dart';
import '../plugin/plugin_registry.dart';
import '../widgets/addon_registry.dart';
import '../widgets/widget_registry.dart';
import 'moose_app_context.dart';
import 'moose_lifecycle_observer.dart';

/// Provides a [MooseAppContext] to the widget tree and manages plugin lifecycle
/// observer wiring for that context.
///
/// Place [MooseScope] at the root of your app (wrapping [MaterialApp]) so all
/// descendant widgets can access registries and caches via `context.moose` or
/// the static accessors on this class.
///
/// ```dart
/// final ctx = MooseAppContext();
/// runApp(
///   MooseScope(
///     appContext: ctx,
///     child: MaterialApp(home: AppBootstrapScreen(appContext: ctx)),
///   ),
/// );
/// ```
class MooseScope extends StatefulWidget {
  final MooseAppContext appContext;

  const MooseScope({
    super.key,
    required this.appContext,
    required this.child,
  });

  final Widget child;

  /// Returns the nearest [MooseAppContext] from the widget tree.
  ///
  /// Throws a descriptive [AssertionError] in debug mode if no [MooseScope]
  /// ancestor is found.
  static MooseAppContext of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_MooseScopeInherited>();
    assert(
      scope != null,
      'MooseScope.of() called with a context that does not contain a MooseScope.\n'
      'Ensure your widget tree wraps MaterialApp with MooseScope:\n'
      '\n'
      '  final ctx = MooseAppContext();\n'
      '  MooseScope(appContext: ctx, child: MaterialApp(...))\n',
    );
    return scope!.appContext;
  }

  // ---------------------------------------------------------------------------
  // Convenience static accessors — identical to of(ctx).<registry>
  // ---------------------------------------------------------------------------

  static PluginRegistry pluginRegistryOf(BuildContext ctx) =>
      of(ctx).pluginRegistry;

  static WidgetRegistry widgetRegistryOf(BuildContext ctx) =>
      of(ctx).widgetRegistry;

  static HookRegistry hookRegistryOf(BuildContext ctx) => of(ctx).hookRegistry;

  static AddonRegistry addonRegistryOf(BuildContext ctx) =>
      of(ctx).addonRegistry;

  static ActionRegistry actionRegistryOf(BuildContext ctx) =>
      of(ctx).actionRegistry;

  static AdapterRegistry adapterRegistryOf(BuildContext ctx) =>
      of(ctx).adapterRegistry;

  static ConfigManager configManagerOf(BuildContext ctx) =>
      of(ctx).configManager;

  static EventBus eventBusOf(BuildContext ctx) => of(ctx).eventBus;

  static CacheManager cacheOf(BuildContext ctx) => of(ctx).cache;

  @override
  State<MooseScope> createState() => _MooseScopeState();
}

class _MooseScopeState extends State<MooseScope> {
  MooseLifecycleObserver? _lifecycleObserver;

  @override
  void initState() {
    super.initState();
    _lifecycleObserver = MooseLifecycleObserver(appContext: widget.appContext)
      ..attach();
  }

  @override
  void didUpdateWidget(covariant MooseScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.appContext, widget.appContext)) return;

    _lifecycleObserver?.detach();
    unawaited(oldWidget.appContext.pluginRegistry.stopAll());

    _lifecycleObserver = MooseLifecycleObserver(appContext: widget.appContext)
      ..attach();
  }

  @override
  void dispose() {
    _lifecycleObserver?.detach();
    unawaited(widget.appContext.pluginRegistry.stopAll());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _MooseScopeInherited(
      appContext: widget.appContext,
      child: widget.child,
    );
  }
}

class _MooseScopeInherited extends InheritedWidget {
  final MooseAppContext appContext;

  const _MooseScopeInherited({
    required this.appContext,
    required super.child,
  });

  @override
  bool updateShouldNotify(_MooseScopeInherited oldWidget) =>
      !identical(oldWidget.appContext, appContext);
}

/// Convenience extension so widgets can write `context.moose` instead of
/// `MooseScope.of(context)`.
extension MooseContextExtension on BuildContext {
  /// Returns the [MooseAppContext] provided by the nearest [MooseScope].
  MooseAppContext get moose => MooseScope.of(this);
}
