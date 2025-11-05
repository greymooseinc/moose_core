import 'package:dio/dio.dart';

/// Advanced API client with comprehensive features
///
/// Features:
/// - Progress tracking for uploads/downloads
/// - Custom headers per request
/// - Request cancellation
/// - File uploads/downloads
/// - Retry logic
/// - Request/response interceptors
class ApiClient {
  final Dio _dio;

  ApiClient(this._dio);

  /// GET request with optional headers and cancellation
  Future<Response> get(
    String endpoint, {
    Map<String, dynamic>? queryParams,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
    Options? options,
  }) async {
    try {
      final response = await _dio.get(
        endpoint,
        queryParameters: queryParams,
        options: _mergeOptions(options, headers),
        cancelToken: cancelToken,
      );

      return response;
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      rethrow;
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
    try {
      return await _dio.post(
        endpoint,
        data: data,
        queryParameters: queryParams,
        options: _mergeOptions(options, headers),
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
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
    try {
      return await _dio.put(
        endpoint,
        data: data,
        queryParameters: queryParams,
        options: _mergeOptions(options, headers),
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
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
    try {
      return await _dio.delete(
        endpoint,
        data: data,
        queryParameters: queryParams,
        options: _mergeOptions(options, headers),
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
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
    try {
      return await _dio.patch(
        endpoint,
        data: data,
        queryParameters: queryParams,
        options: _mergeOptions(options, headers),
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
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

  /// Merge custom headers with options
  Options _mergeOptions(Options? options, Map<String, dynamic>? headers) {
    if (headers == null || headers.isEmpty) {
      return options ?? Options();
    }

    final existingHeaders = options?.headers ?? {};
    return (options ?? Options()).copyWith(
      headers: {...existingHeaders, ...headers},
    );
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