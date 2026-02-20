# Moose Core – Product Roadmap

## Overview
A structured roadmap for developing **moose_core**: a Flutter-based shopping app framework designed for AI agents.
This framework enables AI agents to understand, build, and customize ecommerce applications through a plugin-based architecture with comprehensive AI-ready documentation.

---

## Vision
**"Enable AI agents to build complete shopping applications from natural language descriptions"**

The framework provides:
- Platform-agnostic core entities and business logic
- Plugin-based modular architecture
- Backend adapters (WooCommerce, Shopify, etc.)
- Configuration-driven UI sections
- Comprehensive AI-ready documentation

---

## Phase 1: Foundation
**Goal:** Establish core architecture and AI-agent-friendly patterns.

**Status: Complete** — published to pub.dev v0.1.3

### Core Architecture
- [x] **Entity System**
  - [x] Platform-agnostic domain entities (41 entities)
  - [x] CoreEntity base class with extensions support
  - [x] Comprehensive entity documentation
  - [x] Type-safe entity serialization
- [x] **Plugin System**
  - [x] FeaturePlugin base class
  - [x] Plugin lifecycle management (registration, initialization)
  - [x] Plugin configuration with active/inactive support
  - [x] Settings management per plugin
  - [x] Route registration and merging
- [x] **Configuration Management**
  - [x] Environment-based configuration (environment.json)
  - [x] Nested configuration access (ConfigManager)
  - [x] Plugin-level configuration
  - [x] Section-level configuration with active flags

### Widget & Section System
- [x] **Widget Registry**
  - [x] Dynamic widget registration
  - [x] Configuration-driven section building
  - [x] Active/inactive section filtering
- [x] **Section Configuration**
  - [x] SectionConfig entity
  - [x] Settings support for each section
  - [x] Active flag for conditional rendering
- [x] **Addon Registry**
  - [x] Slot-based supplementary widget injection
  - [x] Priority-based rendering
  - [x] Duplicate detection

### Backend Adapters
- [x] **Adapter Architecture**
  - [x] Repository pattern with adapters
  - [x] Abstract BackendAdapter base class with lazy repository manager
  - [x] AdapterRegistry for managing multiple backends
  - [x] Platform-agnostic service layer
- [x] **Data Mappers**
  - [x] Backend-to-entity mapping (12 repository interfaces)
  - [x] Entity-to-backend mapping
  - [x] Extensions field for platform-specific data
- [x] **Schema Validation**
  - [x] JSON schema validation integrated into BackendAdapter
  - [x] Plugin and adapter configuration validation

### Services & Utilities
- [x] **EventBus** — pub/sub messaging for decoupled plugin communication
- [x] **HookRegistry** — priority-based synchronous data transformation hooks
- [x] **ActionRegistry** — custom user interaction handling (internal/external/custom)
- [x] **AppNavigator** — EventBus-based navigation with context.mounted guards
- [x] **ApiClient** — Dio-based HTTP client with retry, progress tracking, cancellation
- [x] **CacheManager** — unified memory + persistent cache (SharedPreferences)
- [x] **AppLogger** — colour-output application logger

### AI-Ready Documentation
- [x] **Documentation Structure** (18 documents in `doc/ai-ready/`)
  - [x] ARCHITECTURE.md — System overview
  - [x] PLUGIN_SYSTEM.md — Plugin development guide
  - [x] ENTITY_EXTENSIONS.md — Extensions field usage
  - [x] ADAPTER_PATTERN.md — Backend adapter implementation guide
  - [x] ADAPTER_SCHEMA_VALIDATION.md — JSON schema validation
  - [x] AI_CACHE_GUIDE.md — Caching strategy and best practices
  - [x] ANTI_PATTERNS.md — Common mistakes to avoid
  - [x] API.md — Complete API reference
  - [x] ATTRIBUTE_SELECTION_GUIDE.md — Product attribute handling
  - [x] AUTH_ADAPTER_GUIDE.md — Authentication adapter implementation
  - [x] CACHE_SYSTEM.md — Cache system deep dive
  - [x] EVENT_SYSTEM_GUIDE.md — EventBus and hook systems
  - [x] FEATURE_SECTION.md — FeatureSection development guide
  - [x] MANIFEST.md — Plugin/adapter manifest documentation
  - [x] PLUGIN_ADAPTER_CONFIG_GUIDE.md — Configuration management
  - [x] PRODUCT_SECTIONS.md — E-commerce product UI sections
  - [x] REGISTRIES.md — All registries reference
  - [x] README.md — Documentation index
  - [x] Comprehensive code examples
  - [x] Best practices and anti-patterns (ANTI_PATTERNS.md)

