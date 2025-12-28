import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// API Service for connecting to the LockSpot Backend
/// Replaces Firebase with REST API calls
class ApiService {
  // Ngrok URL for development - update this when ngrok restarts
  static const String baseUrl = 'https://hydrogenous-mittie-loopily.ngrok-free.dev/api';
  // Local development: 'http://localhost:8000/api'
  // Production: 'https://your-production-server.com/api'

  String? _authToken;
  bool _isDemoMode = false;
  int? _currentUserId;

  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  /// Set current user ID for user-specific data
  void setCurrentUserId(int userId) {
    _currentUserId = userId;
  }

  /// Get current user ID
  int? get currentUserId => _currentUserId;

  /// ALWAYS use demo mode for now (backend not fully configured)
  /// This ensures all users (demo or signup) can test the full flow
  bool get isDemoMode => true; // Force demo mode for all users

  /// Check if in demo mode (async, from storage)
  Future<bool> checkDemoMode() async {
    return true; // Always demo mode
  }

  /// Set demo mode
  void setDemoMode(bool value) {
    _isDemoMode = value;
  }

  /// Set the auth token after login
  void setAuthToken(String token) {
    _authToken = token;
    if (token == 'demo_token') {
      _isDemoMode = true;
    }
  }

  /// Clear auth token on logout
  void clearAuthToken() {
    _authToken = null;
    _currentUserId = null;
  }

  /// Clear all user-specific data on logout
  void clearUserData() {
    _authToken = null;
    _currentUserId = null;
    // Don't clear bookings - they're stored per user ID
  }

