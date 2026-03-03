import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moose_core/adapters.dart';
import 'package:moose_core/app.dart';
import 'package:moose_core/cache.dart';
import 'package:moose_core/entities.dart';
import 'package:moose_core/repositories.dart';
import 'package:moose_core/services.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

class MockRepo extends CoreRepository {
  MockRepo();

  @override
  void initialize() {}
}

class AnotherMockRepo extends CoreRepository {
  AnotherMockRepo();

  @override
  void initialize() {}
}

class SimpleAdapter extends BackendAdapter {
  @override
  String get name => 'simple';

  @override
  String get version => '1.0.0';

  @override
  Map<String, dynamic> get configSchema => {'type': 'object', 'properties': {}};

  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    registerRepositoryFactory<MockRepo>(() => MockRepo());
  }
}

class AnotherAdapter extends BackendAdapter {
  @override
  String get name => 'another';

  @override
  String get version => '1.0.0';

  @override
  Map<String, dynamic> get configSchema => {'type': 'object', 'properties': {}};

  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    registerRepositoryFactory<AnotherMockRepo>(() => AnotherMockRepo());
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates a MooseAppContext with a pre-initialized ConfigManager and an
/// optional list of manually-initialized adapters (autoInitialize: false).
///
/// Each adapter is initialized before being passed to the registry so that
/// its repository factories are registered without needing ConfigManager lookup.
Future<MooseAppContext> _makeContext({
  Map<String, dynamic>? config,
  List<BackendAdapter> adapters = const [],
}) async {
  final ctx = MooseAppContext();
  ctx.configManager.initialize(config ?? {});
  for (final a in adapters) {
    await a.initialize({});
    await ctx.adapterRegistry.registerAdapter(() => a, autoInitialize: false);
  }
  return ctx;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('MooseAppContext', () {
    group('Instance isolation', () {
      test('two contexts own independent registries', () {
        final ctx1 = MooseAppContext();
        final ctx2 = MooseAppContext();

        expect(identical(ctx1.adapterRegistry, ctx2.adapterRegistry), isFalse);
        expect(identical(ctx1.configManager, ctx2.configManager), isFalse);
        expect(identical(ctx1.hookRegistry, ctx2.hookRegistry), isFalse);
        expect(identical(ctx1.eventBus, ctx2.eventBus), isFalse);
      });

      test('adapters registered in one context are not visible in another',
          () async {
        final ctx1 = await _makeContext(adapters: [SimpleAdapter()]);
        final ctx2 = MooseAppContext();

        expect(ctx1.adapterRegistry.hasRepository<MockRepo>(), true);
        expect(ctx2.adapterRegistry.hasRepository<MockRepo>(), false);
      });

      test('config initialized in one context does not affect another',
          () async {
        final ctx1 = MooseAppContext();
        ctx1.configManager.initialize({'key': 'value1'});

        final ctx2 = MooseAppContext();
        ctx2.configManager.initialize({'key': 'value2'});

        expect(ctx1.configManager.get('key'), 'value1');
        expect(ctx2.configManager.get('key'), 'value2');
      });

      test('two contexts own independent CacheManager instances', () {
        final ctx1 = MooseAppContext();
        final ctx2 = MooseAppContext();

        expect(identical(ctx1.cache, ctx2.cache), isFalse);
        expect(identical(ctx1.cache.memory, ctx2.cache.memory), isFalse);
        expect(identical(ctx1.cache.persistent, ctx2.cache.persistent), isFalse);
      });

      test('memory cache writes in one context are not visible in another', () {
        final ctx1 = MooseAppContext();
        final ctx2 = MooseAppContext();

        ctx1.cache.memory.set('token', 'abc');

        expect(ctx1.cache.memory.get<String>('token'), equals('abc'));
        expect(ctx2.cache.memory.get<String>('token'), isNull);
      });

      test('clearing cache in one context does not affect another', () {
        final ctx1 = MooseAppContext();
        final ctx2 = MooseAppContext();

        ctx1.cache.memory.set('data', 1);
        ctx2.cache.memory.set('data', 2);

        ctx1.cache.clearMemory();

        expect(ctx1.cache.memory.get<int>('data'), isNull);
        expect(ctx2.cache.memory.get<int>('data'), equals(2));
      });

      test('accepts injected CacheManager for testing', () {
        final customCache = CacheManager();
        final ctx = MooseAppContext(cache: customCache);

        expect(identical(ctx.cache, customCache), isTrue);
      });
    });

    group('Scoped dependency wiring', () {
      test('AdapterRegistry receives the scoped ConfigManager', () async {
        final ctx = MooseAppContext();
        ctx.configManager.initialize({
          'adapters': {'simple': {}},
        });

        await ctx.adapterRegistry.registerAdapter(
          () => SimpleAdapter(),
          autoInitialize: true,
        );

        expect(ctx.adapterRegistry.isInitialized, true);
      });
    });

    group('Lazy repository access', () {
      test('getRepository creates instance only on first call', () async {
        int callCount = 0;
        final adapter = SimpleAdapter();
        // Register a tracked factory directly.
        adapter.registerRepositoryFactory<MockRepo>(() {
          callCount++;
          return MockRepo();
        });

        // Build context manually — do not call adapter.initialize() to avoid
        // overwriting the tracked factory.
        final ctx = MooseAppContext();
        ctx.configManager.initialize({});
        await ctx.adapterRegistry.registerAdapter(() => adapter, autoInitialize: false);

        expect(callCount, 0); // Not yet created

        ctx.getRepository<MockRepo>();
        expect(callCount, 1);

        ctx.getRepository<MockRepo>();
        ctx.getRepository<MockRepo>();
        expect(callCount, 1); // Still cached after first call
      });

      test('getRepository returns the same instance on repeated calls',
          () async {
        final ctx = await _makeContext(adapters: [SimpleAdapter()]);

        final repo1 = ctx.getRepository<MockRepo>();
        final repo2 = ctx.getRepository<MockRepo>();

        expect(identical(repo1, repo2), true);
      });

      test('getRepository delegates to adapterRegistry.getRepository',
          () async {
        final ctx = await _makeContext(adapters: [SimpleAdapter()]);

        final fromContext = ctx.getRepository<MockRepo>();
        final fromRegistry = ctx.adapterRegistry.getRepository<MockRepo>();

        // Both paths must return the same cached instance.
        expect(identical(fromContext, fromRegistry), true);
      });
    });

    group('Constructor injection (for testing)', () {
      test('accepts externally created ConfigManager', () {
        final cm = ConfigManager();
        cm.initialize({'theme': 'dark'});

        final ctx = MooseAppContext(configManager: cm);

        expect(identical(ctx.configManager, cm), true);
        expect(ctx.configManager.get('theme'), 'dark');
      });

      test('accepts externally created AdapterRegistry', () {
        final registry = AdapterRegistry();
        final ctx = MooseAppContext(adapterRegistry: registry);

        expect(identical(ctx.adapterRegistry, registry), true);
      });

      test('injected registry is still wired to scoped dependencies', () {
        final cm = ConfigManager();
        cm.initialize({'adapters': {}});
        final registry = AdapterRegistry();

        final ctx = MooseAppContext(configManager: cm, adapterRegistry: registry);

        // The constructor wires the registry to the context's scoped deps.
        // Verify by attempting autoInitialize — it should not throw StateError
        // about missing ConfigManager.
        expect(
          () async => await ctx.adapterRegistry.registerAdapter(
            () async {
              final a = SimpleAdapter();
              // No adapters key in config for 'simple', so will throw about
              // missing config — but NOT about missing ConfigManager.
              return a;
            },
            autoInitialize: true,
          ),
          // Throws because config has no 'simple' entry — not because
          // ConfigManager is null.
          throwsException,
        );
      });
    });

    group('currentUser', () {
      // Minimal stub satisfying AuthRepository's abstract interface.
      // Only authStateChanges is exercised; everything else throws.
      late StreamController<User?> authController;
      late _StubAuthRepository stubRepo;
      // Use a mock persistent cache for all tests in this group to avoid
      // triggering SharedPreferences (which requires a Flutter binding).
      late CacheManager mockCacheManager;

      const testUser = User(
        id: 'u1',
        email: 'test@example.com',
        displayName: 'Test User',
        accessToken: 'tok_abc',
        refreshToken: 'ref_xyz',
      );

      setUp(() {
        authController = StreamController<User?>.broadcast();
        stubRepo = _StubAuthRepository(authController.stream);
        mockCacheManager = CacheManager(persistent: _MockPersistentCache(null));
      });

      tearDown(() async {
        await authController.close();
      });

      test('starts as null on a fresh context', () {
        final ctx = MooseAppContext(cache: mockCacheManager);
        expect(ctx.currentUser.value, isNull);
      });

      test('updates currentUser when authStateChanges emits a user', () async {
        final ctx = MooseAppContext(cache: mockCacheManager);
        ctx.wireAuthRepository(stubRepo);

        authController.add(testUser);
        await Future.microtask(() {});

        expect(ctx.currentUser.value, equals(testUser));
      });

      test('resets currentUser to null on sign-out', () async {
        final ctx = MooseAppContext(cache: mockCacheManager);
        ctx.wireAuthRepository(stubRepo);

        authController.add(testUser);
        await Future.microtask(() {});
        expect(ctx.currentUser.value, isNotNull);

        authController.add(null);
        await Future.microtask(() {});
        expect(ctx.currentUser.value, isNull);
      });

      test('two contexts have independent currentUser notifiers', () async {
        final ctx1 = MooseAppContext(cache: mockCacheManager);
        final ctx2 = MooseAppContext(
          cache: CacheManager(persistent: _MockPersistentCache(null)),
        );

        final ctrl2 = StreamController<User?>.broadcast();
        ctx1.wireAuthRepository(stubRepo);
        ctx2.wireAuthRepository(_StubAuthRepository(ctrl2.stream));

        authController.add(testUser);
        await Future.microtask(() {});

        expect(ctx1.currentUser.value, equals(testUser));
        expect(ctx2.currentUser.value, isNull);

        await ctrl2.close();
      });

      test('restoreAuthState populates currentUser from persistent cache',
          () async {
        final ctx = MooseAppContext(
          cache: CacheManager(persistent: _MockPersistentCache(testUser.toJson())),
        );

        await ctx.restoreAuthState();

        expect(ctx.currentUser.value?.id, equals(testUser.id));
        expect(ctx.currentUser.value?.email, equals(testUser.email));
        expect(ctx.currentUser.value?.accessToken, equals(testUser.accessToken));
      });

      test('restoreAuthState is a no-op when cache is empty', () async {
        final ctx = MooseAppContext(
          cache: CacheManager(persistent: _MockPersistentCache(null)),
        );

        await ctx.restoreAuthState();

        expect(ctx.currentUser.value, isNull);
      });

      test('wireAuthRepository replaces previous subscription', () async {
        final ctx = MooseAppContext(cache: mockCacheManager);
        ctx.wireAuthRepository(stubRepo);

        final ctrl2 = StreamController<User?>.broadcast();
        const user2 = User(id: 'u2', email: 'other@example.com');
        ctx.wireAuthRepository(_StubAuthRepository(ctrl2.stream));

        // Old stream should no longer update currentUser.
        authController.add(testUser);
        await Future.microtask(() {});
        expect(ctx.currentUser.value, isNull);

        // New stream should.
        ctrl2.add(user2);
        await Future.microtask(() {});
        expect(ctx.currentUser.value, equals(user2));

        await ctrl2.close();
      });
    });
  });
}

// ---------------------------------------------------------------------------
// Stubs for currentUser tests
// ---------------------------------------------------------------------------

class _StubAuthRepository extends AuthRepository {
  final Stream<User?> _stream;
  _StubAuthRepository(this._stream);

