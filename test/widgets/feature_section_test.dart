import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moose_core/widgets.dart';

/// Concrete test implementation of FeatureSection
class TestFeatureSection extends FeatureSection {
  const TestFeatureSection({super.key, super.settings});

  @override
  Map<String, dynamic> getDefaultSettings() {
    return {
      'title': 'Default Title',
      'fontSize': 16.0,
      'padding': 20.0,
      'showBorder': true,
      'itemCount': 10,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(getSetting<double>('padding')),
      child: Column(
        children: [
          Text(
            getSetting<String>('title'),
            style: TextStyle(fontSize: getSetting<double>('fontSize')),
          ),
          if (getSetting<bool>('showBorder'))
            Container(
              height: 1,
              color: Colors.grey,
            ),
        ],
      ),
    );
  }
}

void main() {
  group('FeatureSection', () {
    group('Default Settings', () {
      test('should use default settings when no settings provided', () {
        const section = TestFeatureSection();

        expect(section.getSetting<String>('title'), 'Default Title');
        expect(section.getSetting<double>('fontSize'), 16.0);
        expect(section.getSetting<double>('padding'), 20.0);
        expect(section.getSetting<bool>('showBorder'), true);
        expect(section.getSetting<int>('itemCount'), 10);
      });

      test('should override defaults with provided settings', () {
        const section = TestFeatureSection(
          settings: {
            'title': 'Custom Title',
            'fontSize': 24.0,
          },
        );

        expect(section.getSetting<String>('title'), 'Custom Title');
        expect(section.getSetting<double>('fontSize'), 24.0);
        expect(section.getSetting<double>('padding'), 20.0); // Uses default
      });

      test('should merge provided settings with defaults', () {
        const section = TestFeatureSection(
          settings: {'title': 'Custom Title'},
        );

        expect(section.getSetting<String>('title'), 'Custom Title');
        expect(section.getSetting<double>('fontSize'), 16.0);
        expect(section.getSetting<bool>('showBorder'), true);
      });
    });

    group('Type Conversion', () {
      test('should convert int to double automatically', () {
        const section = TestFeatureSection(
          settings: {'fontSize': 24}, // int instead of double
        );

        expect(section.getSetting<double>('fontSize'), 24.0);
      });

      test('should convert double to int automatically', () {
        const section = TestFeatureSection(
          settings: {'itemCount': 15.0}, // double instead of int
        );

        expect(section.getSetting<int>('itemCount'), 15);
      });

      test('should handle num to double conversion', () {
        const section = TestFeatureSection(
          settings: {'padding': 10}, // int num to double
        );

        expect(section.getSetting<double>('padding'), 10.0);
      });

      test('should handle num to int conversion', () {
        const section = TestFeatureSection(
          settings: {'itemCount': 20.0}, // double num to int
        );

        expect(section.getSetting<int>('itemCount'), 20);
      });
    });

    group('Error Handling', () {
      test('should throw when key not found', () {
        const section = TestFeatureSection();

        expect(
          () => section.getSetting<String>('unknownKey'),
          throwsException,
        );
      });

      test('should provide helpful error message for missing key', () {
        const section = TestFeatureSection();

        try {
          section.getSetting<String>('unknownKey');
          fail('Should have thrown');
        } catch (e) {
          expect(e.toString(), contains('Setting "unknownKey" not found'));
          expect(e.toString(), contains('TestFeatureSection'));
        }
      });

      test('should throw when type mismatch', () {
        const section = TestFeatureSection();

        expect(
          () => section.getSetting<int>('title'), // title is String, not int
          throwsException,
        );
      });

      test('should provide helpful error message for type mismatch', () {
        const section = TestFeatureSection();

        try {
          section.getSetting<int>('title');
          fail('Should have thrown');
        } catch (e) {
          expect(e.toString(), contains('Setting "title"'));
          expect(e.toString(), contains('String'));
          expect(e.toString(), contains('int'));
        }
      });
    });

    group('Adapter Access', () {
      test('should provide access to AdapterRegistry', () {
        const section = TestFeatureSection();

        expect(section.adapters, isNotNull);
      });
    });

    group('Edge Cases', () {
      test('should throw when value is explicitly null', () {
        const section = TestFeatureSection(
          settings: {'title': null},
        );

        // Explicitly null values should throw, not fallback to defaults
        expect(
          () => section.getSetting<String>('title'),
          throwsException,
        );
      });

      test('should handle empty settings map', () {
        const section = TestFeatureSection(settings: {});

        expect(section.getSetting<String>('title'), 'Default Title');
        expect(section.getSetting<double>('fontSize'), 16.0);
      });

      test('should handle complex types', () {
        const section = TestFeatureSection(
          settings: {
            'customData': {'key': 'value', 'count': 42},
          },
        );

        final data = section.getSetting<Map<String, dynamic>>('customData');
        expect(data, isA<Map<String, dynamic>>());
        expect(data['key'], 'value');
        expect(data['count'], 42);
      });

      test('should handle list types', () {
        const section = TestFeatureSection(
          settings: {
            'items': ['item1', 'item2', 'item3'],
          },
        );

        final items = section.getSetting<List>('items');
        expect(items, isA<List>());
        expect(items.length, 3);
        expect(items[0], 'item1');
      });
    });

    group('Widget Build', () {
      testWidgets('should build widget with default settings',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: TestFeatureSection(),
            ),
          ),
        );

        expect(find.text('Default Title'), findsOneWidget);
      });

      testWidgets('should build widget with custom settings',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: TestFeatureSection(
                settings: {'title': 'Custom Title'},
              ),
            ),
          ),
        );

        expect(find.text('Custom Title'), findsOneWidget);
        expect(find.text('Default Title'), findsNothing);
      });

      testWidgets('should apply padding from settings',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: TestFeatureSection(
                settings: {'padding': 30.0},
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(
          find.byType(Container).first,
        );
        final padding = container.padding as EdgeInsets;
        expect(padding.left, 30.0);
      });

      testWidgets('should conditionally show border',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: TestFeatureSection(
                settings: {'showBorder': false},
              ),
            ),
          ),
        );

        // Should not find the border container when showBorder is false
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Container &&
                widget.constraints?.maxHeight == 1.0,
          ),
          findsNothing,
        );
      });
    });
  });
}
