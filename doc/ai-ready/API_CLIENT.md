# ApiClient

> **Current version: 2.3.0**

HTTP transport layer for moose_core adapters. Wraps [Dio](https://pub.dev/packages/dio) and exposes two hook points — header transformation (`api:request_headers`) and full request interception (`api:intercept_request`) — plus EventBus lifecycle events for every request.

---

## At a Glance

```
Adapter.initialize()
  → creates Dio (base URL, auth headers, interceptors)
  → ApiClient(dio, appContext: appContext)
      ↓
  get/post/put/patch/delete()
      │
      ├─ fire api:request.start
      ├─ _mergeOptions → api:request_headers hook (sync, headers only)
      ├─ _interceptRequest → api:intercept_request hook (async, full descriptor)
      │     ├─ returns descriptor → proceed with HTTP call
      │     └─ returns null      → fire api:request.queued; throw RequestQueuedError
      │
      ├─ Dio.get/post/...
      │     ├─ success → fire api:response.success
      │     └─ DioException → fire api:response.error; throw Exception
      │
      └─ replay(descriptor) → bypasses intercept hook, dispatches directly to Dio
```

---

## Constructor

```dart
ApiClient(Dio dio, {MooseAppContext? appContext})
```

`dio` is always created by the adapter — with its adapter-specific base URL, auth headers, and interceptors — and injected here. `ApiClient` does not create Dio internally.

**In adapters:**

```dart
@override
Future<void> initialize(Map<String, dynamic> config) async {
  final dio = Dio(BaseOptions(
    baseUrl: config['baseUrl'] as String,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
  ));

  // Add adapter-specific auth interceptor
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      options.queryParameters['consumer_key'] = config['consumerKey'];
      options.queryParameters['consumer_secret'] = config['consumerSecret'];
      handler.next(options);
    },
  ));

  _apiClient = ApiClient(dio, appContext: appContext);
}
```

`appContext` is available on every `BackendAdapter` via `late MooseAppContext appContext` (injected by `AdapterRegistry`). Passing it gives `ApiClient` access to `hookRegistry` and `eventBus` without per-method wiring.

**Without `appContext` (tests, standalone usage):**

```dart
// No hooks, no events, no interception — pure Dio wrapper
final client = ApiClient(dio);
```

---

## HTTP Methods

All methods follow the same signature pattern:

```dart
Future<Response> get(String endpoint, {
  Map<String, dynamic>? queryParams,
  Map<String, dynamic>? headers,
  CancelToken? cancelToken,
  Options? options,
});

Future<Response> post(String endpoint, {
  dynamic data,
  Map<String, dynamic>? queryParams,
  Map<String, dynamic>? headers,
  ProgressCallback? onSendProgress,
  ProgressCallback? onReceiveProgress,
  CancelToken? cancelToken,
  Options? options,
});

// put, patch, delete follow the same pattern as post
// download(urlPath, savePath, ...) — does NOT run the intercept hook
// uploadFile(endpoint, filePath, ...) — delegates to post
// uploadFiles(endpoint, filePaths, ...) — delegates to post
```

**Error handling:** `DioException` is caught and re-thrown as a plain `Exception` with a human-readable message. All other exceptions propagate as-is.

---

## Hooks

### `api:request_headers`

Transforms request headers before every HTTP call. Executed **synchronously** via `HookRegistry.execute<Map<String, dynamic>>`.

| | |
|---|---|
| **Hook name** | `api:request_headers` |
| **Input** | `Map<String, dynamic>` — merged headers (Options headers + per-request headers) |
| **Output** | `Map<String, dynamic>` — transformed headers |
| **Execution** | Synchronous (`execute<T>`) |
| **Typical use** | Inject `Accept-Language`, auth tokens, correlation IDs |

```dart
// In a LocalizationPlugin or AuthPlugin:
hookRegistry.register('api:request_headers', (data) {
  final headers = Map<String, dynamic>.from(data as Map<String, dynamic>);
  headers['Accept-Language'] = appContext.l10n.activeLocale;
  return headers;
});
```

**Header precedence** (highest → lowest):

1. Per-request `headers` param passed to `get()`/`post()`/etc.
2. Values added by `api:request_headers` hook (using `??=` for non-overriding injection)
3. Dio `BaseOptions.headers` (set by adapter at construction time)

To add a header only if not already set by the caller:
```dart
headers['Accept-Language'] ??= locale; // does not overwrite caller's value
```

To always override:
```dart
headers['Accept-Language'] = locale; // always wins
```

---

### `api:intercept_request`

Intercepts the **full request descriptor** before dispatch. Supports async handlers. Allows a plugin to queue requests for offline replay (outbox pattern), log all outgoing traffic, inject cross-cutting request context, or abort requests entirely.

| | |
|---|---|
| **Hook name** | `api:intercept_request` |
| **Input** | `Map<String, dynamic>?` — full request descriptor (see below) |
| **Output** | `Map<String, dynamic>?` — same map (pass-through) OR `null` (abandon) |
| **Execution** | Asynchronous (`executeAsync<Map<String, dynamic>?>`) |
| **Typical use** | Offline request queue, request logging, auth refresh before retry |

**Request descriptor fields:**

| Key | Type | Description |
|---|---|---|
| `method` | `String` | `'GET'`, `'POST'`, `'PUT'`, `'PATCH'`, or `'DELETE'` |
| `endpoint` | `String` | Path passed to `ApiClient.get()` etc. |
| `data` | `dynamic` | Request body (`POST`/`PUT`/`PATCH` only; `null` for `GET`/`DELETE`) |
| `queryParams` | `Map<String, dynamic>?` | Query string parameters |
| `headers` | `Map<String, dynamic>` | Headers after `api:request_headers` transformation |

**Return semantics:**

| Hook returns | ApiClient behaviour |
|---|---|
| Descriptor map (unchanged) | Proceeds with HTTP call |
| Descriptor map (modified) | Proceeds with modified `queryParams` |
| `null` | Fires `api:request.queued`; throws `RequestQueuedError` |

**When no hook is registered:** `executeAsync` returns the input unchanged — the request proceeds normally. No default registration is needed.

---

## EventBus Events

All events are fired on `appContext.eventBus`. They are no-ops when `appContext` is not provided.

| Event | When fired | Payload keys |
|---|---|---|
| `api:request.start` | Before every request (before intercept hook) | `method`, `endpoint` |
| `api:response.success` | After a successful response | `method`, `endpoint`, `statusCode` |
| `api:response.error` | After a `DioException` | `method`, `endpoint`, `statusCode`?, `message` |
| `api:request.queued` | When intercept hook returns `null` | `method`, `endpoint` |

**Subscribing from a plugin:**

```dart
// In AnalyticsPlugin.onInit():
eventBus.on('api:request.start', (event) {
  _tracker.startTimer('${event.data['method']} ${event.data['endpoint']}');
});

eventBus.on('api:response.success', (event) {
  _tracker.stopTimer('${event.data['method']} ${event.data['endpoint']}');
});

eventBus.on('api:response.error', (event) {
  _tracker.recordError(
    endpoint: event.data['endpoint'] as String,
    statusCode: event.data['statusCode'] as int?,
    message: event.data['message'] as String?,
  );
});
```

---

## `RequestQueuedError`

Thrown by `ApiClient` when `api:intercept_request` returns `null`. Exported from `package:moose_core/services.dart`.

```dart
class RequestQueuedError extends Error {
  final String method;
  final String endpoint;
}
```

Using `Error` (not `Exception`) means it propagates by default — callers that don't handle offline queuing receive a clear signal without a silent no-op. An offline queue plugin typically catches it via the `api:request.queued` EventBus event rather than by catching the error directly.

```dart
// Listening for queued requests to show UI feedback:
eventBus.on('api:request.queued', (event) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Saved for later — no internet')),
  );
});
```

---

## `replay(Map<String, dynamic> descriptor)`

Dispatches a stored request descriptor directly to Dio, **bypassing the `api:intercept_request` hook** entirely. Used by offline queue plugins to replay persisted requests when connectivity is restored.

```dart
Future<Response> replay(Map<String, dynamic> descriptor)
```

The descriptor map has the same shape as the one passed to `api:intercept_request`.

---

## Outbox Pattern — Full Example

An offline queue plugin intercepts outgoing requests when the device has no connectivity, persists them, and replays them when connectivity is restored.

### Plugin registration

```dart
class OfflineQueuePlugin extends FeaturePlugin {
  late OfflineQueueRepository _queue;
  late EventSubscription _connectivitySub;
  late ApiClient _apiClient; // reference to the adapter's ApiClient

  @override
  void onRegister() {
    // Register the intercept hook — runs before every ApiClient request
    hookRegistry.register(
      'api:intercept_request',
      _handleIntercept,
      priority: 100,   // high priority — runs before other interceptors
    );
  }

  @override
  Future<void> onInit() async {
    _queue = OfflineQueueRepository();

    // Listen for connectivity restore to replay queued requests
    _connectivitySub = eventBus.on('connectivity.restored', (_) async {
      await _replayQueue();
    });

    // Show UI feedback when a request is queued
    eventBus.on('api:request.queued', (event) {
      eventBus.fire('ui.show_snackbar', data: {
        'message': 'Saved for later — will sync when online',
      });
    });
  }

  // Hook handler — receives the request descriptor
  Future<Map<String, dynamic>?> _handleIntercept(dynamic data) async {
    final descriptor = data as Map<String, dynamic>;

    // Only queue mutating requests — never queue GETs
    final method = descriptor['method'] as String;
    if (method == 'GET') return descriptor; // always pass-through reads

    final isOnline = await Connectivity().checkConnectivity()
        != ConnectivityResult.none;
    if (isOnline) return descriptor; // pass-through when online

    // Persist the request and abandon the in-flight call
    await _queue.enqueue({
      ...descriptor,
      'queuedAt': DateTime.now().toIso8601String(),
    });
    return null; // signals ApiClient to throw RequestQueuedError
  }

  Future<void> _replayQueue() async {
    final pending = await _queue.dequeueAll();
    for (final descriptor in pending) {
      try {
        await _apiClient.replay(descriptor);
      } catch (e) {
        // Re-queue on failure (e.g. server error)
        await _queue.enqueue(descriptor);
      }
    }
  }

  @override
  Future<void> onStop() async {
    await _connectivitySub.cancel();
  }
}
```

### How it works end-to-end

```
User taps "Add to Cart" while offline
  → CartRepository.addItem() → ApiClient.post('/cart/items', data: {...})
    → api:request.start fires (method: POST, endpoint: /cart/items)
    → api:request_headers hook runs (adds Accept-Language)
    → api:intercept_request hook runs:
        OfflineQueuePlugin._handleIntercept()
          → Connectivity check → offline
          → queue.enqueue({method: POST, endpoint: /cart/items, data: {...}})
          → returns null
    → api:request.queued fires (method: POST, endpoint: /cart/items)
    → RequestQueuedError thrown
  → CartBloc catches RequestQueuedError (or catches via api:request.queued event)
  → Shows "Saved for later" snackbar

...device comes online...

  → connectivity.restored fires
    → OfflineQueuePlugin._replayQueue()
      → dequeues [{method: POST, endpoint: /cart/items, data: {...}}]
      → apiClient.replay(descriptor)
        → Dio.post('/cart/items', data: {...}) — no intercept hook
        → success → cart synced
```

---

## Configuration Helper Methods

Post-construction configuration methods on `ApiClient` (rarely needed — adapters usually configure Dio in `BaseOptions`):

```dart
void setBaseUrl(String baseUrl)
void setDefaultHeaders(Map<String, dynamic> headers)
void setConnectTimeout(Duration timeout)
void setReceiveTimeout(Duration timeout)
void setSendTimeout(Duration timeout)
void addInterceptor(Interceptor interceptor)
void removeInterceptor(Interceptor interceptor)
void clearInterceptors()
String? get baseUrl
Dio get dio                    // raw Dio instance for advanced usage
CancelToken createCancelToken()
```

---

## Testing

`MooseAppContext` accepts a custom `HookRegistry` for test isolation. A `_RecordingAdapter` on Dio captures request options without making real HTTP calls.

```dart
test('api:request_headers hook adds Accept-Language', () async {
  final hooks = HookRegistry();
  hooks.register('api:request_headers', (data) {
    final h = Map<String, dynamic>.from(data as Map<String, dynamic>);
    h['Accept-Language'] ??= 'ja';
    return h;
  });

  final dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
  dio.httpClientAdapter = _RecordingAdapter();

  final client = ApiClient(dio, appContext: MooseAppContext(hookRegistry: hooks));
  await client.get('/products');

  expect(recording.lastHeaders['Accept-Language'], 'ja');
});

test('api:intercept_request returning null throws RequestQueuedError', () async {
  final hooks = HookRegistry();
  hooks.register('api:intercept_request', (_) => null);

  final client = ApiClient(dio, appContext: MooseAppContext(hookRegistry: hooks));

  expect(() => client.post('/cart/items', data: {}),
      throwsA(isA<RequestQueuedError>()));
});
```

---

## See Also

- [EVENT_SYSTEM_GUIDE.md](EVENT_SYSTEM_GUIDE.md) — HookRegistry vs EventBus decision matrix
- [ADAPTER_SYSTEM.md](ADAPTER_SYSTEM.md) — BackendAdapter lifecycle, `appContext` injection
- [REGISTRIES.md](REGISTRIES.md) — HookRegistry `execute` vs `executeAsync`, priority