  /// Get headers with optional auth
  Map<String, String> _getHeaders({bool requireAuth = true}) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      // Required for ngrok free tier to skip browser warning
      'ngrok-skip-browser-warning': 'true',
    };
    if (requireAuth && _authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  /// Ensure endpoint has trailing slash for Django
  String _normalizeEndpoint(String endpoint) {
    if (!endpoint.endsWith('/') && !endpoint.contains('?')) {
      return '$endpoint/';
    }
    return endpoint;
  }

  /// Generic HTTP request handler
  Future<Map<String, dynamic>> _request(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
    bool requireAuth = true,
  }) async {
    // Normalize endpoint with trailing slash
    endpoint = _normalizeEndpoint(endpoint);
    Uri uri = Uri.parse('$baseUrl$endpoint');
    if (queryParams != null) {
      uri = uri.replace(queryParameters: queryParams);
    }

    http.Response response;
    final headers = _getHeaders(requireAuth: requireAuth);

    switch (method) {
      case 'GET':
        response = await http.get(uri, headers: headers);
        break;
      case 'POST':
        response = await http.post(
          uri,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
        break;
      case 'PUT':
        response = await http.put(
          uri,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
        break;
      case 'DELETE':
        response = await http.delete(uri, headers: headers);
        break;
      default:
        throw Exception('Unsupported HTTP method: $method');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      // Handle both List and Map responses from DRF
      if (decoded is List) {
        return {'results': decoded};
      }
      return decoded;
    } else {
      final error = jsonDecode(response.body);
      throw ApiException(
        statusCode: response.statusCode,
        message: error['detail'] ?? error['error'] ?? 'An error occurred',
      );
    }
  }

  // ==================== AUTH ====================

  /// Register a new user
  Future<AuthResponse> register({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
  }) async {
    final response = await _request(
      'POST',
      '/auth/register',
      body: {
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'phone': phone,
        'password': password,
      },
      requireAuth: false,
    );
    final authResponse = AuthResponse.fromJson(response);
    setAuthToken(authResponse.accessToken);
    return authResponse;
  }

  /// Login with email and password
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final response = await _request(
      'POST',
      '/auth/login',
      body: {
        'email': email,
        'password': password,
      },
      requireAuth: false,
    );
    final authResponse = AuthResponse.fromJson(response);
    setAuthToken(authResponse.accessToken);
    return authResponse;
  }

  /// Get current user profile
  Future<User> getCurrentUser() async {
    if (isDemoMode) {
      return User(
        userId: 999,
        firstName: 'Demo',
        lastName: 'User',
        email: 'demo@lockspot.com',
        phone: '+966500000000',
        userType: 'customer',
        isVerified: true,
      );
    }

    final response = await _request('GET', '/auth/me');
    return User.fromJson(response);
  }

  // ==================== LOCATIONS ====================

  /// Get all locker locations
  Future<List<LockerLocation>> getLocations({String? city}) async {
    // Return mock data in demo mode
    if (isDemoMode) {
      return _getMockLocations();
    }

    final queryParams = <String, String>{};
    if (city != null) queryParams['city'] = city;

    final response = await _request(
      'GET',
      '/locations',
      queryParams: queryParams,
      requireAuth: false,
    );
    return (response['results'] as List)
        .map((l) => LockerLocation.fromJson(l))
        .toList();
  }

  /// Helper to calculate available lockers at a location
  int _getAvailableLockersCount(int locationId) {
    final allLockers = _getMockLockers(locationId: locationId);
    final availableLockers = allLockers.where((l) => !_bookedLockerIds.contains(l.lockerId)).toList();
    return availableLockers.length;
  }
  
  /// Mock locations for demo mode - Real Egypt locations
  List<LockerLocation> _getMockLocations() {
    return [
      Location(
        locationId: 1,
        name: 'Sheikh Zayed Mall',
        description: 'Premium smart lockers at Arkan Plaza, Sheikh Zayed City',
        availableLockers: _getAvailableLockersCount(1),
        totalLockers: 20,
        operatingHoursStart: '09:00',
        operatingHoursEnd: '23:00',
        averageRating: 4.8,
        address: LocationAddress(
          addressId: 1,
          streetAddress: 'Arkan Plaza, 26th of July Corridor',
          city: 'Sheikh Zayed',
          country: 'Egypt',
          latitude: 30.0131,
          longitude: 30.9718,
        ),
      ),
      Location(
        locationId: 2,
        name: 'Cairo Festival City',
        description: '24/7 locker access at CFC Mall, New Cairo',
        availableLockers: _getAvailableLockersCount(2),
        totalLockers: 50,
        operatingHoursStart: '00:00',
        operatingHoursEnd: '23:59',
        averageRating: 4.5,
        address: LocationAddress(
          addressId: 2,
          streetAddress: 'Ring Road, New Cairo',
          city: 'New Cairo',
          country: 'Egypt',
          latitude: 30.0284,
          longitude: 31.4082,
        ),
      ),
      Location(
        locationId: 3,
        name: 'Alexandria Bibliotheca',
        description: 'Secure lockers near the famous Library of Alexandria',
        availableLockers: _getAvailableLockersCount(3),
        totalLockers: 15,
        operatingHoursStart: '08:00',
        operatingHoursEnd: '20:00',
        averageRating: 4.7,
        address: LocationAddress(
          addressId: 3,
          streetAddress: 'Al Corniche Road, Shatby',
          city: 'Alexandria',
          country: 'Egypt',
          latitude: 31.2089,
          longitude: 29.9092,
        ),
      ),
      Location(
        locationId: 4,
        name: 'Citystars Heliopolis',
        description: 'Large locker station at Citystars Shopping Center',
        availableLockers: _getAvailableLockersCount(4),
        totalLockers: 60,
        operatingHoursStart: '10:00',
        operatingHoursEnd: '22:00',
        averageRating: 4.3,
        address: LocationAddress(
          addressId: 4,
          streetAddress: 'Omar Ibn El Khattab Street, Heliopolis',
          city: 'Cairo',
          country: 'Egypt',
          latitude: 30.0724,
          longitude: 31.3456,
        ),
      ),
      Location(
        locationId: 5,
        name: 'Mall of Egypt',
        description: 'Premium lockers at Mall of Egypt, 6th October',
        availableLockers: _getAvailableLockersCount(5),
        totalLockers: 25,
        operatingHoursStart: '10:00',
        operatingHoursEnd: '23:00',
        averageRating: 4.6,
        address: LocationAddress(
          addressId: 5,
          streetAddress: '26th of July Corridor, 6th October City',
          city: '6th October',
          country: 'Egypt',
          latitude: 29.9726,
          longitude: 30.9433,
        ),
      ),
      Location(
        locationId: 6,
        name: 'Maadi Grand Mall',
        description: 'Convenient lockers in Maadi district',
        availableLockers: _getAvailableLockersCount(6),
        totalLockers: 30,
        operatingHoursStart: '09:00',
        operatingHoursEnd: '22:00',
        averageRating: 4.2,
        address: LocationAddress(
          addressId: 6,
          streetAddress: 'Corniche El Nile, Maadi',
          city: 'Maadi',
          country: 'Egypt',
          latitude: 29.9602,
          longitude: 31.2569,
        ),
      ),
    ];
  }

  /// Get location by ID
  Future<LockerLocation> getLocationById(int locationId) async {
    if (isDemoMode) {
      return _getMockLocations().firstWhere((l) => l.locationId == locationId);
    }

    final response = await _request(
      'GET',
      '/locations/$locationId',
      requireAuth: false,
    );
    return LockerLocation.fromJson(response);
  }

  /// Get pricing for a location
  Future<List<PricingTier>> getLocationPricing(int locationId) async {
    if (isDemoMode) {
      return [
        PricingTier(tierId: 1, name: 'Small Locker', size: 'Small', basePrice: 10.0, hourlyRate: 5.0, dailyRate: 30.0),
        PricingTier(tierId: 2, name: 'Medium Locker', size: 'Medium', basePrice: 15.0, hourlyRate: 8.0, dailyRate: 50.0),
        PricingTier(tierId: 3, name: 'Large Locker', size: 'Large', basePrice: 20.0, hourlyRate: 12.0, dailyRate: 75.0),
      ];
    }

    final response = await _request(
      'GET',
      '/locations/$locationId/pricing',
      requireAuth: false,
    );
    return (response['results'] as List)
        .map((p) => PricingTier.fromJson(p))
        .toList();
  }

  // ==================== LOCKERS ====================

  /// Track booked locker IDs in demo mode
  static final Set<int> _bookedLockerIds = {};

  /// Get available lockers with filters
  Future<List<Locker>> getAvailableLockers({
    int? locationId,
    String? size,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    if (isDemoMode) {
      var lockers = _getMockLockers(locationId: locationId);
      
      // Filter by size if specified
      if (size != null) {
        lockers = lockers.where((l) => l.size.toLowerCase() == size.toLowerCase()).toList();
      }
      
      // Exclude already booked lockers
      lockers = lockers.where((l) => !_bookedLockerIds.contains(l.lockerId)).toList();
      
      return lockers;
    }

    final queryParams = <String, String>{};
    if (locationId != null) queryParams['location_id'] = locationId.toString();
    if (size != null) queryParams['size'] = size;
    if (startTime != null) queryParams['start_time'] = startTime.toIso8601String();
    if (endTime != null) queryParams['end_time'] = endTime.toIso8601String();

    try {
      final response = await _request(
        'GET',
        '/lockers/available',
        queryParams: queryParams,
        requireAuth: false,
      );
      return (response['results'] as List).map((l) => Locker.fromJson(l)).toList();
    } catch (e) {
      // Return mock data on error for demo purposes
      return _getMockLockers(locationId: locationId);
    }
  }

  /// Mock lockers for demo mode - different counts per location
  List<Locker> _getMockLockers({int? locationId}) {
    final Map<int, List<Locker>> lockersByLocation = {
      1: [ // Sheikh Zayed - 12 available
        Locker(lockerId: 101, locationId: 1, locationName: 'Sheikh Zayed Mall', unitNumber: 'SZ-01', size: 'Small', status: 'available', hourlyRate: 10.0, dailyRate: 60.0),
        Locker(lockerId: 102, locationId: 1, locationName: 'Sheikh Zayed Mall', unitNumber: 'SZ-02', size: 'Small', status: 'available', hourlyRate: 10.0, dailyRate: 60.0),
        Locker(lockerId: 103, locationId: 1, locationName: 'Sheikh Zayed Mall', unitNumber: 'SZ-03', size: 'Medium', status: 'available', hourlyRate: 15.0, dailyRate: 90.0),
        Locker(lockerId: 104, locationId: 1, locationName: 'Sheikh Zayed Mall', unitNumber: 'SZ-04', size: 'Medium', status: 'available', hourlyRate: 15.0, dailyRate: 90.0),
        Locker(lockerId: 105, locationId: 1, locationName: 'Sheikh Zayed Mall', unitNumber: 'SZ-05', size: 'Large', status: 'available', hourlyRate: 25.0, dailyRate: 150.0),
      ],
      2: [ // Cairo Festival City - 35 available
        Locker(lockerId: 201, locationId: 2, locationName: 'Cairo Festival City', unitNumber: 'CFC-01', size: 'Small', status: 'available', hourlyRate: 12.0, dailyRate: 70.0),
        Locker(lockerId: 202, locationId: 2, locationName: 'Cairo Festival City', unitNumber: 'CFC-02', size: 'Small', status: 'available', hourlyRate: 12.0, dailyRate: 70.0),
        Locker(lockerId: 203, locationId: 2, locationName: 'Cairo Festival City', unitNumber: 'CFC-03', size: 'Small', status: 'available', hourlyRate: 12.0, dailyRate: 70.0),
        Locker(lockerId: 204, locationId: 2, locationName: 'Cairo Festival City', unitNumber: 'CFC-04', size: 'Medium', status: 'available', hourlyRate: 18.0, dailyRate: 100.0),
        Locker(lockerId: 205, locationId: 2, locationName: 'Cairo Festival City', unitNumber: 'CFC-05', size: 'Medium', status: 'available', hourlyRate: 18.0, dailyRate: 100.0),
        Locker(lockerId: 206, locationId: 2, locationName: 'Cairo Festival City', unitNumber: 'CFC-06', size: 'Large', status: 'available', hourlyRate: 28.0, dailyRate: 160.0),
        Locker(lockerId: 207, locationId: 2, locationName: 'Cairo Festival City', unitNumber: 'CFC-07', size: 'Large', status: 'available', hourlyRate: 28.0, dailyRate: 160.0),
      ],
      3: [ // Alexandria - 8 available
        Locker(lockerId: 301, locationId: 3, locationName: 'Alexandria Bibliotheca', unitNumber: 'ALX-01', size: 'Small', status: 'available', hourlyRate: 8.0, dailyRate: 50.0),
        Locker(lockerId: 302, locationId: 3, locationName: 'Alexandria Bibliotheca', unitNumber: 'ALX-02', size: 'Medium', status: 'available', hourlyRate: 12.0, dailyRate: 75.0),
        Locker(lockerId: 303, locationId: 3, locationName: 'Alexandria Bibliotheca', unitNumber: 'ALX-03', size: 'Large', status: 'available', hourlyRate: 20.0, dailyRate: 120.0),
      ],
      4: [ // Citystars - 42 available
        Locker(lockerId: 401, locationId: 4, locationName: 'Citystars Heliopolis', unitNumber: 'CS-01', size: 'Small', status: 'available', hourlyRate: 10.0, dailyRate: 60.0),
        Locker(lockerId: 402, locationId: 4, locationName: 'Citystars Heliopolis', unitNumber: 'CS-02', size: 'Small', status: 'available', hourlyRate: 10.0, dailyRate: 60.0),
        Locker(lockerId: 403, locationId: 4, locationName: 'Citystars Heliopolis', unitNumber: 'CS-03', size: 'Small', status: 'available', hourlyRate: 10.0, dailyRate: 60.0),
        Locker(lockerId: 404, locationId: 4, locationName: 'Citystars Heliopolis', unitNumber: 'CS-04', size: 'Medium', status: 'available', hourlyRate: 15.0, dailyRate: 90.0),
        Locker(lockerId: 405, locationId: 4, locationName: 'Citystars Heliopolis', unitNumber: 'CS-05', size: 'Medium', status: 'available', hourlyRate: 15.0, dailyRate: 90.0),
        Locker(lockerId: 406, locationId: 4, locationName: 'Citystars Heliopolis', unitNumber: 'CS-06', size: 'Medium', status: 'available', hourlyRate: 15.0, dailyRate: 90.0),
        Locker(lockerId: 407, locationId: 4, locationName: 'Citystars Heliopolis', unitNumber: 'CS-07', size: 'Large', status: 'available', hourlyRate: 22.0, dailyRate: 130.0),
        Locker(lockerId: 408, locationId: 4, locationName: 'Citystars Heliopolis', unitNumber: 'CS-08', size: 'Large', status: 'available', hourlyRate: 22.0, dailyRate: 130.0),
      ],
      5: [ // Mall of Egypt - 5 available (limited!)
        Locker(lockerId: 501, locationId: 5, locationName: 'Mall of Egypt', unitNumber: 'MOE-01', size: 'Small', status: 'available', hourlyRate: 15.0, dailyRate: 90.0),
        Locker(lockerId: 502, locationId: 5, locationName: 'Mall of Egypt', unitNumber: 'MOE-02', size: 'Medium', status: 'available', hourlyRate: 22.0, dailyRate: 130.0),
      ],
      6: [ // Maadi - 18 available
        Locker(lockerId: 601, locationId: 6, locationName: 'Maadi Grand Mall', unitNumber: 'MAA-01', size: 'Small', status: 'available', hourlyRate: 8.0, dailyRate: 50.0),
        Locker(lockerId: 602, locationId: 6, locationName: 'Maadi Grand Mall', unitNumber: 'MAA-02', size: 'Small', status: 'available', hourlyRate: 8.0, dailyRate: 50.0),
        Locker(lockerId: 603, locationId: 6, locationName: 'Maadi Grand Mall', unitNumber: 'MAA-03', size: 'Medium', status: 'available', hourlyRate: 12.0, dailyRate: 75.0),
        Locker(lockerId: 604, locationId: 6, locationName: 'Maadi Grand Mall', unitNumber: 'MAA-04', size: 'Medium', status: 'available', hourlyRate: 12.0, dailyRate: 75.0),
        Locker(lockerId: 605, locationId: 6, locationName: 'Maadi Grand Mall', unitNumber: 'MAA-05', size: 'Large', status: 'available', hourlyRate: 18.0, dailyRate: 110.0),
      ],
    };
    
    if (locationId != null) {
      return lockersByLocation[locationId] ?? [];
    }
    
    // Return all lockers
    return lockersByLocation.values.expand((list) => list).toList();
  }

  /// Check locker availability for time slot
  Future<Map<String, dynamic>> checkLockerAvailability(
    int lockerId,
    DateTime startTime,
    DateTime endTime,
  ) async {
    if (isDemoMode) {
      return {'available': true, 'message': 'Locker is available'};
    }

    return await _request(
      'GET',
      '/lockers/$lockerId/availability',
      queryParams: {
        'start_time': startTime.toIso8601String(),
        'end_time': endTime.toIso8601String(),
      },
      requireAuth: false,
    );
  }

  // ==================== BOOKINGS ====================

  /// Create a new booking
  Future<Booking> createBooking({
    required int lockerId,
    required DateTime startTime,
    required DateTime endTime,
    String bookingType = 'Storage',
    String? discountCode,
    String? locationName,
    String? unitNumber,
    String? size,
    double? totalAmount,
  }) async {
    if (isDemoMode) {
      // Find the locker details
      final allLockers = _getMockLockers();
      final locker = allLockers.firstWhere(
        (l) => l.lockerId == lockerId,
        orElse: () => allLockers.first,
      );
      
      final userId = _currentUserId ?? 0;
      final duration = endTime.difference(startTime).inHours;
      final calcTotal = totalAmount ?? (locker.hourlyRate * duration);
      
      final booking = Booking(
        bookingId: DateTime.now().millisecondsSinceEpoch,
        userId: userId,
        lockerId: lockerId,
        locationName: locationName ?? locker.locationName ?? 'Demo Location',
        unitNumber: unitNumber ?? locker.unitNumber,
        size: size ?? locker.size,
        startTime: startTime,
        endTime: endTime,
        bookingType: bookingType,
        subtotalAmount: calcTotal,
        discountAmount: 0.0,
        totalAmount: calcTotal,
        status: 'Active',
        qrCode: 'LOCKSPOT-${DateTime.now().millisecondsSinceEpoch}',
        paymentStatus: 'paid',
      );
      
      // Store in user-specific bookings list
      if (_userBookings[userId] == null) {
        _userBookings[userId] = [];
      }
      _userBookings[userId]!.add(booking);
      
      // Mark locker as booked
      _bookedLockerIds.add(lockerId);
      
      return booking;
    }

    final response = await _request(
      'POST',
      '/bookings',
      body: {
        'locker_id': lockerId,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime.toIso8601String(),
        'booking_type': bookingType,
        'discount_code': discountCode,
      },
    );
    return Booking.fromJson(response);
  }

  /// Get user's bookings
  Future<List<Booking>> getUserBookings({String? status}) async {
    if (isDemoMode) {
      final bookings = _getMockBookings();
      if (status != null) {
        return bookings.where((b) => b.status.toLowerCase() == status.toLowerCase()).toList();
      }
      return bookings;
    }

    // Return empty list if not authenticated to avoid 403
    if (_authToken == null) {
      return [];
    }

    final queryParams = <String, String>{};
    if (status != null) queryParams['status'] = status;

    try {
      final response = await _request(
        'GET',
        '/bookings',
        queryParams: queryParams,
      );
      return (response['results'] as List)
          .map((b) => Booking.fromJson(b))
          .toList();
    } catch (e) {
      // Return empty list on error (like 403) instead of throwing
      return [];
    }
  }

  /// Mock bookings for demo mode - stored per user ID
  static final Map<int, List<Booking>> _userBookings = {};

  List<Booking> _getMockBookings() {
    final userId = _currentUserId ?? 0;
    
    // Get bookings for current user only
    final userBookings = _userBookings[userId] ?? [];
    
    // Return only current user's bookings (no sample data mixed in)
    return userBookings;
  }

  /// Alias for getUserBookings (for backwards compatibility)
  Future<List<Booking>> getMyBookings({String? status}) => getUserBookings(status: status);

  /// Get booking by ID
  Future<Booking> getBookingById(int bookingId) async {
    if (isDemoMode) {
      return _getMockBookings().firstWhere(
        (b) => b.bookingId == bookingId,
        orElse: () => _getMockBookings().first,
      );
    }

    final response = await _request('GET', '/bookings/$bookingId');
    return Booking.fromJson(response);
  }

  /// Generate QR code for booking
  Future<QRCode> generateBookingQR(int bookingId) async {
    if (isDemoMode) {
      return QRCode(
        qrId: 1,
        bookingId: bookingId,
        code: 'DEMO-UNLOCK-$bookingId',
        codeType: 'unlock',
        expiresAt: DateTime.now().add(const Duration(hours: 6)),
      );
    }

    final response = await _request('GET', '/bookings/$bookingId/qr');
    return QRCode.fromJson(response);
  }

  /// Cancel a booking
  Future<Map<String, dynamic>> cancelBooking(int bookingId, {String? reason}) async {
    if (isDemoMode) {
      return {'success': true, 'message': 'Booking cancelled successfully'};
    }

    return await _request(
      'POST',
      '/bookings/$bookingId/cancel',
      body: reason != null ? {'reason': reason} : null,
    );
  }

  // ==================== PAYMENTS ====================

  /// Process payment for a booking
  Future<Payment> processPayment({
    required int bookingId,
    String methodType = 'Visa',
    String? cardLastFour,
  }) async {
    if (isDemoMode) {
      // Return a successful mock payment
      return Payment(
        paymentId: DateTime.now().millisecondsSinceEpoch,
        bookingId: bookingId,
        amount: 0.0, // Amount is on the booking
        status: 'Success',
        paymentDate: DateTime.now(),
        transactionReference: 'TXN-${DateTime.now().millisecondsSinceEpoch}',
      );
    }
    
    final response = await _request(
      'POST',
      '/payments',
      body: {
        'booking_id': bookingId,
        'method_type': methodType,
        'card_last_four': cardLastFour,
      },
    );
    return Payment.fromJson(response);
  }

  /// Get payment by booking ID
  Future<Payment> getPaymentByBooking(int bookingId) async {
    final response = await _request('GET', '/payments/booking/$bookingId');
    return Payment.fromJson(response);
  }

  // ==================== REVIEWS ====================

  /// Submit a review
  Future<Review> submitReview({
    required int bookingId,
    required int rating,
    String? title,
    String? comment,
  }) async {
    final response = await _request(
      'POST',
      '/reviews',
      body: {
        'booking_id': bookingId,
        'rating': rating,
        'title': title,
        'comment': comment,
      },
    );
    return Review.fromJson(response);
  }

  /// Get reviews for a location
  Future<ReviewList> getLocationReviews(int locationId, {int limit = 20}) async {
    final response = await _request(
      'GET',
      '/reviews/location/$locationId',
      queryParams: {'limit': limit.toString()},
      requireAuth: false,
    );
    return ReviewList.fromJson(response);
  }

  // ==================== DISCOUNTS ====================

  /// Validate a discount code
  Future<Discount> validateDiscount(String code, double bookingAmount) async {
    final response = await _request(
      'POST',
      '/discounts/validate',
      body: {
        'code': code,
        'booking_amount': bookingAmount,
      },
      requireAuth: false,
    );
    return Discount.fromJson(response);
  }
}

// ==================== MODELS ====================

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException({required this.statusCode, required this.message});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class AuthResponse {
  final String accessToken;
  final String tokenType;
  final int expiresIn;
  final User user;

  AuthResponse({
    required this.accessToken,
    required this.tokenType,
    required this.expiresIn,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['access_token'],
      tokenType: json['token_type'],
      expiresIn: json['expires_in'],
      user: User.fromJson(json['user']),
    );
  }
}

class User {
  final int userId;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String userType;
  final bool isVerified;

  User({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.userType,
    required this.isVerified,
  });

  String get fullName => '$firstName $lastName';

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['user_id'] ?? json['id'] ?? 0,
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      userType: json['user_type'] ?? 'customer',
      isVerified: json['is_verified'] ?? false,
    );
  }
}

