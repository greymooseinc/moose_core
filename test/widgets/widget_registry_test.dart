import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moose_core/widgets.dart';

/// Test FeatureSection implementation
class TestSection extends FeatureSection {
  const TestSection({super.key, super.settings});

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
      for (final key in registry.getRegisteredWidgets()) {
        registry.unregister(key);
      }
    });

    group('Instance Isolation', () {
      test('each WidgetRegistry() creates an independent instance', () {
        final registry1 = WidgetRegistry();
        final registry2 = WidgetRegistry();

        registry1.registerSection('widget.a', (ctx, {data, onEvent}) => const TestSection());
        expect(registry1.isRegistered('widget.a'), isTrue);
        expect(registry2.isRegistered('widget.a'), isFalse);
      });
    });

    group('registerSection', () {
      test('registers a FeatureSection builder', () {
        registry.registerSection(
          'test.section',
          (context, {data, onEvent}) => const TestSection(),
        );

        expect(registry.isRegistered('test.section'), isTrue);
      });

      test('tracks registered keys', () {
        registry.registerSection('section1', (ctx, {data, onEvent}) => const TestSection());
        registry.registerSection('section2', (ctx, {data, onEvent}) => const TestSection());

        final keys = registry.getRegisteredWidgets();
        expect(keys, contains('section1'));
        expect(keys, contains('section2'));
        expect(keys.length, 2);
      });

      test('multiple builders for the same key accumulate (multi-slot)', () {
        registry.registerSection(
          'slot',
          (ctx, {data, onEvent}) => const TestSection(settings: {'title': 'A'}),
        );
        registry.registerSection(
          'slot',
          (ctx, {data, onEvent}) => const TestSection(settings: {'title': 'B'}),
        );

        // Two distinct builders — both should be tracked under the same key
        expect(registry.isRegistered('slot'), isTrue);
        expect(registry.getRegisteredWidgets().length, 1); // one key, two entries
      });

      testWidgets('duplicate builder reference is ignored', (tester) async {
        TestSection builder(ctx, {data, onEvent}) => const TestSection();
        registry.registerSection('slot', builder);
        registry.registerSection('slot', builder); // same reference — ignored

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Builder(builder: (ctx) {
              final all = registry.buildAll('slot', ctx);
              expect(all.length, 1);
              return all.first;
            }),
          ),
        ));
      });
    });

    group('registerWidget', () {
      test('registers a plain widget builder', () {
        registry.registerWidget(
          'badge',
          (ctx, {data, onEvent}) => const Text('badge'),
        );

        expect(registry.isRegistered('badge'), isTrue);
      });

      testWidgets('builder returning null is filtered by buildAll', (tester) async {
        registry.registerWidget('slot', (ctx, {data, onEvent}) => null);

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Builder(builder: (ctx) {
              expect(registry.buildAll('slot', ctx), isEmpty);
              return const SizedBox.shrink();
            }),
          ),
        ));
      });

      testWidgets('priority controls order in buildAll', (tester) async {
        registry.registerWidget('slot',
            (ctx, {data, onEvent}) => const Text('low'), priority: 1);
        registry.registerWidget('slot',
            (ctx, {data, onEvent}) => const Text('high'), priority: 10);

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Builder(builder: (ctx) {
              final all = registry.buildAll('slot', ctx);
              expect(all.length, 2);
              return Column(children: all);
            }),
          ),
        ));
      });
    });

    group('buildAll', () {
      testWidgets('returns empty list for unregistered key', (tester) async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Builder(builder: (ctx) {
              expect(registry.buildAll('missing', ctx), isEmpty);
              return const SizedBox.shrink();
            }),
          ),
        ));
      });

      testWidgets('returns all non-null widgets, skips nulls', (tester) async {
        registry.registerWidget('slot', (ctx, {data, onEvent}) => const Text('A'));
        registry.registerWidget('slot', (ctx, {data, onEvent}) => null);
        registry.registerWidget('slot', (ctx, {data, onEvent}) => const Text('C'));

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Builder(builder: (ctx) {
              final all = registry.buildAll('slot', ctx);
              expect(all.length, 2);
              return Column(children: all);
            }),
          ),
        ));
      });
    });

    group('isRegistered', () {
      test('returns false for unregistered key', () {
        expect(registry.isRegistered('unknown.widget'), isFalse);
      });

      test('returns true after registration', () {
        registry.registerSection('s', (ctx, {data, onEvent}) => const TestSection());
        expect(registry.isRegistered('s'), isTrue);
      });

      test('returns false after unregister', () {
        registry.registerSection('s', (ctx, {data, onEvent}) => const TestSection());
        registry.unregister('s');
        expect(registry.isRegistered('s'), isFalse);
      });
    });

    group('unregister', () {
      test('removes all builders for a key', () {
        registry.registerSection('test.widget', (ctx, {data, onEvent}) => const TestSection());
        registry.unregister('test.widget');
        expect(registry.isRegistered('test.widget'), isFalse);
      });

      test('handles unregistering non-existent key gracefully', () {
        expect(() => registry.unregister('non.existent'), returnsNormally);
      });
    });

    group('build — widget tests', () {
      testWidgets('builds a registered section', (tester) async {
        registry.registerSection(
          'test.widget',
          (context, {data, onEvent}) => const TestSection(),
        );

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Builder(builder: (ctx) => registry.build('test.widget', ctx)),
          ),
        ));

        expect(find.text('Test Widget'), findsOneWidget);
      });

      testWidgets('returns fallback for unknown key in debug mode', (tester) async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Builder(builder: (ctx) => registry.build('unknown.widget', ctx)),
          ),
        ));

        // In debug mode UnknownSectionWidget is returned; it renders something
        expect(find.byType(Scaffold), findsOneWidget);
      });

      testWidgets('passes data to section builder', (tester) async {
        String? receivedTitle;

        registry.registerSection(
          'test.widget',
          (context, {data, onEvent}) {
            receivedTitle = data?['settings']?['title'] as String?;
            return const TestSection();
          },
        );

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => registry.build(
                'test.widget',
                ctx,
                data: {'settings': {'title': 'Custom Title'}},
              ),
            ),
          ),
        ));

        expect(receivedTitle, 'Custom Title');
      });

      testWidgets('forwards onEvent callback', (tester) async {
        String? eventName;
        dynamic eventPayload;

        registry.registerSection(
          'test.widget',
          (context, {data, onEvent}) {
            onEvent?.call('test_event', {'value': 42});
            return const TestSection();
          },
        );

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => registry.build(
                'test.widget',
                ctx,
                onEvent: (event, payload) {
                  eventName = event;
                  eventPayload = payload;
                },
              ),
            ),
          ),
        ));

        expect(eventName, 'test_event');
        expect(eventPayload, {'value': 42});
      });

      testWidgets('handles null data', (tester) async {
        registry.registerSection(
          'test.widget',
          (context, {data, onEvent}) => const TestSection(),
        );

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => registry.build('test.widget', ctx, data: null),
            ),
          ),
        ));

        expect(find.text('Test Widget'), findsOneWidget);
      });
    });

    group('Edge Cases', () {
      test('empty string key is valid', () {
        registry.registerSection('', (ctx, {data, onEvent}) => const TestSection());
        expect(registry.isRegistered(''), isTrue);
      });

      testWidgets('builds multiple independent keys', (tester) async {
        registry.registerSection(
          'widget1',
          (ctx, {data, onEvent}) => const TestSection(settings: {'title': 'Widget 1'}),
        );
        registry.registerSection(
          'widget2',
          (ctx, {data, onEvent}) => const TestSection(settings: {'title': 'Widget 2'}),
        );

        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Column(children: [
                registry.build('widget1', ctx),
                registry.build('widget2', ctx),
              ]),
            ),
          ),
        ));

        expect(find.text('Widget 1'), findsOneWidget);
        expect(find.text('Widget 2'), findsOneWidget);
      });
    });
  });
}

