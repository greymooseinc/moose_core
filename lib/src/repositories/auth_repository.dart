import '../entities/auth_credentials.dart';
import '../entities/auth_result.dart';
import '../entities/user.dart';
import 'repository.dart';

/// Abstract repository for authentication operations
///
/// This repository defines the contract for authentication adapters.
/// Implementations can support various authentication providers including:
/// - Email/Password (Firebase, Auth0, custom backend)
/// - OAuth providers (Google, Facebook, Apple, GitHub)
/// - Phone authentication
/// - Anonymous authentication
/// - Custom token authentication
///
/// ## Implementing an Auth Adapter
///
/// To create an authentication adapter, extend this class and implement
/// the required methods. Not all methods need to be implemented - you can
/// throw `UnimplementedError` for unsupported features.
///
/// ### Example: Firebase Auth Adapter
/// ```dart
/// class FirebaseAuthRepository extends AuthRepository {
///   final FirebaseAuth _auth = FirebaseAuth.instance;
///
///   @override
///   Future<AuthResult> signIn(AuthCredentials credentials) async {
///     if (credentials is EmailPasswordCredentials) {
///       try {
///         final userCredential = await _auth.signInWithEmailAndPassword(
///           email: credentials.email,
///           password: credentials.password,
///         );
///         return AuthResult.success(
///           user: _mapFirebaseUser(userCredential.user!),
///           token: await userCredential.user!.getIdToken(),
///         );
///       } catch (e) {
///         return AuthResult.failure(errorMessage: e.toString());
///       }
///     }
///     throw UnimplementedError('Credential type not supported');
///   }
/// }
/// ```
abstract class AuthRepository extends CoreRepository {
  AuthRepository({required super.hookRegistry, required super.eventBus});

  // ============================================================================
  // AUTHENTICATION METHODS
  // ============================================================================

  /// Sign in a user with the provided credentials
  ///
  /// Supports multiple credential types:
  /// - [EmailPasswordCredentials]: Email and password authentication
  /// - [PhoneCredentials]: Phone number with verification code
  /// - [OAuthCredentials]: OAuth provider tokens (Google, Facebook, etc.)
  /// - [CustomTokenCredentials]: Custom JWT or session token
  /// - [AnonymousCredentials]: Anonymous/guest authentication
  ///
  /// Returns an [AuthResult] with the authenticated user and auth token.
  ///
  /// Example:
  /// ```dart
  /// final result = await authRepo.signIn(
  ///   EmailPasswordCredentials(
  ///     email: 'user@example.com',
  ///     password: 'password123',
  ///   ),
  /// );
  /// if (result.success) {
  ///   print('Signed in as: ${result.user!.displayName}');
  /// }
  /// ```
  Future<AuthResult> signIn(AuthCredentials credentials);

  /// Sign up a new user with the provided credentials
  ///
  /// Creates a new user account with the given credentials and optionally
  /// additional user profile data.
  ///
  /// Parameters:
  /// - [credentials]: Authentication credentials for the new account
  /// - [displayName]: Optional display name for the user
  /// - [photoUrl]: Optional profile photo URL
  /// - [metadata]: Additional platform-specific data
  ///
  /// Returns an [AuthResult] with the newly created user.
  ///
  /// Example:
  /// ```dart
  /// final result = await authRepo.signUp(
  ///   EmailPasswordCredentials(
  ///     email: 'newuser@example.com',
  ///     password: 'password123',
  ///   ),
  ///   displayName: 'John Doe',
  /// );
  /// ```
  Future<AuthResult> signUp(
    AuthCredentials credentials, {
    String? displayName,
    String? photoUrl,
    Map<String, dynamic>? metadata,
  });

  /// Sign out the currently authenticated user
  ///
  /// Clears the current session and revokes authentication tokens.
  ///
  /// Example:
  /// ```dart
  /// await authRepo.signOut();
  /// ```
  Future<void> signOut();

  /// Get the currently authenticated user
  ///
  /// Returns the current [User] if authenticated, null otherwise.
  ///
  /// Example:
  /// ```dart
  /// final user = await authRepo.getCurrentUser();
  /// if (user != null) {
  ///   print('Logged in as: ${user.email}');
  /// }
  /// ```
  Future<User?> getCurrentUser();

  /// Stream of authentication state changes
  ///
  /// Emits the current [User] when authentication state changes,
  /// or null when user signs out.
  ///
  /// Example:
  /// ```dart
  /// authRepo.authStateChanges.listen((user) {
  ///   if (user != null) {
  ///     print('User signed in: ${user.email}');
  ///   } else {
  ///     print('User signed out');
  ///   }
  /// });
  /// ```
  Stream<User?> get authStateChanges;

  // ============================================================================
  // PASSWORD MANAGEMENT
  // ============================================================================

  /// Send a password reset email to the specified email address
  ///
  /// Initiates the password reset flow by sending a reset link or code
  /// to the user's email.
  ///
  /// Example:
  /// ```dart
  /// final result = await authRepo.sendPasswordResetEmail('user@example.com');
  /// if (result.success) {
  ///   print('Password reset email sent');
  /// }
  /// ```
  Future<PasswordResetResult> sendPasswordResetEmail(String email);

  /// Confirm password reset with the provided code and new password
  ///
  /// Completes the password reset flow using a verification code/token
  /// and the new password.
  ///
  /// Parameters:
  /// - [code]: Verification code from the reset email
  /// - [newPassword]: The new password to set
  ///
  /// Example:
  /// ```dart
  /// final result = await authRepo.confirmPasswordReset(
  ///   code: 'ABC123',
  ///   newPassword: 'newPassword456',
  /// );
  /// ```
  Future<PasswordResetResult> confirmPasswordReset({
    required String code,
    required String newPassword,
  });

