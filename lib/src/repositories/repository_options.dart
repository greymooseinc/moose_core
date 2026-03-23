import 'package:flutter/foundation.dart';

/// Per-call configuration bag passed to repository methods.
///
/// All fields are optional with sensible defaults. Pass [RepositoryOptions]
/// to override caching behaviour, bypass the cache entirely, or thread
/// arbitrary adapter-specific metadata through a call without changing
/// the interface signature.
///
/// ## Caching examples
///
/// Force-refresh a specific product list:
/// ```dart
/// final products = await productsRepo.getProducts(
///   filters: filters,
///   options: const RepositoryOptions(forceRefresh: true),
/// );
/// ```
///
/// Shorten TTL for a time-sensitive stock check:
/// ```dart
/// final stock = await productsRepo.getProductStock(
///   productId,
///   options: RepositoryOptions(cacheTTL: Duration(seconds: 30)),
/// );
/// ```
///
/// Disable caching entirely for a single call:
/// ```dart
/// final cart = await cartRepo.getCart(
///   options: const RepositoryOptions.noCache(),
/// );
/// ```
///
/// ## Adapter metadata example
///
/// Pass a correlation ID to an adapter for distributed tracing:
/// ```dart
/// await cartRepo.checkout(
///   checkoutRequest: request,
///   options: RepositoryOptions(extra: {'correlationId': uuid}),
/// );
/// ```
@immutable
class RepositoryOptions {
  /// Per-call TTL override. Overrides adapter config, hook values, and
  /// built-in defaults for this single call.
  ///
  /// A value of [Duration.zero] disables caching for this call entirely
  /// (the result is neither read from nor written to the cache).
  final Duration? cacheTTL;

  /// When true, skips the cache lookup and always fetches fresh data from
  /// the backend. The response is still written back to the cache using the
  /// effective TTL — unless [cacheTTL] is [Duration.zero].
  final bool forceRefresh;

  /// Arbitrary key-value pairs for adapter-specific or plugin-specific
  /// behaviour. Common uses:
  /// - `'correlationId'` — distributed tracing across microservices
  /// - `'idempotencyKey'` — idempotent write operations
  /// - `'tenantId'` — multi-tenant deployments
  /// - `'locale'` — locale hint for content-negotiated responses
  ///
  /// Adapters read well-known keys they support; unknown keys are silently
  /// ignored. There is no runtime enforcement of key names or value types.
  final Map<String, dynamic>? extra;

  const RepositoryOptions({
    this.cacheTTL,
    this.forceRefresh = false,
    this.extra,
  });

  /// Convenience constructor: skip cache and fetch fresh data from the backend.
  ///
  /// Equivalent to `RepositoryOptions(forceRefresh: true)`.
  const RepositoryOptions.refresh()
      : cacheTTL = null,
        forceRefresh = true,
        extra = null;

  /// Convenience constructor: disable caching entirely for this call.
  ///
  /// The result will not be read from the cache and will not be written back
  /// to the cache. Equivalent to
  /// `RepositoryOptions(cacheTTL: Duration.zero, forceRefresh: true)`.
  const RepositoryOptions.noCache()
      : cacheTTL = Duration.zero,
        forceRefresh = true,
        extra = null;

  /// Returns a copy of this instance with the specified fields replaced.
  RepositoryOptions copyWith({
    Duration? cacheTTL,
    bool? forceRefresh,
    Map<String, dynamic>? extra,
  }) {
    return RepositoryOptions(
      cacheTTL: cacheTTL ?? this.cacheTTL,
      forceRefresh: forceRefresh ?? this.forceRefresh,
      extra: extra ?? this.extra,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RepositoryOptions &&
          cacheTTL == other.cacheTTL &&
          forceRefresh == other.forceRefresh &&
          extra == other.extra;

  @override
  int get hashCode => Object.hash(cacheTTL, forceRefresh, extra);

  @override
  String toString() =>
      'RepositoryOptions(cacheTTL: $cacheTTL, forceRefresh: $forceRefresh, '
      'extra: $extra)';
}