### Testing Infrastructure
- [x] **Test Coverage**
  - [x] ActionRegistry and UserInteraction tests
  - [x] BackendAdapter and AdapterRegistry tests (including schema validation)
  - [x] MemoryCache tests
  - [x] EventBus and HookRegistry tests
  - [x] WidgetRegistry, AddonRegistry, FeatureSection tests
  - [x] MockRepository and TestAdapter utilities in test suite
- [x] **Testing Guide** (`doc/TESTING_GUIDE.md`)

---

## Phase 2: Enhanced AI Integration (Q1 2026)
**Goal:** Improve AI agent understanding and code generation capabilities.

**Status: In Progress**

### Documentation Enhancements
- [ ] **Schema Documentation**
  - [x] JSON schema validation integrated into adapter/plugin config (`ADAPTER_SCHEMA_VALIDATION.md`)
  - [ ] Standalone JSON schema definition files for all entities
  - [ ] API contract documentation (OpenAPI/Swagger style)
- [ ] **Code Generation Guides**
  - [ ] Plugin scaffolding templates
  - [ ] Common pattern libraries
  - [ ] Migration guides for version updates
- [ ] **Interactive Examples**
  - [ ] Runnable code snippets
  - [ ] Visual architecture diagrams
  - [ ] Decision trees for common scenarios

### Enhanced Registries
- [x] **Hook System** — fully implemented with priority execution and documentation
- [x] **Event Bus** — fully implemented with async support and documentation (`EVENT_SYSTEM_GUIDE.md`)
- [ ] **Action Registry Enhancement**
  - [x] Custom action patterns implemented
  - [ ] Deep linking support
  - [ ] Navigation action standardization

### Shared Test Utilities Module
- [x] Mock adapters and repositories exist within the test suite
- [ ] Extract shared test utilities into a standalone `test/helpers/` module
- [ ] Pre-built mock implementations for WooCommerce/Shopify adapters
- [ ] Widget test templates

---

## Phase 3: Advanced Features (Q2 2026)
**Goal:** Add sophisticated ecommerce capabilities and AI-assisted customization.

### Advanced Commerce Features
- [ ] **Product Variants System**
  - [x] ProductVariation entity exists
  - [x] VariationSelectorService implemented
  - [ ] Variant selection UI components
  - [ ] Inventory tracking per variant
- [ ] **Advanced Filtering**
  - [x] FilterPreset, CollectionFilters, ProductFilters, SearchFilters entities exist
  - [ ] Faceted search support
  - [ ] Dynamic filter generation
- [ ] **Promotions Engine**
  - [x] PromoBanner entity exists
  - [ ] Discount rule configuration
  - [ ] Bundle/combo deals
  - [ ] Loyalty points integration

### AI-Assisted Customization
- [ ] **Visual Component Library**
  - [ ] Pre-built section components
  - [ ] Theme system with presets
  - [ ] Customizable UI patterns
- [ ] **Smart Configuration**
  - [x] Configuration validation (JSON schema in BackendAdapter)
  - [ ] Suggested settings based on use case
  - [ ] Performance optimization hints
- [ ] **Code Analysis Tools**
  - [ ] Plugin dependency analysis
  - [ ] Performance profiling utilities
  - [ ] Code quality metrics

### Multi-Backend Support
- [ ] **Additional Adapters**
  - [ ] BigCommerce adapter
  - [ ] Magento adapter
  - [ ] Custom REST API adapter
