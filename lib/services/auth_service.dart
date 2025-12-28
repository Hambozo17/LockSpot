import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:lockspot/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User model for the app (replaces Firebase User)
class AppUser {
  final int id;
  final String email;
  final String firstName;
  final String lastName;
  final String phone;
  final bool isVerified;

  AppUser({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.phone,
    this.isVerified = true,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['user_id'] ?? json['id'] ?? 0,
      email: json['email'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      phone: json['phone'] ?? '',
      isVerified: json['is_verified'] ?? true,
    );
  }
}

class AuthService extends ChangeNotifier {
  final ApiService _api = ApiService();
  AppUser? _currentUser;
  bool _isLoading = true;

  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal() {
    _initAuth();
  }

  AppUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _currentUser != null;

  // Stream for auth state changes (compatibility with existing code)
  final _authStateController = StreamController<AppUser?>.broadcast();
  Stream<AppUser?> get user => _authStateController.stream;

  /// Initialize auth state from stored token
  Future<void> _initAuth() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token != null) {
        _api.setAuthToken(token);
        // Fetch current user profile
        final user = await _api.getCurrentUser();
        _currentUser = AppUser(
          id: user.userId,
          email: user.email,
          firstName: user.firstName,
          lastName: user.lastName,
          phone: user.phone,
          isVerified: user.isVerified,
        );
        // Set current user ID for user-specific data
        _api.setCurrentUserId(_currentUser!.id);
        _authStateController.add(_currentUser);
      }
    } catch (e) {
      // Token expired or invalid
      await _clearStoredAuth();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Demo credentials that always work (for presentation)
  static const String demoEmail = 'demo@lockspot.com';
  static const String demoPassword = 'demo123';

  /// Sign in with email & password
  Future<AppUser> signIn(String email, String password) async {
    // Check for demo credentials - always works without backend
    if (email.toLowerCase() == demoEmail && password == demoPassword) {
      return _signInAsDemo();
    }

    try {
      final response = await _api.login(email: email, password: password);

      // Store token
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', response.accessToken);
      _api.setAuthToken(response.accessToken);

      // Create user object from response.user
      _currentUser = AppUser(
        id: response.user.userId,
        email: response.user.email,
        firstName: response.user.firstName,
        lastName: response.user.lastName,
        phone: response.user.phone,
        isVerified: response.user.isVerified,
      );

      // Set current user ID for user-specific data
      _api.setCurrentUserId(_currentUser!.id);

      _authStateController.add(_currentUser);
      notifyListeners();

      return _currentUser!;
    } catch (e) {
      rethrow;
    }
  }

  /// Sign in as demo user (works offline)
  Future<AppUser> _signInAsDemo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', 'demo_token');
    await prefs.setBool('is_demo_mode', true);

    _currentUser = AppUser(
      id: 999,
      email: demoEmail,
      firstName: 'Demo',
      lastName: 'User',
      phone: '+966500000000',
      isVerified: true,
    );

    // Set current user ID for user-specific data
    _api.setCurrentUserId(_currentUser!.id);

    _authStateController.add(_currentUser);
    notifyListeners();

    return _currentUser!;
  }

  /// Check if in demo mode
  Future<bool> isDemoMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_demo_mode') ?? false;
  }

  /// Register with email & password
  Future<void> signUp(
    String firstName,
    String lastName,
    String phone,
    String email,
    String password,
  ) async {
    try {
      await _api.register(
        firstName: firstName,
        lastName: lastName,
        email: email,
        phone: phone,
        password: password,
      );
      // Registration successful - user needs to login
    } catch (e) {
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _clearStoredAuth();
    _api.clearUserData(); // Clear user-specific data
    _currentUser = null;
    _authStateController.add(null);
    notifyListeners();
  }

  /// Clear stored authentication data
  Future<void> _clearStoredAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    _api.clearAuthToken();
  }

  /// Send password reset email (placeholder - needs backend endpoint)
  Future<void> sendPasswordResetEmail(String email) async {
    // TODO: Implement password reset endpoint in backend
    throw UnimplementedError('Password reset not yet implemented');
  }

  @override
  void dispose() {
    _authStateController.close();
    super.dispose();
  }
}
