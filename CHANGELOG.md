# Changelog

All notable changes to moose_core will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