class Location {
  final int locationId;
  final String name;
  final String? description;
  final String? imageUrl;
  final String? operatingHoursStart;
  final String? operatingHoursEnd;
  final bool isActive;
  final LocationAddress? address;
  final int availableLockers;
  final int totalLockers;
  final double averageRating;

  Location({
    required this.locationId,
    required this.name,
    this.description,
    this.imageUrl,
    this.operatingHoursStart,
    this.operatingHoursEnd,
    this.isActive = true,
    this.address,
    this.availableLockers = 0,
    this.totalLockers = 0,
    this.averageRating = 0,
  });

  // Convenience getters for backward compatibility
  int get availableLockersCount => availableLockers;
  String get city => address?.city ?? 'Unknown';

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      locationId: json['location_id'] ?? json['id'] ?? 0,
      name: json['name'] ?? 'Unknown Location',
      description: json['description'],
      imageUrl: json['image_url'] ?? json['image'],
      operatingHoursStart: json['operating_hours_start']?.toString(),
      operatingHoursEnd: json['operating_hours_end']?.toString(),
      isActive: json['is_active'] ?? true,
      address: json['address'] != null
          ? LocationAddress.fromJson(json['address'])
          : null,
      availableLockers: json['available_lockers'] ?? 0,
      totalLockers: json['total_lockers'] ?? 0,
      averageRating: (json['average_rating'] ?? 0).toDouble(),
    );
  }
}

