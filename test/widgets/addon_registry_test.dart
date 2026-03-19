// Tests formerly covering AddonRegistry, now migrated to WidgetRegistry
// after AddonRegistry was merged in (v2.3.0).
//
// API mapping:
//   register(key, builder, priority:)  →  registerWidget(key, builder, priority:)
//   build(key, ctx, ...)               →  buildAll(key, ctx, ...)   → List<Widget>
//   hasAddon(key)                      →  isRegistered(key)
//   getRegisteredAddons()              →  getRegisteredWidgets()
//   clearAddons(key)                   →  unregister(key)
//   clearAllAddons()                   →  for each key: unregister(key)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moose_core/widgets.dart';

/// Clears all keys in [registry].
void _clearAll(WidgetRegistry registry) {
  for (final key in registry.getRegisteredWidgets()) {
    registry.unregister(key);
  }
}

void main() {
  group('WidgetRegistry (addon-slot coverage)', () {
    late WidgetRegistry registry;

    setUp(() {
      registry = WidgetRegistry();
      _clearAll(registry);
    });

    tearDown(() {
      _clearAll(registry);
    });

    // =========================================================================
    // Instance Isolation
    // =========================================================================

    group('Instance Isolation', () {
      test('each WidgetRegistry() creates an independent instance', () {
        final registry1 = WidgetRegistry();
        final registry2 = WidgetRegistry();

        registry1.registerWidget('zone.a', (ctx, {data, onEvent}) => const SizedBox());
        expect(registry1.isRegistered('zone.a'), isTrue);
        expect(registry2.isRegistered('zone.a'), isFalse);
      });
    });

    // =========================================================================
    // Registration
    // =========================================================================

    group('Widget Registration', () {
      test('registers a widget builder', () {
        registry.registerWidget(
          'test.zone',
          (context, {data, onEvent}) => const Text('Addon'),
        );

        expect(registry.isRegistered('test.zone'), isTrue);
      });

      test('registers with custom priority', () {
        registry.registerWidget(
          'test.zone',
          (context, {data, onEvent}) => const Text('High Priority'),
          priority: 10,
        );

        expect(registry.isRegistered('test.zone'), isTrue);
      });

      testWidgets('supports multiple builders in the same slot', (tester) async {
        registry.registerWidget('test.zone', (ctx, {data, onEvent}) => const Text('Addon 1'));
        registry.registerWidget('test.zone', (ctx, {data, onEvent}) => const Text('Addon 2'));
        registry.registerWidget('test.zone', (ctx, {data, onEvent}) => const Text('Addon 3'));

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Builder(builder: (ctx) {
              final widgets = registry.buildAll('test.zone', ctx);
              expect(widgets.length, 3);
              return Column(children: widgets);
            }),
          ),
        ));
      });

      test('tracks registered slot keys', () {
        registry.registerWidget('zone1', (ctx, {data, onEvent}) => const Text('A'));
        registry.registerWidget('zone2', (ctx, {data, onEvent}) => const Text('B'));

        final zones = registry.getRegisteredWidgets();
        expect(zones, contains('zone1'));
        expect(zones, contains('zone2'));
      });
    });

    // =========================================================================
    // Priority Sorting
    // =========================================================================

    group('Priority Sorting', () {
      testWidgets('renders widgets in priority order (highest first)', (tester) async {
        registry.registerWidget(
          'test.zone',
          (ctx, {data, onEvent}) => const Text('Low Priority'),
          priority: 1,
        );
        registry.registerWidget(
          'test.zone',
          (ctx, {data, onEvent}) => const Text('High Priority'),
          priority: 10,
        );
        registry.registerWidget(
          'test.zone',
          (ctx, {data, onEvent}) => const Text('Medium Priority'),
          priority: 5,
        );

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Builder(builder: (ctx) {
              final widgets = registry.buildAll('test.zone', ctx);
              return Column(children: widgets);
            }),
          ),
        ));

        final texts = tester.widgetList<Text>(find.byType(Text)).toList();
        expect(texts[0].data, 'High Priority');
        expect(texts[1].data, 'Medium Priority');
        expect(texts[2].data, 'Low Priority');
      });
    });

    // =========================================================================
    // buildAll
    // =========================================================================

    group('buildAll', () {
      testWidgets('builds all widgets in slot', (tester) async {
        registry.registerWidget('test.zone', (ctx, {data, onEvent}) => const Text('Addon 1'));
        registry.registerWidget('test.zone', (ctx, {data, onEvent}) => const Text('Addon 2'));

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Builder(builder: (ctx) {
              return Column(children: registry.buildAll('test.zone', ctx));
            }),
          ),
        ));

        expect(find.text('Addon 1'), findsOneWidget);
        expect(find.text('Addon 2'), findsOneWidget);
      });

      testWidgets('returns empty list for unknown slot', (tester) async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Builder(builder: (ctx) {
              expect(registry.buildAll('unknown.zone', ctx), isEmpty);
              return const SizedBox.shrink();
            }),
          ),
        ));
      });

      testWidgets('filters out null widgets', (tester) async {
        registry.registerWidget('test.zone', (ctx, {data, onEvent}) => const Text('Valid Widget'));
        registry.registerWidget('test.zone', (ctx, {data, onEvent}) => null);
        registry.registerWidget('test.zone', (ctx, {data, onEvent}) => const Text('Another Valid Widget'));

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Builder(builder: (ctx) {
              final widgets = registry.buildAll('test.zone', ctx);
              expect(widgets.length, 2);
              return Column(children: widgets);
            }),
          ),
        ));

        expect(find.text('Valid Widget'), findsOneWidget);
        expect(find.text('Another Valid Widget'), findsOneWidget);
      });

      testWidgets('handles builder errors gracefully', (tester) async {
        registry.registerWidget('test.zone', (ctx, {data, onEvent}) => const Text('Good Addon'));
        registry.registerWidget('test.zone', (ctx, {data, onEvent}) => throw Exception('Addon Error'));
        registry.registerWidget('test.zone', (ctx, {data, onEvent}) => const Text('Another Good Addon'));

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Builder(builder: (ctx) {
              return Column(children: registry.buildAll('test.zone', ctx));
            }),
          ),
        ));

        expect(find.text('Good Addon'), findsOneWidget);
        expect(find.text('Another Good Addon'), findsOneWidget);
      });

      testWidgets('passes data to widget builders', (tester) async {
        String? receivedData;

        registry.registerWidget('test.zone', (ctx, {data, onEvent}) {
          receivedData = data?['message'] as String?;
          return Text(receivedData ?? 'No data');
        });

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Builder(builder: (ctx) {
              return Column(
                children: registry.buildAll(
                  'test.zone',
                  ctx,
                  data: {'message': 'Hello Addon'},
                ),
              );
            }),
          ),
        ));

        expect(receivedData, 'Hello Addon');
        expect(find.text('Hello Addon'), findsOneWidget);
      });

      testWidgets('forwards onEvent callback', (tester) async {
        String? eventName;
        dynamic eventPayload;

        registry.registerWidget('test.zone', (ctx, {data, onEvent}) {
          onEvent?.call('addon_event', {'value': 123});
          return const Text('Addon');
        });

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Builder(builder: (ctx) {
              return Column(
                children: registry.buildAll(
                  'test.zone',
                  ctx,
                  onEvent: (event, payload) {
                    eventName = event;
                    eventPayload = payload;
                  },
                ),
              );
            }),
          ),
        ));

        expect(eventName, 'addon_event');
        expect(eventPayload, {'value': 123});
      });

      testWidgets('handles null data', (tester) async {
        registry.registerWidget('test.zone', (ctx, {data, onEvent}) => const Text('Addon'));

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Builder(builder: (ctx) {
              return Column(children: registry.buildAll('test.zone', ctx, data: null));
            }),
          ),
        ));

        expect(find.text('Addon'), findsOneWidget);
      });

      testWidgets('handles null onEvent', (tester) async {
        registry.registerWidget('test.zone', (ctx, {data, onEvent}) => const Text('Addon'));

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Builder(builder: (ctx) {
              return Column(children: registry.buildAll('test.zone', ctx, onEvent: null));
            }),
          ),
        ));

        expect(find.text('Addon'), findsOneWidget);
      });
    });

    // =========================================================================
    // unregister (replaces clearAddons / clearAllAddons / removeAddon)
    // =========================================================================

    group('unregister', () {
      test('removes all builders for a key', () {
        registry.registerWidget('test.zone', (ctx, {data, onEvent}) => const Text('Addon 1'));
        registry.registerWidget('test.zone', (ctx, {data, onEvent}) => const Text('Addon 2'));

        expect(registry.isRegistered('test.zone'), isTrue);

        registry.unregister('test.zone');

        expect(registry.isRegistered('test.zone'), isFalse);
      });

      test('clearing one slot does not affect other slots', () {
        registry.registerWidget('zone1', (ctx, {data, onEvent}) => const Text('A'));
        registry.registerWidget('zone2', (ctx, {data, onEvent}) => const Text('B'));

        registry.unregister('zone1');

        expect(registry.isRegistered('zone1'), isFalse);
        expect(registry.isRegistered('zone2'), isTrue);
      });

      test('clearing all slots leaves registry empty', () {
        registry.registerWidget('zone1', (ctx, {data, onEvent}) => const Text('A'));
        registry.registerWidget('zone2', (ctx, {data, onEvent}) => const Text('B'));

        expect(registry.getRegisteredWidgets().length, 2);

        _clearAll(registry);

        expect(registry.getRegisteredWidgets().length, 0);
      });

      test('handles unregistering non-existent key gracefully', () {
        expect(() => registry.unregister('no.such.zone'), returnsNormally);
      });
    });

    // =========================================================================
    // isRegistered
    // =========================================================================

    group('isRegistered', () {
      test('returns true when slot has builders', () {
        registry.registerWidget('test.zone', (ctx, {data, onEvent}) => const Text('Addon'));
        expect(registry.isRegistered('test.zone'), isTrue);
      });

      test('returns false for unknown slot', () {
        expect(registry.isRegistered('empty.zone'), isFalse);
      });

      test('returns false after unregister', () {
        registry.registerWidget('test.zone', (ctx, {data, onEvent}) => const Text('Addon'));
        registry.unregister('test.zone');
        expect(registry.isRegistered('test.zone'), isFalse);
      });
    });

    // =========================================================================
    // Multiple Zones
    // =========================================================================

    group('Multiple Zones', () {
      testWidgets('supports independent slots', (tester) async {
        registry.registerWidget('zone1', (ctx, {data, onEvent}) => const Text('Zone 1 Addon'));
        registry.registerWidget('zone2', (ctx, {data, onEvent}) => const Text('Zone 2 Addon'));

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Builder(builder: (ctx) {
              return Column(children: [
                ...registry.buildAll('zone1', ctx),
                ...registry.buildAll('zone2', ctx),
              ]);
            }),
          ),
        ));

        expect(find.text('Zone 1 Addon'), findsOneWidget);
        expect(find.text('Zone 2 Addon'), findsOneWidget);
      });
    });

    // =========================================================================
    // Edge Cases
    // =========================================================================

    group('Edge Cases', () {
      test('empty string key is valid', () {
        registry.registerWidget('', (ctx, {data, onEvent}) => const Text('Addon'));
        expect(registry.isRegistered(''), isTrue);
      });
    });
  });
}
