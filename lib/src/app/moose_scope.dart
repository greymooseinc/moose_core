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
/// Place [MooseScope] at the root of your application (wrapping [MaterialApp])
/// so all descendant widgets can access registries, caches, and services via
/// `context.moose` or the typed static accessors on this class.
///
/// ```dart
/// final ctx = MooseAppContext();
///
/// runApp(
///   MooseScope(
///     appContext: ctx,
///     child: MaterialApp(home: AppBootstrapScreen(appContext: ctx)),
///   ),
/// );
/// ```
///
/// ## Plugin lifecycle
///
/// [MooseScope] automatically attaches a [MooseLifecycleObserver] so that
/// Flutter's [AppLifecycleState] changes are forwarded to every registered
/// plugin. The observer is detached and [PluginRegistry.stopAll] is called
/// when the widget is disposed, or when [appContext] is replaced via
/// [didUpdateWidget].
///
/// ## Accessing the context
///
/// Use the [MooseContextExtension] for the most concise syntax:
///
/// ```dart
/// // From any descendant widget
/// final ctx = context.moose;
/// final repo = ctx.getRepository<ProductsRepository>();
/// ```
///
/// Use the typed static accessors when you only need one registry and want
/// to avoid the intermediate variable:
///
/// ```dart
/// final hooks = MooseScope.hookRegistryOf(context);
/// ```
///
/// See also:
///
///  * [MooseAppContext], the dependency-injection container served by this widget.
///  * [MooseBootstrapper], which initialises the context before the UI runs.
///  * [MooseContextExtension], which adds `context.moose` to [BuildContext].
class MooseScope extends StatefulWidget {
  /// The application context to expose to the widget tree.
  final MooseAppContext appContext;

  /// The widget subtree that has access to [appContext].
  final Widget child;

  /// Creates a [MooseScope] that serves [appContext] to [child] and all
  /// descendants.
  const MooseScope({
    super.key,
    required this.appContext,
    required this.child,
  });

  /// Returns the nearest [MooseAppContext] from the widget tree.
  ///
  /// Throws a descriptive [AssertionError] in debug mode if no [MooseScope]
  /// ancestor is found. In release mode, the assertion is stripped and a
  /// null-dereference will occur — always ensure [MooseScope] wraps your
  /// widget tree before calling this method.
  ///
  /// ```dart
  /// final ctx = MooseScope.of(context);
  /// final user = ctx.currentUser.value;
  /// ```
  ///
  /// See also:
  ///
  ///  * [MooseContextExtension.moose], the shorthand form `context.moose`.
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
  // Typed convenience accessors — identical to of(context).<registry>
  // ---------------------------------------------------------------------------

  /// Returns the [PluginRegistry] from the nearest [MooseScope].
  static PluginRegistry pluginRegistryOf(BuildContext ctx) =>
      of(ctx).pluginRegistry;

  /// Returns the [WidgetRegistry] from the nearest [MooseScope].
  static WidgetRegistry widgetRegistryOf(BuildContext ctx) =>
      of(ctx).widgetRegistry;

  /// Returns the [HookRegistry] from the nearest [MooseScope].
  static HookRegistry hookRegistryOf(BuildContext ctx) => of(ctx).hookRegistry;

  /// Returns the [AddonRegistry] from the nearest [MooseScope].
  static AddonRegistry addonRegistryOf(BuildContext ctx) =>
      of(ctx).addonRegistry;

  /// Returns the [ActionRegistry] from the nearest [MooseScope].
  static ActionRegistry actionRegistryOf(BuildContext ctx) =>
      of(ctx).actionRegistry;

  /// Returns the [AdapterRegistry] from the nearest [MooseScope].
  static AdapterRegistry adapterRegistryOf(BuildContext ctx) =>
      of(ctx).adapterRegistry;

  /// Returns the [ConfigManager] from the nearest [MooseScope].
  static ConfigManager configManagerOf(BuildContext ctx) =>
      of(ctx).configManager;

  /// Returns the [EventBus] from the nearest [MooseScope].
  static EventBus eventBusOf(BuildContext ctx) => of(ctx).eventBus;

  /// Returns the [CacheManager] from the nearest [MooseScope].
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
    // Skip the teardown-and-rewire if the context object has not changed.
    if (identical(oldWidget.appContext, widget.appContext)) return;

    // Detach the old lifecycle observer and stop all plugins on the old context.
    _lifecycleObserver?.detach();
    unawaited(oldWidget.appContext.pluginRegistry.stopAll());

    // Attach a new observer for the incoming context.
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

// The actual InheritedWidget that carries [MooseAppContext] down the tree.
// [MooseScope] is the public-facing StatefulWidget; this is an implementation
// detail and is never referenced directly by application code.
class _MooseScopeInherited extends InheritedWidget {
  final MooseAppContext appContext;

  const _MooseScopeInherited({
    required this.appContext,
    required super.child,
  });

  // Notify dependants only when the context object itself is replaced.
  // Field-level changes inside an existing context (e.g. a new plugin
  // registered) do not trigger a rebuild here — widgets react to those via
  // ValueNotifier listeners or BLoC streams.
  @override
  bool updateShouldNotify(_MooseScopeInherited oldWidget) =>
      !identical(oldWidget.appContext, appContext);
}

/// Convenience extension that adds `context.moose` to [BuildContext].
///
/// Equivalent to `MooseScope.of(context)` but more concise at the call site.
///
/// ```dart
/// // Read the current user from any widget
/// final user = context.moose.currentUser.value;
///
/// // Get a repository
/// final products = context.moose.getRepository<ProductsRepository>();
/// ```
///
/// See also:
///
///  * [MooseScope.of], the underlying lookup this extension calls.
extension MooseContextExtension on BuildContext {
  /// Returns the [MooseAppContext] provided by the nearest [MooseScope].
  MooseAppContext get moose => MooseScope.of(this);
}
