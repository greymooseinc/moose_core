import 'package:dio/dio.dart';

import '../app/moose_app_context.dart';
import 'request_queued_error.dart';

/// Advanced API client with comprehensive features
///
/// Features:
/// - Progress tracking for uploads/downloads
/// - Custom headers per request
/// - Request cancellation
/// - File uploads/downloads
/// - Retry logic
/// - Request/response interceptors
/// - Hook-based request header transformation via `api:request_headers`
/// - Hook-based request interception via `api:intercept_request` (outbox pattern)
/// - EventBus lifecycle events (`api:request.start`, `api:response.success`,
///   `api:response.error`, `api:request.queued`)
///
/// ## Hook contracts
///
/// ### `api:request_headers`
/// Transforms request headers before every call.
/// - Input: `Map<String, dynamic>` — merged request headers
/// - Output: `Map<String, dynamic>` — transformed headers
///
/// ### `api:intercept_request`
/// Intercepts the full request descriptor before dispatch. Supports async
/// handlers (e.g. writing to a local queue database). Called via
/// `HookRegistry.executeAsync`.
/// - Input: `Map<String, dynamic>` with keys: `method`, `endpoint`, `data`,
///   `queryParams`, `headers`
/// - Output: `Map<String, dynamic>` to proceed (may be modified), or `null`
///   to abandon the request (throws [RequestQueuedError])
///
/// ```dart
/// // Offline queue plugin — queue request and abandon it when offline:
/// hookRegistry.register('api:intercept_request', (descriptor) async {
///   if (await connectivity.isOnline()) return descriptor;
///   await queue.enqueue(descriptor as Map<String, dynamic>);
///   return null;
/// }, priority: 100);
///
/// // Replay queued requests when connectivity restores:
/// for (final d in await queue.dequeueAll()) {
///   await apiClient.replay(d);
/// }
/// ```
class ApiClient {
  final Dio _dio;
  final MooseAppContext? _appContext;

  ApiClient(this._dio, {MooseAppContext? appContext})
      : _appContext = appContext;

  // ---------------------------------------------------------------------------
  // HTTP methods
  // ---------------------------------------------------------------------------

  /// GET request with optional headers and cancellation
  Future<Response> get(
    String endpoint, {
    Map<String, dynamic>? queryParams,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
    Options? options,
  }) async {
    _fire('api:request.start', {'method': 'GET', 'endpoint': endpoint});
    final mergedOptions = _mergeOptions(options, headers);
    final descriptor = await _interceptRequest({
      'method': 'GET',
      'endpoint': endpoint,
      'queryParams': queryParams,
      'headers': mergedOptions.headers ?? {},
    });
    if (descriptor == null) {
      _fire('api:request.queued', {'method': 'GET', 'endpoint': endpoint});
      throw RequestQueuedError('GET', endpoint);
    }
    try {
      final response = await _dio.get(
        endpoint,
        queryParameters: descriptor['queryParams'] as Map<String, dynamic>?,
        options: mergedOptions,
        cancelToken: cancelToken,
      );
      _fire('api:response.success',
          {'method': 'GET', 'endpoint': endpoint, 'statusCode': response.statusCode});
      return response;
    } on DioException catch (e) {
      _fire('api:response.error', {
        'method': 'GET',
        'endpoint': endpoint,
        'statusCode': e.response?.statusCode,
        'message': e.message,
      });
      throw _handleError(e);
    }
  }

