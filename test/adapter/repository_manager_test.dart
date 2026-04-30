import 'package:flutter_test/flutter_test.dart';
import 'package:moose_core/adapters.dart';
import 'package:moose_core/repositories.dart';
import 'package:moose_core/src/adapter/repository_manager.dart';

class _MockRepo extends CoreRepository {
  @override
  void initialize() {}
}

void main() {
  group('RepositoryManager', () {
    test('registers and retrieves a sync factory', () async {
      final mgr = RepositoryManager();
      mgr.registerFactory<_MockRepo>(() => _MockRepo(), provider: 'test');
      final repo = await mgr.getAsync<_MockRepo>();
      expect(repo, isA<_MockRepo>());
    });

    test('concurrent getAsync calls return the same instance', () async {
      final mgr = RepositoryManager();
      mgr.registerFactory<_MockRepo>(() => _MockRepo(), provider: 'test');
      final results = await Future.wait([
        mgr.getAsync<_MockRepo>(),
        mgr.getAsync<_MockRepo>(),
      ]);
      expect(results[0], same(results[1]));
    });

    test('getSync returns cached instance on second call', () {
      final mgr = RepositoryManager();
      mgr.registerFactory<_MockRepo>(() => _MockRepo(), provider: 'test');
      final a = mgr.getSync<_MockRepo>();
      final b = mgr.getSync<_MockRepo>();
      expect(a, same(b));
    });

    test('throws RepositoryNotRegisteredException for unknown type', () {
      final mgr = RepositoryManager();
      expect(
        () => mgr.getSync<_MockRepo>(),
        throwsA(isA<RepositoryNotRegisteredException>()),
      );
    });

    test('getSync throws RepositoryAsyncOnlyException for async factory', () {
      final mgr = RepositoryManager();
      mgr.registerAsyncFactory<_MockRepo>(() async => _MockRepo(), provider: 'test');
      expect(
        () => mgr.getSync<_MockRepo>(),
        throwsA(isA<RepositoryAsyncOnlyException>()),
      );
    });

    test('isCached returns false before first access', () {
      final mgr = RepositoryManager();
      mgr.registerFactory<_MockRepo>(() => _MockRepo(), provider: 'test');
      expect(mgr.isCached<_MockRepo>(), isFalse);
    });

    test('isCached returns true after getSync', () {
      final mgr = RepositoryManager();
      mgr.registerFactory<_MockRepo>(() => _MockRepo(), provider: 'test');
      mgr.getSync<_MockRepo>();
      expect(mgr.isCached<_MockRepo>(), isTrue);
    });

    test('clearCache resets instance so next call creates new one', () {
      final mgr = RepositoryManager();
      mgr.registerFactory<_MockRepo>(() => _MockRepo(), provider: 'test');
      final first = mgr.getSync<_MockRepo>();
      mgr.clearCache<_MockRepo>();
      final second = mgr.getSync<_MockRepo>();
      expect(first, isNot(same(second)));
    });
  });
}
