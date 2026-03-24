import 'package:flutter/material.dart';

import '../ui/app_background_styles.dart';
import '../ui/moose_app_bar.dart';
import 'moose_scope.dart';

/// A config-driven page screen rendered for entries in the top-level `pages`
/// object of `environment.json`.
///
/// The [pageConfig] map is the raw JSON object for one page entry — it drives
/// the app bar (via `appBar` key), the section list (via `sections` key), and
/// an optional bottom bar (via `bottomBar` key).
///
/// ## dataProvider
///
/// Supply [dataProvider] to inject live context (e.g. a product object from a
/// BLoC) into every section, appBar button, and bottomBar widget rendered by
/// this screen. It is called **once per build** and its result is
/// shallow-merged into each widget's `data` map:
///
/// ```dart
/// data: {'settings': sectionSettings, ...extraData}
/// ```
///
/// Sections access the injected values directly via `data['product']`, etc.
///
/// ```dart
/// PageScreen(
///   pageConfig: config,
///   dataProvider: (_) => {
///     'product': state.product,
///     'selectedVariation': state.selectedVariation,
///   },
/// )
/// ```
///
/// ## bottomBar
///
/// Add a `bottomBar` object to the page config to render a
/// `Scaffold.bottomNavigationBar`:
///
/// ```json
/// "bottomBar": {
///   "name": "product.detail.action_bar",
///   "settings": {}
/// }
/// ```
///
/// The `name` is resolved via [WidgetRegistry] and receives the same merged
/// `data` (settings + dataProvider output) as every other section.
///
/// ## appBar buttons
///
/// The `appBar` object may contain `buttonsLeft` and `buttonsRight` arrays,
/// each holding widget-registry entries (`name`, `settings`, `active`).
/// Those entries are resolved via [WidgetRegistry] and passed to [MooseAppBar]
/// as [leftActions] / [rightActions].
class PageScreen extends StatelessWidget {
  final Map<String, dynamic> pageConfig;

  /// Optional. Called once per [build]; the returned map is shallow-merged
  /// into the `data` passed to every section, appBar button, and bottomBar
  /// widget. Use this to inject live BLoC/state data that cannot come from
  /// static JSON config.
  final Map<String, dynamic>? Function(BuildContext)? dataProvider;

  const PageScreen({
    super.key,
    required this.pageConfig,
    this.dataProvider,
  });

  @override
  Widget build(BuildContext context) {
    final widgetRegistry = MooseScope.of(context).widgetRegistry;
    final extraData = dataProvider?.call(context) ?? {};

    final rawSections = pageConfig['sections'] as List? ?? [];
    final appBarConfig = (pageConfig['appBar'] as Map?)?.cast<String, dynamic>();
    final bottomBarConfig =
        (pageConfig['bottomBar'] as Map?)?.cast<String, dynamic>();

    // Build section widgets.
    final sectionWidgets = <Widget>[];
    for (final entry in rawSections.whereType<Map>()) {
      final e = entry.cast<String, dynamic>();
      if (e['active'] == false) continue;
      final name = e['name'] as String? ?? '';
      if (name.isEmpty) continue;
      final settings = (e['settings'] as Map?)?.cast<String, dynamic>() ?? {};
      sectionWidgets.add(
        widgetRegistry.build(
          name,
          context,
          data: {'settings': settings, ...extraData},
        ),
      );
    }

    // Build app bar.
    Widget? appBarWidget;
    if (appBarConfig != null) {
      List<Widget> buildButtons(String key) {
        final raw = appBarConfig[key] as List? ?? [];
        final results = <Widget>[];
        for (final entry in raw.whereType<Map>()) {
          final e = entry.cast<String, dynamic>();
          if (e['active'] == false) continue;
          final name = e['name'] as String? ?? '';
          if (name.isEmpty) continue;
          final s = (e['settings'] as Map?)?.cast<String, dynamic>() ?? {};
          results.add(
            widgetRegistry.build(
              name,
              context,
              data: {'settings': s, ...extraData},
            ),
          );
        }
        return results;
      }

      appBarWidget = MooseAppBar(
        settings: appBarConfig,
        leftActions: buildButtons('buttonsLeft'),
        rightActions: buildButtons('buttonsRight'),
      );
    }

    // Build bottom bar.
    Widget? bottomBarWidget;
    if (bottomBarConfig != null) {
      final name = bottomBarConfig['name'] as String? ?? '';
      if (name.isNotEmpty) {
        final settings =
            (bottomBarConfig['settings'] as Map?)?.cast<String, dynamic>() ??
                {};
        final built = widgetRegistry.build(
          name,
          context,
          data: {'settings': settings, ...extraData},
        );
        // Only use if the registry returned a real widget (not a shrink box).
        if (built is! SizedBox || (built.width != null || built.height != null)) {
          bottomBarWidget = built;
        }
      }
    }

    final scrollView = CustomScrollView(
      slivers: [
        if (appBarWidget != null) appBarWidget,
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < sectionWidgets.length; i++) ...[
                sectionWidgets[i],
                if (i < sectionWidgets.length - 1) const SizedBox(height: 48),
              ],
              const SizedBox(height: 80),
            ],
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackgroundStyles.screenWidget(context, child: scrollView),
      bottomNavigationBar: bottomBarWidget,
    );
  }
}