  /// Change the password for the currently authenticated user
  ///
  /// Updates the password while the user is logged in.
  ///
  /// Parameters:
  /// - [currentPassword]: Current password for verification
  /// - [newPassword]: New password to set
  ///
  /// Example:
  /// ```dart
  /// final result = await authRepo.changePassword(
  ///   currentPassword: 'oldPassword',
  ///   newPassword: 'newPassword123',
  /// );
  /// ```
  Future<PasswordResetResult> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  // ============================================================================
  // EMAIL VERIFICATION
  // ============================================================================

  /// Send email verification to the current user
  ///
  /// Sends a verification email to the user's registered email address.
  ///
  /// Example:
  /// ```dart
  /// await authRepo.sendEmailVerification();
  /// ```
  Future<void> sendEmailVerification();

  /// Verify email with the provided verification code
  ///
  /// Confirms the user's email address using the verification code.
  ///
  /// Example:
  /// ```dart
  /// final result = await authRepo.verifyEmail('VERIFY123');
  /// if (result.success) {
  ///   print('Email verified successfully');
  /// }
  /// ```
  Future<EmailVerificationResult> verifyEmail(String code);

  // ============================================================================
  // PHONE VERIFICATION
  // ============================================================================

  /// Send phone verification code to the specified phone number
  ///
  /// Initiates phone number verification by sending an SMS code.
  ///
  /// Parameters:
  /// - [phoneNumber]: Phone number in E.164 format (e.g., +1234567890)
  ///
  /// Example:
  /// ```dart
  /// await authRepo.sendPhoneVerificationCode('+1234567890');
  /// ```
  Future<void> sendPhoneVerificationCode(String phoneNumber);

  /// Verify phone number with the provided verification code
  ///
  /// Confirms the phone number using the SMS verification code.
  ///
  /// Example:
  /// ```dart
  /// final result = await authRepo.verifyPhoneNumber(
  ///   phoneNumber: '+1234567890',
  ///   verificationCode: '123456',
  /// );
  /// ```
  Future<EmailVerificationResult> verifyPhoneNumber({
    required String phoneNumber,
    required String verificationCode,
  });

  // ============================================================================
  // USER PROFILE MANAGEMENT
  // ============================================================================

  /// Update the current user's profile information
  ///
  /// Updates user profile fields like display name and photo URL.
  ///
  /// Example:
  /// ```dart
  /// final user = await authRepo.updateProfile(
  ///   displayName: 'Jane Doe',
  ///   photoUrl: 'https://example.com/photo.jpg',
  /// );
  /// ```
  Future<User> updateProfile({
    String? displayName,
    String? photoUrl,
    Map<String, dynamic>? metadata,
  });

  /// Update the current user's email address
  ///
  /// Changes the email address for the authenticated user.
  /// May require re-authentication depending on the provider.
  ///
  /// Example:
  /// ```dart
  /// final user = await authRepo.updateEmail('newemail@example.com');
  /// ```
  Future<User> updateEmail(String newEmail);

  /// Delete the current user's account
  ///
  /// Permanently deletes the user account and all associated data.
  /// This action is irreversible.
  ///
  /// Example:
  /// ```dart
  /// await authRepo.deleteAccount();
  /// ```
  Future<void> deleteAccount();

  // ============================================================================
  // TOKEN MANAGEMENT
  // ============================================================================

  /// Get a fresh authentication token for the current user
  ///
  /// Retrieves a new auth token, useful for making authenticated API requests.
  ///
  /// Parameters:
  /// - [forceRefresh]: Whether to force refresh even if current token is valid
  ///
  /// Example:
  /// ```dart
  /// final token = await authRepo.getIdToken(forceRefresh: true);
  /// ```
  Future<String?> getIdToken({bool forceRefresh = false});

  /// Refresh the authentication token using a refresh token
  ///
  /// Obtains a new auth token using the refresh token.
  ///
  /// Example:
  /// ```dart
  /// final result = await authRepo.refreshToken('refresh_token_here');
  /// ```
  Future<AuthResult> refreshToken(String refreshToken);

  // ============================================================================
  // ACCOUNT LINKING
  // ============================================================================

  /// Link an additional authentication method to the current user
  ///
  /// Allows a user to sign in with multiple providers (e.g., both email and Google).
  ///
  /// Example:
  /// ```dart
  /// final result = await authRepo.linkCredential(
  ///   OAuthCredentials(provider: 'google.com', idToken: 'token'),
  /// );
  /// ```
  Future<AuthResult> linkCredential(AuthCredentials credentials);

  /// Unlink an authentication method from the current user
  ///
  /// Removes a linked authentication provider.
  ///
  /// Example:
  /// ```dart
  /// await authRepo.unlinkProvider('google.com');
  /// ```
  Future<User> unlinkProvider(String providerId);

  // ============================================================================
  // MULTI-FACTOR AUTHENTICATION (OPTIONAL)
  // ============================================================================

  /// Enroll in multi-factor authentication
  ///
  /// Enables MFA for the current user account.
  Future<void> enrollMFA({
    required String phoneNumber,
  });

  /// Unenroll from multi-factor authentication
  ///
  /// Disables MFA for the current user account.
  Future<void> unenrollMFA();
}
