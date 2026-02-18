# Changelog

All notable changes to moose_core will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
