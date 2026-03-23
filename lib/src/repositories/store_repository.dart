import '../entities/address.dart';
import 'repository.dart';
import 'repository_options.dart';

/// Repository for store metadata and configuration.
///
/// Provides access to store-wide settings, legal information,
/// physical locations, and other store-related data.
abstract class StoreRepository extends CoreRepository {

  // ==================== Store Information ====================

  /// Get basic store information
  ///
  /// Returns general metadata about the store such as name, description,
  /// logo URL, and other basic information.
  ///
  /// Returns a map with store metadata
  Future<Map<String, dynamic>> getStoreInfo({RepositoryOptions? options});

  /// Get store name
  ///
  /// Returns the display name of the store
  Future<String> getStoreName({RepositoryOptions? options});

  /// Get store description
  ///
  /// Returns the store's description or tagline
  Future<String?> getStoreDescription({RepositoryOptions? options});

  /// Get store logo URL
  ///
  /// Returns the URL to the store's logo image
  Future<String?> getStoreLogoUrl({RepositoryOptions? options});

  /// Get store currency
  ///
  /// Returns the default currency code for the store (e.g., 'USD', 'GBP')
  Future<String> getStoreCurrency({RepositoryOptions? options});

  /// Get store timezone
  ///
  /// Returns the timezone identifier for the store (e.g., 'America/New_York')
  Future<String?> getStoreTimezone({RepositoryOptions? options});

  // ==================== Store Locations ====================

  /// Get all physical store locations
  ///
  /// Returns a list of Address entities representing physical store locations,
  /// warehouses, or pickup points.
  ///
  /// [locationType] - Optional filter by location type (e.g., 'store', 'warehouse', 'pickup')
  ///
  /// Returns list of store location addresses
  Future<List<Address>> getStoreLocations({
    String? locationType,
    RepositoryOptions? options,
  });

  /// Get a specific store location by ID
  ///
  /// [locationId] - The unique identifier for the store location
  ///
  /// Returns the store location Address, or null if not found
  Future<Address?> getStoreLocation({
    required String locationId,
    RepositoryOptions? options,
  });

  /// Find nearest store locations to coordinates
  ///
  /// [latitude] - Geographic latitude
  /// [longitude] - Geographic longitude
  /// [radius] - Search radius in kilometers (default: 50)
  /// [limit] - Maximum number of results (default: 10)
  ///
  /// Returns list of nearby store locations sorted by distance
  Future<List<Address>> findNearestStores({
    required double latitude,
    required double longitude,
    double radius = 50.0,
    int limit = 10,
    RepositoryOptions? options,
  });

  // ==================== Legal & Policy Information ====================

  /// Get Terms of Service (ToS) link
  ///
  /// Returns the URL to the store's Terms of Service page
  Future<String?> getTermsOfServiceUrl({RepositoryOptions? options});

  /// Get Privacy Policy link
  ///
  /// Returns the URL to the store's Privacy Policy page
  Future<String?> getPrivacyPolicyUrl({RepositoryOptions? options});

  /// Get Return Policy link
  ///
  /// Returns the URL to the store's Return Policy page
  Future<String?> getReturnPolicyUrl({RepositoryOptions? options});

  /// Get Shipping Policy link
  ///
  /// Returns the URL to the store's Shipping Policy page
  Future<String?> getShippingPolicyUrl({RepositoryOptions? options});

  /// Get Refund Policy link
  ///
  /// Returns the URL to the store's Refund Policy page
  Future<String?> getRefundPolicyUrl({RepositoryOptions? options});

  /// Get Cookie Policy link
  ///
  /// Returns the URL to the store's Cookie Policy page
  Future<String?> getCookiePolicyUrl({RepositoryOptions? options});

  /// Get all policy links
  ///
  /// Returns a map of policy type to URL
  /// Keys: 'terms', 'privacy', 'return', 'shipping', 'refund', 'cookie'
  Future<Map<String, String>> getAllPolicyUrls({RepositoryOptions? options});

  // ==================== Contact Information ====================

  /// Get store contact email
  ///
  /// Returns the primary contact email address for the store
  Future<String?> getContactEmail({RepositoryOptions? options});

  /// Get store contact phone
  ///
  /// Returns the primary contact phone number for the store
  Future<String?> getContactPhone({RepositoryOptions? options});

  /// Get customer support email
  ///
  /// Returns the customer support email address
  Future<String?> getSupportEmail({RepositoryOptions? options});

  /// Get customer support phone
  ///
  /// Returns the customer support phone number
  Future<String?> getSupportPhone({RepositoryOptions? options});

  // ==================== Social Media ====================

  /// Get social media links
  ///
  /// Returns a map of social media platform to profile URL
  /// Keys: 'facebook', 'twitter', 'instagram', 'youtube', 'linkedin', etc.
  Future<Map<String, String>> getSocialMediaLinks({RepositoryOptions? options});

  /// Get a specific social media link
  ///
  /// [platform] - The social media platform (e.g., 'facebook', 'instagram')
  ///
  /// Returns the URL to the store's profile on that platform
  Future<String?> getSocialMediaLink({
    required String platform,
    RepositoryOptions? options,
  });

  // ==================== Operating Hours ====================

  /// Get store operating hours
  ///
  /// Returns operating hours for each day of the week
  /// Format: Map with day keys ('monday', 'tuesday', etc.) and time strings
  /// Example: {'monday': '9:00 AM - 5:00 PM', 'tuesday': '9:00 AM - 5:00 PM'}
  Future<Map<String, String>?> getOperatingHours({RepositoryOptions? options});

  /// Check if store is currently open
  ///
  /// [locationId] - Optional specific store location ID
  ///
  /// Returns true if the store is currently open
  Future<bool> isStoreOpen({
    String? locationId,
    RepositoryOptions? options,
  });

  // ==================== Custom Settings ====================

  /// Get a custom store setting by key
  ///
  /// Generic method to retrieve any custom store configuration value.
  ///
  /// [key] - The setting key
  /// [defaultValue] - Optional default value if setting doesn't exist
  ///
  /// Returns the setting value or defaultValue
  Future<dynamic> getSetting({
    required String key,
    dynamic defaultValue,
    RepositoryOptions? options,
  });

  /// Get multiple store settings
  ///
  /// [keys] - List of setting keys to retrieve
  ///
  /// Returns a map of key to value for the requested settings
  Future<Map<String, dynamic>> getSettings({
    required List<String> keys,
    RepositoryOptions? options,
  });

  /// Get all store settings
  ///
  /// Returns a map of all available store settings
  Future<Map<String, dynamic>> getAllSettings({RepositoryOptions? options});

  // ==================== Locale ====================

  /// Get the currently active store locale (language code, e.g. 'en', 'ja').
  ///
  /// Returns null if locale selection is not supported by this backend.
  Future<String?> getStoreLocale({RepositoryOptions? options});

  /// Set the store locale — persists the preference on the backend if possible
  /// (e.g. updates a customer's language preference in their account).
  ///
  /// [languageCode] — BCP-47 language code (e.g. 'en', 'ja', 'fr')
  ///
  /// Returns the locale code that was accepted, or null if not supported.
  Future<String?> setStoreLocale(
    String languageCode, {
    RepositoryOptions? options,
  });
}