- [ ] **Adapter Development Kit**
  - [x] BackendAdapter abstract base class (foundation in place)
  - [x] AUTH_ADAPTER_GUIDE.md — adapter authoring guide
  - [ ] Adapter scaffolding tools
  - [ ] Testing utilities package for adapters

---

## Phase 4: Ecosystem & Community (Q3-Q4 2026)
**Goal:** Build a thriving ecosystem of plugins and extensions.

### Plugin Marketplace Preparation
- [ ] **Plugin Standards**
  - [x] moose.manifest.json format defined (`MANIFEST.md`)
  - [ ] Version compatibility matrix
  - [ ] Security review guidelines
- [ ] **Plugin Discovery**
  - [ ] Plugin registry/catalog
  - [ ] Dependency management
  - [ ] Plugin installation system

### Developer Tools
- [ ] **CLI Tools**
  - [x] CLI design specified in `ai/blueprint.json`
  - [ ] Project scaffolding CLI (implementation)
  - [ ] Plugin generator CLI
  - [ ] Configuration validator CLI
- [ ] **IDE Extensions**
  - [ ] VS Code snippets for common patterns
  - [ ] Configuration file intellisense
  - [ ] Live documentation in IDE

### AI Agent Improvements
- [ ] **Semantic Code Search**
  - [ ] Natural language code search
  - [ ] Intent-based pattern matching
  - [ ] Context-aware suggestions
- [ ] **Automated Refactoring**
  - [ ] Migration scripts for breaking changes
  - [ ] Pattern-based code modernization
  - [ ] Dependency update automation

---

## Release Timeline

| Phase | Focus Area | Target | Status |
|-------|-----------|--------|--------|
| Phase 1 – Foundation | Core architecture & plugin system | Q4 2025 | Complete (v0.1.3 on pub.dev) |
| Phase 2 – AI Integration | Documentation & testing enhancements | Q1 2026 | In Progress |
| Phase 3 – Advanced Features | Commerce features & customization | Q2 2026 | Planned |
| Phase 4 – Ecosystem | Community & developer tools | Q3-Q4 2026 | Planned |

---

## Current Focus (Phase 2)

### Immediate Priorities
- [ ] Extract shared test utilities into `test/helpers/` module
- [ ] Standalone JSON schema definition files for entities
- [ ] Plugin scaffolding templates / code generation guides
- [ ] Deep linking support in ActionRegistry
- [ ] Migration guide for v0.1.x → future breaking changes

### Near-Term Goals
- [ ] Visual architecture diagrams for AI-ready docs
- [ ] Decision trees for common plugin/adapter scenarios
- [ ] Additional runnable example: complex multi-plugin app
- [ ] Error handling best practices guide

---

## Future Considerations

### AI-Specific Features
- [ ] Natural language configuration generation
- [ ] Intent-based plugin composition
- [ ] Automated UI generation from descriptions
- [ ] Smart error recovery suggestions

### Platform Expansion
- [ ] Web platform support (Flutter Web)
- [ ] Desktop platform support
- [ ] Server-side rendering support
- [ ] Headless commerce support

### Developer Experience
- [ ] Hot reload for configuration changes
- [ ] Visual configuration editor
- [ ] Real-time preview system
- [ ] Plugin debugging tools

---

## Contributing

This is a framework designed for AI agents, but human contributions are welcome!

### How to Contribute
1. Review [ARCHITECTURE.md](doc/ai-ready/ARCHITECTURE.md) to understand the system
2. Check [PLUGIN_SYSTEM.md](doc/ai-ready/PLUGIN_SYSTEM.md) for plugin development
3. Follow the existing patterns and documentation style
4. Ensure all code includes comprehensive documentation
5. Update relevant AI-ready documentation

### Documentation Standards
- Write for AI agent comprehension
- Include complete code examples
- Document assumptions and edge cases
- Provide clear intent and reasoning
- Use consistent terminology

---

**Last Updated:** 2026-02-19
**Maintainer:** Moose Core Framework Team
**Framework Version:** 0.1.3
**Target Flutter Version:** 3.24+