// Type alias for backward compatibility
typedef LockerLocation = Location;

class LocationAddress {
  final int addressId;
  final String streetAddress;
  final String city;
  final String? state;
  final String? zipCode;
  final String country;
  final double? latitude;
  final double? longitude;

  LocationAddress({
    required this.addressId,
    required this.streetAddress,
    required this.city,
    this.state,
    this.zipCode,
    this.country = 'Egypt',
    this.latitude,
    this.longitude,
  });

  factory LocationAddress.fromJson(Map<String, dynamic> json) {
    // Handle latitude/longitude which can be string or number from Django
    double? parseLat = json['latitude'] != null 
        ? (json['latitude'] is String ? double.tryParse(json['latitude']) : json['latitude']?.toDouble())
        : null;
    double? parseLng = json['longitude'] != null 
        ? (json['longitude'] is String ? double.tryParse(json['longitude']) : json['longitude']?.toDouble())
        : null;
    
    return LocationAddress(
      addressId: json['address_id'] ?? json['id'] ?? 0,
      streetAddress: json['street_address'] ?? '',
      city: json['city'] ?? 'Unknown',
      state: json['state'],
      zipCode: json['zip_code'],
      country: json['country'] ?? 'Saudi Arabia',
      latitude: parseLat,
      longitude: parseLng,
    );
  }
}

