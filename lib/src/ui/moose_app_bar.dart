import 'package:flutter/material.dart';

import '../app/moose_scope.dart';
import '../helpers/color_helper.dart';
import '../helpers/text_style_helper.dart';
import '../l10n/moose_l10n.dart';
import '../widgets/feature_section.dart';

/// A sliver app bar section that renders configurable button lists on the left
/// and right sides.
///
/// Use this directly in a [CustomScrollView]'s slivers list:
///
/// ```dart
/// CustomScrollView(
///   slivers: [
///     MooseAppBar(
///       settings: {'title': 'MY STORE', 'pinned': true},
///       leftActions: [backButton],
///       rightActions: [cartButton, searchButton],
///     ),
///     SliverFillRemaining(child: body),
///   ],
/// )
/// ```
///
/// Settings are read via [getSetting] with defaults from [getDefaultSettings].
class MooseAppBar extends FeatureSection {
  final void Function(String event, dynamic payload)? onEvent;
  final List<Widget> leftActions;
  final List<Widget> rightActions;
  final Widget? flexibleSpace;

  const MooseAppBar({
    super.key,
    super.settings,
    this.onEvent,
    List<Widget>? leftActions,
    List<Widget>? rightActions,
    this.flexibleSpace,
  })  : leftActions = leftActions ?? const [],
        rightActions = rightActions ?? const [];

  @override
  Map<String, dynamic> getDefaultSettings() {
    return {
      'titleStyle': {
        'fontSize': 13.0,
        'letterSpacing': 2.0,
        'fontWeight': 'w700',
      },
      'expandedHeight': 0.0,
      'floating': true,
      'pinned': true,
      'elevation': 0.0,
      'actionsEndSpacing': 8.0,
    };
  }

  /// Returns a [Color] from settings if the key is present and non-null,
  /// otherwise returns null so the caller can fall back to the theme.
  Color? _getColorOrNull(String key) {
    final config = {...getDefaultSettings(), ...(settings ?? {})};
    final value = config[key];
    if (value == null) return null;
    return ColorHelper.parse(value);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bgSetting = _getColorOrNull('backgroundColor');
    final fgSetting = _getColorOrNull('foregroundColor');
    return SliverAppBar(
      expandedHeight: getSetting<double>('expandedHeight'),
      floating: getSetting<bool>('floating'),
      pinned: getSetting<bool>('pinned'),
      backgroundColor: bgSetting ?? colorScheme.surface,
      foregroundColor: fgSetting ?? colorScheme.onSurface,
      elevation: getSetting<double>('elevation'),
      title: _buildTitle(context),
      leadingWidth: leftActions.isEmpty ? null : (leftActions.length * 56.0),
      leading: leftActions.isEmpty
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: leftActions,
            ),
      actions: rightActions.isEmpty
          ? null
          : [
              ...rightActions,
              SizedBox(width: getSetting<double>('actionsEndSpacing')),
            ],
      flexibleSpace: flexibleSpace,
    );
  }

  Widget _buildTitle(BuildContext context) {
    final title = settings?.containsKey('title') == true
        ? getSetting<String>('title')
        : '';
    if (title.isEmpty) return const SizedBox.shrink();
    return Text(
      MooseL10n.resolve(title, context.moose.l10n),
      style: TextStyleHelper.fromJson(
          getSetting<Map<String, dynamic>>('titleStyle')),
    );
  }
}
