# Authentication Adapter Guide

> Complete guide to implementing authentication adapters in moose_core

## Table of Contents
- [Overview](#overview)
- [AuthRepository Architecture](#authrepository-architecture)
- [Authentication Credentials](#authentication-credentials)
- [Creating a Custom Authentication Adapter](#creating-a-custom-authentication-adapter)
- [Authentication Flow Patterns](#authentication-flow-patterns)
- [Token Management](#token-management)
- [Multi-Factor Authentication](#multi-factor-authentication)
- [Social Authentication Providers](#social-authentication-providers)
- [Best Practices](#best-practices)

## Overview

The Authentication Adapter pattern enables support for multiple authentication providers (Firebase Auth, Auth0, custom backends, OAuth providers, etc.) without changing business logic. Authentication adapters provide provider-specific implementations of the core AuthRepository interface.

## AuthRepository Architecture

### AuthRepository Base Class

```dart
abstract class AuthRepository extends CoreRepository {
  /// Sign in with credentials
  Future<AuthResult> signIn(AuthCredentials credentials);

  /// Sign up with credentials and profile information
  Future<AuthResult> signUp(
    AuthCredentials credentials, {
    String? displayName,
    String? photoUrl,
    Map<String, dynamic>? metadata,
  });

  /// Sign out the current user
  Future<void> signOut();

  /// Get the current authenticated user
  Future<User?> getCurrentUser();

  /// Stream of authentication state changes
  Stream<User?> authStateChanges();

  /// Send password reset email
  Future<PasswordResetResult> sendPasswordResetEmail(String email);

  /// Confirm password reset with code and new password
  Future<PasswordResetResult> confirmPasswordReset(
    String code,
    String newPassword,
  );

  /// Change password for the current user
  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  );

  /// Send email verification
  Future<EmailVerificationResult> sendEmailVerification();

  /// Verify email with verification code
  Future<EmailVerificationResult> verifyEmail(String verificationCode);

  /// Send phone number verification code
  Future<void> sendPhoneVerificationCode(String phoneNumber);

  /// Verify phone number with verification code
  Future<void> verifyPhoneNumber(
    String phoneNumber,
    String verificationCode,
  );

  /// Update user profile information
  Future<User> updateProfile({
    String? displayName,
    String? photoUrl,
    Map<String, dynamic>? metadata,
  });

  /// Update email address
  Future<void> updateEmail(String newEmail);

  /// Delete user account
  Future<void> deleteAccount();

  /// Get ID token for the current user
  Future<String?> getIdToken({bool forceRefresh = false});

  /// Refresh the authentication token
  Future<AuthResult> refreshToken(String refreshToken);

  /// Link additional credentials to the current account
  Future<User> linkCredential(AuthCredentials credentials);

  /// Unlink a provider from the current account
  Future<User> unlinkProvider(String providerId);

  /// Enroll in multi-factor authentication
  Future<void> enrollMFA(String phoneNumber);

  /// Unenroll from multi-factor authentication
  Future<void> unenrollMFA();
}
```

### User Entity

```dart
class User {
  final String id;
  final String? email;
  final String? displayName;
  final String? phoneNumber;
  final String? photoUrl;
  final bool emailVerified;
  final bool phoneVerified;
  final bool isActive;
  final bool isAdmin;

  /// List of authentication provider IDs (e.g., ['password', 'google.com', 'facebook.com'])
  final List<String> providers;

  /// Provider-specific user data mapped by provider ID
  /// Stores the original provider user objects for each authentication method
  final Map<String, Map<String, dynamic>>? providerData;

  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final Map<String, dynamic>? metadata;

  const User({
    required this.id,
    this.email,
    this.displayName,
    this.phoneNumber,
    this.photoUrl,
    this.emailVerified = false,
    this.phoneVerified = false,
    this.isActive = true,
    this.isAdmin = false,
    this.providers = const [],
    this.providerData,
    required this.createdAt,
    this.lastLoginAt,
    this.metadata,
  });
}
```

### AuthResult Entity

```dart
class AuthResult {
  final bool success;
  final User? user;
  final String? token;
  final String? refreshToken;
  final DateTime? expiresAt;
  final String? errorMessage;
  final String? errorCode;
  final bool requiresAdditionalAction;
  final String? additionalActionType;
  final Map<String, dynamic>? metadata;

  factory AuthResult.success({
    required User user,
    String? token,
    String? refreshToken,
    DateTime? expiresAt,
    Map<String, dynamic>? metadata,
  });

  factory AuthResult.failure({
    required String errorMessage,
    String? errorCode,
    Map<String, dynamic>? metadata,
  });

  factory AuthResult.requiresAction({
    required String actionType,
    User? user,
    String? message,
    Map<String, dynamic>? metadata,
  });
}
```

## Authentication Credentials

### Credential Types

The system supports multiple credential types through the `AuthCredentials` abstract class:

```dart
abstract class AuthCredentials {
  const AuthCredentials();
}
```

#### Email/Password Credentials

```dart
class EmailPasswordCredentials extends AuthCredentials {
  final String email;
  final String password;

  const EmailPasswordCredentials({
    required this.email,
    required this.password,
  });
}
```

#### OAuth Credentials

```dart
class OAuthCredentials extends AuthCredentials {
  final String provider;  // 'google', 'facebook', 'apple', etc.
  final String accessToken;
  final String? idToken;
  final Map<String, dynamic>? additionalData;

  const OAuthCredentials({
    required this.provider,
    required this.accessToken,
    this.idToken,
    this.additionalData,
  });
}
```

#### Phone Credentials

```dart
class PhoneCredentials extends AuthCredentials {
  final String phoneNumber;
  final String verificationCode;

  const PhoneCredentials({
    required this.phoneNumber,
    required this.verificationCode,
  });
}
```

#### Custom Token Credentials

```dart
class CustomTokenCredentials extends AuthCredentials {
  final String token;

  const CustomTokenCredentials({required this.token});
}
```

#### Anonymous Credentials

```dart
class AnonymousCredentials extends AuthCredentials {
  const AnonymousCredentials();
}
```

### Understanding `providers` vs `providerData`

The User entity has two related but distinct properties for tracking authentication providers:

#### `providers` Property
- **Type**: `List<String>`
- **Purpose**: Stores the **IDs** of authentication methods linked to the user
- **Example**: `['password', 'google.com', 'facebook.com']`
- **Use Case**: Determine which sign-in methods are available for the user

```dart
// Check if user can sign in with Google
if (user.providers.contains('google.com')) {
  // Show Google sign-in option
}

// Check if user has password authentication
if (user.providers.contains('password')) {
  // Allow password changes
}
```

#### `providerData` Property
- **Type**: `Map<String, Map<String, dynamic>>?`
- **Purpose**: Stores the **actual provider-specific user objects** for each authentication method
- **Example**:
```dart
{
  'google.com': {
    'uid': 'google_user_12345',
    'email': 'user@gmail.com',
    'displayName': 'John Doe',
    'photoURL': 'https://lh3.googleusercontent.com/...',
    'providerId': 'google.com',
  },
  'facebook.com': {
    'uid': 'facebook_user_67890',
    'email': 'user@facebook.com',
    'displayName': 'John Doe',
    'photoURL': 'https://graph.facebook.com/...',
    'providerId': 'facebook.com',
  }
}
```
- **Use Case**: Access provider-specific data like Google's user ID, profile photo URLs, or other provider metadata

```dart
// Get Google-specific user data
final googleData = user.providerData?['google.com'];
if (googleData != null) {
  final googleUserId = googleData['uid'];
  final googlePhotoUrl = googleData['photoURL'];
  // Use provider-specific data...
}

// Check if user signed in with a specific Google account
final googleEmail = user.providerData?['google.com']?['email'];
print('Google account: $googleEmail');
```

## Creating a Custom Authentication Adapter

### Step 1: Implement the AuthRepository

```dart
import 'package:moose_core/repositories.dart';
import 'package:moose_core/entities.dart';

class FirebaseAuthRepository extends AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final AppLogger _logger = AppLogger('FirebaseAuthRepository');

  FirebaseAuthRepository(this._firebaseAuth);

  @override
  Future<AuthResult> signIn(AuthCredentials credentials) async {
    try {
      if (credentials is EmailPasswordCredentials) {
        return await _signInWithEmailPassword(credentials);
      } else if (credentials is OAuthCredentials) {
        return await _signInWithOAuth(credentials);
      } else if (credentials is PhoneCredentials) {
        return await _signInWithPhone(credentials);
      } else if (credentials is CustomTokenCredentials) {
        return await _signInWithCustomToken(credentials);
      } else if (credentials is AnonymousCredentials) {
        return await _signInAnonymously();
      } else {
        return AuthResult.failure(
          errorMessage: 'Unsupported credential type',
          errorCode: 'unsupported_credential',
        );
      }
    } catch (e) {
      _logger.error('Sign in failed', e);
      return AuthResult.failure(
        errorMessage: e.toString(),
        errorCode: 'sign_in_failed',
      );
    }
  }

  Future<AuthResult> _signInWithEmailPassword(
    EmailPasswordCredentials credentials,
  ) async {
    final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
      email: credentials.email,
      password: credentials.password,
    );

    final firebaseUser = userCredential.user;
    if (firebaseUser == null) {
      return AuthResult.failure(
        errorMessage: 'Authentication failed',
        errorCode: 'auth_failed',
      );
    }

    // Check if email verification is required
    if (!firebaseUser.emailVerified) {
      return AuthResult.requiresAction(
        actionType: 'email_verification',
        user: _convertToUser(firebaseUser),
        message: 'Please verify your email address',
      );
    }

    final token = await firebaseUser.getIdToken();

    return AuthResult.success(
      user: _convertToUser(firebaseUser),
      token: token,
    );
  }

  Future<AuthResult> _signInWithOAuth(OAuthCredentials credentials) async {
    AuthCredential firebaseCredential;

    switch (credentials.provider) {
      case 'google':
        firebaseCredential = GoogleAuthProvider.credential(
          accessToken: credentials.accessToken,
          idToken: credentials.idToken,
        );
        break;
      case 'facebook':
        firebaseCredential = FacebookAuthProvider.credential(
          credentials.accessToken,
        );
        break;
      case 'apple':
        firebaseCredential = OAuthProvider('apple.com').credential(
          accessToken: credentials.accessToken,
          idToken: credentials.idToken,
        );
        break;
      default:
        return AuthResult.failure(
          errorMessage: 'Unsupported OAuth provider: ${credentials.provider}',
          errorCode: 'unsupported_provider',
        );
    }

    final userCredential = await _firebaseAuth.signInWithCredential(
      firebaseCredential,
    );

    final firebaseUser = userCredential.user;
    if (firebaseUser == null) {
      return AuthResult.failure(
        errorMessage: 'OAuth authentication failed',
        errorCode: 'oauth_failed',
      );
    }

    final token = await firebaseUser.getIdToken();

    return AuthResult.success(
      user: _convertToUser(firebaseUser),
      token: token,
    );
  }

  @override
  Future<AuthResult> signUp(
    AuthCredentials credentials, {
    String? displayName,
    String? photoUrl,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      if (credentials is! EmailPasswordCredentials) {
        return AuthResult.failure(
          errorMessage: 'Sign up only supports email/password',
          errorCode: 'unsupported_credential',
        );
      }

      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: credentials.email,
        password: credentials.password,
      );

      final firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        return AuthResult.failure(
          errorMessage: 'Account creation failed',
          errorCode: 'signup_failed',
        );
      }

      // Update profile
      if (displayName != null || photoUrl != null) {
        await firebaseUser.updateDisplayName(displayName);
        await firebaseUser.updatePhotoURL(photoUrl);
        await firebaseUser.reload();
      }

      // Send verification email
      await firebaseUser.sendEmailVerification();

      return AuthResult.requiresAction(
        actionType: 'email_verification',
        user: _convertToUser(firebaseUser),
        message: 'Please check your email to verify your account',
      );
    } catch (e) {
      _logger.error('Sign up failed', e);
      return AuthResult.failure(
        errorMessage: e.toString(),
        errorCode: 'signup_failed',
      );
    }
  }

  @override
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  @override
  Future<User?> getCurrentUser() async {
    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser == null) return null;

    await firebaseUser.reload();
    return _convertToUser(_firebaseAuth.currentUser!);
  }

  @override
  Stream<User?> authStateChanges() {
    return _firebaseAuth.authStateChanges().map((firebaseUser) {
      if (firebaseUser == null) return null;
      return _convertToUser(firebaseUser);
    });
  }

  @override
  Future<PasswordResetResult> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
      return PasswordResetResult.success(
        message: 'Password reset email sent to $email',
      );
    } catch (e) {
      _logger.error('Failed to send password reset email', e);
      return PasswordResetResult.failure(e.toString());
    }
  }

  @override
  Future<PasswordResetResult> confirmPasswordReset(
    String code,
    String newPassword,
  ) async {
    try {
      await _firebaseAuth.confirmPasswordReset(
        code: code,
        newPassword: newPassword,
      );
      return PasswordResetResult.success(
        message: 'Password reset successfully',
      );
    } catch (e) {
      _logger.error('Failed to confirm password reset', e);
      return PasswordResetResult.failure(e.toString());
    }
  }

  @override
  Future<EmailVerificationResult> sendEmailVerification() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        return EmailVerificationResult.failure('No user signed in');
      }

      await user.sendEmailVerification();
      return EmailVerificationResult.success(
        message: 'Verification email sent',
      );
    } catch (e) {
      _logger.error('Failed to send email verification', e);
      return EmailVerificationResult.failure(e.toString());
    }
  }

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return null;

    return await user.getIdToken(forceRefresh);
  }

  @override
  Future<User> updateProfile({
    String? displayName,
    String? photoUrl,
    Map<String, dynamic>? metadata,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw Exception('No user signed in');
    }

    if (displayName != null) {
      await user.updateDisplayName(displayName);
    }

    if (photoUrl != null) {
      await user.updatePhotoURL(photoUrl);
    }

    await user.reload();
    return _convertToUser(_firebaseAuth.currentUser!);
  }

  /// Convert Firebase User to domain User entity
  User _convertToUser(firebase_auth.User firebaseUser) {
    // Build provider data map from Firebase provider info
    final providerDataMap = <String, Map<String, dynamic>>{};
    for (final providerInfo in firebaseUser.providerData) {
      providerDataMap[providerInfo.providerId] = {
        'uid': providerInfo.uid,
        'email': providerInfo.email,
        'displayName': providerInfo.displayName,
        'photoURL': providerInfo.photoURL,
        'phoneNumber': providerInfo.phoneNumber,
        'providerId': providerInfo.providerId,
      };
    }

    return User(
      id: firebaseUser.uid,
      email: firebaseUser.email,
      displayName: firebaseUser.displayName,
      phoneNumber: firebaseUser.phoneNumber,
      photoUrl: firebaseUser.photoURL,
      emailVerified: firebaseUser.emailVerified,
      phoneVerified: firebaseUser.phoneNumber != null,
      providers: firebaseUser.providerData
          .map((info) => info.providerId)
          .toList(),
      providerData: providerDataMap,
      createdAt: firebaseUser.metadata.creationTime ?? DateTime.now(),
      lastLoginAt: firebaseUser.metadata.lastSignInTime,
    );
  }

  @override
  void dispose() {
    // Clean up resources if needed
  }
}
```

### Step 2: Create the Authentication Adapter

```dart
class FirebaseBackendAdapter extends BackendAdapter {
  late FirebaseAuth _firebaseAuth;

  @override
  String get name => 'firebase';

  @override
  String get version => '1.0.0';

  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    // Validate configuration
    _validateConfig(config);

    // Initialize Firebase
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: config['apiKey'],
        appId: config['appId'],
        messagingSenderId: config['messagingSenderId'],
        projectId: config['projectId'],
      ),
    );

    _firebaseAuth = FirebaseAuth.instance;

    // Configure Firebase Auth settings
    if (config['enablePersistence'] == true) {
      await _firebaseAuth.setPersistence(Persistence.LOCAL);
    }

    // Register repositories
    _registerRepositories();
  }

  void _validateConfig(Map<String, dynamic> config) {
    final required = ['apiKey', 'appId', 'messagingSenderId', 'projectId'];
    for (final key in required) {
      if (!config.containsKey(key) || config[key] == null) {
        throw AdapterConfigurationException(
          'Missing required Firebase configuration: $key',
        );
      }
    }
  }

  void _registerRepositories() {
    // Register authentication repository
    registerRepositoryFactory<AuthRepository>(
      () => FirebaseAuthRepository(_firebaseAuth),
    );

    // Register other Firebase repositories...
  }
}
```

### Step 3: Register with AdapterRegistry

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = await loadConfiguration();

  final adapterRegistry = AdapterRegistry();

  // Register Firebase adapter
  await adapterRegistry.registerAdapter(() async {
    final adapter = FirebaseBackendAdapter();
    await adapter.initialize(config['firebase']);
    return adapter;
  });

  runApp(MyApp(adapterRegistry: adapterRegistry));
}
```

## Authentication Flow Patterns

### Sign In Flow

```dart
class AuthService {
  final AuthRepository _authRepository;

  AuthService(this._authRepository);

  Future<AuthResult> signInWithEmail(String email, String password) async {
    final credentials = EmailPasswordCredentials(
      email: email,
      password: password,
    );

    final result = await _authRepository.signIn(credentials);

    if (result.success) {
      // Handle successful sign in
      print('Welcome ${result.user?.displayName}');
    } else if (result.requiresAdditionalAction) {
      // Handle additional action required (e.g., email verification)
      if (result.additionalActionType == 'email_verification') {
        print('Please verify your email');
      }
    } else {
      // Handle error
      print('Sign in failed: ${result.errorMessage}');
    }

    return result;
  }

  Future<AuthResult> signInWithGoogle(String accessToken, String idToken) async {
    final credentials = OAuthCredentials(
      provider: 'google',
      accessToken: accessToken,
      idToken: idToken,
    );

    return await _authRepository.signIn(credentials);
  }
}
```

### Sign Up Flow

```dart
Future<AuthResult> signUpWithEmail({
  required String email,
  required String password,
  required String displayName,
}) async {
  final credentials = EmailPasswordCredentials(
    email: email,
    password: password,
  );

  final result = await _authRepository.signUp(
    credentials,
    displayName: displayName,
  );

  if (result.requiresAdditionalAction &&
      result.additionalActionType == 'email_verification') {
    // Prompt user to check email
    print('Check your email to verify your account');
  }

  return result;
}
```

### Password Reset Flow

```dart
Future<void> resetPassword(String email) async {
  // Step 1: Send password reset email
  final result = await _authRepository.sendPasswordResetEmail(email);

  if (result.success) {
    print('Password reset email sent to $email');
  }
}

Future<void> confirmPasswordReset(String code, String newPassword) async {
  // Step 2: Confirm password reset with code from email
  final result = await _authRepository.confirmPasswordReset(code, newPassword);

  if (result.success) {
    print('Password reset successfully');
  }
}
```

## Token Management

### Getting ID Token

```dart
Future<String?> getAuthToken() async {
  // Get cached token
  final token = await _authRepository.getIdToken();

  // Force refresh if needed
  final freshToken = await _authRepository.getIdToken(forceRefresh: true);

  return token;
}
```

### Refreshing Token

```dart
Future<AuthResult> refreshAuthToken(String refreshToken) async {
  final result = await _authRepository.refreshToken(refreshToken);

  if (result.success && result.token != null) {
    // Save new token
    await saveToken(result.token!);
  }

  return result;
}
```

### Using Token in API Calls

```dart
class AuthenticatedApiClient {
  final AuthRepository _authRepository;
  final ApiClient _apiClient;

  AuthenticatedApiClient(this._authRepository, this._apiClient);

  Future<Response> makeAuthenticatedRequest(String endpoint) async {
    // Get current token
    final token = await _authRepository.getIdToken();

    if (token == null) {
      throw Exception('User not authenticated');
    }

    // Make API request with token
    return await _apiClient.get(
      endpoint,
      headers: {'Authorization': 'Bearer $token'},
    );
  }
}
```

## Multi-Factor Authentication

### Enrolling in MFA

```dart
Future<void> enableMFA(String phoneNumber) async {
  try {
    await _authRepository.enrollMFA(phoneNumber);
    print('MFA enrolled successfully');
  } catch (e) {
    print('Failed to enroll MFA: $e');
  }
}
```

### Unenrolling from MFA

```dart
Future<void> disableMFA() async {
  try {
    await _authRepository.unenrollMFA();
    print('MFA unenrolled successfully');
  } catch (e) {
    print('Failed to unenroll MFA: $e');
  }
}
```

## Social Authentication Providers

Social authentication is handled through the standard `signIn(AuthCredentials)` method using `OAuthCredentials`. The UI layer handles the provider-specific SDK interactions (Google Sign-In, Facebook Login, etc.) and creates the appropriate credentials.

### Google Sign In Integration

```dart
// UI/Service Layer - Handles Google Sign In SDK
class GoogleAuthService {
  final GoogleSignIn _googleSignIn;
  final AuthRepository _authRepository;

  GoogleAuthService(this._googleSignIn, this._authRepository);

  /// Trigger Google Sign In flow and authenticate with the repository
  Future<AuthResult> signInWithGoogle() async {
    try {
      // Trigger Google Sign In flow (UI interaction)
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return AuthResult.failure(
          errorMessage: 'Google sign in cancelled',
          errorCode: 'sign_in_cancelled',
        );
      }

      // Get authentication tokens from Google
      final googleAuth = await googleUser.authentication;

      // Create OAuth credentials
      final credentials = OAuthCredentials(
        provider: 'google',
        accessToken: googleAuth.accessToken!,
        idToken: googleAuth.idToken,
      );

      // Use standard AuthRepository.signIn method
      return await _authRepository.signIn(credentials);
    } catch (e) {
      return AuthResult.failure(
        errorMessage: e.toString(),
        errorCode: 'google_sign_in_failed',
      );
    }
  }
}

// Repository Layer - Handles OAuth credentials
// Your AuthRepository implementation should handle OAuthCredentials in signIn():
@override
Future<AuthResult> signIn(AuthCredentials credentials) async {
  if (credentials is OAuthCredentials && credentials.provider == 'google') {
    // Handle Google OAuth credentials
    // For Firebase: Use GoogleAuthProvider.credential()
    // For custom backend: Send tokens to your API
  }
  // ... handle other credential types
}
```

### Facebook Sign In Integration

```dart
// UI/Service Layer - Handles Facebook Login SDK
class FacebookAuthService {
  final FacebookAuth _facebookAuth;
  final AuthRepository _authRepository;

  FacebookAuthService(this._facebookAuth, this._authRepository);

  /// Trigger Facebook Login flow and authenticate with the repository
  Future<AuthResult> signInWithFacebook() async {
    try {
      // Trigger Facebook login flow (UI interaction)
      final result = await _facebookAuth.login();

      if (result.status != LoginStatus.success) {
        return AuthResult.failure(
          errorMessage: 'Facebook sign in failed',
          errorCode: 'facebook_sign_in_failed',
        );
      }

      final accessToken = result.accessToken!;

      // Create OAuth credentials
      final credentials = OAuthCredentials(
        provider: 'facebook',
        accessToken: accessToken.token,
      );

      // Use standard AuthRepository.signIn method
      return await _authRepository.signIn(credentials);
    } catch (e) {
      return AuthResult.failure(
        errorMessage: e.toString(),
        errorCode: 'facebook_sign_in_failed',
      );
    }
  }
}

// Repository Layer - Handles OAuth credentials
@override
Future<AuthResult> signIn(AuthCredentials credentials) async {
  if (credentials is OAuthCredentials && credentials.provider == 'facebook') {
    // Handle Facebook OAuth credentials
    // For Firebase: Use FacebookAuthProvider.credential()
    // For custom backend: Send token to your API
  }
  // ... handle other credential types
}
```

### Auth0 Example

```dart
class Auth0Repository extends AuthRepository {
  final Auth0Client _auth0Client;
  final AppLogger _logger = AppLogger('Auth0Repository');

  Auth0Repository(this._auth0Client);

  @override
  Future<AuthResult> signIn(AuthCredentials credentials) async {
    try {
      if (credentials is EmailPasswordCredentials) {
        final result = await _auth0Client.loginWithPassword(
          email: credentials.email,
          password: credentials.password,
        );

        return AuthResult.success(
          user: _convertToUser(result.user),
          token: result.accessToken,
          refreshToken: result.refreshToken,
          expiresAt: result.expiresAt,
        );
      } else if (credentials is OAuthCredentials) {
        final result = await _auth0Client.loginWithOAuth(
          connection: credentials.provider,
        );

        return AuthResult.success(
          user: _convertToUser(result.user),
          token: result.accessToken,
          refreshToken: result.refreshToken,
          expiresAt: result.expiresAt,
        );
      } else {
        return AuthResult.failure(
          errorMessage: 'Unsupported credential type',
          errorCode: 'unsupported_credential',
        );
      }
    } catch (e) {
      _logger.error('Auth0 sign in failed', e);
      return AuthResult.failure(
        errorMessage: e.toString(),
        errorCode: 'auth0_sign_in_failed',
      );
    }
  }

  @override
  Future<AuthResult> signUp(
    AuthCredentials credentials, {
    String? displayName,
    String? photoUrl,
    Map<String, dynamic>? metadata,
  }) async {
    if (credentials is! EmailPasswordCredentials) {
      return AuthResult.failure(
        errorMessage: 'Sign up only supports email/password',
        errorCode: 'unsupported_credential',
      );
    }

    try {
      await _auth0Client.signUp(
        email: credentials.email,
        password: credentials.password,
        metadata: metadata,
      );

      // Auto sign in after sign up
      return await signIn(credentials);
    } catch (e) {
      _logger.error('Auth0 sign up failed', e);
      return AuthResult.failure(
        errorMessage: e.toString(),
        errorCode: 'auth0_sign_up_failed',
      );
    }
  }

  User _convertToUser(Auth0User auth0User) {
    return User(
      id: auth0User.sub,
      email: auth0User.email,
      displayName: auth0User.name,
      photoUrl: auth0User.picture,
      emailVerified: auth0User.emailVerified ?? false,
      createdAt: auth0User.createdAt ?? DateTime.now(),
      metadata: auth0User.metadata,
    );
  }
}
```

## Best Practices

### DO

```dart
// ✅ Extend CoreRepository
abstract class AuthRepository extends CoreRepository {
  Future<AuthResult> signIn(AuthCredentials credentials);
}

// ✅ Return domain entities
@override
Future<AuthResult> signIn(AuthCredentials credentials) async {
  final providerUser = await _provider.signIn(/* ... */);
  return AuthResult.success(user: _convertToUser(providerUser));
}

// ✅ Handle all credential types
@override
Future<AuthResult> signIn(AuthCredentials credentials) async {
  if (credentials is EmailPasswordCredentials) {
    return await _signInWithEmailPassword(credentials);
  } else if (credentials is OAuthCredentials) {
    return await _signInWithOAuth(credentials);
  } else {
    return AuthResult.failure(
      errorMessage: 'Unsupported credential type',
      errorCode: 'unsupported_credential',
    );
  }
}

// ✅ Validate credentials
Future<AuthResult> _signInWithEmailPassword(
  EmailPasswordCredentials credentials,
) async {
  if (credentials.email.isEmpty || credentials.password.isEmpty) {
    return AuthResult.failure(
      errorMessage: 'Email and password are required',
      errorCode: 'invalid_credentials',
    );
  }

  // Proceed with sign in...
}

// ✅ Use AuthResult factory methods
return AuthResult.success(
  user: user,
  token: token,
  refreshToken: refreshToken,
);

return AuthResult.failure(
  errorMessage: 'Invalid credentials',
  errorCode: 'invalid_credentials',
);

return AuthResult.requiresAction(
  actionType: 'email_verification',
  message: 'Please verify your email',
);

// ✅ Stream authentication state
@override
Stream<User?> authStateChanges() {
  return _authProvider.onAuthStateChanged.map((providerUser) {
    if (providerUser == null) return null;
    return _convertToUser(providerUser);
  });
}

// ✅ Clean up resources
@override
void dispose() {
  _authStateSubscription?.cancel();
  super.dispose();
}
```

### DON'T

```dart
// ❌ Don't return provider-specific types
@override
Future<FirebaseUser> signIn(/* ... */) async {  // Wrong!
  return await FirebaseAuth.instance.signInWithEmailAndPassword(/* ... */);
}

// ❌ Don't throw exceptions for authentication failures
@override
Future<AuthResult> signIn(AuthCredentials credentials) async {
  // ❌ Don't do this
  throw Exception('Invalid credentials');

  // ✅ Do this instead
  return AuthResult.failure(
    errorMessage: 'Invalid credentials',
    errorCode: 'invalid_credentials',
  );
}

// ❌ Don't put business logic in repositories
@override
Future<AuthResult> signIn(AuthCredentials credentials) async {
  final result = await _provider.signIn(/* ... */);

  // ❌ Don't do authorization checks here
  if (!result.user.isAdmin) {
    return AuthResult.failure(errorMessage: 'Admin only');
  }

  return result;
}

// ❌ Don't skip credential type validation
@override
Future<AuthResult> signIn(AuthCredentials credentials) async {
  // ❌ Casting without checking
  final emailCreds = credentials as EmailPasswordCredentials;
  // ...
}

// ❌ Don't hardcode error messages
return AuthResult.failure(
  errorMessage: 'Sign in failed',  // ❌ Not helpful
);

// ✅ Provide detailed error messages
return AuthResult.failure(
  errorMessage: 'Invalid email or password',  // ✅ Helpful
  errorCode: 'invalid_credentials',
);
```

### Error Handling

```dart
@override
Future<AuthResult> signIn(AuthCredentials credentials) async {
  try {
    // Attempt sign in
    final result = await _provider.signIn(/* ... */);
    return AuthResult.success(user: _convertToUser(result));
  } on NetworkException catch (e) {
    return AuthResult.failure(
      errorMessage: 'Network error. Please check your connection.',
      errorCode: 'network_error',
    );
  } on InvalidCredentialsException catch (e) {
    return AuthResult.failure(
      errorMessage: 'Invalid email or password',
      errorCode: 'invalid_credentials',
    );
  } on UserDisabledException catch (e) {
    return AuthResult.failure(
      errorMessage: 'This account has been disabled',
      errorCode: 'user_disabled',
    );
  } catch (e) {
    _logger.error('Unexpected sign in error', e);
    return AuthResult.failure(
      errorMessage: 'An unexpected error occurred',
      errorCode: 'unknown_error',
    );
  }
}
```

### Security Best Practices

```dart
// ✅ Always validate tokens before use
Future<String?> getValidToken() async {
  final token = await _authRepository.getIdToken();

  if (token == null) return null;

  // Check if token is expired
  final isExpired = _isTokenExpired(token);

  if (isExpired) {
    // Refresh token
    return await _authRepository.getIdToken(forceRefresh: true);
  }

  return token;
}

// ✅ Secure token storage
class SecureTokenStorage {
  final FlutterSecureStorage _secureStorage;

  SecureTokenStorage(this._secureStorage);

  Future<void> saveToken(String token) async {
    await _secureStorage.write(key: 'auth_token', value: token);
  }

  Future<String?> getToken() async {
    return await _secureStorage.read(key: 'auth_token');
  }

  Future<void> deleteToken() async {
    await _secureStorage.delete(key: 'auth_token');
  }
}

// ✅ Implement session timeout
class SessionManager {
  final AuthRepository _authRepository;
  Timer? _sessionTimer;

  void startSession({Duration timeout = const Duration(minutes: 30)}) {
    _sessionTimer?.cancel();
    _sessionTimer = Timer(timeout, () async {
      await _authRepository.signOut();
      // Notify user of session timeout
    });
  }

  void resetSessionTimer() {
    startSession();
  }

  void endSession() {
    _sessionTimer?.cancel();
  }
}
```

## Testing

### Mock Authentication Repository

```dart
class MockAuthRepository extends AuthRepository {
  User? _currentUser;
  final StreamController<User?> _authStateController = StreamController<User?>.broadcast();

  @override
  Future<AuthResult> signIn(AuthCredentials credentials) async {
    await Future.delayed(Duration(milliseconds: 500));  // Simulate network delay

    if (credentials is EmailPasswordCredentials) {
      if (credentials.email == 'test@example.com' &&
          credentials.password == 'password123') {
        _currentUser = User(
          id: '1',
          email: credentials.email,
          displayName: 'Test User',
          emailVerified: true,
          createdAt: DateTime.now(),
        );
        _authStateController.add(_currentUser);

        return AuthResult.success(
          user: _currentUser!,
          token: 'mock_token_123',
        );
      } else {
        return AuthResult.failure(
          errorMessage: 'Invalid credentials',
          errorCode: 'invalid_credentials',
        );
      }
    }

    return AuthResult.failure(
      errorMessage: 'Unsupported credential type',
      errorCode: 'unsupported_credential',
    );
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _authStateController.add(null);
  }

  @override
  Future<User?> getCurrentUser() async {
    return _currentUser;
  }

  @override
  Stream<User?> authStateChanges() {
    return _authStateController.stream;
  }

  @override
  void dispose() {
    _authStateController.close();
  }
}
```

### Unit Testing

```dart
void main() {
  group('FirebaseAuthRepository', () {
    late FirebaseAuthRepository repository;
    late MockFirebaseAuth mockFirebaseAuth;

    setUp(() {
      mockFirebaseAuth = MockFirebaseAuth();
      repository = FirebaseAuthRepository(mockFirebaseAuth);
    });

    test('signIn with valid credentials returns success', () async {
      final credentials = EmailPasswordCredentials(
        email: 'test@example.com',
        password: 'password123',
      );

      when(mockFirebaseAuth.signInWithEmailAndPassword(
        email: anyNamed('email'),
        password: anyNamed('password'),
      )).thenAnswer((_) async => MockUserCredential());

      final result = await repository.signIn(credentials);

      expect(result.success, isTrue);
      expect(result.user, isNotNull);
    });

    test('signIn with invalid credentials returns failure', () async {
      final credentials = EmailPasswordCredentials(
        email: 'test@example.com',
        password: 'wrong_password',
      );

      when(mockFirebaseAuth.signInWithEmailAndPassword(
        email: anyNamed('email'),
        password: anyNamed('password'),
      )).thenThrow(FirebaseAuthException(code: 'invalid-credentials'));

      final result = await repository.signIn(credentials);

      expect(result.success, isFalse);
      expect(result.errorCode, equals('sign_in_failed'));
    });

    test('authStateChanges emits user on sign in', () async {
      final stream = repository.authStateChanges();

      expectLater(
        stream,
        emitsInOrder([
          null,
          isA<User>(),
        ]),
      );

      // Trigger sign in
      await repository.signIn(
        EmailPasswordCredentials(
          email: 'test@example.com',
          password: 'password123',
        ),
      );
    });
  });
}
```

## Example Adapters

### Custom Backend Adapter

```dart
class CustomBackendAuthRepository extends AuthRepository {
  final ApiClient _apiClient;
  final AppLogger _logger = AppLogger('CustomBackendAuthRepository');

  CustomBackendAuthRepository(this._apiClient);

  @override
  Future<AuthResult> signIn(AuthCredentials credentials) async {
    if (credentials is! EmailPasswordCredentials) {
      return AuthResult.failure(
        errorMessage: 'Only email/password supported',
        errorCode: 'unsupported_credential',
      );
    }

    try {
      final response = await _apiClient.post('/auth/login', data: {
        'email': credentials.email,
        'password': credentials.password,
      });

      final data = response.data as Map<String, dynamic>;

      return AuthResult.success(
        user: User(
          id: data['user']['id'],
          email: data['user']['email'],
          displayName: data['user']['name'],
          emailVerified: data['user']['email_verified'] ?? false,
          createdAt: DateTime.parse(data['user']['created_at']),
        ),
        token: data['access_token'],
        refreshToken: data['refresh_token'],
        expiresAt: DateTime.now().add(
          Duration(seconds: data['expires_in']),
        ),
      );
    } catch (e) {
      _logger.error('Sign in failed', e);
      return AuthResult.failure(
        errorMessage: 'Sign in failed',
        errorCode: 'sign_in_failed',
      );
    }
  }
}
```

## Related Documentation

- **[ADAPTER_PATTERN.md](./ADAPTER_PATTERN.md)** - General adapter pattern guide
- **[ARCHITECTURE.md](./ARCHITECTURE.md)** - Overall architecture
- **[ANTI_PATTERNS.md](./ANTI_PATTERNS.md)** - What to avoid

---

**Last Updated:** 2025-11-05
**Version:** 1.0.0
