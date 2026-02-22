import '../entities/address.dart';
import 'repository.dart';

/// Repository for store metadata and configuration.
///
/// Provides access to store-wide settings, legal information,
/// physical locations, and other store-related data.
abstract class StoreRepository extends CoreRepository {
  StoreRepository({required super.hookRegistry, required super.eventBus});

  // ==================== Store Information ====================

  /// Get basic store information
  ///
  /// Returns general metadata about the store such as name, description,
  /// logo URL, and other basic information.
  ///
  /// Returns a map with store metadata
  Future<Map<String, dynamic>> getStoreInfo();

  /// Get store name
  ///
  /// Returns the display name of the store
  Future<String> getStoreName();

  /// Get store description
  ///
  /// Returns the store's description or tagline
  Future<String?> getStoreDescription();

  /// Get store logo URL
  ///
  /// Returns the URL to the store's logo image
  Future<String?> getStoreLogoUrl();

  /// Get store currency
  ///
  /// Returns the default currency code for the store (e.g., 'USD', 'GBP')
  Future<String> getStoreCurrency();

  /// Get store timezone
  ///
  /// Returns the timezone identifier for the store (e.g., 'America/New_York')
  Future<String?> getStoreTimezone();

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
  });

  /// Get a specific store location by ID
  ///
  /// [locationId] - The unique identifier for the store location
  ///
  /// Returns the store location Address, or null if not found
  Future<Address?> getStoreLocation({
    required String locationId,
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
  });

  // ==================== Legal & Policy Information ====================

  /// Get Terms of Service (ToS) link
  ///
  /// Returns the URL to the store's Terms of Service page
  Future<String?> getTermsOfServiceUrl();

  /// Get Privacy Policy link
  ///
  /// Returns the URL to the store's Privacy Policy page
  Future<String?> getPrivacyPolicyUrl();

  /// Get Return Policy link
  ///
  /// Returns the URL to the store's Return Policy page
  Future<String?> getReturnPolicyUrl();

  /// Get Shipping Policy link
  ///
  /// Returns the URL to the store's Shipping Policy page
  Future<String?> getShippingPolicyUrl();

  /// Get Refund Policy link
  ///
  /// Returns the URL to the store's Refund Policy page
  Future<String?> getRefundPolicyUrl();

  /// Get Cookie Policy link
  ///
  /// Returns the URL to the store's Cookie Policy page
  Future<String?> getCookiePolicyUrl();

  /// Get all policy links
  ///
  /// Returns a map of policy type to URL
  /// Keys: 'terms', 'privacy', 'return', 'shipping', 'refund', 'cookie'
  Future<Map<String, String>> getAllPolicyUrls();

  // ==================== Contact Information ====================

  /// Get store contact email
  ///
  /// Returns the primary contact email address for the store
  Future<String?> getContactEmail();

  /// Get store contact phone
  ///
  /// Returns the primary contact phone number for the store
  Future<String?> getContactPhone();

  /// Get customer support email
  ///
  /// Returns the customer support email address
  Future<String?> getSupportEmail();

  /// Get customer support phone
  ///
  /// Returns the customer support phone number
  Future<String?> getSupportPhone();

  // ==================== Social Media ====================

  /// Get social media links
  ///
  /// Returns a map of social media platform to profile URL
  /// Keys: 'facebook', 'twitter', 'instagram', 'youtube', 'linkedin', etc.
  Future<Map<String, String>> getSocialMediaLinks();

  /// Get a specific social media link
  ///
  /// [platform] - The social media platform (e.g., 'facebook', 'instagram')
  ///
  /// Returns the URL to the store's profile on that platform
  Future<String?> getSocialMediaLink({
    required String platform,
  });

  // ==================== Operating Hours ====================

  /// Get store operating hours
  ///
  /// Returns operating hours for each day of the week
  /// Format: Map with day keys ('monday', 'tuesday', etc.) and time strings
  /// Example: {'monday': '9:00 AM - 5:00 PM', 'tuesday': '9:00 AM - 5:00 PM'}
  Future<Map<String, String>?> getOperatingHours();

  /// Check if store is currently open
  ///
  /// [locationId] - Optional specific store location ID
  ///
  /// Returns true if the store is currently open
  Future<bool> isStoreOpen({
    String? locationId,
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
  });

  /// Get multiple store settings
  ///
  /// [keys] - List of setting keys to retrieve
  ///
  /// Returns a map of key to value for the requested settings
  Future<Map<String, dynamic>> getSettings({
    required List<String> keys,
  });

  /// Get all store settings
  ///
  /// Returns a map of all available store settings
  Future<Map<String, dynamic>> getAllSettings();
}
