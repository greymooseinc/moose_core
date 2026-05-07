import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:moose_core/app.dart';
import 'package:moose_core/src/events/hook_registry.dart';

/// Builds a [HookRegistry] that serves [content] for every [assetPath] via the
/// `moose.config.load_persisted:<assetPath>` hook, bypassing rootBundle entirely.
HookRegistry _hookFor(Map<String, Map<String, dynamic>> contentByPath) {
  final registry = HookRegistry();
  for (final entry in contentByPath.entries) {
    final hookName = 'moose.config.load_persisted:${entry.key}';
    final jsonStr = json.encode(entry.value);
    registry.register(hookName, (_) => jsonStr);
  }
  return registry;
}

void main() {
  group('loadConfigs merge', () {
    test('later file keys overwrite earlier file keys', () async {
      final registry = _hookFor({
        'env.json': {'version': '1.0.0', 'foo': 'from-env'},
        'layout.json': {'version': '2.0.0', 'theme': 'colorful'},
      });
      final merged = await loadConfigs(
        ['env.json', 'layout.json'],
        hookRegistry: registry,
      );
      expect(merged['version'], equals('2.0.0'));
      expect(merged['foo'], equals('from-env'));
      expect(merged['theme'], equals('colorful'));
    });

    test('keys only in earlier file are preserved', () async {
      final registry = _hookFor({
        'env.json': {
          'version': '1.0.0',
          'adapters': [
            {'id': 'shopify'}
          ],
        },
        'layout.json': {'layoutVersion': '1.0.0', 'pages': <dynamic>[]},
      });
      final merged = await loadConfigs(
        ['env.json', 'layout.json'],
        hookRegistry: registry,
      );
      expect((merged['adapters'] as List).length, equals(1));
      expect(merged['pages'], isNotNull);
    });

    test('plugins are merged by id across files', () async {
      final registry = _hookFor({
        'env.json': {
          'plugins': [
            {'id': 'search', 'description': 'Product search'},
            {'id': 'cart', 'active': true},
          ],
        },
        'layout.json': {
          'plugins': [
            {
              'id': 'search',
              'sections': {
                'extra': [
                  {'name': 'moose.search.section.results'}
                ]
              }
            }
          ],
        },
      });
      final merged = await loadConfigs(
        ['env.json', 'layout.json'],
        hookRegistry: registry,
      );
      final plugins = merged['plugins'] as List;
      expect(plugins.length, equals(2));
      final search =
          plugins.firstWhere((p) => (p as Map)['id'] == 'search') as Map;
      expect(search['description'], equals('Product search'));
      expect(search['sections'], isNotNull);
      final cart =
          plugins.firstWhere((p) => (p as Map)['id'] == 'cart') as Map;
      expect(cart['active'], isTrue);
    });

    test('plugins only in first file are preserved unchanged', () async {
      final registry = _hookFor({
        'env.json': {
          'plugins': [
            {
              'id': 'checkout',
              'active': true,
              'settings': {'mode': 'web'}
            },
          ],
        },
        'layout.json': {'pages': <dynamic>[]},
      });
      final merged = await loadConfigs(
        ['env.json', 'layout.json'],
        hookRegistry: registry,
      );
      final plugins = merged['plugins'] as List;
      expect(plugins.length, equals(1));
      expect((plugins.first as Map)['settings']['mode'], equals('web'));
    });

    test('hook returning null falls through to next hook (no null content)', () async {
      final registry = HookRegistry();
      // First hook returns null — should be ignored.
      registry.register('moose.config.load_persisted:env.json', (_) => null,
          priority: 10);
      // Second hook (lower priority) returns real content.
      registry.register(
        'moose.config.load_persisted:env.json',
        (_) => json.encode({'version': '3.0.0'}),
        priority: 1,
      );
      // layout served normally
      registry.register(
        'moose.config.load_persisted:layout.json',
        (_) => json.encode({'pages': <dynamic>[]}),
      );
      final merged = await loadConfigs(
        ['env.json', 'layout.json'],
        hookRegistry: registry,
      );
      // The null result means the hook chain returned null → falls through to
      // the next registered hook which returns real content.
      expect(merged['version'], equals('3.0.0'));
    });

    test('single path returns that file unchanged', () async {
      final registry = _hookFor({
        'env.json': {'version': '1.0.0', 'adapters': <dynamic>[]},
      });
      final merged =
          await loadConfigs(['env.json'], hookRegistry: registry);
      expect(merged['version'], equals('1.0.0'));
      expect(merged['adapters'], isNotNull);
    });
  });
}
