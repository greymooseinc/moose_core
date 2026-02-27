import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent cache using SharedPreferences for data that survives app restarts.
///
/// Each [PersistentCache] instance is independent — there is no shared global
/// state. Instances are owned and scoped by [MooseAppContext] and accessed via
/// `appContext.cache.persistent`.
///
/// Provides persistent key-value storage backed by SharedPreferences.
/// Data stored here persists between app sessions and device reboots.
///
/// Note: For temporary runtime data that doesn't need persistence,
/// use [MemoryCache] instead for better performance.
class PersistentCache {
  PersistentCache();

  // SharedPreferences instance (lazy loaded)
  SharedPreferences? _prefs;

  /// Initialize the cache (must be called before first use)
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Ensure prefs is initialized
  Future<SharedPreferences> get _prefsInstance async {
    if (_prefs == null) {
      await init();
    }
    return _prefs!;
  }

  /// Store a string value
  ///
  /// Example:
  /// ```dart
  /// await cache.set('username', 'john_doe');
  /// ```
  Future<bool> set(String key, dynamic value) async {
    final prefs = await _prefsInstance;

    if (value is String) {
      return await prefs.setString(key, value);
    } else if (value is int) {
      return await prefs.setInt(key, value);
    } else if (value is double) {
      return await prefs.setDouble(key, value);
    } else if (value is bool) {
      return await prefs.setBool(key, value);
    } else if (value is List<String>) {
      return await prefs.setStringList(key, value);
    } else {
      // For complex objects, store as JSON string
      try {
        final jsonString = json.encode(value);
        return await prefs.setString(key, jsonString);
      } catch (e) {
        print('Error encoding value to JSON: $e');
        return false;
      }
    }
  }

  /// Get a value from cache
  /// Returns null if key doesn't exist
  ///
  /// For complex objects, use getJson() instead
  T? get<T>(String key) {
    if (_prefs == null) {
      print('PersistentCache not initialized. Call init() first.');
      return null;
    }

    final value = _prefs!.get(key);
    if (value is T) {
      return value;
    }
    return null;
  }

  /// Get a string value
  Future<String?> getString(String key) async {
    final prefs = await _prefsInstance;
    return prefs.getString(key);
  }

  /// Get an int value
  Future<int?> getInt(String key) async {
    final prefs = await _prefsInstance;
    return prefs.getInt(key);
  }

  /// Get a double value
  Future<double?> getDouble(String key) async {
    final prefs = await _prefsInstance;
    return prefs.getDouble(key);
  }

  /// Get a bool value
  Future<bool?> getBool(String key) async {
    final prefs = await _prefsInstance;
    return prefs.getBool(key);
  }

  /// Get a string list value
  Future<List<String>?> getStringList(String key) async {
    final prefs = await _prefsInstance;
    return prefs.getStringList(key);
  }

  /// Get a JSON object (stored as string)
  Future<T?> getJson<T>(String key) async {
    final prefs = await _prefsInstance;
    final jsonString = prefs.getString(key);
    if (jsonString == null) return null;

    try {
      final decoded = json.decode(jsonString);
      if (decoded is T) {
        return decoded;
      }
      return null;
    } catch (e) {
      print('Error decoding JSON from cache: $e');
      return null;
    }
  }

  /// Get a value with a default fallback
  Future<T> getOrDefault<T>(String key, T defaultValue) async {
    final prefs = await _prefsInstance;
    final value = prefs.get(key);
    if (value is T) {
      return value;
    }
    return defaultValue;
  }

  /// Check if a key exists in cache
  Future<bool> has(String key) async {
    final prefs = await _prefsInstance;
    return prefs.containsKey(key);
  }

  /// Remove a value from cache
  Future<bool> remove(String key) async {
    final prefs = await _prefsInstance;
    return await prefs.remove(key);
  }

  /// Clear all cache
  Future<bool> clear() async {
    final prefs = await _prefsInstance;
    return await prefs.clear();
  }

  /// Get all keys in cache
  Future<List<String>> get keys async {
    final prefs = await _prefsInstance;
    return prefs.getKeys().toList();
  }

  /// Set a string value
  Future<bool> setString(String key, String value) async {
    final prefs = await _prefsInstance;
    return await prefs.setString(key, value);
  }

  /// Set an int value
  Future<bool> setInt(String key, int value) async {
    final prefs = await _prefsInstance;
    return await prefs.setInt(key, value);
  }

  /// Set a double value
  Future<bool> setDouble(String key, double value) async {
    final prefs = await _prefsInstance;
    return await prefs.setDouble(key, value);
  }

  /// Set a bool value
  Future<bool> setBool(String key, bool value) async {
    final prefs = await _prefsInstance;
    return await prefs.setBool(key, value);
  }

  /// Set a string list value
  Future<bool> setStringList(String key, List<String> value) async {
    final prefs = await _prefsInstance;
    return await prefs.setStringList(key, value);
  }

  /// Set a JSON object (will be stored as string)
  Future<bool> setJson(String key, dynamic value) async {
    final prefs = await _prefsInstance;
    try {
      final jsonString = json.encode(value);
      return await prefs.setString(key, jsonString);
    } catch (e) {
      print('Error encoding JSON for cache: $e');
      return false;
    }
  }

  /// Set multiple values at once
  Future<void> setAll(Map<String, dynamic> values) async {
    for (final entry in values.entries) {
      await set(entry.key, entry.value);
    }
  }

  /// Remove multiple keys at once
  Future<void> removeAll(List<String> keys) async {
    final prefs = await _prefsInstance;
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  /// Reload the cache from disk
  /// Useful if the data might have been modified externally
  Future<void> reload() async {
    final prefs = await _prefsInstance;
    await prefs.reload();
  }
}
