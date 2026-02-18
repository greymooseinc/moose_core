# moose_core Testing Guide

> Comprehensive testing strategy and test file organization for moose_core

**Last Updated**: 2025-11-12
**Version**: 1.0.0

## Overview

This guide outlines the testing structure for the moose_core library. All tests mirror the `lib/src` directory structure in the `test` directory.

## Test Coverage Status

✅ **Completed**:
- `test/adapter/backend_adapter_test.dart` - 30 tests, all passing
- `test/adapter_schema_validation_test.dart` - 8 tests, all passing

🚧 **In Progress**:
- Additional adapter tests
- Entity tests
- Service tests
- Repository tests

## Directory Structure

```
test/
├── adapter/
│   ├── backend_adapter_test.dart ✅
│   └── adapter_registry_test.dart
├── entities/
│   ├── product_test.dart
│   ├── cart_test.dart
│   ├── user_test.dart
│   ├── category_test.dart
│   ├── collection_test.dart
│   ├── order_test.dart
│   ├── paginated_result_test.dart
│   └── ... (all entity tests)
├── repositories/
│   ├── repository_test.dart
│   ├── products_repository_test.dart
│   ├── cart_repository_test.dart
│   └── ... (all repository tests)
├── services/
│   ├── api_client_test.dart
│   ├── config_manager_test.dart
│   ├── app_navigator_test.dart
│   ├── cache_manager_test.dart
│   └── ... (all service tests)
├── plugin/
│   ├── feature_plugin_test.dart
│   └── plugin_registry_test.dart
├── actions/
│   └── action_registry_test.dart
├── events/
│   ├── event_bus_test.dart
│   └── hook_registry_test.dart
├── helpers/
│   ├── color_helper_test.dart
│   └── text_style_helper_test.dart
├── utils/
│   ├── currency_formatter_test.dart
│   └── logger_test.dart
└── widgets/
    ├── feature_section_test.dart
    ├── widget_registry_test.dart
    └── addon_registry_test.dart
```

## Test Templates

### Entity Test Template

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:moose_core/entities.dart';

void main() {
  group('EntityName', () {
    group('Construction', () {
      test('should create instance with required fields', () {
        final entity = EntityName(
          id: 'test-id',
          // ... required fields
        );

        expect(entity.id, 'test-id');
        // ... assert other fields
      });

      test('should create instance with optional fields', () {
        final entity = EntityName(
          id: 'test-id',
          optional Field: 'value',
        );

        expect(entity.optionalField, 'value');
      });
    });

    group('Equality', () {
      test('should be equal when all fields match', () {
        final entity1 = EntityName(id: 'test-id');
        final entity2 = EntityName(id: 'test-id');

        expect(entity1, equals(entity2));
      });

      test('should not be equal when fields differ', () {
        final entity1 = EntityName(id: 'test-id-1');
        final entity2 = EntityName(id: 'test-id-2');

        expect(entity1, isNot(equals(entity2)));
      });
    });

    group('Serialization', () {
      test('should convert to JSON', () {
        final entity = EntityName(id: 'test-id');
        final json = entity.toJson();

        expect(json['id'], 'test-id');
      });

      test('should create from JSON', () {
        final json = {'id': 'test-id'};
        final entity = EntityName.fromJson(json);

        expect(entity.id, 'test-id');
      });

      test('should handle round-trip serialization', () {
        final original = EntityName(id: 'test-id');
        final json = original.toJson();
        final deserialized = EntityName.fromJson(json);

        expect(deserialized, equals(original));
      });
    });

    group('CopyWith', () {
      test('should create copy with modified fields', () {
        final original = EntityName(id: 'test-id');
        final copy = original.copyWith(id: 'new-id');

        expect(copy.id, 'new-id');
        expect(original.id, 'test-id'); // Original unchanged
      });
    });
  });
}
```

### Service Test Template

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:moose_core/services.dart';

void main() {
  group('ServiceName', () {
    late ServiceName service;

    setUp(() {
      service = ServiceName();
    });

    tearDown(() {
      // Clean up if needed
    });

    group('Initialization', () {
      test('should initialize correctly', () {
        expect(service.isInitialized, false);
        service.initialize();
        expect(service.isInitialized, true);
      });
    });

    group('Core Functionality', () {
      test('should perform expected operation', () async {
        final result = await service.someOperation();
        expect(result, isNotNull);
      });

      test('should handle errors gracefully', () {
        expect(
          () => service.invalidOperation(),
          throwsException,
        );
      });
    });

    group('Edge Cases', () {
      test('should handle null inputs', () {
        expect(() => service.operation(null), returnsNormally);
      });

      test('should handle empty inputs', () {
        expect(() => service.operation([]), returnsNormally);
      });
    });
  });
}
```

### Repository Test Template

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:moose_core/repositories.dart';

// Mock implementation for testing
class MockRepositoryName extends RepositoryName {
  @override
  void initialize() {}

  // Implement required abstract methods with test behavior
}

void main() {
  group('RepositoryName', () {
    late MockRepositoryName repository;

    setUp(() {
      repository = MockRepositoryName();
    });

    group('Abstract Methods', () {
      test('should require implementation of key methods', () {
        // Verify abstract contract
        expect(repository, isA<CoreRepository>());
      });
    });

    group('Common Behavior', () {
      test('should call initialize on creation', () {
        repository.initialize();
        // Verify initialization behavior
      });
    });
  });
}
```

## Running Tests

### Run All Tests

```bash
cd c:\Users\MadushaKumarasiri\source\repos\ecommerce_core
flutter test
```

### Run Specific Test File

```bash
flutter test test/adapter/backend_adapter_test.dart
```

### Run Tests with Coverage

```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