class PricingTier {
  final int tierId;
  final String name;
  final String size;
  final double basePrice;
  final double hourlyRate;
  final double dailyRate;
  final double? weeklyRate;
  final String? description;
  final int availableCount;

  PricingTier({
    required this.tierId,
    required this.name,
    required this.size,
    required this.basePrice,
    required this.hourlyRate,
    required this.dailyRate,
    this.weeklyRate,
    this.description,
    this.availableCount = 0,
  });

  factory PricingTier.fromJson(Map<String, dynamic> json) {
    return PricingTier(
      tierId: json['tier_id'] ?? json['id'] ?? 0,
      name: json['name'] ?? 'Standard',
      size: json['size'] ?? 'Medium',
      basePrice: (json['base_price'] ?? 0).toDouble(),
      hourlyRate: (json['hourly_rate'] ?? 0).toDouble(),
      dailyRate: (json['daily_rate'] ?? 0).toDouble(),
      weeklyRate: json['weekly_rate']?.toDouble(),
      description: json['description'],
      availableCount: json['available_count'] ?? 0,
    );
  }
}

class Locker {
  final int lockerId;
  final int locationId;
  final String? locationName;
  final String unitNumber;
  final String size;
  final String status;
  final double hourlyRate;
  final double dailyRate;

  Locker({
    required this.lockerId,
    required this.locationId,
    this.locationName,
    required this.unitNumber,
    required this.size,
    required this.status,
    required this.hourlyRate,
    required this.dailyRate,
  });

