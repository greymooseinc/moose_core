import 'dart:convert';

import 'package:flutter/services.dart';

import '../events/hook_registry.dart';

/// Loads and merges multiple config files for [MooseApp] startup.
///
/// Call [loadConfigs] with one or more asset paths. For each path a hook named
/// `moose.config.load_persisted:<assetPath>` is fired; if any registered
/// callback returns a non-null [String] that content is used instead of the
/// bundled asset. This lets plugins such as `ConfigRefreshPlugin` substitute
/// an OTA-downloaded file without `main.dart` importing plugin internals.
///
/// All loaded maps are shallow-merged left-to-right (later files win on scalar
/// and list collisions). After merging, a plugin-by-id deep merge is applied
/// to any `plugins` arrays so that each file can contribute different keys for
/// the same plugin entry without losing the other file's settings.
///
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   final config = await loadConfigs(
///     ['assets/config/environment.json', 'assets/config/layout.json'],
///   );
///   runApp(MooseApp(config: config, ...));
/// }
/// ```
Future<Map<String, dynamic>> loadConfigs(
  List<String> assetPaths, {
  HookRegistry? hookRegistry,
}) async {
  final futures = assetPaths.map((p) => _loadOne(p, hookRegistry));
  final maps = await Future.wait(futures);
  return maps.fold<Map<String, dynamic>>({}, _mergeTwo);
}

Future<Map<String, dynamic>> _loadOne(
  String assetPath,
  HookRegistry? hookRegistry,
) async {
  if (hookRegistry != null) {
    try {
      final persisted = await hookRegistry.executeAsync<String?>(
        'moose.config.load_persisted:$assetPath',
        null,
      );
      if (persisted != null) {
        return json.decode(persisted) as Map<String, dynamic>;
      }
    } catch (_) {
      // Fall through to bundled asset on any hook or decode error.
    }
  }
  final assetJson = await rootBundle.loadString(assetPath);
  return json.decode(assetJson) as Map<String, dynamic>;
}

/// Shallow-merges [b] into [a], with a plugin-by-id deep merge for `plugins`.
Map<String, dynamic> _mergeTwo(
  Map<String, dynamic> a,
  Map<String, dynamic> b,
) {
  final merged = <String, dynamic>{...a, ...b};

  final aPlugins = a['plugins'];
  final bPlugins = b['plugins'];
  if (aPlugins is List && bPlugins is List) {
    final byId = <String, Map<String, dynamic>>{};
    for (final entry in aPlugins) {
      if (entry is Map<String, dynamic>) {
        final id = entry['id'] as String?;
        if (id != null) byId[id] = Map<String, dynamic>.from(entry);
      }
    }
    for (final entry in bPlugins) {
      if (entry is Map<String, dynamic>) {
        final id = entry['id'] as String?;
        if (id != null) {
          byId[id] = <String, dynamic>{...(byId[id] ?? {}), ...entry};
        }
      }
    }
    merged['plugins'] = byId.values.toList();
  }

  return merged;
}
