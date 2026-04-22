import 'package:flutter/material.dart';

import '../adapter/backend_adapter.dart';
import '../plugin/feature_plugin.dart';
import '../theme/moose_theme.dart';
import '../ui/style_hook_data.dart';
import 'moose_app_context.dart';
import 'page_screen.dart';

/// Structured result returned by [MooseBootstrapper.run].
///
/// Inspect [succeeded] for a quick pass/fail check, [failures] for details on
/// any adapter or plugin that failed to initialise, and [pluginTimings] /
/// [pluginStartTimings] for performance diagnostics.
///
/// ```dart
/// final report = await MooseBootstrapper(appContext: ctx).run(...);
///
/// if (!report.succeeded) {
///   for (final entry in report.failures.entries) {
///     logger.error('${entry.key}: ${entry.value}');
///   }
/// }
/// ```
class BootstrapReport {
  /// Wall-clock time for the entire bootstrap sequence.
  final Duration totalTime;

  /// Per-plugin initialisation timings, keyed by plugin name.
  ///
  /// Populated from [PluginRegistry.initAll]; absent when a plugin's `onInit`
  /// throws (the error is recorded in [failures] instead).
  final Map<String, Duration> pluginTimings;

  /// Per-plugin start timings, keyed by plugin name.
  ///
  /// Populated from [PluginRegistry.startAll]; absent when a plugin's `onStart`
  /// throws.
  final Map<String, Duration> pluginStartTimings;

  /// Failures that occurred during bootstrap, keyed by `"adapter:<name>"` or
  /// `"plugin:<name>"`.
  ///
  /// The value is the caught error object. A non-empty map causes [succeeded]
  /// to return `false`.
  final Map<String, Object> failures;

  /// Returns `true` when no failures occurred during bootstrap.
  bool get succeeded => failures.isEmpty;

  /// Creates a bootstrap report with explicit field values.
  ///
  /// All fields are required; the bootstrapper is the only caller.
  const BootstrapReport({
    required this.totalTime,
    required this.pluginTimings,
    required this.pluginStartTimings,
    required this.failures,
  });

  @override
  String toString() => 'BootstrapReport(${succeeded ? "OK" : "FAILED"}, '
      '${pluginTimings.length} plugins, '
      '${pluginStartTimings.length} plugin starts, '
      '${failures.length} failures, '
      'took ${totalTime.inMilliseconds}ms)';
}

/// Orchestrates the moose_core startup sequence against a [MooseAppContext].
///
/// Create one bootstrapper per app context, then call [run] once — typically
/// inside the `initState` of your root bootstrap screen:
///
/// ```dart
/// final report = await MooseBootstrapper(appContext: appContext).run(
///   config: await loadEnvironmentJson(),
///   adapters: [WooCommerceAdapter()],
///   plugins: [() => ProductsPlugin(), () => CartPlugin()],
/// );
///
/// if (!report.succeeded) {
///   // Surface failures to an error screen or analytics.
/// }
/// ```
///
/// ## Bootstrap sequence
///
/// The sequence is strictly ordered. A failure in one step is recorded in
/// [BootstrapReport.failures] but does not abort subsequent steps, so partial
/// initialisation is always reported rather than silently swallowed.
///
/// 1. **Config** — [ConfigManager.initialize] loads the provided config map.
/// 2. **Persistent cache** — [CacheManager.initPersistent] opens the
///    SharedPreferences-backed store.
/// 2b. **Auth restore** — [MooseAppContext.restoreAuthState] reads the last
///    persisted user from the persistent cache so the UI can render
///    user-specific content on the very first frame.
/// 3. **Adapter registration** — each [BackendAdapter] is registered via
///    [AdapterRegistry.registerAdapter]; adapter factories are evaluated lazily.
/// 5. **Plugin registration** — each plugin factory is called, the resulting
///    [FeaturePlugin] is registered via [PluginRegistry.register], which
///    injects [MooseAppContext] and calls [FeaturePlugin.onRegister] (sync).
/// 6. **Plugin init** — [PluginRegistry.initAll] calls each plugin's
///    [FeaturePlugin.onInit] sequentially (in registration order) and records
///    per-plugin timing. Each plugin must complete before the next starts.
/// 7. **Plugin start** — [PluginRegistry.startAll] calls each plugin's
///    [FeaturePlugin.onStart] and records per-plugin timing.
///
/// See also:
///
///  * [MooseAppContext], the DI container consumed by this bootstrapper.
///  * [BootstrapReport], the structured result of [run].
///  * [MooseScope], which must wrap your widget tree to expose the context.
class MooseBootstrapper {
  /// The application context this bootstrapper will initialise.
  final MooseAppContext appContext;

