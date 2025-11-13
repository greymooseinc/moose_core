import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moose_core/widgets.dart';

/// Test widget implementation
class TestWidget extends FeatureSection {
  const TestWidget({super.key, super.settings});

  @override
  Map<String, dynamic> getDefaultSettings() {
    return {'title': 'Test Widget'};
  }

  @override
  Widget build(BuildContext context) {
    return Text(getSetting<String>('title'));
  }
}

void main() {
  group('WidgetRegistry', () {
    late WidgetRegistry registry;

    setUp(() {
      registry = WidgetRegistry();
      // Clear registry before each test
      final widgets = registry.getRegisteredWidgets();
      for (final widget in widgets) {
        registry.unregister(widget);
      }
    });

    group('Singleton Pattern', () {
      test('should return same instance', () {
        final registry1 = WidgetRegistry();
        final registry2 = WidgetRegistry();

        expect(identical(registry1, registry2), true);
      });

      test('should access via instance getter', () {
        final registry1 = WidgetRegistry.instance;
        final registry2 = WidgetRegistry();

        expect(identical(registry1, registry2), true);
      });
    });

    group('Widget Registration', () {
      test('should register widget builder', () {
        registry.register(
          'test.widget',
          (context, {data, onEvent}) => const TestWidget(),
        );

        expect(registry.isRegistered('test.widget'), true);
      });

      test('should track registered widgets', () {
        registry.register(
          'widget1',
          (context, {data, onEvent}) => const TestWidget(),
        );
        registry.register(
          'widget2',
          (context, {data, onEvent}) => const TestWidget(),
        );

        final widgets = registry.getRegisteredWidgets();
        expect(widgets, contains('widget1'));
        expect(widgets, contains('widget2'));
        expect(widgets.length, 2);
      });

      test('should return false for unregistered widget', () {
        expect(registry.isRegistered('unknown.widget'), false);
      });

      test('should overwrite existing registration', () {
        registry.register(
          'test.widget',
          (context, {data, onEvent}) => const TestWidget(
            settings: {'title': 'First'},
          ),
        );

        registry.register(
          'test.widget',
          (context, {data, onEvent}) => const TestWidget(
            settings: {'title': 'Second'},
          ),
        );

        expect(registry.getRegisteredWidgets().length, 1);
      });
    });

    group('Widget Unregistration', () {
      test('should unregister widget', () {
        registry.register(
          'test.widget',
          (context, {data, onEvent}) => const TestWidget(),
        );

        expect(registry.isRegistered('test.widget'), true);

        registry.unregister('test.widget');

        expect(registry.isRegistered('test.widget'), false);
      });

      test('should handle unregistering non-existent widget', () {
        expect(
          () => registry.unregister('non.existent'),
          returnsNormally,
        );
      });
    });

    group('Widget Building', () {
      testWidgets('should build registered widget', (WidgetTester tester) async {
        registry.register(
          'test.widget',
          (context, {data, onEvent}) => const TestWidget(),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => registry.build('test.widget', context),
              ),
            ),
          ),
        );

        expect(find.text('Test Widget'), findsOneWidget);
      });

      testWidgets('should return empty container for unknown widget',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => registry.build('unknown.widget', context),
              ),
            ),
          ),
        );

        expect(find.byType(Container), findsOneWidget);
      });

      testWidgets('should pass data to widget builder',
          (WidgetTester tester) async {
        String? receivedTitle;

        registry.register(
          'test.widget',
          (context, {data, onEvent}) {
            receivedTitle = data?['settings']?['title'] as String?;
            return const TestWidget();
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => registry.build(
                  'test.widget',
                  context,
                  data: {
                    'settings': {'title': 'Custom Title'}
                  },
                ),
              ),
            ),
          ),
        );

        expect(receivedTitle, 'Custom Title');
      });

      testWidgets('should support onEvent callback',
          (WidgetTester tester) async {
        String? eventName;
        dynamic eventPayload;

        registry.register(
          'test.widget',
          (context, {data, onEvent}) {
            // Trigger event in builder
            onEvent?.call('test_event', {'value': 42});
            return const TestWidget();
          },
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => registry.build(
                  'test.widget',
                  context,
                  onEvent: (event, payload) {
                    eventName = event;
                    eventPayload = payload;
                  },
                ),
              ),
            ),
          ),
        );

        expect(eventName, 'test_event');
        expect(eventPayload, {'value': 42});
      });
    });

    group('Multiple Widgets', () {
      test('should support multiple widget registrations', () {
        registry.register(
          'widget1',
          (context, {data, onEvent}) => const TestWidget(),
        );
        registry.register(
          'widget2',
          (context, {data, onEvent}) => const TestWidget(),
        );
        registry.register(
          'widget3',
          (context, {data, onEvent}) => const TestWidget(),
        );

        expect(registry.getRegisteredWidgets().length, 3);
        expect(registry.isRegistered('widget1'), true);
        expect(registry.isRegistered('widget2'), true);
        expect(registry.isRegistered('widget3'), true);
      });

      testWidgets('should build different widgets independently',
          (WidgetTester tester) async {
        registry.register(
          'widget1',
          (context, {data, onEvent}) => const TestWidget(
            settings: {'title': 'Widget 1'},
          ),
        );
        registry.register(
          'widget2',
          (context, {data, onEvent}) => const TestWidget(
            settings: {'title': 'Widget 2'},
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Column(
                  children: [
                    registry.build('widget1', context),
                    registry.build('widget2', context),
                  ],
                ),
              ),
            ),
          ),
        );

        expect(find.text('Widget 1'), findsOneWidget);
        expect(find.text('Widget 2'), findsOneWidget);
      });
    });

    group('Edge Cases', () {
      test('should handle empty widget name', () {
        registry.register(
          '',
          (context, {data, onEvent}) => const TestWidget(),
        );

        expect(registry.isRegistered(''), true);
      });

      testWidgets('should handle null data', (WidgetTester tester) async {
        registry.register(
          'test.widget',
          (context, {data, onEvent}) => const TestWidget(),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => registry.build(
                  'test.widget',
                  context,
                  data: null,
                ),
              ),
            ),
          ),
        );

        expect(find.text('Test Widget'), findsOneWidget);
      });

      testWidgets('should handle null onEvent', (WidgetTester tester) async {
        registry.register(
          'test.widget',
          (context, {data, onEvent}) => const TestWidget(),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => registry.build(
                  'test.widget',
                  context,
                  onEvent: null,
                ),
              ),
            ),
          ),
        );

        expect(find.text('Test Widget'), findsOneWidget);
      });
    });
  });
}
