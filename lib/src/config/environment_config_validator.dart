import 'package:json_schema/json_schema.dart';

/// JSON Schema that describes the canonical `environment.json` format.
///
/// The schema enforces:
/// - `"version"` is required (string).
/// - `"adapters"`, `"plugins"`, `"pages"`, and `"tabs"` are optional arrays
///   whose items must conform to the corresponding `$defs`.
/// - No extra top-level properties are allowed.
///
/// Used by [EnvironmentConfigValidator.validate] to guard against malformed
/// or tampered configs before they are applied at runtime.
const Map<String, dynamic> _kEnvironmentSchema = {
  r'$schema': 'https://json-schema.org/draft/2020-12/schema',
  r'$id': 'https://greymoose.ca/moose-app-config/v1.0.0',
  'type': 'object',
  'required': ['version'],
  'additionalProperties': false,
  'properties': {
    'version': {'type': 'string'},
    'theme': {'type': 'string'},
    'adapters': {
      'type': 'array',
      'items': {r'$ref': r'#/$defs/adapter'},
    },
    'plugins': {
      'type': 'array',
      'items': {r'$ref': r'#/$defs/plugin'},
    },
    'pages': {
      'type': 'array',
      'items': {r'$ref': r'#/$defs/page'},
    },
    'tabs': {
      'type': 'array',
      'items': {r'$ref': r'#/$defs/tab'},
    },
  },
  r'$defs': {
    'section': {
      'type': 'object',
      'required': ['name'],
      'additionalProperties': false,
      'properties': {
        'name': {'type': 'string'},
        'description': {'type': 'string'},
        'active': {'type': 'boolean'},
        'settings': {'type': 'object', 'additionalProperties': true},
      },
    },
    'appBar': {
      'type': 'object',
      'additionalProperties': false,
      'properties': {
        'title': {'type': 'string'},
        'floating': {'type': 'boolean'},
        'pinned': {'type': 'boolean'},
        'buttonsLeft': {
          'type': 'array',
          'items': {r'$ref': r'#/$defs/section'},
        },
        'buttonsRight': {
          'type': 'array',
          'items': {r'$ref': r'#/$defs/section'},
        },
      },
    },
    'adapter': {
      'type': 'object',
      'required': ['id'],
      'additionalProperties': false,
      'properties': {
        'id': {'type': 'string'},
        'description': {'type': 'string'},
        'active': {'type': 'boolean'},
        'settings': {'type': 'object', 'additionalProperties': true},
      },
    },
    'plugin': {
      'type': 'object',
      'required': ['id'],
      'additionalProperties': false,
      'properties': {
        'id': {'type': 'string'},
        'description': {'type': 'string'},
        'active': {'type': 'boolean'},
        'sections': {
          'type': 'object',
          'additionalProperties': {
            'type': 'array',
            'items': {r'$ref': r'#/$defs/section'},
          },
        },
        'settings': {'type': 'object', 'additionalProperties': true},
        'filters': {'type': 'object', 'additionalProperties': true},
      },
    },
    'page': {
      'type': 'object',
      'required': ['route', 'sections'],
      'additionalProperties': false,
      'properties': {
        'route': {'type': 'string'},
        'plugin': {'type': 'string'},
        'description': {'type': 'string'},
        'active': {'type': 'boolean'},
        'appBar': {r'$ref': r'#/$defs/appBar'},
        'bottomBar': {r'$ref': r'#/$defs/section'},
        'sections': {
          'type': 'array',
          'items': {r'$ref': r'#/$defs/section'},
        },
      },
    },
    'tab': {
      'type': 'object',
      'required': ['id', 'label', 'icon', 'activeIcon', 'route', 'order'],
      'additionalProperties': false,
      'properties': {
        'id': {'type': 'string'},
        'description': {'type': 'string'},
        'label': {'type': 'string'},
        'icon': {'type': 'string'},
        'activeIcon': {'type': 'string'},
        'route': {'type': 'string'},
        'order': {'type': 'integer'},
        'enabled': {'type': 'boolean'},
      },
    },
  },
};

/// Validates an `environment.json` map against the canonical schema.
///
/// Throws [EnvironmentConfigValidationException] if the map does not conform.
/// Returns normally on success.
///
/// Usage:
/// ```dart
/// EnvironmentConfigValidator.validate(newConfig);
/// ```
class EnvironmentConfigValidator {
  EnvironmentConfigValidator._();

  /// Validates [config] against the canonical environment.json schema.
  ///
  /// Throws [EnvironmentConfigValidationException] on the first schema
  /// violation, with a human-readable error summary.
  static void validate(Map<String, dynamic> config) {
    final schema = JsonSchema.create(_kEnvironmentSchema);
    final result = schema.validate(config);

    if (!result.isValid) {
      final errors = result.errors.map((e) {
        final path = e.instancePath.isEmpty ? 'root' : e.instancePath;
        return '  • $path: ${e.message}';
      }).join('\n');

      throw EnvironmentConfigValidationException(
        'environment.json failed schema validation:\n$errors',
      );
    }
  }
}

/// Thrown by [EnvironmentConfigValidator.validate] when the config map does
/// not conform to the environment.json schema.
class EnvironmentConfigValidationException implements Exception {
  final String message;
  const EnvironmentConfigValidationException(this.message);

  @override
  String toString() => 'EnvironmentConfigValidationException: $message';
}
