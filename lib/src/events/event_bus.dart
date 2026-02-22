import 'dart:async';

import 'package:flutter/foundation.dart';

/// Event - Represents an event in the system
///
/// Events are identified by name (string) and carry a data payload.
/// This enables decoupled plugin-to-plugin communication without
/// requiring shared type definitions.
///
/// Example:
/// ```dart
/// // Fire an event
/// EventBus().fire('user.profile.updated', data: {'userId': '123'});
///
/// // Listen to an event
/// EventBus().on('user.profile.updated', (event) {
///   print('User updated: ${event.data['userId']}');
/// });
/// ```
class Event {
  /// The name/type of this event
  final String name;

  /// Data payload for this event
  final Map<String, dynamic> data;

  /// Timestamp when the event was created
  final DateTime timestamp;

  /// Optional metadata for the event
  final Map<String, dynamic>? metadata;

  Event({
    required this.name,
    required this.data,
    DateTime? timestamp,
    this.metadata,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() => 'Event(name: $name, data: $data)';
}

/// Subscription handle that allows unsubscribing from events
class EventSubscription {
  final String _eventName;
  final StreamSubscription _subscription;
  final EventBus _eventBus;

  EventSubscription._(this._eventName, this._subscription, this._eventBus);

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
/// All events are string-based, eliminating the need for shared type definitions
/// between plugins. This enables true plugin independence.
///
/// ## Basic Example:
/// ```dart
/// // Subscribe to an event
/// final subscription = EventBus().on('user.logged.in', (event) {
///   print('User logged in: ${event.data['userId']}');
/// });
///
/// // Fire an event
/// EventBus().fire('user.logged.in', data: {'userId': 'user123'});
///
/// // Unsubscribe when done
/// await subscription.cancel();
/// ```
///
/// ## Event Naming Convention:
/// Use dot notation: `<domain>.<action>.<optional-detail>`
/// - `cart.item.added`
/// - `user.profile.updated`
/// - `payment.completed`
/// - `notification.sent`
///
/// ## Plugin Communication Example:
/// ```dart
/// // Payment plugin fires event (no dependency on other plugins)
/// EventBus().fire('payment.completed', data: {
///   'orderId': 'order-123',
///   'amount': 99.99,
/// });
///
/// // Analytics plugin listens (no dependency on payment plugin!)
/// EventBus().on('payment.completed', (event) {
///   trackPayment(event.data['orderId'], event.data['amount']);
/// });
/// ```
class EventBus {
  EventBus();

  // Map of event name to stream controller
  final Map<String, StreamController<Event>> _controllers = {};

  // Track all active subscriptions for cleanup
  final Set<EventSubscription> _activeSubscriptions = {};

  /// Subscribe to events by name
  ///
  /// [eventName] - The name of the event to subscribe to
  /// [onEvent] - Callback function that will be called when the event is fired
  /// [onError] - Optional error handler for the subscription
  /// [onDone] - Optional callback when the subscription is cancelled
  ///
  /// Example:
  /// ```dart
  /// final subscription = EventBus().on(
  ///   'user.profile.updated',
  ///   (event) {
  ///     print('User: ${event.data['userId']}');
  ///   },
  /// );
  /// ```
  EventSubscription on(
    String eventName,
    void Function(Event event) onEvent, {
    Function? onError,
    void Function()? onDone,
  }) {
    final controller = _getControllerForName(eventName);

    final subscription = controller.stream
        .where((event) => event.name == eventName)
        .listen(
          onEvent,
          onError: onError,
          onDone: onDone,
        );

    final eventSubscription = EventSubscription._(
      eventName,
      subscription,
      this,
    );

    _activeSubscriptions.add(eventSubscription);

    return eventSubscription;
  }

  /// Subscribe to events and handle them asynchronously
  ///
  /// Similar to [on] but supports async event handlers
  ///
  /// Example:
  /// ```dart
  /// EventBus().onAsync(
  ///   'order.placed',
  ///   (event) async {
  ///     await sendConfirmationEmail(event.data['orderId']);
  ///     await updateInventory(event.data['orderId']);
  ///   },
  /// );
  /// ```
  EventSubscription onAsync(
    String eventName,
    Future<void> Function(Event event) onEvent, {
    Function? onError,
    void Function()? onDone,
  }) {
    return on(
      eventName,
      (event) async {
        try {
          await onEvent(event);
        } catch (e) {
          if (onError != null) {
            onError(e);
          } else {
            debugPrint('Error in async event handler for "$eventName": $e');
          }
        }
      },
      onError: onError,
      onDone: onDone,
    );
  }

  /// Fire an event by name
  ///
  /// This publishes an event that all subscribers will receive.
  ///
  /// [eventName] - The name of the event to fire
  /// [data] - The data payload for the event (default: empty map)
  /// [metadata] - Optional metadata for the event
  ///
  /// Example:
  /// ```dart
  /// EventBus().fire(
  ///   'user.profile.updated',
  ///   data: {'userId': '123', 'name': 'John'},
  /// );
  /// ```
  void fire(
    String eventName, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? metadata,
  }) {
    final event = Event(
      name: eventName,
      data: data ?? {},
      metadata: metadata,
    );

    final controller = _getControllerForName(eventName);

    if (!controller.isClosed) {
      controller.add(event);
    } else {
      debugPrint('Warning: Attempted to fire event on closed controller: $eventName');
    }
  }

  /// Fire an event and wait for all handlers to complete
  ///
  /// This is useful when you need to ensure all event handlers have finished
  /// processing before continuing execution
  ///
  /// Example:
  /// ```dart
  /// await EventBus().fireAndWait('critical.operation', data: {...});
  /// // All handlers have completed
  /// ```
  Future<void> fireAndWait(
    String eventName, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? metadata,
  }) async {
    fire(eventName, data: data, metadata: metadata);
    // Allow microtasks to complete
    await Future.delayed(Duration.zero);
  }

  /// Get a stream of events by event name
  ///
  /// This is useful when you want to use stream operators
  /// like map, where, debounce, etc.
  ///
  /// Example:
  /// ```dart
  /// EventBus().stream('user.profile.updated')
  ///   .debounceTime(Duration(seconds: 1))
  ///   .listen((event) => updateUI(event.data));
  /// ```
  Stream<Event> stream(String eventName) {
    final controller = _getControllerForName(eventName);
    return controller.stream.where((event) => event.name == eventName);
  }

  /// Remove a subscription from tracking
  void _removeSubscription(EventSubscription subscription) {
    _activeSubscriptions.remove(subscription);
  }

  /// Get or create a stream controller for the given event name
  StreamController<Event> _getControllerForName(String eventName) {
    if (!_controllers.containsKey(eventName)) {
      _controllers[eventName] = StreamController<Event>.broadcast(
        onCancel: () {
          // Keep the controller around for future subscriptions
          // Only close it when explicitly destroying the event bus
        },
      );
    }
    return _controllers[eventName]!;
  }

  /// Cancel all active subscriptions for a specific event name
  Future<void> cancelSubscriptionsForEvent(String eventName) async {
    final subscriptionsToCancel = _activeSubscriptions
        .where((sub) => sub._eventName == eventName)
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

  /// Get the number of registered event names
  int get registeredEventCount => _controllers.length;

  /// Check if there are any subscribers for a specific event
  bool hasSubscribers(String eventName) {
    return _controllers.containsKey(eventName) &&
           _controllers[eventName]!.hasListener;
  }

  /// Get all registered event names
  List<String> getRegisteredEvents() {
    return _controllers.keys.toList();
  }

  /// Reset the event bus (useful for testing)
  ///
  /// WARNING: This will destroy all subscriptions and controllers
  Future<void> reset() async {
    await destroy();
  }
}