  factory Locker.fromJson(Map<String, dynamic> json) {
    return Locker(
      lockerId: json['locker_id'] ?? json['id'] ?? 0,
      locationId: json['location_id'] ?? json['location'] ?? 0,
      locationName: json['location_name'],
      unitNumber: json['unit_number'] ?? '',
      size: json['size'] ?? 'Medium',
      status: json['status'] ?? 'Available',
      hourlyRate: (json['hourly_rate'] ?? 0).toDouble(),
      dailyRate: (json['daily_rate'] ?? 0).toDouble(),
    );
  }
}

// Type alias for backward compatibility
typedef LockerUnit = Locker;

class Booking {
  final int bookingId;
  final int userId;
  final int lockerId;
  final String? locationName;
  final String? unitNumber;
  final String? size;
  final DateTime startTime;
  final DateTime endTime;
  final String bookingType;
  final double subtotalAmount;
  final double discountAmount;
  final double totalAmount;
  final String status;
  final DateTime? createdAt;
  final String? qrCode;
  final String? paymentStatus;

  Booking({
    required this.bookingId,
    required this.userId,
    required this.lockerId,
    this.locationName,
    this.unitNumber,
    this.size,
    required this.startTime,
    required this.endTime,
    required this.bookingType,
    required this.subtotalAmount,
    required this.discountAmount,
    required this.totalAmount,
    required this.status,
    this.createdAt,
    this.qrCode,
    this.paymentStatus,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      bookingId: json['booking_id'] ?? json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      lockerId: json['locker_id'] ?? json['locker'] ?? 0,
      locationName: json['location_name'],
      unitNumber: json['unit_number'],
      size: json['size'],
      startTime: json['start_time'] != null 
          ? DateTime.parse(json['start_time']) 
          : DateTime.now(),
      endTime: json['end_time'] != null 
          ? DateTime.parse(json['end_time']) 
          : DateTime.now().add(const Duration(hours: 1)),
      bookingType: json['booking_type'] ?? 'Storage',
      subtotalAmount: (json['subtotal_amount'] ?? 0).toDouble(),
      discountAmount: (json['discount_amount'] ?? 0).toDouble(),
      totalAmount: (json['total_amount'] ?? 0).toDouble(),
      status: json['status'] ?? 'Pending',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      qrCode: json['qr_code'],
      paymentStatus: json['payment_status'],
    );
  }
}

