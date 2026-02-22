import '../actions/action_registry.dart';
import '../adapter/adapter_registry.dart';
import '../config/config_manager.dart';
import '../events/event_bus.dart';
import '../events/hook_registry.dart';
import '../plugin/plugin_registry.dart';
import '../utils/logger.dart';
import '../widgets/addon_registry.dart';
import '../widgets/widget_registry.dart';

/// App-scoped container holding all registries and managers for a moose_core instance.
///
/// Create one [MooseAppContext] per app (or per isolated test), then pass it to
/// [MooseScope] so widgets can access it via `context.moose`.
///
/// ```dart
/// final ctx = MooseAppContext();
/// runApp(MooseScope(appContext: ctx, child: MyApp()));
/// ```
///
/// All optional constructor parameters allow injection of custom or mock instances
/// for testing:
///
/// ```dart
/// final ctx = MooseAppContext(
///   hookRegistry: MockHookRegistry(),
///   configManager: MockConfigManager(),
/// );
/// ```
class MooseAppContext {
  final PluginRegistry pluginRegistry;
  final WidgetRegistry widgetRegistry;
  final HookRegistry hookRegistry;
  final AddonRegistry addonRegistry;
  final ActionRegistry actionRegistry;
  final AdapterRegistry adapterRegistry;
  final ConfigManager configManager;
  final EventBus eventBus;
  final AppLogger logger;

  MooseAppContext({
    PluginRegistry? pluginRegistry,
    WidgetRegistry? widgetRegistry,
    HookRegistry? hookRegistry,
    AddonRegistry? addonRegistry,
    ActionRegistry? actionRegistry,
    AdapterRegistry? adapterRegistry,
    ConfigManager? configManager,
    EventBus? eventBus,
    AppLogger? logger,
  })  : configManager = configManager ?? ConfigManager(),
        hookRegistry = hookRegistry ?? HookRegistry(),
        addonRegistry = addonRegistry ?? AddonRegistry(),
        actionRegistry = actionRegistry ?? ActionRegistry(),
        adapterRegistry = adapterRegistry ?? AdapterRegistry(),
        eventBus = eventBus ?? EventBus(),
        logger = logger ?? AppLogger('MooseApp'),
        pluginRegistry = pluginRegistry ?? PluginRegistry(),
        widgetRegistry = widgetRegistry ?? WidgetRegistry() {
    // Wire WidgetRegistry to the scoped ConfigManager (post-construction to avoid
    // circular initializer-list dependency).
    this.widgetRegistry.setConfigManager(this.configManager);
    // Wire AdapterRegistry to scoped dependencies.
    this.adapterRegistry.setDependencies(
      configManager: this.configManager,
      hookRegistry: this.hookRegistry,
      eventBus: this.eventBus,
    );
  }
}
