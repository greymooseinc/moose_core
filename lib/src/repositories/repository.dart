import '../events/hook_registry.dart';

/// Base class for all repository implementations
///
/// Provides common functionality and lifecycle management for repositories.
abstract class CoreRepository {
  final HookRegistry hookRegistry = HookRegistry();

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
  /// class WooProductsRepository extends CoreRepository implements ProductsRepository {
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
    // Default implementation: do nothing
    // Subclasses can override to perform initialization tasks

    print('repository initialize: $runtimeType');
  }
}