  /// Creates a bootstrapper bound to [appContext].
  MooseBootstrapper({required this.appContext});

  /// Executes the full startup sequence and returns a [BootstrapReport].
  ///
  /// Provide [config] as the raw configuration map (typically parsed from
  /// `environment.json`). Pass [adapters] and [plugins] in the order they
  /// should be registered — registration order determines hook priority
  /// tie-breaking and plugin dependency resolution.
  ///
  /// The returned [BootstrapReport] is safe to inspect immediately after
  /// `await`; it is never null and always contains timing data for every step
  /// that completed, even if later steps failed.
  ///
  /// ```dart
  /// // Inside AppBootstrap.initState
  /// final report = await MooseBootstrapper(appContext: ctx).run(
  ///   config: {'plugins': {'products': {'active': true}}},
  ///   adapters: [WooCommerceAdapter()],
  ///   plugins: [() => ProductsPlugin()],
  /// );
  /// setState(() => _bootstrapReport = report);
  /// ```
  ///
  /// See also:
  ///
  ///  * [BootstrapReport.succeeded], for a quick pass/fail check.
  ///  * [BootstrapReport.failures], for per-adapter and per-plugin error details.
  Future<BootstrapReport> run({
    required Map<String, dynamic> config,
    List<MooseTheme> themes = const [],
    List<BackendAdapter> adapters = const [],
    List<FeaturePlugin Function()> plugins = const [],
  }) async {
    final sw = Stopwatch()..start();
    final timings = <String, Duration>{};
    final startTimings = <String, Duration>{};
    final failures = <String, Object>{};

    // Step 1: Initialize configuration.
    appContext.configManager.initialize(config);

    // Step 1b: Build page routes from the `pages` object in environment.json.
    //
    // Each active entry whose key is a non-empty route path maps to a PageScreen.
    // A fallback `/home` route is added when no page declares that route.
    // These routes are stored on appContext and merged into getAllRoutes().
    _registerPagesRoutes();

    // Step 0 (applied after config): Resolve and wire the active theme.
    //
    // Theme hooks are registered before any plugin, so plugins may still
    // override individual hooks at higher priority if needed.
    if (themes.isNotEmpty) {
      final themeName = appContext.configManager.get('theme') as String?;
      final active = themes.firstWhere(
        (t) => t.name == themeName,
        orElse: () => themes.first,
      );
      _registerThemeHooks(active);
    }

    // Step 2: Initialize the scoped persistent cache layer.
    await appContext.cache.initPersistent();

    // Step 2b: Restore last-known auth state from persistent cache so the UI
    //          can show user-specific content on the first frame, before any
    //          adapter's authStateChanges stream confirms the session.
    await appContext.restoreAuthState();

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
      await appContext.pluginRegistry.initAll(timings: timings);
    } catch (e) {
      failures['plugin:initAll'] = e;
      appContext.logger.error('Plugin init phase failed', e);
    }

    // Step 7: Start all registered plugins (async).
    try {
      await appContext.pluginRegistry.startAll(timings: startTimings);
    } catch (e) {
      failures['plugin:startAll'] = e;
      appContext.logger.error('Plugin start phase failed', e);
    }

    sw.stop();
    appContext.logger.info(
      'Bootstrap complete in ${sw.elapsed.inMilliseconds}ms '
      '(${timings.length} plugins inited, ${startTimings.length} plugins started, ${failures.length} failures)',
    );

    appContext.logger.debug('Plugin timings: $timings');
    appContext.logger.debug('Plugin start timings: $startTimings');

