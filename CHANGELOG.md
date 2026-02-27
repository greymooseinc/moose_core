# Changelog

All notable changes to moose_core will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2026-02-27

### Breaking Changes

- **`FeaturePlugin.initialize()` renamed to `FeaturePlugin.onInit()`**: Plugin
  implementations must now override `onInit()` instead of `initialize()`.
- **`PluginRegistry.initializeAll()` renamed to `PluginRegistry.initAll()`**.

### Added

- **Plugin lifecycle hooks on `FeaturePlugin`**:
  - `onStart()` — called after all plugins complete `onInit()`
  - `onStop()` — called during teardown
  - `onAppLifecycle(AppLifecycleState)` — receives app foreground/background transitions
- **`PluginRegistry.startAll()`** and **`PluginRegistry.stopAll()`** lifecycle orchestration APIs.
- **`PluginRegistry.notifyAppLifecycle()`** for dispatching Flutter lifecycle changes to plugins.
- **`MooseLifecycleObserver`** (`package:moose_core/app.dart`) to forward
  `WidgetsBindingObserver` lifecycle events into plugin lifecycle callbacks.

## [1.1.0] - 2026-02-26

### Breaking Changes

- **`BackendAdapter.initializeFromConfig()`**: `configManager` parameter is now named
  and **required** — `({required ConfigManager configManager})`. No global fallback exists.
  `MooseBootstrapper` passes the scoped instance automatically; callers that invoked
  `initializeFromConfig()` directly (without the parameter) must now pass the scoped
  `ConfigManager` explicitly.

### Changed

- **`AdapterRegistry`**: Repository registration is now fully **lazy**. Calling
  `registerAdapter()` stores factory closures but creates **no** repository instances.
  Instances are created on the first `getRepository<T>()` call and cached thereafter.
  This eliminates all eager repository construction during app startup.
- **`AdapterRegistry`**: Removed the `ConfigManager()` fallback in `registerAdapter()`.
  Adapter defaults are only registered when a scoped `ConfigManager` has been injected
  via `setDependencies()`. Calling `registerAdapter(autoInitialize: true)` without a
  prior `setDependencies()` call now throws a clear `StateError`.

### Added

- **`MooseAppContext.getRepository<T>()`**: Convenience shortcut that delegates to
  `adapterRegistry.getRepository<T>()`. Simplifies access from plugins and tests.
- **`test/app/moose_app_context_test.dart`**: New test file covering context isolation,
  scoped dependency wiring, lazy repository access, and constructor injection.

## [1.0.0] - 2026-02-22

### Breaking Changes

- **Singletons removed**: Global singleton constructors removed from all registry and
  manager classes. `WidgetRegistry()`, `HookRegistry()`, `AddonRegistry()`,
  `ActionRegistry()`, `AdapterRegistry()`, `EventBus()`, `PluginRegistry()`, and
  `ConfigManager()` no longer return a shared instance — each call creates a new
  independent object.
- **`MooseAppContext` replaces singletons**: All registries are now owned by a
  `MooseAppContext` instance. Construct one at app startup and expose via `MooseScope`.
- **`CoreRepository` constructor**: Now requires `{required HookRegistry hookRegistry,
  required EventBus eventBus}` named parameters. All concrete subclasses must forward
  via `super`.
- **`FeaturePlugin` field injection**: Registry fields (`hookRegistry`, `addonRegistry`,
  `widgetRegistry`, `adapterRegistry`, `actionRegistry`, `eventBus`) are now getters
  delegating to an injected `appContext` set by `PluginRegistry.register()`.
- **`PluginRegistry`**: `registerPlugin()` split into sync `register(plugin, {required appContext})`
  and async `initializeAll()`.
- **`FeatureSection.adapters` getter removed**: Replaced by `adaptersOf(BuildContext)`
  method. Call inside `build(context)`.
- **`BackendAdapter`**: `hookRegistry` and `eventBus` are now settable fields (set by
  `AdapterRegistry` before `initializeFromConfig`). Method signature changed to
  `Future<void> initializeFromConfig({ConfigManager? configManager})`.
- **`AppNavigator`**: No longer holds a static singleton `EventBus`. Call
  `AppNavigator.setEventBus(eventBus)` before navigation (done automatically by
  `MooseBootstrapper`).

### Added

- **`MooseAppContext`** (`package:moose_core/app.dart`): App-scoped container owning
  all registries. Supports optional constructor parameters for testing and DI.
- **`MooseScope`** (`package:moose_core/app.dart`): `InheritedWidget` that exposes
  `MooseAppContext` down the widget tree. Use the `context.moose` extension from any
  widget to access registries.
- **`MooseBootstrapper`** (`package:moose_core/app.dart`): Orchestrates 5-step startup
  (config → EventBus wiring → adapters → plugin registration → plugin initialization)
  and returns a `BootstrapReport` with per-plugin timings and failure details.
- **`BootstrapReport`**: Exposes `totalTime`, `pluginTimings`, `failures`, `succeeded`.
- **`UnknownSectionWidget`** (`package:moose_core/widgets.dart`): Displayed in debug
  mode when `WidgetRegistry.build()` is called with an unregistered section name.