  /// POST request with optional headers, progress tracking, and cancellation
  Future<Response> post(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParams,
    Map<String, dynamic>? headers,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
    Options? options,
  }) async {
    _fire('api:request.start', {'method': 'POST', 'endpoint': endpoint});
    final mergedOptions = _mergeOptions(options, headers);
    final descriptor = await _interceptRequest({
      'method': 'POST',
      'endpoint': endpoint,
      'data': data,
      'queryParams': queryParams,
      'headers': mergedOptions.headers ?? {},
    });
    if (descriptor == null) {
      _fire('api:request.queued', {'method': 'POST', 'endpoint': endpoint});
      throw RequestQueuedError('POST', endpoint);
    }
    try {
      final response = await _dio.post(
        endpoint,
        data: data,
        queryParameters: descriptor['queryParams'] as Map<String, dynamic>?,
        options: mergedOptions,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
        cancelToken: cancelToken,
      );
      _fire('api:response.success',
          {'method': 'POST', 'endpoint': endpoint, 'statusCode': response.statusCode});
      return response;
    } on DioException catch (e) {
      _fire('api:response.error', {
        'method': 'POST',
        'endpoint': endpoint,
        'statusCode': e.response?.statusCode,
        'message': e.message,
      });
      throw _handleError(e);
    }
  }

  /// PUT request with optional headers, progress tracking, and cancellation
  Future<Response> put(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParams,
    Map<String, dynamic>? headers,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
    Options? options,
  }) async {
    _fire('api:request.start', {'method': 'PUT', 'endpoint': endpoint});
    final mergedOptions = _mergeOptions(options, headers);
    final descriptor = await _interceptRequest({
      'method': 'PUT',
      'endpoint': endpoint,
      'data': data,
      'queryParams': queryParams,
      'headers': mergedOptions.headers ?? {},
    });
    if (descriptor == null) {
      _fire('api:request.queued', {'method': 'PUT', 'endpoint': endpoint});
      throw RequestQueuedError('PUT', endpoint);
    }
    try {
      final response = await _dio.put(
        endpoint,
        data: data,
        queryParameters: descriptor['queryParams'] as Map<String, dynamic>?,
        options: mergedOptions,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
        cancelToken: cancelToken,
      );
      _fire('api:response.success',
          {'method': 'PUT', 'endpoint': endpoint, 'statusCode': response.statusCode});
      return response;
    } on DioException catch (e) {
      _fire('api:response.error', {
        'method': 'PUT',
        'endpoint': endpoint,
        'statusCode': e.response?.statusCode,
        'message': e.message,
      });
      throw _handleError(e);
    }
  }

  /// DELETE request with optional headers and cancellation
  Future<Response> delete(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParams,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
    Options? options,
  }) async {
    _fire('api:request.start', {'method': 'DELETE', 'endpoint': endpoint});
    final mergedOptions = _mergeOptions(options, headers);
    final descriptor = await _interceptRequest({
      'method': 'DELETE',
      'endpoint': endpoint,
      'data': data,
      'queryParams': queryParams,
      'headers': mergedOptions.headers ?? {},
    });
    if (descriptor == null) {
      _fire('api:request.queued', {'method': 'DELETE', 'endpoint': endpoint});
      throw RequestQueuedError('DELETE', endpoint);
    }
    try {
      final response = await _dio.delete(
        endpoint,
        data: data,
        queryParameters: descriptor['queryParams'] as Map<String, dynamic>?,
        options: mergedOptions,
        cancelToken: cancelToken,
      );
      _fire('api:response.success',
          {'method': 'DELETE', 'endpoint': endpoint, 'statusCode': response.statusCode});
      return response;
    } on DioException catch (e) {
      _fire('api:response.error', {
        'method': 'DELETE',
        'endpoint': endpoint,
        'statusCode': e.response?.statusCode,
        'message': e.message,
      });
      throw _handleError(e);
    }
  }

  /// PATCH request with optional headers, progress tracking, and cancellation
  Future<Response> patch(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParams,
    Map<String, dynamic>? headers,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
    Options? options,
  }) async {
    _fire('api:request.start', {'method': 'PATCH', 'endpoint': endpoint});
    final mergedOptions = _mergeOptions(options, headers);
    final descriptor = await _interceptRequest({
      'method': 'PATCH',
      'endpoint': endpoint,
      'data': data,
      'queryParams': queryParams,
      'headers': mergedOptions.headers ?? {},
    });
    if (descriptor == null) {
      _fire('api:request.queued', {'method': 'PATCH', 'endpoint': endpoint});
      throw RequestQueuedError('PATCH', endpoint);
    }
    try {
      final response = await _dio.patch(
        endpoint,
        data: data,
        queryParameters: descriptor['queryParams'] as Map<String, dynamic>?,
        options: mergedOptions,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
        cancelToken: cancelToken,
      );
      _fire('api:response.success',
          {'method': 'PATCH', 'endpoint': endpoint, 'statusCode': response.statusCode});
      return response;
    } on DioException catch (e) {
      _fire('api:response.error', {
        'method': 'PATCH',
        'endpoint': endpoint,
        'statusCode': e.response?.statusCode,
        'message': e.message,
      });
      throw _handleError(e);
    }
  }

  /// Download file with progress tracking
  Future<Response> download(
    String urlPath,
    String savePath, {
    ProgressCallback? onReceiveProgress,
    Map<String, dynamic>? queryParams,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
    bool deleteOnError = true,
    Options? options,
  }) async {
    try {
      return await _dio.download(
        urlPath,
        savePath,
        queryParameters: queryParams,
        options: _mergeOptions(options, headers),
        onReceiveProgress: onReceiveProgress,
        cancelToken: cancelToken,
        deleteOnError: deleteOnError,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Upload file with progress tracking
  Future<Response> uploadFile(
    String endpoint,
    String filePath, {
    String fieldName = 'file',
    Map<String, dynamic>? additionalData,
    ProgressCallback? onSendProgress,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
  }) async {
    try {
      final formData = FormData.fromMap({
        fieldName: await MultipartFile.fromFile(filePath),
        ...?additionalData,
      });

      return await post(
        endpoint,
        data: formData,
        headers: headers,
        onSendProgress: onSendProgress,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Upload multiple files with progress tracking
  Future<Response> uploadFiles(
    String endpoint,
    List<String> filePaths, {
    String fieldName = 'files',
    Map<String, dynamic>? additionalData,
    ProgressCallback? onSendProgress,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
  }) async {
    try {
      final files = await Future.wait(
        filePaths.map((path) => MultipartFile.fromFile(path)),
      );

      final formData = FormData.fromMap({
        fieldName: files,
        ...?additionalData,
      });

      return await post(
        endpoint,
        data: formData,
        headers: headers,
        onSendProgress: onSendProgress,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Replays a previously queued request descriptor without running it through
  /// the `api:intercept_request` hook (to prevent re-queuing).
  ///
  /// Used by offline queue plugins to replay persisted requests when
  /// connectivity is restored:
  /// ```dart
  /// for (final descriptor in await queue.dequeueAll()) {
  ///   try {
  ///     await apiClient.replay(descriptor);
  ///   } catch (_) {
  ///     await queue.enqueue(descriptor); // re-queue on failure
  ///   }
  /// }
  /// ```
  Future<Response> replay(Map<String, dynamic> descriptor) async {
    final method = (descriptor['method'] as String? ?? 'GET').toUpperCase();
    final endpoint = descriptor['endpoint'] as String;
    final data = descriptor['data'];
    final queryParams = descriptor['queryParams'] as Map<String, dynamic>?;

    switch (method) {
      case 'GET':
        return _dio.get(endpoint, queryParameters: queryParams);
      case 'POST':
        return _dio.post(endpoint, data: data, queryParameters: queryParams);
      case 'PUT':
        return _dio.put(endpoint, data: data, queryParameters: queryParams);
      case 'PATCH':
        return _dio.patch(endpoint, data: data, queryParameters: queryParams);
      case 'DELETE':
        return _dio.delete(endpoint, data: data, queryParameters: queryParams);
      default:
        throw ArgumentError('Unknown HTTP method: $method');
    }
  }

  // ---------------------------------------------------------------------------
  // Dio configuration helpers
  // ---------------------------------------------------------------------------

  /// Add request interceptor
  void addInterceptor(Interceptor interceptor) {
    _dio.interceptors.add(interceptor);
  }

  /// Remove specific interceptor
  void removeInterceptor(Interceptor interceptor) {
    _dio.interceptors.remove(interceptor);
  }

  /// Clear all interceptors
  void clearInterceptors() {
    _dio.interceptors.clear();
  }

  /// Set base URL
  void setBaseUrl(String baseUrl) {
    _dio.options.baseUrl = baseUrl;
  }

  /// Set default headers
  void setDefaultHeaders(Map<String, dynamic> headers) {
    _dio.options.headers.addAll(headers);
  }

  /// Set connection timeout
  void setConnectTimeout(Duration timeout) {
    _dio.options.connectTimeout = timeout;
  }

  /// Set receive timeout
  void setReceiveTimeout(Duration timeout) {
    _dio.options.receiveTimeout = timeout;
  }

  /// Set send timeout
  void setSendTimeout(Duration timeout) {
    _dio.options.sendTimeout = timeout;
  }

  /// Get current base URL
  String? get baseUrl => _dio.options.baseUrl;

  /// Get underlying Dio instance for advanced usage
  Dio get dio => _dio;

  /// Create a cancel token for request cancellation
  CancelToken createCancelToken() => CancelToken();

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Fires an EventBus event if a [MooseAppContext] is available.
  void _fire(String event, Map<String, dynamic> data) {
    _appContext?.eventBus.fire(event, data: data);
  }

  /// Runs the `api:intercept_request` async hook.
  ///
  /// Returns the (possibly modified) descriptor to proceed, or `null` to
  /// abandon the request (caller throws [RequestQueuedError]).
  Future<Map<String, dynamic>?> _interceptRequest(
      Map<String, dynamic> descriptor) async {
    final registry = _appContext?.hookRegistry;
    if (registry == null) return descriptor;
    return registry.executeAsync<Map<String, dynamic>?>(
        'api:intercept_request', descriptor);
  }

  /// Merges custom headers with options and applies the `api:request_headers` hook.
  Options _mergeOptions(Options? options, Map<String, dynamic>? headers) {
    final existingHeaders = _asStringDynamicMap(options?.headers);
    final mergedHeaders = <String, dynamic>{
      ...existingHeaders,
      ...?headers,
    };
    final transformedHeaders = _applyHeaderHooks(mergedHeaders);

    return (options ?? Options()).copyWith(headers: transformedHeaders);
  }

  Map<String, dynamic> _applyHeaderHooks(Map<String, dynamic> headers) {
    final registry = _appContext?.hookRegistry;
    if (registry == null) return headers;
    return registry.execute<Map<String, dynamic>>(
      'api:request_headers',
      headers,
    );
  }

  Map<String, dynamic> _asStringDynamicMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map(
        (key, mapValue) => MapEntry(key.toString(), mapValue),
      );
    }
    return <String, dynamic>{};
  }

  Exception _handleError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return Exception('Connection timeout. Please check your internet connection.');

      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final message = e.response?.data?['message'] ??
            e.response?.data?['error'] ??
            'Unknown error occurred';
        return Exception('Error $statusCode: $message');

      case DioExceptionType.cancel:
        return Exception('Request cancelled');

      case DioExceptionType.badCertificate:
        return Exception('SSL certificate error');

      case DioExceptionType.connectionError:
        return Exception('Connection error. Please check your internet connection.');

      default:
        return Exception('Network error: ${e.message}');
    }
  }
}
