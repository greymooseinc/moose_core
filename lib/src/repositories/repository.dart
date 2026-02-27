/// Base class for all repository implementations
///
/// Provides lifecycle management for repositories. Concrete subclasses
/// declare their own dependencies (e.g. `EventBus`, `HookRegistry`,
/// `CacheManager`) as local fields — only what each repo actually needs.
abstract class CoreRepository {
  /// Initialize the repository
  ///
  /// This method is called after the repository is instantiated but before
  /// it's cached. Override this method to perform synchronous initialization
  /// tasks such as:
  /// - Setting up listeners
  /// - Initializing local variables
  /// - Registering hooks
  /// - Configuring internal state
  ///
  /// **Note:** This method is synchronous. For async initialization (loading
  /// data, network calls, etc.), trigger those operations here but don't await
  /// them, or handle them in your repository methods as needed.
  ///
  /// The default implementation does nothing.
  ///
  /// **Example:**
  /// ```dart
  /// class WooProductsRepository extends ProductsRepository {
  ///   @override
  ///   void initialize() {
  ///     // Setup listeners
  ///     _setupListeners();
  ///     // Initialize local state
  ///     _initializeState();
  ///     // Trigger async loading (fire-and-forget)
  ///     _loadCache();
  ///   }
  /// }
  /// ```
  void initialize() {
    // Default implementation: no-op.
    // Subclasses override to perform synchronous initialization.
  }
}
