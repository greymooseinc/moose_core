import 'package:flutter/widgets.dart';

import '../actions/action_registry.dart';
import '../adapter/adapter_registry.dart';
import '../config/config_manager.dart';
import '../events/event_bus.dart';
import '../events/hook_registry.dart';
import '../plugin/plugin_registry.dart';
import '../widgets/addon_registry.dart';
import '../widgets/widget_registry.dart';
import 'moose_app_context.dart';

/// InheritedWidget that provides a [MooseAppContext] to the widget tree.
///
/// Place [MooseScope] at the root of your app (wrapping [MaterialApp]) so all
/// descendant widgets can access registries via `context.moose` or the static
/// accessors on this class.
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
class MooseScope extends InheritedWidget {
  final MooseAppContext appContext;

  const MooseScope({
    super.key,
    required this.appContext,
    required super.child,
  });

  /// Returns the nearest [MooseAppContext] from the widget tree.
  ///
  /// Throws a descriptive [AssertionError] in debug mode if no [MooseScope]
  /// ancestor is found.
  static MooseAppContext of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<MooseScope>();
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

  static HookRegistry hookRegistryOf(BuildContext ctx) =>
      of(ctx).hookRegistry;

  static AddonRegistry addonRegistryOf(BuildContext ctx) =>
      of(ctx).addonRegistry;

  static ActionRegistry actionRegistryOf(BuildContext ctx) =>
      of(ctx).actionRegistry;

  static AdapterRegistry adapterRegistryOf(BuildContext ctx) =>
      of(ctx).adapterRegistry;

  static ConfigManager configManagerOf(BuildContext ctx) =>
      of(ctx).configManager;

  static EventBus eventBusOf(BuildContext ctx) => of(ctx).eventBus;

  @override
  bool updateShouldNotify(MooseScope oldWidget) =>
      !identical(oldWidget.appContext, appContext);
}

/// Convenience extension so widgets can write `context.moose` instead of
/// `MooseScope.of(context)`.
extension MooseContextExtension on BuildContext {
  /// Returns the [MooseAppContext] provided by the nearest [MooseScope].
  MooseAppContext get moose => MooseScope.of(this);
}
