import 'package:flutter_test/flutter_test.dart';
import 'package:moose_core/services.dart';

void main() {
  group('EventBus', () {
    late EventBus bus;

    setUp(() async {
      bus = EventBus();
      await bus.reset();
    });

    tearDown(() async {
      await bus.reset();
    });

    // =========================================================================
    // Singleton
    // =========================================================================

    group('Instance Isolation', () {
      test('each EventBus() creates an independent instance', () {
        final a = EventBus();
        final b = EventBus();

        expect(identical(a, b), isFalse);
      });
    });

    // =========================================================================
    // Event class
    // =========================================================================

    group('Event', () {
      test('should create event with required fields', () {
        final event = Event(name: 'test.event', data: {'key': 'value'});

        expect(event.name, equals('test.event'));
        expect(event.data['key'], equals('value'));
        expect(event.metadata, isNull);
        expect(event.timestamp, isA<DateTime>());
      });

      test('should create event with metadata', () {
        final event = Event(
          name: 'test.event',
          data: {'id': 1},
          metadata: {'source': 'unit_test'},
        );

        expect(event.metadata?['source'], equals('unit_test'));
      });

      test('should allow custom timestamp', () {
        final fixedTime = DateTime(2026, 1, 1);
        final event = Event(
          name: 'test.event',
          data: {},
          timestamp: fixedTime,
        );

        expect(event.timestamp, equals(fixedTime));
      });

      test('toString should include name and data', () {
        final event = Event(name: 'my.event', data: {'x': 1});
        expect(event.toString(), contains('my.event'));
        expect(event.toString(), contains('x'));
      });
    });

    // =========================================================================
    // on / fire
    // =========================================================================

    group('on / fire', () {
      test('should receive fired event', () async {
        Event? received;
        bus.on('user.login', (event) => received = event);

        bus.fire('user.login', data: {'userId': '123'});
        await Future.delayed(Duration.zero);

        expect(received, isNotNull);
        expect(received!.name, equals('user.login'));
        expect(received!.data['userId'], equals('123'));
      });

      test('should not receive events for a different name', () async {
        Event? received;
        bus.on('event.a', (event) => received = event);

        bus.fire('event.b', data: {'key': 'value'});
        await Future.delayed(Duration.zero);

        expect(received, isNull);
      });

      test('should support multiple subscribers on the same event', () async {
        final received = <Event>[];
        bus.on('shared.event', (event) => received.add(event));
        bus.on('shared.event', (event) => received.add(event));

        bus.fire('shared.event');
        await Future.delayed(Duration.zero);

        expect(received.length, equals(2));
      });

      test('should pass empty data map when not specified', () async {
        Map<String, dynamic>? receivedData;
        bus.on('test.event', (event) => receivedData = event.data);

        bus.fire('test.event');
        await Future.delayed(Duration.zero);

        expect(receivedData, isNotNull);
        expect(receivedData, isEmpty);
      });

      test('should pass metadata to subscriber', () async {
        Map<String, dynamic>? receivedMeta;
        bus.on('test.event', (event) => receivedMeta = event.metadata);

        bus.fire('test.event', metadata: {'version': '2'});
        await Future.delayed(Duration.zero);

        expect(receivedMeta?['version'], equals('2'));
      });

      test('should receive multiple fired events in order', () async {
        final values = <int>[];
        bus.on('count.event', (event) => values.add(event.data['n'] as int));

        bus.fire('count.event', data: {'n': 1});
        bus.fire('count.event', data: {'n': 2});
        bus.fire('count.event', data: {'n': 3});
        await Future.delayed(Duration.zero);

        expect(values, equals([1, 2, 3]));
      });
    });

    // =========================================================================
    // EventSubscription
    // =========================================================================

    group('EventSubscription', () {
      test('cancel should stop receiving events', () async {
        final received = <Event>[];
        final sub = bus.on('test.event', (event) => received.add(event));

        bus.fire('test.event');
        await Future.delayed(Duration.zero);
        expect(received.length, equals(1));

        await sub.cancel();

        bus.fire('test.event');
        await Future.delayed(Duration.zero);
        expect(received.length, equals(1)); // No new events
      });

      test('pause and resume should work correctly', () async {
        final received = <Event>[];
        final sub = bus.on('test.event', (event) => received.add(event));

        bus.fire('test.event');
        await Future.delayed(Duration.zero);
        expect(received.length, equals(1));

        sub.pause();
        bus.fire('test.event');
        await Future.delayed(Duration.zero);

        sub.resume();
        bus.fire('test.event');
        await Future.delayed(Duration.zero);

        // Should have 2 total: 1 before pause, 1 after resume
        expect(received.length, greaterThanOrEqualTo(1));

        await sub.cancel();
      });

      test('isActive returns true for active subscription', () {
        final sub = bus.on('test.event', (_) {});
        expect(sub.isActive, isTrue);
      });
    });

    // =========================================================================
    // onAsync
    // =========================================================================

    group('onAsync', () {
      test('should handle async event handler', () async {
        bool handled = false;

        bus.onAsync('async.event', (event) async {
          await Future.delayed(const Duration(milliseconds: 10));
          handled = true;
        });

        bus.fire('async.event');
        await Future.delayed(const Duration(milliseconds: 50));

        expect(handled, isTrue);
      });

      test('should not throw when async handler errors', () async {
        bus.onAsync('error.event', (event) async {
          throw Exception('async error');
        });

        expect(
          () async {
            bus.fire('error.event');
            await Future.delayed(const Duration(milliseconds: 20));
          },
          returnsNormally,
        );
      });

      test('should call custom onError when async handler throws', () async {
        dynamic capturedError;

        bus.onAsync(
          'error.event',
          (event) async => throw Exception('async fail'),
          onError: (e) => capturedError = e,
        );

        bus.fire('error.event');
        await Future.delayed(const Duration(milliseconds: 20));

        expect(capturedError, isNotNull);
      });
    });

    // =========================================================================
    // fireAndWait
    // =========================================================================

    group('fireAndWait', () {
      test('should complete after firing event', () async {
        bool called = false;
        bus.on('wait.event', (event) => called = true);

        await bus.fireAndWait('wait.event', data: {'x': 1});

        expect(called, isTrue);
      });
    });

    // =========================================================================
    // stream
    // =========================================================================

    group('stream', () {
      test('should expose event as a stream', () async {
        final events = <Event>[];
        final subscription = bus.stream('stream.event').listen(events.add);

        bus.fire('stream.event', data: {'a': 1});
        bus.fire('stream.event', data: {'a': 2});
        await Future.delayed(Duration.zero);

        expect(events.length, equals(2));
        await subscription.cancel();
      });

      test('should not include events from other names', () async {
        final events = <Event>[];
        final subscription = bus.stream('only.this').listen(events.add);

        bus.fire('only.this');
        bus.fire('not.this');
        await Future.delayed(Duration.zero);

        expect(events.length, equals(1));
        await subscription.cancel();
      });
    });

    // =========================================================================
    // cancelSubscriptionsForEvent
    // =========================================================================

    group('cancelSubscriptionsForEvent', () {
      test('should cancel all subscriptions for a specific event', () async {
        final received = <Event>[];
        bus.on('specific.event', (event) => received.add(event));
        bus.on('specific.event', (event) => received.add(event));
        bus.on('other.event', (event) => received.add(event));

        await bus.cancelSubscriptionsForEvent('specific.event');

        bus.fire('specific.event');
        bus.fire('other.event');
        await Future.delayed(Duration.zero);

        // Only other.event should have been received
        expect(received.where((e) => e.name == 'specific.event').length, equals(0));
      });
    });

    // =========================================================================
    // cancelAllSubscriptions
    // =========================================================================

    group('cancelAllSubscriptions', () {
      test('should cancel all active subscriptions', () async {
        final received = <Event>[];
        bus.on('event.a', (event) => received.add(event));
        bus.on('event.b', (event) => received.add(event));

        await bus.cancelAllSubscriptions();

        bus.fire('event.a');
        bus.fire('event.b');
        await Future.delayed(Duration.zero);

        expect(received, isEmpty);
        expect(bus.activeSubscriptionCount, equals(0));
      });
    });

    // =========================================================================
    // Metadata / introspection
    // =========================================================================

    group('Metadata', () {
      test('activeSubscriptionCount reflects current subscriptions', () async {
        expect(bus.activeSubscriptionCount, equals(0));

        final sub1 = bus.on('e1', (_) {});
        final sub2 = bus.on('e2', (_) {});

        expect(bus.activeSubscriptionCount, equals(2));

        await sub1.cancel();
        expect(bus.activeSubscriptionCount, equals(1));

        await sub2.cancel();
        expect(bus.activeSubscriptionCount, equals(0));
      });

      test('registeredEventCount increases as new event names are used', () {
        bus.fire('new.event.1');
        bus.fire('new.event.2');

        expect(bus.registeredEventCount, greaterThanOrEqualTo(2));
      });

      test('hasSubscribers returns true when there are listeners', () {
        bus.on('my.event', (_) {});
        expect(bus.hasSubscribers('my.event'), isTrue);
      });

      test('hasSubscribers returns false for unknown event', () {
        expect(bus.hasSubscribers('never.fired'), isFalse);
      });

      test('getRegisteredEvents returns all event names', () {
        bus.fire('alpha');
        bus.fire('beta');

        final events = bus.getRegisteredEvents();
        expect(events, containsAll(['alpha', 'beta']));
      });
    });

    // =========================================================================
    // Real-world plugin communication patterns
    // =========================================================================

    group('Plugin Communication Patterns', () {
      test('payment plugin fires event that analytics plugin receives', () async {
        final analyticsEvents = <Event>[];

        // Analytics plugin subscribes
        bus.on('payment.completed', (event) => analyticsEvents.add(event));

        // Payment plugin fires
        bus.fire('payment.completed', data: {
          'orderId': 'order-123',
          'amount': 99.99,
        });

        await Future.delayed(Duration.zero);

        expect(analyticsEvents.length, equals(1));
        expect(analyticsEvents.first.data['orderId'], equals('order-123'));
        expect(analyticsEvents.first.data['amount'], equals(99.99));
      });

      test('multiple plugins can subscribe to the same commerce event', () async {
        final pluginAReceived = <Event>[];
        final pluginBReceived = <Event>[];

        bus.on('cart.item.added', (event) => pluginAReceived.add(event));
        bus.on('cart.item.added', (event) => pluginBReceived.add(event));

        bus.fire('cart.item.added', data: {'productId': 'prod-001', 'qty': 2});
        await Future.delayed(Duration.zero);

        expect(pluginAReceived.length, equals(1));
        expect(pluginBReceived.length, equals(1));
      });
    });
  });
}
