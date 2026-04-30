import 'package:flutter_test/flutter_test.dart';
import 'package:moose_core/cache.dart';
import 'package:moose_core/entities.dart';
import 'package:moose_core/repositories.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Minimal concrete implementation of AuthRepository for testing.
class _ConcreteAuthRepository extends AuthRepository {
  @override
  void initialize() {}

  @override
  Stream<User?> get authStateChanges => const Stream.empty();

  @override
  Future<User?> getCurrentUser({RepositoryOptions? options}) async => null;

  @override
  Future<AuthResult> signIn(
    AuthCredentials credentials, {
    RepositoryOptions? options,
  }) async =>
      throw UnimplementedError();

  @override
  Future<AuthResult> signUp(
    AuthCredentials credentials, {
    String? displayName,
    String? photoUrl,
    Map<String, dynamic>? metadata,
    RepositoryOptions? options,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> signOut({RepositoryOptions? options}) async {}

  @override
  Future<PasswordResetResult> sendPasswordResetEmail(
    String email, {
    RepositoryOptions? options,
  }) async =>
      throw UnimplementedError();

  @override
  Future<PasswordResetResult> confirmPasswordReset({
    required String code,
    required String newPassword,
    RepositoryOptions? options,
  }) async =>
      throw UnimplementedError();

  @override
  Future<PasswordResetResult> changePassword({
    required String currentPassword,
    required String newPassword,
    RepositoryOptions? options,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> sendEmailVerification({RepositoryOptions? options}) async {}

  @override
  Future<EmailVerificationResult> verifyEmail(
    String code, {
    RepositoryOptions? options,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> sendPhoneVerificationCode(
    String phoneNumber, {
    RepositoryOptions? options,
  }) async {}

  @override
  Future<EmailVerificationResult> verifyPhoneNumber({
    required String phoneNumber,
    required String verificationCode,
    RepositoryOptions? options,
  }) async =>
      throw UnimplementedError();

  @override
  Future<User> updateProfile({
    String? displayName,
    String? photoUrl,
    Map<String, dynamic>? metadata,
    RepositoryOptions? options,
  }) async =>
      throw UnimplementedError();

  @override
  Future<User> updateEmail(String newEmail, {RepositoryOptions? options}) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteAccount({RepositoryOptions? options}) async {}

  @override
  Future<String?> getIdToken({
    bool forceRefresh = false,
    RepositoryOptions? options,
  }) async =>
      null;

  @override
  Future<AuthResult> refreshToken(
    String refreshToken, {
    RepositoryOptions? options,
  }) async =>
      throw UnimplementedError();

  @override
  Future<AuthResult> linkCredential(
    AuthCredentials credentials, {
    RepositoryOptions? options,
  }) async =>
      throw UnimplementedError();

  @override
  Future<User> unlinkProvider(
    String providerId, {
    RepositoryOptions? options,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> enrollMFA({
    required String phoneNumber,
    RepositoryOptions? options,
  }) async {}

  @override
  Future<void> unenrollMFA({RepositoryOptions? options}) async {}
}

void main() {
  group('AuthRepository.saveSession()', () {
    test('throws AssertionError in debug mode when initTokenStorage not called', () async {
      final repo = _ConcreteAuthRepository();
      expect(
        () => repo.saveSession(accessToken: 'tok'),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('AuthRepository.loadSession()', () {
    test('returns null tokens when initTokenStorage not called', () async {
      final repo = _ConcreteAuthRepository();
      final session = await repo.loadSession();
      expect(session.accessToken, isNull);
      expect(session.refreshToken, isNull);
      expect(session.expiresAt, isNull);
    });

    test('saves and loads session round-trip', () async {
      SharedPreferences.setMockInitialValues({});
      final cache = CacheManager();
      await cache.initPersistent();
      final repo = _ConcreteAuthRepository();
      repo.initTokenStorage(cache, keyPrefix: 'test');

      await repo.saveSession(
        accessToken: 'access_token_123',
        refreshToken: 'refresh_token_456',
        expiresAt: DateTime(2099),
      );

      final session = await repo.loadSession();
      expect(session.accessToken, equals('access_token_123'));
      expect(session.refreshToken, equals('refresh_token_456'));
      expect(session.expiresAt, equals(DateTime(2099)));
    });

    test('loadSession returns null fields when no tokens have been saved', () async {
      SharedPreferences.setMockInitialValues({});
      final cache = CacheManager();
      await cache.initPersistent();
      final repo = _ConcreteAuthRepository();
      repo.initTokenStorage(cache, keyPrefix: 'empty');

      final session = await repo.loadSession();
      expect(session.accessToken, isNull);
      expect(session.refreshToken, isNull);
      expect(session.expiresAt, isNull);
    });

    test('clearSession removes all persisted tokens', () async {
      SharedPreferences.setMockInitialValues({});
      final cache = CacheManager();
      await cache.initPersistent();
      final repo = _ConcreteAuthRepository();
      repo.initTokenStorage(cache, keyPrefix: 'clear_test');

      await repo.saveSession(
        accessToken: 'tok',
        refreshToken: 'rtok',
        expiresAt: DateTime(2099),
      );
      await repo.clearSession();

      final session = await repo.loadSession();
      expect(session.accessToken, isNull);
      expect(session.refreshToken, isNull);
      expect(session.expiresAt, isNull);
    });
  });
}
