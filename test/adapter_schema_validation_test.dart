import 'package:flutter_test/flutter_test.dart';
import 'package:moose_core/adapters.dart';

/// Mock adapter for testing schema validation
class TestAdapter extends BackendAdapter {
  @override
  String get name => 'test';

  @override
  String get version => '1.0.0';

  @override
  Map<String, dynamic> get configSchema => {
        'type': 'object',
        'required': ['apiKey', 'baseUrl'],
        'properties': {
          'apiKey': {
            'type': 'string',
            'minLength': 10,
            'description': 'API authentication key',
          },
          'baseUrl': {
            'type': 'string',
            'format': 'uri',
            'description': 'Base URL of the API',
          },
          'timeout': {
            'type': 'integer',
            'minimum': 0,
            'description': 'Request timeout in seconds',
          },
        },
        'additionalProperties': false,
      };

  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    // Mock initialization
  }
}

void main() {
  group('BackendAdapter Schema Validation', () {
    late TestAdapter adapter;

    setUp(() {
      adapter = TestAdapter();
    });

    test('should pass validation with valid config', () {
      final config = {
        'apiKey': 'valid-api-key-12345',
        'baseUrl': 'https://api.example.com',
        'timeout': 30,
      };

      expect(() => adapter.validateConfig(config), returnsNormally);
    });

    test('should fail validation when required field is missing', () {
      final config = {
        'baseUrl': 'https://api.example.com',
        // Missing required 'apiKey'
      };

      expect(
        () => adapter.validateConfig(config),
        throwsA(isA<AdapterConfigValidationException>()),
      );
    });

    test('should fail validation when field type is wrong', () {
      final config = {
        'apiKey': 'valid-api-key-12345',
        'baseUrl': 'https://api.example.com',
        'timeout': 'not-an-integer', // Wrong type
      };

      expect(
        () => adapter.validateConfig(config),
        throwsA(isA<AdapterConfigValidationException>()),
      );
    });

    test('should fail validation when string is too short', () {
      final config = {
        'apiKey': 'short', // Less than minLength of 10
        'baseUrl': 'https://api.example.com',
      };

      expect(
        () => adapter.validateConfig(config),
        throwsA(isA<AdapterConfigValidationException>()),
      );
    });

    test('should fail validation when number is below minimum', () {
      final config = {
        'apiKey': 'valid-api-key-12345',
        'baseUrl': 'https://api.example.com',
        'timeout': -1, // Below minimum of 0
      };

      expect(
        () => adapter.validateConfig(config),
        throwsA(isA<AdapterConfigValidationException>()),
      );
    });

    test('should fail validation with additional properties', () {
      final config = {
        'apiKey': 'valid-api-key-12345',
        'baseUrl': 'https://api.example.com',
        'unknownField': 'value', // Not allowed
      };

      expect(
        () => adapter.validateConfig(config),
        throwsA(isA<AdapterConfigValidationException>()),
      );
    });

    test('should include helpful error message on validation failure', () {
      final config = {
        'baseUrl': 'https://api.example.com',
        // Missing required 'apiKey'
      };

      try {
        adapter.validateConfig(config);
        fail('Should have thrown AdapterConfigValidationException');
      } catch (e) {
        expect(e, isA<AdapterConfigValidationException>());
        expect(
          e.toString(),
          contains('Configuration validation failed for adapter "test"'),
        );
        expect(e.toString(), contains('Required fields'));
        expect(e.toString(), contains('apiKey'));
      }
    });

    test('should pass validation without optional fields', () {
      final config = {
        'apiKey': 'valid-api-key-12345',
        'baseUrl': 'https://api.example.com',
        // 'timeout' is optional, so it can be omitted
      };

      expect(() => adapter.validateConfig(config), returnsNormally);
    });
  });
}
