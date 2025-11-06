import 'dart:async';

/// Base class for all events in the system
abstract class Event {
  /// Timestamp when the event was created
  final DateTime timestamp;

  /// Optional metadata for the event
  final Map<String, dynamic>? metadata;

  Event({DateTime? timestamp, this.metadata})
      : timestamp = timestamp ?? DateTime.now();
}

/// Subscription handle that allows unsubscribing from events
class EventSubscription {
  final String _eventType;
  final StreamSubscription _subscription;
  final EventBus _eventBus;

  EventSubscription._(this._eventType, this._subscription, this._eventBus);

  /// Cancel this subscription
  Future<void> cancel() async {
    await _subscription.cancel();
    _eventBus._removeSubscription(this);
  }

  /// Check if the subscription is active
  bool get isActive => !_subscription.isPaused;

  /// Pause the subscription temporarily
  void pause([Future<void>? resumeSignal]) {
    _subscription.pause(resumeSignal);
  }

  /// Resume a paused subscription
  void resume() {
    _subscription.resume();
  }
}

/// EventBus - A publish-subscribe messaging system for decoupled communication
///
/// The EventBus allows different parts of your application to communicate
/// without direct dependencies. Components can publish events and other
/// components can subscribe to those events.
///
/// Example:
/// ```dart
/// // Define an event
/// class UserLoggedInEvent extends Event {
///   final String userId;
///   UserLoggedInEvent(this.userId);
/// }
///
/// // Subscribe to events
/// final subscription = EventBus().on<UserLoggedInEvent>((event) {
///   print('User logged in: ${event.userId}');
/// });
///
/// // Publish an event
/// EventBus().fire(UserLoggedInEvent('user123'));
///
/// // Unsubscribe when done
/// await subscription.cancel();
/// ```
class EventBus {
  static final EventBus _instance = EventBus._internal();

  /// Get the singleton instance
  factory EventBus() => _instance;

  /// Named constructor for explicit access
  static EventBus get instance => _instance;

  EventBus._internal();

  // Map of event type to stream controller
  final Map<Type, StreamController<Event>> _controllers = {};

  // Track all active subscriptions for cleanup
  final Set<EventSubscription> _activeSubscriptions = {};

  /// Subscribe to events of type T
  ///
  /// [onEvent] - Callback function that will be called when an event is published
  /// [onError] - Optional error handler for the subscription
  /// [onDone] - Optional callback when the subscription is cancelled
  ///
  /// Returns an [EventSubscription] that can be used to cancel the subscription
  EventSubscription on<T extends Event>(
    void Function(T event) onEvent, {
    Function? onError,
    void Function()? onDone,
  }) {
    final controller = _getControllerForType<T>();

    final subscription = controller.stream
        .where((event) => event is T)
        .cast<T>()
        .listen(
          onEvent,
          onError: onError,
          onDone: onDone,
        );

    final eventSubscription = EventSubscription._(
      T.toString(),
      subscription,
      this,
    );

    _activeSubscriptions.add(eventSubscription);

    return eventSubscription;
  }

  /// Subscribe to events of type T and handle them asynchronously
  ///
  /// Similar to [on] but supports async event handlers
  EventSubscription onAsync<T extends Event>(
    Future<void> Function(T event) onEvent, {
    Function? onError,
    void Function()? onDone,
  }) {
    return on<T>(
      (event) async {
        try {
          await onEvent(event);
        } catch (e) {
          if (onError != null) {
            onError(e);
          } else {
            print('Error in async event handler: $e');
          }
        }
      },
      onError: onError,
      onDone: onDone,
    );
  }

  /// Publish an event to all subscribers
  ///
  /// [event] - The event to publish
  ///
  /// All subscribers of this event type will be notified
  void fire<T extends Event>(T event) {
    final controller = _getControllerForType<T>();

    if (!controller.isClosed) {
      controller.add(event);
    } else {
      print('Warning: Attempted to fire event on closed controller: ${T.toString()}');
    }
  }

  /// Publish an event asynchronously and wait for all handlers to complete
  ///
  /// This is useful when you need to ensure all event handlers have finished
  /// processing before continuing execution
  Future<void> fireAndWait<T extends Event>(T event) async {
    fire(event);
    // Allow microtasks to complete
    await Future.delayed(Duration.zero);
  }

  /// Get a stream of events of type T
  ///
  /// This is useful when you want to use stream operators
  /// like map, where, debounce, etc.
  Stream<T> stream<T extends Event>() {
    final controller = _getControllerForType<T>();
    return controller.stream.where((event) => event is T).cast<T>();
  }

  /// Remove a subscription from tracking
  void _removeSubscription(EventSubscription subscription) {
    _activeSubscriptions.remove(subscription);
  }

  /// Get or create a stream controller for the given event type
  StreamController<Event> _getControllerForType<T extends Event>() {
    if (!_controllers.containsKey(T)) {
      _controllers[T] = StreamController<Event>.broadcast(
        onCancel: () {
          // Keep the controller around for future subscriptions
          // Only close it when explicitly destroying the event bus
        },
      );
    }
    return _controllers[T]!;
  }

  /// Cancel all active subscriptions for a specific event type
  Future<void> cancelSubscriptionsForType<T extends Event>() async {
    final subscriptionsToCancel = _activeSubscriptions
        .where((sub) => sub._eventType == T.toString())
        .toList();

    for (final subscription in subscriptionsToCancel) {
      await subscription.cancel();
    }
  }

  /// Cancel all active subscriptions
  Future<void> cancelAllSubscriptions() async {
    final subscriptions = _activeSubscriptions.toList();
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
    _activeSubscriptions.clear();
  }

  /// Destroy the event bus and clean up all resources
  ///
  /// This will close all stream controllers and cancel all subscriptions.
  /// Use this when shutting down your application.
  Future<void> destroy() async {
    await cancelAllSubscriptions();

    for (final controller in _controllers.values) {
      if (!controller.isClosed) {
        await controller.close();
      }
    }

    _controllers.clear();
  }

  /// Get the number of active subscriptions
  int get activeSubscriptionCount => _activeSubscriptions.length;

  /// Get the number of registered event types
  int get registeredEventTypes => _controllers.length;

  /// Check if there are any subscribers for a specific event type
  bool hasSubscribers<T extends Event>() {
    return _controllers.containsKey(T) &&
           _controllers[T]!.hasListener;
  }

  /// Get all registered event type names
  List<String> getRegisteredEventTypes() {
    return _controllers.keys.map((type) => type.toString()).toList();
  }

  /// Reset the event bus (useful for testing)
  ///
  /// WARNING: This will destroy all subscriptions and controllers
  Future<void> reset() async {
    await destroy();
  }
}
