# moose_core Testing Guide

**Last Updated:** 2026-02-26

## Test Status

331 tests passing, 1 pre-existing skip.

## Directory Structure

```
test/
├── actions/
│   ├── action_registry_test.dart
│   └── user_interaction_test.dart
├── adapter/
│   ├── adapter_registry_test.dart
│   └── backend_adapter_test.dart
├── adapter_schema_validation_test.dart
├── api/
│   └── api_client_test.dart
├── app/
│   └── moose_app_context_test.dart
├── cache/
│   └── memory_cache_test.dart
├── events/
│   ├── event_bus_test.dart
│   └── hook_registry_test.dart
└── widgets/
    ├── addon_registry_test.dart
    ├── feature_section_test.dart
    └── widget_registry_test.dart
```

## Running Tests

```bash
flutter test                                          # all tests
flutter test test/adapter/adapter_registry_test.dart  # single file
flutter test --coverage                               # with coverage
```

## Key Patterns

### Adapter — manual init (`autoInitialize: false`)

```dart
final registry = AdapterRegistry();
await registry.registerAdapter(
  () async {
    final adapter = MyAdapter();
    await adapter.initialize({});
    return adapter;
  },
  autoInitialize: false,
);
```

### Adapter — auto init (`autoInitialize: true`) requires scoped config

```dart
final registry = AdapterRegistry();
final cm = ConfigManager()
  ..initialize({'adapters': {'my_adapter': { /* config */ }}});
registry.setDependencies(
  configManager: cm,
  hookRegistry: HookRegistry(),
  eventBus: EventBus(),
);
await registry.registerAdapter(() => MyAdapter());
```

### AppNavigator — set EventBus in `setUp`

```dart
setUp(() {
  AppNavigator.setEventBus(EventBus());
});
```

### MooseAppContext isolation

Each `MooseAppContext()` owns independent registries — no shared state.

```dart
final ctx1 = MooseAppContext();
final ctx2 = MooseAppContext();
expect(identical(ctx1.adapterRegistry, ctx2.adapterRegistry), isFalse);
```

### Repositories are lazy

No instance is created until the first `getRepository<T>()` call.

```dart
// After registerAdapter — factory registered, no instance yet
expect(registry.hasRepository<MyRepo>(), true);

// First call creates and caches the instance
final repo = registry.getRepository<MyRepo>();
```

## Guidelines

- Mirror `lib/src/` structure in `test/`
- One `group()` per class, nested groups per concern
- Name tests: `'should <expected behaviour>'`
- Arrange / Act / Assert
- No real network calls in unit tests
- Each test creates its own instances — never share mutable state across tests
