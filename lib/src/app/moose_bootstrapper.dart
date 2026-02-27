import '../adapter/backend_adapter.dart';
import '../plugin/feature_plugin.dart';
import '../services/app_navigator.dart';
import 'moose_app_context.dart';

/// Summary of a [MooseBootstrapper.run] call.
class BootstrapReport {
  /// Wall-clock time for the entire bootstrap sequence.
  final Duration totalTime;

  /// Per-plugin initialization timings (plugin name → elapsed time).
  final Map<String, Duration> pluginTimings;

  /// Failures that occurred (key = `"adapter:<name>"` or `"plugin:<name>"`).
  final Map<String, Object> failures;

  /// True when no failures occurred.
  bool get succeeded => failures.isEmpty;

  const BootstrapReport({
    required this.totalTime,
    required this.pluginTimings,
    required this.failures,
  });

  @override
  String toString() =>
      'BootstrapReport(${succeeded ? "OK" : "FAILED"}, '
      '${pluginTimings.length} plugins, '
      '${failures.length} failures, '
      'took ${totalTime.inMilliseconds}ms)';
}

/// Orchestrates the moose_core startup sequence against a [MooseAppContext].
///
/// Typical usage inside a splash/bootstrap screen:
///
/// ```dart
/// final report = await MooseBootstrapper(appContext: appContext).run(
///   config: {
///     'plugins': {
///       'products': {'active': true, 'settings': {...}},
///     },
///   },
///   adapters: [WooCommerceAdapter()],
///   plugins: [() => ProductsPlugin()],
/// );
///
/// if (!report.succeeded) {
///   // handle failures
/// }
/// ```
///
/// The bootstrap sequence:
/// 1. Initialize [ConfigManager] with the provided config map.
/// 2. Initialize the scoped [CacheManager] persistent layer.
/// 3. Wire [AppNavigator] to the scoped [EventBus].
/// 4. Register each adapter via [AdapterRegistry].
/// 5. Register each plugin via [PluginRegistry] (sync, injects [MooseAppContext]).
/// 6. Initialize all registered plugins via [PluginRegistry.initializeAll] (async).
class MooseBootstrapper {
  final MooseAppContext appContext;

  MooseBootstrapper({required this.appContext});

  Future<BootstrapReport> run({
    required Map<String, dynamic> config,
    List<BackendAdapter> adapters = const [],
    List<FeaturePlugin Function()> plugins = const [],
  }) async {
    final sw = Stopwatch()..start();
    final timings = <String, Duration>{};
    final failures = <String, Object>{};

    // Step 1: Initialize configuration.
    appContext.configManager.initialize(config);

    // Step 2: Initialize the scoped persistent cache layer.
    await appContext.cache.initPersistent();

    // Step 3: Wire AppNavigator to the scoped EventBus so that navigation
    //         events flow through this context's bus (not a global singleton).
    AppNavigator.setEventBus(appContext.eventBus);

    // Step 4: Register and initialize adapters.
    for (final adapter in adapters) {
      try {
        await appContext.adapterRegistry.registerAdapter(() => adapter);
      } catch (e) {
        failures['adapter:${adapter.name}'] = e;
        appContext.logger.error(
          'Adapter "${adapter.name}" failed to register',
          e,
        );
      }
    }

    // Step 5: Register plugins (sync — injects appContext, calls onRegister).
    for (final factory in plugins) {
      FeaturePlugin? plugin;
      try {
        plugin = factory();
        appContext.pluginRegistry.register(plugin, appContext: appContext);
      } catch (e) {
        final name = plugin?.name ?? 'unknown';
        failures['plugin:$name'] = e;
        appContext.logger.error('Plugin "$name" failed to register', e);
      }
    }

    // Step 6: Initialize all registered plugins (async).
    try {
      await appContext.pluginRegistry.initializeAll(timings: timings);
    } catch (e) {
      failures['plugin:initializeAll'] = e;
      appContext.logger.error('Plugin initialization phase failed', e);
    }

    sw.stop();
    appContext.logger.info(
      'Bootstrap complete in ${sw.elapsed.inMilliseconds}ms '
      '(${timings.length} plugins, ${failures.length} failures)',
    );

    appContext.logger.debug('Plugin timings: $timings');

    return BootstrapReport(
      totalTime: sw.elapsed,
      pluginTimings: timings,
      failures: failures,
    );
  }
}
