import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moose_core/entities.dart';
import 'package:moose_core/services.dart';

void main() {
  group('ActionRegistry', () {
    late ActionRegistry registry;

    setUp(() {
      registry = ActionRegistry();
      // Clear any previously registered handlers
      registry.clearCustomHandlers();
    });

    tearDown(() {
      registry.clearCustomHandlers();
    });

    group('Singleton Pattern', () {
      test('should return the same instance', () {
        final instance1 = ActionRegistry();
        final instance2 = ActionRegistry();
        final instance3 = ActionRegistry.instance;

        expect(instance1, equals(instance2));
        expect(instance2, equals(instance3));
        expect(identical(instance1, instance2), isTrue);
      });
    });

    group('registerCustomHandler', () {
      test('should register a custom handler', () {
        // Arrange
        void testHandler(BuildContext context, Map<String, dynamic>? params) {
          // Handler implementation
        }

        // Act
        registry.registerCustomHandler('test_action', testHandler);

        // Assert
        expect(registry.hasCustomHandler('test_action'), isTrue);
        expect(registry.getRegisteredHandlers(), contains('test_action'));
      });

      test('should overwrite existing handler with same actionId', () {
        // Arrange
        void firstHandler(BuildContext context, Map<String, dynamic>? params) {
          // First handler
        }

        void secondHandler(BuildContext context, Map<String, dynamic>? params) {
          // Second handler
        }

        // Act
        registry.registerCustomHandler('action', firstHandler);
        registry.registerCustomHandler('action', secondHandler);

        // Assert - only the second handler should be registered
        expect(registry.hasCustomHandler('action'), isTrue);
        expect(registry.getRegisteredHandlers().length, equals(1));
      });
    });

    group('registerMultipleHandlers', () {
      test('should register multiple handlers at once', () {
        // Arrange
        final handlers = <String, CustomActionHandler>{
          'action1': (ctx, params) {},
          'action2': (ctx, params) {},
          'action3': (ctx, params) {},
        };

        // Act
        registry.registerMultipleHandlers(handlers);

        // Assert
        expect(registry.getRegisteredHandlers().length, equals(3));
        expect(registry.hasCustomHandler('action1'), isTrue);
        expect(registry.hasCustomHandler('action2'), isTrue);
        expect(registry.hasCustomHandler('action3'), isTrue);
      });

      test('should merge with existing handlers', () {
        // Arrange
        registry.registerCustomHandler('existing', (ctx, params) {});
        final newHandlers = <String, CustomActionHandler>{
          'new1': (ctx, params) {},
          'new2': (ctx, params) {},
        };

        // Act
        registry.registerMultipleHandlers(newHandlers);

        // Assert
        expect(registry.getRegisteredHandlers().length, equals(3));
        expect(registry.hasCustomHandler('existing'), isTrue);
        expect(registry.hasCustomHandler('new1'), isTrue);
        expect(registry.hasCustomHandler('new2'), isTrue);
      });
    });

    group('unregisterCustomHandler', () {
      test('should unregister a handler', () {
        // Arrange
        registry.registerCustomHandler('test_action', (ctx, params) {});

        // Act
        registry.unregisterCustomHandler('test_action');

        // Assert
        expect(registry.hasCustomHandler('test_action'), isFalse);
        expect(registry.getRegisteredHandlers(), isEmpty);
      });

      test('should do nothing if handler does not exist', () {
        // Act & Assert - should not throw
        registry.unregisterCustomHandler('non_existent');
        expect(registry.getRegisteredHandlers(), isEmpty);
      });
    });

    group('hasCustomHandler', () {
      test('should return true for registered handler', () {
        registry.registerCustomHandler('test', (ctx, params) {});
        expect(registry.hasCustomHandler('test'), isTrue);
      });

      test('should return false for unregistered handler', () {
        expect(registry.hasCustomHandler('non_existent'), isFalse);
      });
    });

    group('getRegisteredHandlers', () {
      test('should return empty list when no handlers registered', () {
        expect(registry.getRegisteredHandlers(), isEmpty);
      });

      test('should return list of all registered handler IDs', () {
        // Arrange
        registry.registerCustomHandler('action1', (ctx, params) {});
        registry.registerCustomHandler('action2', (ctx, params) {});
        registry.registerCustomHandler('action3', (ctx, params) {});

        // Act
        final handlers = registry.getRegisteredHandlers();

        // Assert
        expect(handlers.length, equals(3));
        expect(handlers, containsAll(['action1', 'action2', 'action3']));
      });
    });

    group('clearCustomHandlers', () {
      test('should clear all registered handlers', () {
        // Arrange
        registry.registerCustomHandler('action1', (ctx, params) {});
        registry.registerCustomHandler('action2', (ctx, params) {});
        registry.registerCustomHandler('action3', (ctx, params) {});

        // Act
        registry.clearCustomHandlers();

        // Assert
        expect(registry.getRegisteredHandlers(), isEmpty);
        expect(registry.hasCustomHandler('action1'), isFalse);
        expect(registry.hasCustomHandler('action2'), isFalse);
        expect(registry.hasCustomHandler('action3'), isFalse);
      });

      test('should do nothing if no handlers registered', () {
        // Act & Assert - should not throw
        registry.clearCustomHandlers();
        expect(registry.getRegisteredHandlers(), isEmpty);
      });
    });

    group('handleInteraction', () {
      testWidgets('should do nothing for null interaction', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                registry.handleInteraction(context, null);
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        // Should not throw or navigate
        expect(tester.takeException(), isNull);
      });

      testWidgets('should do nothing for invalid interaction', (tester) async {
        // Invalid internal interaction (no route)
        final interaction = UserInteraction.internal(route: '', parameters: {});

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                registry.handleInteraction(context, interaction);
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        expect(tester.takeException(), isNull);
      });

      testWidgets('should handle none interaction type', (tester) async {
        final interaction = UserInteraction.none();

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                registry.handleInteraction(context, interaction);
                return const Scaffold(body: Text('Home'));
              },
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should still be on home page
        expect(find.text('Home'), findsOneWidget);
      });

      testWidgets('should handle internal navigation', (tester) async {
        final interaction = UserInteraction.internal(
          route: '/test',
          parameters: {'id': '123'},
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: ElevatedButton(
                    onPressed: () => registry.handleInteraction(context, interaction),
                    child: const Text('Navigate'),
                  ),
                );
              },
            ),
            routes: {
              '/test': (context) => const Scaffold(body: Text('Test Page')),
            },
          ),
        );

        await tester.tap(find.text('Navigate'));
        await tester.pumpAndSettle();

        expect(find.text('Test Page'), findsOneWidget);
      });

      testWidgets('should handle external URL with snackbar', (tester) async {
        final interaction = UserInteraction.external(url: 'https://example.com');

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: ElevatedButton(
                    onPressed: () => registry.handleInteraction(context, interaction),
                    child: const Text('Open URL'),
                  ),
                );
              },
            ),
          ),
        );

        await tester.tap(find.text('Open URL'));
        await tester.pump();

        expect(find.text('External URL: https://example.com'), findsOneWidget);
        expect(find.text('OK'), findsOneWidget);
      });

      testWidgets('should handle custom action with registered handler', (tester) async {
        var handlerCalled = false;
        Map<String, dynamic>? receivedParams;

        registry.registerCustomHandler('test_action', (context, params) {
          handlerCalled = true;
          receivedParams = params;
        });

        final interaction = UserInteraction.custom(
          actionId: 'test_action',
          parameters: {'key': 'value'},
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: ElevatedButton(
                    onPressed: () => registry.handleInteraction(context, interaction),
                    child: const Text('Execute'),
                  ),
                );
              },
            ),
          ),
        );

        await tester.tap(find.text('Execute'));
        await tester.pump();

        expect(handlerCalled, isTrue);
        expect(receivedParams, equals({'key': 'value'}));
      });

      testWidgets('should show error for unregistered custom action', (tester) async {
        final interaction = UserInteraction.custom(actionId: 'unregistered');

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: ElevatedButton(
                    onPressed: () => registry.handleInteraction(context, interaction),
                    child: const Text('Execute'),
                  ),
                );
              },
            ),
          ),
        );

        await tester.tap(find.text('Execute'));
        await tester.pump();

        expect(
          find.text('No handler registered for action: unregistered'),
          findsOneWidget,
        );
      });

      testWidgets('should silently ignore custom action without actionId (invalid)', (tester) async {
        // This interaction is invalid (no customActionId), so handleInteraction returns early
        const interaction = UserInteraction(
          interactionType: UserInteractionType.custom,
          customActionId: null,
        );

        expect(interaction.isValid, isFalse);

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: ElevatedButton(
                    onPressed: () => registry.handleInteraction(context, interaction),
                    child: const Text('Execute'),
                  ),
                );
              },
            ),
          ),
        );

        await tester.tap(find.text('Execute'));
        await tester.pump();

        // Should not show any error since interaction is invalid
        expect(find.byType(SnackBar), findsNothing);
      });

      testWidgets('should handle exceptions in custom handlers', (tester) async {
        registry.registerCustomHandler('error_action', (context, params) {
          throw Exception('Test error');
        });

        final interaction = UserInteraction.custom(actionId: 'error_action');

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: ElevatedButton(
                    onPressed: () => registry.handleInteraction(context, interaction),
                    child: const Text('Execute'),
                  ),
                );
              },
            ),
          ),
        );

        await tester.tap(find.text('Execute'));
        await tester.pump();

        expect(
          find.textContaining('Error executing custom action "error_action"'),
          findsOneWidget,
        );
      });
    });
  });
}
