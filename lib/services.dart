/// Services and utilities for moose_core package.
///
/// This module exports business services, helpers, registries, and utilities
/// used throughout the application.
library services;

// Actions
export 'src/actions/action_registry.dart';

// API Client
export 'src/api/api_client.dart';

// Configuration
export 'src/config/config_manager.dart';

// Events System
export 'src/events/hook_registry.dart';

// Helpers
export 'src/helpers/color_helper.dart';
export 'src/helpers/text_style_helper.dart';

// Business Services
export 'src/services/variation_selector_service.dart';

// Utilities
export 'src/utils/logger.dart';