  @override
  Stream<User?> get authStateChanges => _stream;

  @override
  void initialize() {}

  @override
  Future<AuthResult> signIn(AuthCredentials credentials) => throw UnimplementedError();
  @override
  Future<AuthResult> signUp(AuthCredentials credentials,
      {String? displayName, String? photoUrl, Map<String, dynamic>? metadata}) =>
      throw UnimplementedError();
  @override
  Future<void> signOut() => throw UnimplementedError();
  @override
  Future<User?> getCurrentUser() => throw UnimplementedError();
  @override
  Future<PasswordResetResult> sendPasswordResetEmail(String email) => throw UnimplementedError();
  @override
  Future<PasswordResetResult> confirmPasswordReset(
      {required String code, required String newPassword}) =>
      throw UnimplementedError();
  @override
  Future<PasswordResetResult> changePassword(
      {required String currentPassword, required String newPassword}) =>
      throw UnimplementedError();
  @override
  Future<void> sendEmailVerification() => throw UnimplementedError();
  @override
  Future<EmailVerificationResult> verifyEmail(String code) => throw UnimplementedError();
  @override
  Future<void> sendPhoneVerificationCode(String phoneNumber) => throw UnimplementedError();
  @override
  Future<EmailVerificationResult> verifyPhoneNumber(
      {required String phoneNumber, required String verificationCode}) =>
      throw UnimplementedError();
  @override
  Future<User> updateProfile(
      {String? displayName, String? photoUrl, Map<String, dynamic>? metadata}) =>
      throw UnimplementedError();
  @override
  Future<User> updateEmail(String newEmail) => throw UnimplementedError();
  @override
  Future<void> deleteAccount() => throw UnimplementedError();
  @override
  Future<String?> getIdToken({bool forceRefresh = false}) => throw UnimplementedError();
  @override
  Future<AuthResult> refreshToken(String refreshToken) => throw UnimplementedError();
  @override
  Future<AuthResult> linkCredential(AuthCredentials credentials) => throw UnimplementedError();
  @override
  Future<User> unlinkProvider(String providerId) => throw UnimplementedError();
  @override
  Future<void> enrollMFA({required String phoneNumber}) => throw UnimplementedError();
  @override
  Future<void> unenrollMFA() => throw UnimplementedError();
}

class _MockPersistentCache extends PersistentCache {
  final Map<String, dynamic>? _storedUser;
  _MockPersistentCache(this._storedUser);

  @override
  Future<T?> getJson<T>(String key) async {
    if (key == 'moose:auth:current_user' && _storedUser is T?) {
      return _storedUser as T?;
    }
    return null;
  }

  @override
  Future<bool> setJson(String key, dynamic value) async => true;

  @override
  Future<bool> remove(String key) async => true;
}
