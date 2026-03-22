import 'package:flutter/material.dart';

import '../ui/app_background_styles.dart';
import '../ui/moose_app_bar.dart';
import 'moose_scope.dart';

/// A config-driven page screen rendered for entries in the top-level `pages`
/// array of `environment.json`.
///
/// The [pageConfig] map is the raw JSON object for one page entry — it drives
/// the app bar (via `appBar` key) and the section list (via `sections` key).
///
/// The `appBar` object may contain `buttonsLeft` and `buttonsRight` arrays,
/// each holding widget-registry entries (`name`, `settings`, `active`).
/// Those entries are resolved via [WidgetRegistry] and passed to [MooseAppBar]
/// as [leftActions] / [rightActions].
class PageScreen extends StatelessWidget {
  final Map<String, dynamic> pageConfig;

  const PageScreen({super.key, required this.pageConfig});

  @override
  Widget build(BuildContext context) {
    final widgetRegistry = MooseScope.of(context).widgetRegistry;
    final rawSections = pageConfig['sections'] as List? ?? [];
    final appBarConfig = (pageConfig['appBar'] as Map?)?.cast<String, dynamic>();

    final sectionWidgets = <Widget>[];
    for (final entry in rawSections.whereType<Map>()) {
      final e = entry.cast<String, dynamic>();
      if (e['active'] == false) continue;
      final name = e['name'] as String? ?? '';
      if (name.isEmpty) continue;
      final settings = (e['settings'] as Map?)?.cast<String, dynamic>() ?? {};
      sectionWidgets.add(
        widgetRegistry.build(name, context, data: {'settings': settings}),
      );
    }

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
          final w = widgetRegistry.build(name, context, data: {'settings': s});
          results.add(w);
        }
        return results;
      }

      appBarWidget = MooseAppBar(
        settings: appBarConfig,
        leftActions: buildButtons('buttonsLeft'),
        rightActions: buildButtons('buttonsRight'),
      );
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
    );
  }
}
