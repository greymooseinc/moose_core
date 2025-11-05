import '../entities/push_notification.dart';
import 'repository.dart';

/// Abstract repository for push notification operations
///
/// This repository defines the contract for push notification functionality.
/// Adapters implement this interface to support different push notification providers:
/// - Firebase Cloud Messaging (FCM)
/// - OneSignal
/// - AWS SNS
/// - Custom push notification services
///
/// ## Implementation Pattern:
/// ```dart
/// class FCMNotificationRepository extends CoreRepository
///     implements PushNotificationRepository {
///   final FirebaseMessaging _fcm;
///
///   @override
///   Future<void> initialize() async {
///     await _fcm.requestPermission();
///     await _subscribe ToTopics();
///     _setupMessageHandlers();
///   }
///
///   @override
///   Future<String?> getDeviceToken() async {
///     return await _fcm.getToken();
///   }
/// }
/// ```
abstract class PushNotificationRepository extends CoreRepository {
  /// Request notification permissions from the user
  ///
  /// Returns the permission status after the request.
  /// On iOS, this shows the system permission dialog.
  /// On Android, permissions are granted automatically on most versions.
  Future<NotificationPermissionStatus> requestPermission();

  /// Get current notification permission status
  ///
  /// Check if user has granted notification permissions without requesting.
  Future<NotificationPermissionStatus> getPermissionStatus();

  /// Get the device's push notification token
  ///
  /// This token is used by your backend to send push notifications to this device.
  /// The token may change, so listen to [onTokenRefresh] for updates.
  ///
  /// Returns null if token is not yet available or permissions not granted.
  Future<String?> getDeviceToken();

  /// Stream of device token refreshes
  ///
  /// Listen to this stream to get notified when the token changes.
  /// Send updated tokens to your backend to ensure notifications can be delivered.
  ///
  /// Example:
  /// ```dart
  /// repository.onTokenRefresh.listen((newToken) {
  ///   await backend.updateDeviceToken(userId, newToken);
  /// });
  /// ```
  Stream<String> get onTokenRefresh;

  /// Stream of received notifications when app is in foreground
  ///
  /// Listen to this to handle notifications while the user is actively using the app.
  ///
  /// Example:
  /// ```dart
  /// repository.onNotificationReceived.listen((notification) {
  ///   // Show in-app notification banner
  ///   showInAppNotification(notification);
  /// });
  /// ```
  Stream<PushNotification> get onNotificationReceived;

  /// Stream of notification taps/opens
  ///
  /// Fired when user taps a notification (app in background or terminated).
  /// Use this for deep linking and navigation.
  ///
  /// Example:
  /// ```dart
  /// repository.onNotificationTapped.listen((notification) {
  ///   if (notification.route != null) {
  ///     Navigator.pushNamed(context, notification.route!);
  ///   }
  /// });
  /// ```
  Stream<PushNotification> get onNotificationTapped;

  /// Subscribe to a notification topic
  ///
  /// Topics allow you to send notifications to groups of devices without managing individual tokens.
  /// Common topics: 'all_users', 'promotions', 'order_updates', 'category_electronics'
  ///
  /// Example:
  /// ```dart
  /// await repository.subscribeToTopic('new_arrivals');
  /// await repository.subscribeToTopic('category_${categoryId}');
  /// ```
  Future<void> subscribeToTopic(String topic);

  /// Unsubscribe from a notification topic
  ///
  /// Stop receiving notifications for a specific topic.
  ///
  /// Example:
  /// ```dart
  /// await repository.unsubscribeFromTopic('promotions');
  /// ```
  Future<void> unsubscribeFromTopic(String topic);

  /// Get notification badge count
  ///
  /// Returns the current badge count (iOS) or notification count.
  /// Returns null if not supported by the platform.
  Future<int?> getBadgeCount();

  /// Set notification badge count
  ///
  /// Update the app icon badge (iOS) or notification count.
  /// Set to 0 to clear the badge.
  ///
  /// Example:
  /// ```dart
  /// await repository.setBadgeCount(5); // Show 5
  /// await repository.setBadgeCount(0); // Clear badge
  /// ```
  Future<void> setBadgeCount(int count);

  /// Clear all notifications from the notification center
  ///
  /// Removes all notifications displayed in the system notification tray.
  Future<void> clearAllNotifications();

  /// Send notification settings to backend (optional)
  ///
  /// Some implementations may want to sync notification preferences with backend.
  /// This is optional and can return an empty Future if not needed.
  ///
  /// Example:
  /// ```dart
  /// await repository.syncSettings(NotificationSettings(
  ///   enabled: true,
  ///   enabledTypes: {'orders', 'promotions'},
  /// ));
  /// ```
  Future<void> syncSettings(NotificationSettings settings) async {
    // Optional: Override in implementation to sync with backend
    return;
  }

  /// Get notification history (optional)
  ///
  /// Some providers support retrieving notification history.
  /// Returns empty list if not supported.
  ///
  /// Parameters:
  /// - [limit]: Maximum number of notifications to retrieve
  /// - [offset]: Number of notifications to skip (for pagination)
  Future<List<PushNotification>> getNotificationHistory({
    int limit = 20,
    int offset = 0,
  }) async {
    // Optional: Override in implementation if provider supports history
    return [];
  }

  /// Mark notification as read (optional)
  ///
  /// Track read status for notifications.
  /// Returns updated notification or null if not supported.
  Future<PushNotification?> markAsRead(String notificationId) async {
    // Optional: Override in implementation if you want to track read status
    return null;
  }

  /// Delete a notification (optional)
  ///
  /// Remove a specific notification from history.
  Future<void> deleteNotification(String notificationId) async {
    // Optional: Override in implementation
    return;
  }

  /// Get the notification that launched the app (if any)
  ///
  /// When app is launched by tapping a notification while terminated,
  /// this returns the notification that opened the app.
  ///
  /// Returns null if app was not launched from a notification.
  Future<PushNotification?> getInitialNotification();

  /// Set foreground notification presentation options
  ///
  /// Configure how notifications are displayed when app is in foreground.
  ///
  /// Example:
  /// ```dart
  /// await repository.setForegroundPresentationOptions(
  ///   showAlert: true,
  ///   playSound: true,
  ///   showBadge: true,
  /// );
  /// ```
  Future<void> setForegroundPresentationOptions({
    bool showAlert = true,
    bool playSound = true,
    bool showBadge = true,
  }) async {
    // Optional: Override in implementation
    return;
  }
}
