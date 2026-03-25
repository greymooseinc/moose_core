import 'package:flutter/material.dart';

import '../adapter/backend_adapter.dart';
import '../plugin/feature_plugin.dart';
import '../theme/moose_theme.dart';
import 'moose_app_context.dart';
import 'moose_bootstrapper.dart';
import 'moose_scope.dart';

/// A self-contained root widget that bootstraps a moose_core application.
///
/// [MooseApp] handles the full startup lifecycle — creating [MooseAppContext],
/// running [MooseBootstrapper], managing the loading state, and surfacing the
/// app via [builder] once bootstrap completes. It also wraps the widget tree
/// in [MooseScope] so `context.moose` is available to all descendants.
///
/// ## Basic usage
///
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   final config = json.decode(await rootBundle.loadString('config/environment.json'));
///
///   runApp(
///     MooseApp(
///       config: config,
///       adapters: [ShopifyAdapter(), JudgemeAdapter()],
///       plugins: [() => ProductsPlugin(), () => CartPlugin()],
///       builder: (context, appContext) => MyApp(appContext: appContext),
///     ),
///   );
/// }
/// ```
///
/// ## Custom loading screen
///
/// Supply [loadingWidget] to replace the default spinner shown while
/// bootstrapping:
///
/// ```dart
/// MooseApp(
///   config: config,
///   adapters: [...],
///   plugins: [...],
///   builder: (context, appContext) => MyApp(appContext: appContext),
///   loadingWidget: const SplashScreen(),
/// )
/// ```
///
/// See also:
///
///  * [MooseBootstrapper], the underlying bootstrapper this widget drives.
///  * [MooseAppContext], the DI container created internally by this widget.
///  * [MooseScope], which this widget inserts into the tree automatically.
class MooseApp extends StatefulWidget {
  /// Raw configuration map passed to [MooseBootstrapper.run].
  ///
  /// Typically loaded from an `environment.json` asset.
  final Map<String, dynamic> config;

  /// Backend adapters to register during bootstrap.
  ///
  /// Adapters are registered in list order, which determines hook
  /// priority tie-breaking.
  final List<BackendAdapter> adapters;

  /// Plugin factories to register during bootstrap.
  ///
  /// Each entry is a zero-argument factory (`() => MyPlugin()`) so that
  /// plugins are instantiated fresh inside the bootstrap sequence.
  final List<FeaturePlugin Function()> plugins;

  /// Called once bootstrap succeeds; return your root [MaterialApp] here.
  ///
  /// Both [BuildContext] and the fully-initialised [MooseAppContext] are
  /// provided. The context is already available via `context.moose` at this
  /// point because [MooseScope] wraps the tree above [builder]'s output.
  final Widget Function(BuildContext context, MooseAppContext appContext) builder;

  /// Widget shown while the bootstrap sequence is running.
  ///
  /// Defaults to a plain [MaterialApp] containing a centred
  /// [CircularProgressIndicator] if not provided.
  final Widget? loadingWidget;

  /// Themes available to this application.
  ///
  /// The active theme is selected by matching the `"theme"` key in
  /// [config] against each theme's [MooseTheme.name]. If no match is found,
  /// or if [config] has no `"theme"` key, the first entry in the list is used
  /// as the fallback. When the list is empty, no theme hooks are registered
  /// and existing plugin-registered hooks remain in effect.
  ///
  /// ```dart
  /// MooseApp(
  ///   themes: [DefaultTheme(), ColorfulTheme()],
  ///   ...
  /// )
  /// ```
  final List<MooseTheme> themes;

  /// Optional callback invoked with the [BootstrapReport] once the bootstrap
  /// sequence completes — whether it succeeded or not.
  ///
  /// Use this to surface partial failures to an error screen or crash reporter:
  ///
  /// ```dart
  /// MooseApp(
  ///   ...
  ///   onBootstrapComplete: (report) {
  ///     if (!report.succeeded) {
  ///       FirebaseCrashlytics.instance.log('Bootstrap failures: ${report.failures}');
  ///     }
  ///   },
  /// )
  /// ```
  final void Function(BootstrapReport report)? onBootstrapComplete;

  /// Creates a [MooseApp] that manages the full bootstrap lifecycle.
  const MooseApp({
    super.key,
    required this.config,
    required this.adapters,
    required this.plugins,
    required this.builder,
    this.themes = const [],
    this.loadingWidget,
    this.onBootstrapComplete,
  });

  @override
  State<MooseApp> createState() => _MooseAppState();
}

class _MooseAppState extends State<MooseApp> {
  late MooseAppContext _appContext;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _appContext = MooseAppContext();
    _appContext.setReloadHandler(_handleReload);
    _bootstrap(_appContext, widget.config);
  }

  Future<void> _bootstrap(
    MooseAppContext ctx,
    Map<String, dynamic> config, {
    bool setReady = true,
  }) async {
    final report = await MooseBootstrapper(appContext: ctx).run(
      config: config,
      themes: widget.themes,
      adapters: widget.adapters,
      plugins: widget.plugins,
    );
    widget.onBootstrapComplete?.call(report);
    if (setReady && mounted) setState(() => _ready = true);
  }

  /// Called by [MooseAppContext.reloadConfig] when a new config is available.
  ///
  /// Disposes the current context and bootstraps a brand-new one, then swaps
  /// it into the widget tree via [setState]. [MooseScope.didUpdateWidget]
  /// handles stopping the old context's plugins and attaching lifecycle
  /// observers to the new one.
  Future<void> _handleReload(
    Map<String, dynamic> newConfig, {
    bool showLoadingScreen = true,
  }) async {
    final oldCtx = _appContext;

    final newCtx = MooseAppContext();
    newCtx.setReloadHandler(_handleReload);

    // Wait for the current frame to finish before swapping the context.
    // Calling setState mid-build triggers an assertion on Flutter Web.
    await Future.delayed(Duration.zero);

    if (showLoadingScreen) {
      // Swap context and show loading screen while bootstrapping.
      // Dispose old context only after it leaves the widget tree.
      if (mounted) setState(() { _appContext = newCtx; _ready = false; });
      oldCtx.dispose();
      await _bootstrap(newCtx, newConfig);
    } else {
      // Bootstrap silently — old context stays in the tree (and alive) until
      // the new one is ready, then swap and dispose in one atomic update.
      await _bootstrap(newCtx, newConfig, setReady: false);
      if (mounted) setState(() { _appContext = newCtx; _ready = true; });
      oldCtx.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MooseScope(
      appContext: _appContext,
      child: Builder(
        builder: (ctx) {
          if (!_ready) {
            return widget.loadingWidget ?? const _DefaultLoadingWidget();
          }
          return widget.builder(ctx, _appContext);
        },
      ),
    );
  }
}

class _DefaultLoadingWidget extends StatelessWidget {
  const _DefaultLoadingWidget();

  @override
  Widget build(BuildContext context) {
    // Wraps in a WidgetsApp-compatible shell so a bare runApp works without
    // the caller supplying their own MaterialApp during loading.
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(child: CircularProgressIndicator.adaptive()),
      ),
    );
  }
}
