import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moose_core/services.dart';

class _RecordingAdapter implements HttpClientAdapter {
  RequestOptions? lastRequestOptions;
  int requestCount = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequestOptions = options;
    requestCount++;

    return ResponseBody.fromBytes(
      utf8.encode('{"ok": true}'),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  group('ApiClient request header hooks', () {
    late Dio dio;
    late _RecordingAdapter adapter;

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
      adapter = _RecordingAdapter();
      dio.httpClientAdapter = adapter;
    });

    test('applies api:request_headers hook to GET request', () async {
      final hooks = HookRegistry();
      hooks.register('api:request_headers', (data) {
        final headers = Map<String, dynamic>.from(data as Map<String, dynamic>);
        headers['Accept-Language'] ??= 'en-US';
        headers['X-Locale'] ??= 'en-US';
        return headers;
      });

      final client = ApiClient(dio, hookRegistry: hooks);
      await client.get('/products');

      expect(adapter.lastRequestOptions, isNotNull);
      expect(adapter.lastRequestOptions!.headers['Accept-Language'], 'en-US');
      expect(adapter.lastRequestOptions!.headers['X-Locale'], 'en-US');
    });

    test('manual headers override hook values', () async {
      final hooks = HookRegistry();
      hooks.register('api:request_headers', (data) {
        final headers = Map<String, dynamic>.from(data as Map<String, dynamic>);
        headers['Accept-Language'] ??= 'fr-FR';
        headers['X-Locale'] ??= 'fr-FR';
        return headers;
      });

      final client = ApiClient(dio, hookRegistry: hooks);
      await client.get(
        '/products',
        headers: {
          'Accept-Language': 'de-DE',
        },
      );

      expect(adapter.lastRequestOptions!.headers['Accept-Language'], 'de-DE');
      expect(adapter.lastRequestOptions!.headers['X-Locale'], 'fr-FR');
    });

    test('hook does not run when hookRegistry is null', () async {
      final client = ApiClient(dio);
      await client.get('/products', headers: {'X-Test': '1'});

      expect(adapter.lastRequestOptions, isNotNull);
      expect(adapter.lastRequestOptions!.headers['X-Test'], '1');
      expect(adapter.lastRequestOptions!.headers['Accept-Language'], isNull);
      expect(adapter.lastRequestOptions!.headers['X-Locale'], isNull);
    });

    test('hook executes for get/post/put/delete/patch/download', () async {
      final hooks = HookRegistry();
      var hookCalls = 0;
      hooks.register('api:request_headers', (data) {
        hookCalls++;
        final headers = Map<String, dynamic>.from(data as Map<String, dynamic>);
        headers['X-From-Hook'] = 'yes';
        return headers;
      });

      final client = ApiClient(dio, hookRegistry: hooks);
      final file = File(
        '${Directory.systemTemp.path}/moose_api_client_download_${DateTime.now().microsecondsSinceEpoch}.tmp',
      );

      try {
        await client.get('/g');
        await client.post('/p', data: {'a': 1});
        await client.put('/u', data: {'a': 1});
        await client.delete('/d');
        await client.patch('/pa', data: {'a': 1});
        await client.download('/file', file.path);
      } finally {
        if (await file.exists()) {
          await file.delete();
        }
      }

      expect(hookCalls, 6);
      expect(adapter.requestCount, 6);
      expect(adapter.lastRequestOptions!.headers['X-From-Hook'], 'yes');
    });

    test('hook failure does not crash request path', () async {
      final hooks = HookRegistry();
      hooks.register(
        'api:request_headers',
        (data) => throw Exception('hook failed'),
      );

      final client = ApiClient(dio, hookRegistry: hooks);
      await client.get('/products', headers: {'X-Test': 'ok'});

      expect(adapter.lastRequestOptions, isNotNull);
      expect(adapter.lastRequestOptions!.headers['X-Test'], 'ok');
    });

    test('existing interceptors still work with hooks', () async {
      final hooks = HookRegistry();
      hooks.register('api:request_headers', (data) {
        final headers = Map<String, dynamic>.from(data as Map<String, dynamic>);
        headers['X-From-Hook'] = 'hook';
        return headers;
      });

      final client = ApiClient(dio, hookRegistry: hooks);
      client.addInterceptor(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            options.headers['X-From-Interceptor'] = 'interceptor';
            handler.next(options);
          },
        ),
      );

      await client.get('/products');

      expect(adapter.lastRequestOptions, isNotNull);
      expect(adapter.lastRequestOptions!.headers['X-From-Hook'], 'hook');
      expect(
        adapter.lastRequestOptions!.headers['X-From-Interceptor'],
        'interceptor',
      );
    });
  });
}
