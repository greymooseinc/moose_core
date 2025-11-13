import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moose_core/widgets.dart';

void main() {
  group('AddonRegistry', () {
    late AddonRegistry registry;

    setUp(() {
      registry = AddonRegistry();
      // Clear all addons before each test
      registry.clearAllAddons();
    });

    tearDown(() {
      registry.clearAllAddons();
    });

    group('Singleton Pattern', () {
      test('should return same instance', () {
        final registry1 = AddonRegistry();
        final registry2 = AddonRegistry();

        expect(identical(registry1, registry2), true);
      });

      test('should access via instance getter', () {
        final registry1 = AddonRegistry.instance;
        final registry2 = AddonRegistry();

        expect(identical(registry1, registry2), true);
      });
    });

    group('Addon Registration', () {
      test('should register addon', () {
        registry.register(
          'test.zone',
          (context, {data, onEvent}) => const Text('Addon'),
        );

        expect(registry.hasAddon('test.zone'), true);
      });

      test('should register addon with custom priority', () {
        registry.register(
          'test.zone',
          (context, {data, onEvent}) => const Text('High Priority'),
          priority: 10,
        );

        expect(registry.getAddonCount('test.zone'), 1);
      });

      test('should support multiple addons in same zone', () {
        registry.register(
          'test.zone',
          (context, {data, onEvent}) => const Text('Addon 1'),
        );
        registry.register(
          'test.zone',
          (context, {data, onEvent}) => const Text('Addon 2'),
        );
        registry.register(
          'test.zone',
          (context, {data, onEvent}) => const Text('Addon 3'),
        );

        expect(registry.getAddonCount('test.zone'), 3);
      });

      test('should track registered addon zones', () {
        registry.register(
          'zone1',
          (context, {data, onEvent}) => const Text('Addon'),
        );
        registry.register(
          'zone2',
          (context, {data, onEvent}) => const Text('Addon'),
        );

        final zones = registry.getRegisteredAddons();
        expect(zones, contains('zone1'));
        expect(zones, contains('zone2'));
      });
    });

    group('Priority Sorting', () {
      testWidgets('should render addons in priority order (highest first)',
          (WidgetTester tester) async {
        registry.register(
          'test.zone',
          (context, {data, onEvent}) => const Text('Low Priority'),
          priority: 1,
        );
        registry.register(
          'test.zone',
          (context, {data, onEvent}) => const Text('High Priority'),
          priority: 10,
        );
        registry.register(
          'test.zone',
          (context, {data, onEvent}) => const Text('Medium Priority'),
          priority: 5,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  final widgets = registry.build('test.zone', context);
                  return Column(children: widgets);
                },
              ),
            ),
          ),
        );

        final texts = tester.widgetList<Text>(find.byType(Text)).toList();
        expect(texts[0].data, 'High Priority');
        expect(texts[1].data, 'Medium Priority');
        expect(texts[2].data, 'Low Priority');
      });
    });

    group('Addon Building', () {
      testWidgets('should build all addons in zone',
          (WidgetTester tester) async {
        registry.register(
          'test.zone',
          (context, {data, onEvent}) => const Text('Addon 1'),
        );
        registry.register(
          'test.zone',
          (context, {data, onEvent}) => const Text('Addon 2'),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  final widgets = registry.build('test.zone', context);
                  return Column(children: widgets);
                },
              ),
            ),
          ),
        );

        expect(find.text('Addon 1'), findsOneWidget);
        expect(find.text('Addon 2'), findsOneWidget);
      });

      testWidgets('should return empty list for unknown zone',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  final widgets = registry.build('unknown.zone', context);
                  return Column(children: widgets);
                },
              ),
            ),
          ),
        );

        expect(find.byType(Text), findsNothing);
      });

      testWidgets('should filter out null widgets',
          (WidgetTester tester) async {
        registry.register(
          'test.zone',
          (context, {data, onEvent}) => const Text('Valid Widget'),
        );
        registry.register(
          'test.zone',
          (context, {data, onEvent}) => null, // Returns null
        );
        registry.register(
          'test.zone',
          (context, {data, onEvent}) => const Text('Another Valid Widget'),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  final widgets = registry.build('test.zone', context);
                  return Column(children: widgets);
                },
              ),
            ),
          ),
        );

        expect(find.text('Valid Widget'), findsOneWidget);
        expect(find.text('Another Valid Widget'), findsOneWidget);
      });

      testWidgets('should handle addon errors gracefully',
          (WidgetTester tester) async {
        registry.register(
          'test.zone',
          (context, {data, onEvent}) => const Text('Good Addon'),
        );
        registry.register(
          'test.zone',
          (context, {data, onEvent}) => throw Exception('Addon Error'),
        );
        registry.register(
          'test.zone',
          (context, {data, onEvent}) => const Text('Another Good Addon'),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  final widgets = registry.build('test.zone', context);
                  return Column(children: widgets);
                },
              ),
            ),
          ),
        );

        // Should still render non-failing addons
        expect(find.text('Good Addon'), findsOneWidget);
        expect(find.text('Another Good Addon'), findsOneWidget);
      });

      testWidgets('should pass data to addon builders',
          (WidgetTester tester) async {
        String? receivedData;

        registry.register(
          'test.zone',
          (context, {data, onEvent}) {
            receivedData = data?['message'] as String?;
            return Text(receivedData ?? 'No data');
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  final widgets = registry.build(
                    'test.zone',
                    context,
                    data: {'message': 'Hello Addon'},
                  );
                  return Column(children: widgets);
                },
              ),
            ),
          ),
        );

        expect(receivedData, 'Hello Addon');
        expect(find.text('Hello Addon'), findsOneWidget);
      });

      testWidgets('should support onEvent callback',
          (WidgetTester tester) async {
        String? eventName;
        dynamic eventPayload;

        registry.register(
          'test.zone',
          (context, {data, onEvent}) {
            onEvent?.call('addon_event', {'value': 123});
            return const Text('Addon');
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  final widgets = registry.build(
                    'test.zone',
                    context,
                    onEvent: (event, payload) {
                      eventName = event;
                      eventPayload = payload;
                    },
                  );
                  return Column(children: widgets);
                },
              ),
            ),
          ),
        );

        expect(eventName, 'addon_event');
        expect(eventPayload, {'value': 123});
      });
    });

    group('Addon Removal', () {
      test('should remove specific addon', () {
        final builder1 = (BuildContext context, {data, onEvent}) => const Text('Addon 1');
        final builder2 = (BuildContext context, {data, onEvent}) => const Text('Addon 2');

        registry.register('test.zone', builder1);
        registry.register('test.zone', builder2);

        expect(registry.getAddonCount('test.zone'), 2);

        registry.removeAddon('test.zone', builder1);

        expect(registry.getAddonCount('test.zone'), 1);
      });

      test('should clear all addons in zone', () {
        registry.register(
          'test.zone',
          (context, {data, onEvent}) => const Text('Addon 1'),
        );
        registry.register(
          'test.zone',
          (context, {data, onEvent}) => const Text('Addon 2'),
        );

        expect(registry.getAddonCount('test.zone'), 2);

        registry.clearAddons('test.zone');

        expect(registry.getAddonCount('test.zone'), 0);
        expect(registry.hasAddon('test.zone'), false);
      });

      test('should clear all addons from all zones', () {
        registry.register(
          'zone1',
          (context, {data, onEvent}) => const Text('Addon'),
        );
        registry.register(
          'zone2',
          (context, {data, onEvent}) => const Text('Addon'),
        );

        expect(registry.getRegisteredAddons().length, 2);

        registry.clearAllAddons();

        expect(registry.getRegisteredAddons().length, 0);
      });
    });

    group('Addon Count', () {
      test('should return addon count for zone', () {
        registry.register(
          'test.zone',
          (context, {data, onEvent}) => const Text('Addon 1'),
        );
        registry.register(
          'test.zone',
          (context, {data, onEvent}) => const Text('Addon 2'),
        );

        expect(registry.getAddonCount('test.zone'), 2);
      });

      test('should return 0 for zone with no addons', () {
        expect(registry.getAddonCount('empty.zone'), 0);
      });
    });

    group('Has Addon', () {
      test('should return true when zone has addons', () {
        registry.register(
          'test.zone',
          (context, {data, onEvent}) => const Text('Addon'),
        );

        expect(registry.hasAddon('test.zone'), true);
      });

      test('should return false when zone has no addons', () {
        expect(registry.hasAddon('empty.zone'), false);
      });

      test('should return false after clearing zone', () {
        registry.register(
          'test.zone',
          (context, {data, onEvent}) => const Text('Addon'),
        );

        registry.clearAddons('test.zone');

        expect(registry.hasAddon('test.zone'), false);
      });
    });

    group('Multiple Zones', () {
      testWidgets('should support independent addon zones',
          (WidgetTester tester) async {
        registry.register(
          'zone1',
          (context, {data, onEvent}) => const Text('Zone 1 Addon'),
        );
        registry.register(
          'zone2',
          (context, {data, onEvent}) => const Text('Zone 2 Addon'),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  final zone1Widgets = registry.build('zone1', context);
                  final zone2Widgets = registry.build('zone2', context);
                  return Column(
                    children: [...zone1Widgets, ...zone2Widgets],
                  );
                },
              ),
            ),
          ),
        );

        expect(find.text('Zone 1 Addon'), findsOneWidget);
        expect(find.text('Zone 2 Addon'), findsOneWidget);
      });
    });

    group('Edge Cases', () {
      test('should handle empty zone name', () {
        registry.register(
          '',
          (context, {data, onEvent}) => const Text('Addon'),
        );

        expect(registry.hasAddon(''), true);
      });

      testWidgets('should handle null data', (WidgetTester tester) async {
        registry.register(
          'test.zone',
          (context, {data, onEvent}) => const Text('Addon'),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  final widgets = registry.build(
                    'test.zone',
                    context,
                    data: null,
                  );
                  return Column(children: widgets);
                },
              ),
            ),
          ),
        );

        expect(find.text('Addon'), findsOneWidget);
      });

      testWidgets('should handle null onEvent', (WidgetTester tester) async {
        registry.register(
          'test.zone',
          (context, {data, onEvent}) => const Text('Addon'),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  final widgets = registry.build(
                    'test.zone',
                    context,
                    onEvent: null,
                  );
                  return Column(children: widgets);
                },
              ),
            ),
          ),
        );

        expect(find.text('Addon'), findsOneWidget);
      });
    });
  });
}
