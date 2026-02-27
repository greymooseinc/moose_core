import '../entities/address.dart';
import '../entities/country.dart';
import '../entities/postal_code.dart';
import 'repository.dart';

/// Repository for location-based operations.
///
/// Handles address autocomplete, postal code lookup, geolocation,
/// and customer address management.
abstract class LocationRepository extends CoreRepository {

  // ==================== Address Autocomplete ====================

  /// Search for addresses based on a partial query string
  ///
  /// Used for address autocomplete functionality. Returns a list of
  /// address suggestions that match the search query.
  ///
  /// [query] - The search string (e.g., "1600 Amphitheatre")
  /// [countryCode] - Optional country code to restrict results (e.g., 'US', 'GB')
  /// [limit] - Maximum number of results to return (default: 10)
  ///
  /// Returns a list of Address suggestions
  Future<List<Address>> searchAddresses({
    required String query,
    String? countryCode,
    int limit = 10,
  });

  /// Get full address details from a place ID or address ID
  ///
  /// Used to get complete address information after selecting a suggestion
  /// from autocomplete results.
  ///
  /// [placeId] - The unique identifier for the address/place
  ///
  /// Returns complete Address with all available details
  Future<Address> getAddressDetails({
    required String placeId,
  });

  // ==================== Postal Code Lookup ====================

  /// Look up postal code information
  ///
  /// Returns geographic and administrative information for a given postal code.
  ///
  /// [postalCode] - The postal code to look up (e.g., '90210', 'SW1A 1AA')
  /// [countryCode] - Country code for the postal code (e.g., 'US', 'GB')
  ///
  /// Returns PostalCode entity with location data, or null if not found
  Future<PostalCode?> lookupPostalCode({
    required String postalCode,
    required String countryCode,
  });

  /// Validate a postal code format
  ///
  /// Checks if a postal code matches the expected format for a given country.
  ///
  /// [postalCode] - The postal code to validate
  /// [countryCode] - Country code for validation rules
  ///
  /// Returns true if the postal code format is valid
  Future<bool> validatePostalCode({
    required String postalCode,
    required String countryCode,
  });

  // ==================== Geolocation ====================

  /// Get address from geographic coordinates (reverse geocoding)
  ///
  /// Converts latitude and longitude into a physical address.
  ///
  /// [latitude] - Geographic latitude
  /// [longitude] - Geographic longitude
  ///
  /// Returns Address at the specified coordinates, or null if not found
  Future<Address?> getAddressFromCoordinates({
    required double latitude,
    required double longitude,
  });

  /// Get coordinates from an address (forward geocoding)
  ///
  /// Converts a physical address into geographic coordinates.
  ///
  /// [address] - The Address to geocode
  ///
  /// Returns a map with 'latitude' and 'longitude' keys, or null if not found
  Future<Map<String, double>?> getCoordinatesFromAddress({
    required Address address,
  });

  // ==================== Countries ====================

  /// Get list of available countries
  ///
  /// Returns all countries that are available for shipping or billing.
  ///
  /// [shippingOnly] - If true, returns only countries available for shipping
  /// [billingOnly] - If true, returns only countries available for billing
  ///
  /// Returns list of Country entities
  Future<List<Country>> getCountries({
    bool shippingOnly = false,
    bool billingOnly = false,
  });

  /// Get country by code
  ///
  /// [countryCode] - ISO 3166-1 alpha-2 country code (e.g., 'US', 'GB')
  ///
  /// Returns Country entity, or null if not found
  Future<Country?> getCountry({
    required String countryCode,
  });

  /// Get states/provinces for a country
  ///
  /// [countryCode] - ISO 3166-1 alpha-2 country code
  ///
  /// Returns list of CountryState entities for the country
  Future<List<CountryState>> getStates({
    required String countryCode,
  });

  // ==================== Customer Addresses ====================

  /// Get all addresses for a customer
  ///
  /// [customerId] - The customer's unique identifier
  ///
  /// Returns list of saved Address entities for the customer
  Future<List<Address>> getCustomerAddresses({
    required String customerId,
  });

  /// Get a specific customer address by ID
  ///
  /// [customerId] - The customer's unique identifier
  /// [addressId] - The address's unique identifier
  ///
  /// Returns the Address, or null if not found
  Future<Address?> getCustomerAddress({
    required String customerId,
    required String addressId,
  });

  /// Save a new address for a customer
  ///
  /// [customerId] - The customer's unique identifier
  /// [address] - The Address to save
  ///
  /// Returns the saved Address with generated ID
  Future<Address> saveCustomerAddress({
    required String customerId,
    required Address address,
  });

  /// Update an existing customer address
  ///
  /// [customerId] - The customer's unique identifier
  /// [addressId] - The address's unique identifier
  /// [address] - The updated Address data
  ///
  /// Returns the updated Address
  Future<Address> updateCustomerAddress({
    required String customerId,
    required String addressId,
    required Address address,
  });

  /// Delete a customer address
  ///
  /// [customerId] - The customer's unique identifier
  /// [addressId] - The address's unique identifier
  ///
  /// Returns true if deletion was successful
  Future<bool> deleteCustomerAddress({
    required String customerId,
    required String addressId,
  });

  /// Set an address as the default for a customer
  ///
  /// [customerId] - The customer's unique identifier
  /// [addressId] - The address's unique identifier
  ///
  /// Returns the updated Address with isDefault = true
  Future<Address> setDefaultAddress({
    required String customerId,
    required String addressId,
  });
}
