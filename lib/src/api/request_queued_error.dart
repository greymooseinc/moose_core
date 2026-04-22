/// Thrown by [ApiClient] when a request is intercepted by the
/// `api:intercept_request` hook and the hook handler returns `null`.
///
/// This typically means an offline queue plugin has persisted the request for
/// later replay (outbox pattern). The error propagates through the normal
/// exception chain so callers that do not handle offline queuing receive a
/// clear signal without a silent no-op.
///
/// ```dart
/// // In an offline queue plugin:
/// hookRegistry.register('api:intercept_request', (descriptor) async {
///   if (await connectivity.isOnline()) return descriptor;   // pass-through
///   await queue.enqueue(descriptor as Map<String, dynamic>); // persist
///   return null;                                             // abandon request
/// }, priority: 100);
///
/// // To replay queued requests when connectivity restores:
/// for (final descriptor in await queue.dequeueAll()) {
///   await apiClient.replay(descriptor);
/// }
/// ```
///
/// Subscribe to `api:request.queued` on the [EventBus] to show UI feedback
/// (e.g. "Saved for later") without catching this error directly:
/// ```dart
/// eventBus.on('api:request.queued', (event) {
///   showQueuedSnackbar(event.data['endpoint'] as String);
/// });
/// ```
class RequestQueuedError extends Error {
  /// HTTP method of the intercepted request (e.g. `'GET'`, `'POST'`).
  final String method;

  /// Endpoint path of the intercepted request.
  final String endpoint;

  RequestQueuedError(this.method, this.endpoint);

  @override
  String toString() =>
      'RequestQueuedError: $method $endpoint was intercepted and queued for later execution';
}