### Run Tests in Watch Mode

```bash
flutter test --watch
```

## Test Guidelines

### 1. Test Naming Conventions

- Test files: `<filename>_test.dart`
- Test groups: Use descriptive names matching functionality
- Test cases: Start with "should" for clarity

```dart
group('ProductEntity', () {
  test('should create product with valid data', () { ... });
  test('should throw when id is empty', () { ... });
});
```

### 2. Test Organization

- **Arrange**: Set up test data
- **Act**: Execute the code being tested
- **Assert**: Verify the results

```dart
test('should calculate cart total correctly', () {
  // Arrange
  final cart = Cart(items: [
    CartItem(productId: '1', quantity: 2, price: 10.0),
    CartItem(productId: '2', quantity: 1, price: 15.0),
  ]);

  // Act
  final total = cart.calculateTotal();

  // Assert
  expect(total, 35.0);
});
```

### 3. Use Test Helpers

```dart
// Create reusable test data builders
Product createTestProduct({
  String id = 'test-id',
  String name = 'Test Product',
  double price = 10.0,
}) {
  return Product(
    id: id,
    name: name,
    price: price,
  );
}

test('should work with test product', () {
  final product = createTestProduct(price: 20.0);
  expect(product.price, 20.0);
});
```

### 4. Test Edge Cases

```dart
group('Edge Cases', () {
  test('should handle empty list', () { ... });
  test('should handle null values', () { ... });
  test('should handle very large numbers', () { ... });
  test('should handle special characters', () { ... });
  test('should handle concurrent operations', () { ... });
});
```

### 5. Mock External Dependencies

For services that depend on external systems, use mocks:

```dart
class MockApiClient implements ApiClient {
  @override
  Future<Response> get(String endpoint, {Map<String, dynamic>? queryParams}) async {
    return Response(data: {'mock': 'data'}, statusCode: 200);
  }
}

test('should fetch data using API client', () async {
  final repository = ProductRepository(MockApiClient());
  final products = await repository.getProducts();
  expect(products, isNotEmpty);
});
```

## Test Coverage Goals

| Component | Target Coverage | Current Status |
|-----------|----------------|----------------|
| Adapters | 90%+ | ✅ 100% (backend_adapter) |
| Entities | 85%+ | 🚧 In Progress |
| Repositories | 80%+ | 📝 Planned |
| Services | 90%+ | 📝 Planned |
| Plugins | 85%+ | 📝 Planned |
| Utils | 95%+ | 📝 Planned |
| Widgets | 70%+ | 📝 Planned |

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter test --coverage
      - uses: codecov/codecov-action@v2
```

## Best Practices

### DO

✅ Write tests before fixing bugs (TDD for bug fixes)
✅ Test both success and failure cases
✅ Use descriptive test names
✅ Keep tests independent
✅ Mock external dependencies
✅ Test edge cases and boundary conditions
✅ Maintain test data builders
✅ Run tests before committing

### DON'T

❌ Test implementation details
❌ Write interdependent tests
❌ Ignore failing tests
❌ Skip edge cases
❌ Test framework code
❌ Use real API calls in unit tests
❌ Commit commented-out tests

## Common Test Patterns

### Testing Async Code

```dart
test('should handle async operations', () async {
  final result = await asyncFunction();
  expect(result, isNotNull);
});

test('should handle async errors', () {
  expect(
    () async => await failingAsyncFunction(),
    throwsA(isA<CustomException>()),
  );
});
```

### Testing Streams

```dart
test('should emit expected values from stream', () {
  final stream = service.dataStream;

  expect(
    stream,
    emitsInOrder([
      'value1',
      'value2',
      emitsDone,
    ]),
  );
});
```

### Testing State Changes

```dart
test('should transition through expected states', () async {
  final states = <String>[];
  final subscription = bloc.stream.listen(states.add);

  bloc.add(SomeEvent());
  await Future.delayed(Duration.zero);

  expect(states, [InitialState(), LoadingState(), LoadedState()]);
  await subscription.cancel();
});
```

## Troubleshooting

### Issue: Tests timeout

**Solution**: Increase timeout or check for infinite loops

```dart
test('slow operation', () async {
  // ...
}, timeout: Timeout(Duration(seconds: 30)));
```

### Issue: Flaky tests

**Solution**: Avoid time-dependent logic, use deterministic data

```dart
// Bad
final timestamp = DateTime.now();

// Good
final timestamp = DateTime(2025, 1, 1);
```

### Issue: Tests pass locally but fail in CI

**Solution**: Check for environment-specific dependencies

```dart
test('should work in CI', () {
  // Use platform-independent paths
  final path = p.join('test', 'fixtures', 'data.json');
});
```

## Next Steps

1. **Complete Adapter Tests**: Finish `adapter_registry_test.dart`
2. **Entity Tests**: Create tests for all 30+ entities
3. **Service Tests**: Test `ApiClient`, `ConfigManager`, `CacheManager`
4. **Repository Tests**: Abstract tests for repository contracts
5. **Integration Tests**: Test complete workflows
6. **Performance Tests**: Benchmark critical paths
7. **Widget Tests**: Test UI components

## Resources

- [Flutter Testing Documentation](https://flutter.dev/docs/testing)
- [Effective Dart: Testing](https://dart.dev/guides/language/effective-dart/testing)
- [Package:test Documentation](https://pub.dev/packages/test)
- [Mockito Package](https://pub.dev/packages/mockito)

---

**Note**: This is a living document. Update as testing coverage improves and new patterns emerge.