class Payment {
  final int paymentId;
  final int bookingId;
  final double amount;
  final String status;
  final DateTime? paymentDate;
  final String? transactionReference;

  Payment({
    required this.paymentId,
    required this.bookingId,
    required this.amount,
    required this.status,
    this.paymentDate,
    this.transactionReference,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      paymentId: json['payment_id'] ?? json['id'] ?? 0,
      bookingId: json['booking_id'] ?? json['booking'] ?? 0,
      amount: (json['amount'] ?? 0).toDouble(),
      status: json['status'] ?? 'Pending',
      paymentDate: json['payment_date'] != null
          ? DateTime.parse(json['payment_date'])
          : null,
      transactionReference: json['transaction_reference'],
    );
  }
}

class QRCode {
  final int qrId;
  final int bookingId;
  final String code;
  final String codeType;
  final DateTime expiresAt;
  final String? qrImageBase64;

  QRCode({
    required this.qrId,
    required this.bookingId,
    required this.code,
    required this.codeType,
    required this.expiresAt,
    this.qrImageBase64,
  });

  factory QRCode.fromJson(Map<String, dynamic> json) {
    return QRCode(
      qrId: json['qr_id'] ?? json['id'] ?? 0,
      bookingId: json['booking_id'] ?? json['booking'] ?? 0,
      code: json['code'] ?? '',
      codeType: json['code_type'] ?? 'access',
      expiresAt: json['expires_at'] != null 
          ? DateTime.parse(json['expires_at'])
          : DateTime.now().add(const Duration(hours: 24)),
      qrImageBase64: json['qr_image_base64'],
    );
  }
}

