/// Services and utilities for moose_core package.
///
/// This module exports business services, helpers, registries, and utilities
/// used throughout the application.
///
/// ## Event Systems
///
/// This module provides two complementary event systems:
///
/// - **HookRegistry**: Synchronous callback system for data transformation
///   - Use when you need to modify/transform data
///   - Callbacks can return modified values
///   - Execution order controlled by priority
///   - Example: Transform product prices, filter search results
///
/// - **EventBus**: Asynchronous pub/sub system for notifications
///   - Use for fire-and-forget notifications and side effects
///   - Type-safe event classes extend Event base class
///   - Multiple subscribers can listen to same event
///   - Example: Track analytics, send notifications, update cache
///
/// See EVENT_SYSTEM_COMPARISON.md for detailed comparison and usage guide.
library services;

// Actions
export 'src/actions/action_registry.dart';

// API Client
export 'src/api/api_client.dart';

// Configuration
export 'src/config/config_manager.dart';

// Events System
export 'src/events/hook_registry.dart';
export 'src/events/event_bus.dart';
export 'src/events/common_events.dart';

// Helpers
export 'src/helpers/color_helper.dart';
export 'src/helpers/text_style_helper.dart';

// Business Services
export 'src/services/variation_selector_service.dart';

// Utilities
export 'src/utils/logger.dart';
