# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2025-11-04

### Added
- Modular package structure with focused export files
  - `entities.dart` - Domain entities module
  - `repositories.dart` - Repository interfaces module
  - `plugin.dart` - Plugin system module
  - `widgets.dart` - UI components module
  - `adapters.dart` - Adapter pattern module
  - `cache.dart` - Caching system module
  - `services.dart` - Utilities & helpers module
- Selective import support for optimized builds
- Migration guide for modular structure (docs/MIGRATION_MODULAR_STRUCTURE.md)

### Changed
- Restructured main `moose_core.dart` to re-export all modules
- Updated AI-ready documentation with modular import examples
- Enhanced package documentation with module reference table

### Notes
- Fully backward compatible - no breaking changes
- Existing code using `import 'package:moose_core/moose_core.dart'` continues to work
- Developers can now optionally import specific modules for better tree-shaking

## [1.0.0] - 2025-11-03

### Added
- Initial release of moose_core package
- Plugin-based architecture with FeaturePlugin base class
- Repository pattern with BackendAdapter abstraction
- FeatureSection pattern for configurable UI sections
- WidgetRegistry for dynamic widget composition
- AdapterRegistry for backend adapter management
- ActionRegistry for custom action handling
- HookRegistry for event hooks
- AddonRegistry for UI extension points
- ConfigManager for JSON-based configuration
- CacheManager with multi-layer caching support
- ApiClient abstraction for HTTP operations
- Complete domain entities (Product, Cart, Order, etc.)
- Type-safe generic methods throughout
- Comprehensive AI-ready documentation
- Full test coverage for core components

### Core Components
- `FeaturePlugin` - Base class for feature plugins
- `BackendAdapter` - Abstract adapter for backend implementations
- `FeatureSection` - Base class for configurable sections
- `WidgetRegistry` - Dynamic widget registration and building
- `AdapterRegistry` - Backend adapter management
- `ActionRegistry` - Custom action registration and execution
- `HookRegistry` - Event hook system
- `AddonRegistry` - Zone-based UI injection
- `ConfigManager` - Configuration management
- `CacheManager` - Multi-layer caching
- `ApiClient` - HTTP client abstraction

### Entities
- Product domain entities (Product, ProductFilters, ProductVariation, etc.)
- Cart domain entities (Cart, CartItem)
- Review domain entities (ProductReview, ProductReviewStats)
- Search domain entities (SearchResult, SearchFilters)
- Post domain entities (Post, PostSortOption)
- Collection domain entities (Collection, CollectionFilters)
- Checkout domain entities (Order, Checkout)
- Notification domain entities (PushNotification)
- Common entities (Category, ProductTag, PaginatedResult, etc.)

### Repositories
- `ProductsRepository` - Product data operations
- `CartRepository` - Shopping cart operations
- `ReviewRepository` - Review operations
- `SearchRepository` - Search operations
- `PostRepository` - Content/blog operations
- `PushNotificationRepository` - Push notification operations

### Utilities
- `AppLogger` - Logging utility with different log levels
- `ColorHelper` - Color parsing and manipulation
- `TextStyleHelper` - TextStyle creation helpers
- `VariationSelectorService` - Product variation selection logic

### Documentation
- Complete architecture guide
- Plugin system documentation
- FeatureSection pattern guide
- Adapter pattern documentation
- Registry systems guide
- Anti-patterns reference
- API reference documentation
- AI-ready development guides

[1.0.0]: https://github.com/yourusername/moose_core/releases/tag/v1.0.0
