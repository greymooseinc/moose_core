// ignore_for_file: public_member_api_docs
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
///
/// ## App bar extension slot — `moose.core.slot.page_screen:app_bar`
///
/// Register a widget under this slot key to replace the default [MooseAppBar]
/// on any [PageScreen] that has an `appBar` config. The default [MooseAppBar]
/// is used as fallback when no registration is found.
///
/// The slot receives the following `data` keys:
///
/// | Key | Type | Description |
/// |---|---|---|
/// | `appBarConfig` | `Map<String, dynamic>` | Raw `appBar` object from the page config (title, floating, pinned, transparent, etc.) |
/// | `leftActions` | `List<Widget>` | Pre-built left action widgets resolved from `buttonsLeft` |
/// | `rightActions` | `List<Widget>` | Pre-built right action widgets resolved from `buttonsRight` |
/// | `pageConfig` | `Map<String, dynamic>` | Full page config for the current screen |
///
/// The builder must return a sliver widget (e.g. [SliverAppBar]) because it is
/// placed directly in a [CustomScrollView]'s slivers list.
///
/// ### Example — custom animated app bar
///
/// ```dart
/// widgetRegistry.registerWidget(
///   'moose.core.slot.page_screen:app_bar',
///   (context, {data, onEvent}) {
///     final config = data?['appBarConfig'] as Map<String, dynamic>? ?? {};
///     final left = data?['leftActions'] as List<Widget>? ?? [];
///     final right = data?['rightActions'] as List<Widget>? ?? [];
///     return MyCustomSliverAppBar(
///       settings: config,
///       leftActions: left,
///       rightActions: right,
///     );
///   },
/// );
/// ```
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

      final leftActions = buildButtons('buttonsLeft');
      final rightActions = buildButtons('buttonsRight');

      appBarWidget = widgetRegistry.build(
        'moose.core.slot.page_screen:app_bar',
        context,
        data: {
          'appBarConfig': appBarConfig,
          'leftActions': leftActions,
          'rightActions': rightActions,
          'pageConfig': pageConfig,
        },
        fallback: MooseAppBar(
          settings: appBarConfig,
          leftActions: leftActions,
          rightActions: rightActions,
        ),
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

    final isTransparentAppBar = appBarConfig?['transparent'] == true;

    final scrollView = CustomScrollView(
      slivers: [
        if (appBarWidget != null && !isTransparentAppBar) appBarWidget,
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

    Widget body = AppBackgroundStyles.screenWidget(context, child: scrollView);

    // Transparent app bar: overlay buttons above the scroll content so the
    // first section starts at position 0 instead of below the app bar.
    // The overlay is capped to kToolbarHeight + status bar so touches below
    // the button area fall through to the scrollable content.
    if (isTransparentAppBar && appBarWidget != null) {
      body = Stack(
        children: [
          body,
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).padding.top + kToolbarHeight,
            child: CustomScrollView(
              slivers: [appBarWidget],
              physics: const NeverScrollableScrollPhysics(),
            ),
          ),
        ],
      );
    }

    final scaffold = Scaffold(
      backgroundColor: Colors.transparent,
      body: body,
      bottomNavigationBar: bottomBarWidget,
    );

    // When using a transparent overlay app bar, remove the top MediaQuery
    // padding before Scaffold sees it so the body is laid out from y=0.
    // Scaffold uses MediaQuery.padding.top to inset the body below the
    // status bar; stripping it here lets content start at the screen edge.
    if (isTransparentAppBar) {
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(
          padding: MediaQuery.of(context).padding.copyWith(top: 0),
        ),
        child: scaffold,
      );
    }
    return scaffold;
  }
}
