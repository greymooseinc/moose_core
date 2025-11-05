/// Adapter pattern for moose_core package.
///
/// This module exports the adapter architecture that enables backend-agnostic data access.
/// Adapters provide concrete implementations of repository interfaces for specific backends
/// (e.g., WooCommerce, Shopify).
library adapters;

export 'src/adapter/adapter_registry.dart' hide RepositoryNotRegisteredException;
export 'src/adapter/backend_adapter.dart';