- **`WidgetRegistry.setConfigManager()`** and **`AdapterRegistry.setDependencies()`**:
  Post-construction wiring methods used internally by `MooseAppContext`.
- New barrel `lib/app.dart`, re-exported from `lib/moose_core.dart`.

## [0.1.3] - 2026-02-18

### Fixed
- Raised `json_schema` minimum constraint to `>=5.2.2` to prevent downgrade analysis failure (`instancePath` nullable in older versions)
- Added `context.mounted` guards in `AppNavigator` before using `BuildContext` after async gaps

## [0.1.2] - 2026-02-18

### Fixed
- Updated `intl` constraint from `^0.19.0` to `^0.20.2` to support latest stable version
- Fixed angle-bracket HTML warnings in `PostRepository` and `ReviewRepository` doc comments

## [0.1.1] - 2026-02-18

### Changed
- Comprehensive documentation update for all AI-ready docs in `doc/ai-ready/`

### Fixed
- Corrected file paths throughout documentation (`lib/core/` → `lib/src/`)
- Fixed `WidgetRegistry` typedef: `SectionBuilderFn = FeatureSection Function(...)` (was incorrectly documented as returning `Widget`)
- Fixed `buildSectionGroup` signature to use named parameters `pluginName` and `groupName`
- Fixed `EventBus` usage examples to reflect string-based pub/sub API (not typed events)
- Fixed `FeatureSection.getSetting<T>()` exception documentation to match actual `Exception` type
- Fixed GitHub organisation in README URLs (`your-org` → `greymooseinc`)
- Fixed `BackendAdapter.initialize()` signature to include `Map<String, dynamic> config` parameter
- Fixed `CacheManager` API documentation to reflect static factory methods
- Fixed `AdapterRegistry` API: removed non-existent `getRepositoryAsync()`; added `getAvailableRepositories()`, `getInitializedAdapters()`, `clearAll()`

### Added
- Full `AddonRegistry` documentation in `doc/ai-ready/REGISTRIES.md` (purpose, API, slot naming, best practices)
- `AddonRegistry` entries in `ai/blueprint.json` (templates, checklist rules, add-addon example walkthrough)

## [0.1.0] - 2025-12-01

### Added
- `CartAmount` entity for flexible cart line items (shipping, tax, discount fees)
- `MediaItem` entity with multi-media support (image, video) and thumbnail variants
- `ShippingMethod` and `PaymentMethod` types in `CartRepository`
- `PaymentResult`, `PaymentStatus`, `RefundResult`, and `CartValidationResult` in `CartRepository`
- `CheckoutResult` with redirect URL support for external payment flows
- `ShortsRepository` and `Short` entity for short-form video content
- `BannerRepository` and `PromoBanner` entity
- `StoreRepository` for multi-store support
- `LocationRepository` with `Address`, `Country`, and `PostalCode` entities
- `ReviewRepository` as a standalone interface separate from `ProductsRepository`
- `AddonRegistry` for UI extension points in `FeatureSection`
- `EventBus` asynchronous publish-subscribe system for inter-plugin communication
- `BackendAdapter.initializeFromConfig()` for automatic configuration loading from `ConfigManager`
- JSON Schema validation in `BackendAdapter.validateConfig()` via the `json_schema` package
- `PluginRegistry` bottom tab management with `bottomTabs` hook registration
- `AppNavigator` service for plugin-agnostic navigation
- `CurrencyFormatter` utility for locale-aware currency display
- `AdapterRegistry` repository-level management (last-registered-wins model)
- `FeaturePlugin.configSchema` and `BackendAdapter.configSchema` for configuration validation
- Platform support declarations for Android, iOS, web, Windows, macOS, and Linux
- Comprehensive `///` API documentation on all public classes and methods
- AI-ready documentation in `docs/ai-ready/` covering all architectural patterns

### Changed
- `AdapterRegistry` redesigned from "active adapter" model to repository-level registration
- `Cart` entity now includes `amounts` list replacing fixed fee fields
- `CartRepository` expanded with full payment, order, and checkout lifecycle methods
- `ProductsRepository` split: review methods moved to `ReviewRepository`

## [0.0.1] - 2025-06-01

### Added
- Initial release of the moose_core package
- Plugin-based architecture with `FeaturePlugin` and `PluginRegistry`
- Repository pattern with `CoreRepository` base class and interfaces for products, cart, auth, posts, search, and push notifications
- Backend adapter pattern with `BackendAdapter` and `AdapterRegistry`
- `FeatureSection` pattern for configurable UI sections with default settings
- `WidgetRegistry` for dynamic widget composition and registration
- `HookRegistry` synchronous data transformation system for inter-plugin hooks
- `ActionRegistry` for custom user interaction handling
- `CacheManager` with `MemoryCache` and `PersistentCache` (TTL support)
- `ConfigManager` for JSON-based external configuration
- `ApiClient` built on Dio with configurable interceptors
- Core domain entities: `Product`, `Category`, `Cart`, `CartItem`, `Order`, `Checkout`, `User`, `ProductVariation`, `ProductAttribute`, `ProductFilters`, `ProductSortOption`
- Modular library structure: `entities`, `repositories`, `plugin`, `widgets`, `adapters`, `cache`, `services`
- BLoC-ready architecture with `flutter_bloc` integration