class Review {
  final int reviewId;
  final int bookingId;
  final String? userName;
  final String? locationName;
  final int rating;
  final String? title;
  final String? comment;
  final DateTime? createdAt;

  Review({
    required this.reviewId,
    required this.bookingId,
    this.userName,
    this.locationName,
    required this.rating,
    this.title,
    this.comment,
    this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      reviewId: json['review_id'] ?? json['id'] ?? 0,
      bookingId: json['booking_id'] ?? json['booking'] ?? 0,
      userName: json['user_name'],
      locationName: json['location_name'],
      rating: json['rating'] ?? 0,
      title: json['title'],
      comment: json['comment'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }
}

class ReviewList {
  final List<Review> reviews;
  final double averageRating;
  final int total;

  ReviewList({
    required this.reviews,
    required this.averageRating,
    required this.total,
  });

  factory ReviewList.fromJson(Map<String, dynamic> json) {
    return ReviewList(
      reviews: (json['reviews'] as List)
          .map((r) => Review.fromJson(r))
          .toList(),
      averageRating: (json['average_rating'] ?? 0).toDouble(),
      total: json['total'] ?? 0,
    );
  }
}

class Discount {
  final int discountId;
  final String code;
  final String? description;
  final String discountType;
  final double discountValue;
  final double calculatedDiscount;
  final bool isValid;
  final String message;

  Discount({
    required this.discountId,
    required this.code,
    this.description,
    required this.discountType,
    required this.discountValue,
    required this.calculatedDiscount,
    required this.isValid,
    required this.message,
  });

  factory Discount.fromJson(Map<String, dynamic> json) {
    return Discount(
      discountId: json['discount_id'] ?? 0,
      code: json['code'],
      description: json['description'],
      discountType: json['discount_type'] ?? '',
      discountValue: (json['discount_value'] ?? 0).toDouble(),
      calculatedDiscount: (json['calculated_discount'] ?? 0).toDouble(),
      isValid: json['is_valid'] ?? false,
      message: json['message'] ?? '',
    );
  }
}
