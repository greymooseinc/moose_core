import 'package:flutter_test/flutter_test.dart';
import 'package:moose_core/entities.dart';

void main() {
  group('UserInteraction', () {
    group('Factory Constructors', () {
      test('internal() should create internal navigation interaction', () {
        final interaction = UserInteraction.internal(
          route: '/products',
          parameters: {'id': '123'},
        );

        expect(interaction.interactionType, equals(UserInteractionType.internal));
        expect(interaction.route, equals('/products'));
        expect(interaction.parameters, equals({'id': '123'}));
        expect(interaction.url, isNull);
        expect(interaction.customActionId, isNull);
      });

      test('external() should create external URL interaction', () {
        final interaction = UserInteraction.external(
          url: 'https://example.com',
          parameters: {'ref': 'app'},
        );

        expect(interaction.interactionType, equals(UserInteractionType.external));
        expect(interaction.url, equals('https://example.com'));
        expect(interaction.parameters, equals({'ref': 'app'}));
        expect(interaction.route, isNull);
        expect(interaction.customActionId, isNull);
      });

      test('none() should create no-action interaction', () {
        final interaction = UserInteraction.none();

        expect(interaction.interactionType, equals(UserInteractionType.none));
        expect(interaction.route, isNull);
        expect(interaction.url, isNull);
        expect(interaction.parameters, isNull);
        expect(interaction.customActionId, isNull);
      });

      test('custom() should create custom action interaction', () {
        final interaction = UserInteraction.custom(
          actionId: 'share',
          parameters: {'content': 'Hello'},
        );

        expect(interaction.interactionType, equals(UserInteractionType.custom));
        expect(interaction.customActionId, equals('share'));
        expect(interaction.parameters, equals({'content': 'Hello'}));
        expect(interaction.route, isNull);
        expect(interaction.url, isNull);
      });
    });

    group('copyWith', () {
      test('should copy with new values', () {
        final original = UserInteraction.internal(route: '/home');
        final copied = original.copyWith(
          route: '/products',
          parameters: {'id': '123'},
        );

        expect(copied.interactionType, equals(UserInteractionType.internal));
        expect(copied.route, equals('/products'));
        expect(copied.parameters, equals({'id': '123'}));
      });

      test('should preserve original values when not specified', () {
        final original = UserInteraction.custom(
          actionId: 'share',
          parameters: {'text': 'Hello'},
        );
        final copied = original.copyWith();

        expect(copied.interactionType, equals(original.interactionType));
        expect(copied.customActionId, equals(original.customActionId));
        expect(copied.parameters, equals(original.parameters));
      });

      test('should allow changing interaction type', () {
        final original = UserInteraction.internal(route: '/home');
        final copied = original.copyWith(
          interactionType: UserInteractionType.external,
          url: 'https://example.com',
        );

        expect(copied.interactionType, equals(UserInteractionType.external));
        expect(copied.url, equals('https://example.com'));
      });
    });

    group('JSON Serialization', () {
      test('should serialize internal interaction to JSON', () {
        final interaction = UserInteraction.internal(
          route: '/products',
          parameters: {'id': '123'},
        );

        final json = interaction.toJson();

        expect(json['interactionType'], equals('internal'));
        expect(json['route'], equals('/products'));
        expect(json['parameters'], equals({'id': '123'}));
        expect(json.containsKey('url'), isFalse);
        expect(json.containsKey('customActionId'), isFalse);
      });

      test('should serialize external interaction to JSON', () {
        final interaction = UserInteraction.external(url: 'https://example.com');

        final json = interaction.toJson();

        expect(json['interactionType'], equals('external'));
        expect(json['url'], equals('https://example.com'));
        expect(json.containsKey('route'), isFalse);
      });

      test('should serialize custom interaction to JSON', () {
        final interaction = UserInteraction.custom(
          actionId: 'share',
          parameters: {'text': 'Hello'},
        );

        final json = interaction.toJson();

        expect(json['interactionType'], equals('custom'));
        expect(json['customActionId'], equals('share'));
        expect(json['parameters'], equals({'text': 'Hello'}));
      });

      test('should deserialize internal interaction from JSON', () {
        final json = {
          'interactionType': 'internal',
          'route': '/products',
          'parameters': {'id': '123'},
        };

        final interaction = UserInteraction.fromJson(json);

        expect(interaction.interactionType, equals(UserInteractionType.internal));
        expect(interaction.route, equals('/products'));
        expect(interaction.parameters, equals({'id': '123'}));
      });

      test('should deserialize external interaction from JSON', () {
        final json = {
          'interactionType': 'external',
          'url': 'https://example.com',
        };

        final interaction = UserInteraction.fromJson(json);

        expect(interaction.interactionType, equals(UserInteractionType.external));
        expect(interaction.url, equals('https://example.com'));
      });

      test('should deserialize custom interaction from JSON', () {
        final json = {
          'interactionType': 'custom',
          'customActionId': 'share',
          'parameters': {'text': 'Hello'},
        };

        final interaction = UserInteraction.fromJson(json);

        expect(interaction.interactionType, equals(UserInteractionType.custom));
        expect(interaction.customActionId, equals('share'));
        expect(interaction.parameters, equals({'text': 'Hello'}));
      });

      test('should default to none for invalid interaction type', () {
        final json = {
          'interactionType': 'invalid_type',
        };

        final interaction = UserInteraction.fromJson(json);

        expect(interaction.interactionType, equals(UserInteractionType.none));
      });

      test('should default to none when interactionType is missing', () {
        final json = <String, dynamic>{};

        final interaction = UserInteraction.fromJson(json);

        expect(interaction.interactionType, equals(UserInteractionType.none));
      });

      test('should round-trip through JSON serialization', () {
        final original = UserInteraction.custom(
          actionId: 'camera',
          parameters: {'mode': 'photo', 'quality': 'high'},
        );

        final json = original.toJson();
        final deserialized = UserInteraction.fromJson(json);

        expect(deserialized.interactionType, equals(original.interactionType));
        expect(deserialized.customActionId, equals(original.customActionId));
        expect(deserialized.parameters, equals(original.parameters));
      });
    });

    group('Equality', () {
      test('should be equal for identical interactions', () {
        final interaction1 = UserInteraction.internal(
          route: '/products',
          parameters: {'id': '123'},
        );
        final interaction2 = UserInteraction.internal(
          route: '/products',
          parameters: {'id': '123'},
        );

        expect(interaction1, equals(interaction2));
        expect(interaction1.hashCode, equals(interaction2.hashCode));
      });

      test('should not be equal for different routes', () {
        final interaction1 = UserInteraction.internal(route: '/home');
        final interaction2 = UserInteraction.internal(route: '/products');

        expect(interaction1, isNot(equals(interaction2)));
      });

      test('should not be equal for different interaction types', () {
        final interaction1 = UserInteraction.internal(route: '/home');
        final interaction2 = UserInteraction.external(url: 'https://example.com');

        expect(interaction1, isNot(equals(interaction2)));
      });

      test('should not be equal for different parameters', () {
        final interaction1 = UserInteraction.internal(
          route: '/products',
          parameters: {'id': '123'},
        );
        final interaction2 = UserInteraction.internal(
          route: '/products',
          parameters: {'id': '456'},
        );

        expect(interaction1, isNot(equals(interaction2)));
      });

      test('should handle null parameters in equality', () {
        final interaction1 = UserInteraction.internal(route: '/home');
        final interaction2 = UserInteraction.internal(
          route: '/home',
          parameters: null,
        );

        expect(interaction1, equals(interaction2));
      });
    });

    group('isValid', () {
      test('should be valid for internal interaction with route', () {
        final interaction = UserInteraction.internal(route: '/products');
        expect(interaction.isValid, isTrue);
      });

      test('should be invalid for internal interaction without route', () {
        const interaction = UserInteraction(
          interactionType: UserInteractionType.internal,
          route: null,
        );
        expect(interaction.isValid, isFalse);
      });

      test('should be invalid for internal interaction with empty route', () {
        final interaction = UserInteraction.internal(route: '');
        expect(interaction.isValid, isFalse);
      });

      test('should be valid for external interaction with URL', () {
        final interaction = UserInteraction.external(url: 'https://example.com');
        expect(interaction.isValid, isTrue);
      });

      test('should be invalid for external interaction without URL', () {
        const interaction = UserInteraction(
          interactionType: UserInteractionType.external,
          url: null,
        );
        expect(interaction.isValid, isFalse);
      });

      test('should be invalid for external interaction with empty URL', () {
        final interaction = UserInteraction.external(url: '');
        expect(interaction.isValid, isFalse);
      });

      test('should be valid for custom interaction with actionId', () {
        final interaction = UserInteraction.custom(actionId: 'share');
        expect(interaction.isValid, isTrue);
      });

      test('should be invalid for custom interaction without actionId', () {
        const interaction = UserInteraction(
          interactionType: UserInteractionType.custom,
          customActionId: null,
        );
        expect(interaction.isValid, isFalse);
      });

      test('should be invalid for custom interaction with empty actionId', () {
        final interaction = UserInteraction.custom(actionId: '');
        expect(interaction.isValid, isFalse);
      });

      test('should always be valid for none interaction', () {
        final interaction = UserInteraction.none();
        expect(interaction.isValid, isTrue);
      });
    });

    group('description', () {
      test('should provide description for internal interaction', () {
        final interaction = UserInteraction.internal(route: '/products');
        expect(interaction.description, equals('Navigate to /products'));
      });

      test('should provide description for internal interaction without route', () {
        const interaction = UserInteraction(
          interactionType: UserInteractionType.internal,
          route: null,
        );
        expect(interaction.description, equals('Navigate to unknown route'));
      });

      test('should provide description for external interaction', () {
        final interaction = UserInteraction.external(url: 'https://example.com');
        expect(interaction.description, equals('Open https://example.com'));
      });

      test('should provide description for external interaction without URL', () {
        const interaction = UserInteraction(
          interactionType: UserInteractionType.external,
          url: null,
        );
        expect(interaction.description, equals('Open unknown URL'));
      });

      test('should provide description for custom interaction', () {
        final interaction = UserInteraction.custom(actionId: 'share');
        expect(interaction.description, equals('Custom action: share'));
      });

      test('should provide description for custom interaction without actionId', () {
        const interaction = UserInteraction(
          interactionType: UserInteractionType.custom,
          customActionId: null,
        );
        expect(interaction.description, equals('Custom action: unknown'));
      });

      test('should provide description for none interaction', () {
        final interaction = UserInteraction.none();
        expect(interaction.description, equals('No action'));
      });
    });

    group('toString', () {
      test('should provide readable string representation', () {
        final interaction = UserInteraction.custom(
          actionId: 'share',
          parameters: {'text': 'Hello'},
        );

        final str = interaction.toString();

        expect(str, contains('UserInteraction'));
        expect(str, contains('custom'));
        expect(str, contains('share'));
        expect(str, contains('text'));
        expect(str, contains('Hello'));
      });
    });

    group('Edge Cases', () {
      test('should handle interaction with all null optional fields', () {
        const interaction = UserInteraction(
          interactionType: UserInteractionType.none,
        );

        expect(interaction.route, isNull);
        expect(interaction.url, isNull);
        expect(interaction.parameters, isNull);
        expect(interaction.customActionId, isNull);
        expect(interaction.isValid, isTrue);
      });

      test('should handle interaction with complex parameters', () {
        final interaction = UserInteraction.custom(
          actionId: 'complex',
          parameters: {
            'string': 'value',
            'number': 123,
            'bool': true,
            'list': [1, 2, 3],
            'nested': {'key': 'value'},
          },
        );

        expect(interaction.parameters?['string'], equals('value'));
        expect(interaction.parameters?['number'], equals(123));
        expect(interaction.parameters?['bool'], equals(true));
        expect(interaction.parameters?['list'], equals([1, 2, 3]));
        expect(interaction.parameters?['nested'], equals({'key': 'value'}));
      });

      test('should handle empty parameters map', () {
        final interaction = UserInteraction.internal(
          route: '/home',
          parameters: {},
        );

        expect(interaction.parameters, isEmpty);
        expect(interaction.isValid, isTrue);
      });
    });
  });
}
