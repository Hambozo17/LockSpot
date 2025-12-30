import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lockspot/services/api_service.dart';

/// Simple cache service for persisting data across app restarts
/// Data is stored per-user to prevent conflicts
class CacheService {
  // Singleton pattern
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  SharedPreferences? _prefs;
  int? _currentUserId;

  Future<void> _ensureInitialized() async {
    _prefs ??= await SharedPreferences.getInstance();
    
    // If user ID not set yet, try to load it from stored data
    if (_currentUserId == null) {
      _currentUserId = _prefs!.getInt('cached_user_id');
      if (_currentUserId != null) {
        print('🔄 Loaded user ID from cache: $_currentUserId');
      }
    }
  }

  /// Set current user ID for scoped caching
  Future<void> setUserId(int userId) async {
    await _ensureInitialized();
    _currentUserId = userId;
    // Also store it for next app startup
    final success = await _prefs!.setInt('cached_user_id', userId);
    print('💾 Cache user ID set to: $userId (saved: $success)');
  }

  /// Get user-specific cache key
  String _getUserKey(String baseKey) {
    if (_currentUserId == null) {
      print('⚠️ Warning: User ID not set, using base key');
      return baseKey;
    }
    return '${baseKey}_user_$_currentUserId';
  }

  /// Save active bookings to cache
  Future<void> saveActiveBookings(List<Booking> bookings) async {
    await _ensureInitialized();
    final jsonList = bookings.map((b) => b.toJson()).toList();
    final key = _getUserKey('cache_active_bookings');
    final jsonString = jsonEncode(jsonList);
    final success = await _prefs!.setString(key, jsonString);
    print('✅ Saved ${bookings.length} active bookings to cache (key: $key, success: $success, size: ${jsonString.length} bytes)');
  }

  /// Get active bookings from cache
  Future<List<Booking>?> getActiveBookings() async {
    await _ensureInitialized();
    final key = _getUserKey('cache_active_bookings');
    print('🔍 Looking for cached bookings with key: $key');
    final jsonString = _prefs!.getString(key);
    if (jsonString == null) {
      print('ℹ️ No cached active bookings found (key: $key)');
      return null;
    }
    
    try {
      final jsonList = jsonDecode(jsonString) as List;
      final bookings = jsonList.map((json) => Booking.fromJson(json)).toList();
      print('✅ Loaded ${bookings.length} active bookings from cache (key: $key)');
      return bookings;
    } catch (e) {
      print('❌ Failed to load cached bookings: $e');
      return null;
    }
  }

  /// Save completed bookings to cache
  Future<void> saveCompletedBookings(List<Booking> bookings) async {
    await _ensureInitialized();
    final jsonList = bookings.map((b) => b.toJson()).toList();
    final key = _getUserKey('cache_completed_bookings');
    final success = await _prefs!.setString(key, jsonEncode(jsonList));
    print('✅ Saved ${bookings.length} completed bookings to cache (success: $success)');
  }

  /// Get completed bookings from cache
  Future<List<Booking>?> getCompletedBookings() async {
    await _ensureInitialized();
    final key = _getUserKey('cache_completed_bookings');
    final jsonString = _prefs!.getString(key);
    if (jsonString == null) return null;
    
    try {
      final jsonList = jsonDecode(jsonString) as List;
      return jsonList.map((json) => Booking.fromJson(json)).toList();
    } catch (e) {
      return null;
    }
  }

  /// Save locations to cache
  Future<void> saveLocations(List<LockerLocation> locations) async {
    await _ensureInitialized();
    final jsonList = locations.map((l) => l.toJson()).toList();
    await _prefs!.setString('cache_locations', jsonEncode(jsonList));
  }

  /// Get locations from cache
  Future<List<LockerLocation>?> getLocations() async {
    await _ensureInitialized();
    final jsonString = _prefs!.getString('cache_locations');
    if (jsonString == null) return null;
    
    try {
      final jsonList = jsonDecode(jsonString) as List;
      return jsonList.map((json) => LockerLocation.fromJson(json)).toList();
    } catch (e) {
      return null;
    }
  }

  /// Clear all cached data for current user
  Future<void> clearAll() async {
    await _ensureInitialized();
    final activeKey = _getUserKey('cache_active_bookings');
    final completedKey = _getUserKey('cache_completed_bookings');
    await _prefs!.remove(activeKey);
    await _prefs!.remove(completedKey);
    await _prefs!.remove('cache_locations');
    print('🗑️ Cleared all cached data for user $_currentUserId');
  }

  /// Clear user-specific data (on logout)
  Future<void> clearUserData() async {
    await clearAll();
    await _prefs!.remove('cached_user_id');
    _currentUserId = null;
    print('👋 Cleared user cache and logged out');
  }

  /// Debug: List all cache keys
  Future<void> debugListAllKeys() async {
    await _ensureInitialized();
    final allKeys = _prefs!.getKeys();
    print('📋 ALL CACHE KEYS:');
    for (final key in allKeys) {
      if (key.startsWith('cache_')) {
        final value = _prefs!.get(key);
        if (value is String && value.length > 100) {
          print('  $key: <${value.length} bytes>');
        } else {
          print('  $key: $value');
        }
      }
    }
  }
}