    return BootstrapReport(
      totalTime: sw.elapsed,
      pluginTimings: timings,
      pluginStartTimings: startTimings,
      failures: failures,
    );
  }

  /// Reads the `pages` object from [ConfigManager] and populates
  /// [MooseAppContext.pagesRoutes] with a route builder per active entry.
  ///
  /// Three kinds of page entries are handled:
  ///
  /// ## 1. Plugin-owned pages (`plugin:<name>:<route>`)
  ///
  /// Keys prefixed with `plugin:` are **config-only** entries — the bootstrapper
  /// skips route registration for them. The owning plugin declares the route in
  /// its `getRoutes()` (typically wrapping a BLoC or other stateful setup), and
  /// reads the layout config via `configManager.get('pages')['plugin:name:/route']`.
  ///
  /// ```json
  /// "pages": {
  ///   "plugin:products:/product": { "sections": [...], "bottomBar": {...} }
  /// }
  /// ```
  ///
  /// ## 2. Plugin-provided page slots (`"pageSlotIdentifier"` field)
  ///
  /// Plain-route entries that carry a `"pageSlotIdentifier"` field are dispatched
  /// to the matching plugin's [FeaturePlugin.pageSlots] handler. Each entry gets
  /// its own route, `sections`, `appBar`, and optional `settings` map. The plugin
  /// lookup is deferred to route-build time via [Builder], so plugin registration
  /// order does not matter.
  ///
  /// ```json
  /// "pages": {
  ///   "/products/sale": {
  ///     "pageSlotIdentifier": "plugins/products/slots/product_list",
  ///     "settings": { "filters": { "onSale": true } },
  ///     "appBar": { "title": "SALE" },
  ///     "sections": [{ "name": "moose.products.section.list_grid" }]
  ///   }
  /// }
  /// ```
  ///
  /// ## 3. Auto-route pages
  ///
  /// All other active plain-route entries register a [PageScreen] route:
  ///
  /// ```json
  /// "pages": {
  ///   "/home": { "active": true, "appBar": {}, "sections": [] }
  /// }
  /// ```
  ///
  /// A fallback `/home` route is added when no page entry claims that path.
  void _registerPagesRoutes() {
    final pages = appContext.configManager.get('pages');
    final routes = appContext.pagesRoutes;

    if (pages is Map) {
      for (final entry in pages.entries) {
        final key = entry.key as String;
        if (key.isEmpty) continue;
        if (entry.value is! Map) continue;
        // Keys prefixed with "plugin:" are plugin-owned config-only entries.
        // The owning plugin's getRoutes() registers the actual Flutter route.
        if (key.startsWith('plugin:')) continue;
        final e = (entry.value as Map).cast<String, dynamic>();
        if (e['active'] == false) continue;

        // Plugin-provided page slot: dispatch to the plugin's pageSlots handler.
        final slotId = e['pageSlotIdentifier'] as String?;
        if (slotId != null) {
          final pageConfig = {'route': key, ...e};
          final settings =
              (e['settings'] as Map?)?.cast<String, dynamic>() ?? {};
          routes[key] = (_) => Builder(
                builder: (ctx) {
                  final builder =
                      appContext.pluginRegistry.getPageSlotBuilder(slotId);
                  if (builder == null) return const SizedBox.shrink();
                  // ModalRoute.of(ctx) works here because Builder provides a
                  // context that is a descendant of the ModalRoute element.
                  final routeArgs = ModalRoute.of(ctx)?.settings.arguments;
                  return builder(ctx, pageConfig, settings, routeArgs);
                },
              );
          continue;
        }

        final config = {'route': key, ...e};
        routes[key] = (_) => PageScreen(pageConfig: config);
      }
    }

    if (!routes.containsKey('/home')) {
      routes['/home'] = (_) => const PageScreen(pageConfig: {});
    }
  }

  /// Registers `theme:palette_*` and `styles:*` hooks for [theme].
  ///
  /// Called before plugin registration so plugins can still override
  /// individual hooks at higher priority.
  void _registerThemeHooks(MooseTheme theme) {
    final hooks = appContext.hookRegistry;

    hooks.register('theme:palette_light', (_) => theme.light);
    hooks.register('theme:palette_dark', (_) => theme.dark);

    hooks.register('styles:text', (data) {
      final d = data as StyleHookData;
      return theme.textStyles.resolve(d.name, d.context);
    });

    hooks.register('styles:button', (data) {
      final d = data as StyleHookData;
      return theme.buttonStyles.resolve(d.name, d.context);
    });

    hooks.register('styles:input', (data) {
      final d = data as StyleHookData;
      return theme.inputStyles.resolve(d.name, d.context, d);
    });

    hooks.register('styles:background', (data) {
      final d = data as Map<String, dynamic>;
      return theme.resolveBackground(
        d['name'] as String,
        d['context'] as BuildContext,
        d,
      );
    });

    hooks.register('styles:custom', (data) {
      final d = data as Map<String, dynamic>;
      return theme.resolveCustom(
        d['name'] as String,
        d['context'] as BuildContext,
      );
    });
  }
}
