import 'dart:convert';
import 'package:http/http.dart' as http;

/// API Service for connecting to the LockSpot Backend
/// Replaces Firebase with REST API calls
class ApiService {
  // Change this to your Render deployment URL
  static const String baseUrl = 'http://localhost:8000';
  // static const String baseUrl = 'https://your-app.onrender.com';

  String? _authToken;

  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  /// Set the auth token after login
  void setAuthToken(String token) {
    _authToken = token;
  }

  /// Clear auth token on logout
  void clearAuthToken() {
    _authToken = null;
  }

  /// Get headers with optional auth
  Map<String, String> _getHeaders({bool requireAuth = true}) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (requireAuth && _authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  /// Generic HTTP request handler
  Future<Map<String, dynamic>> _request(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
    bool requireAuth = true,
  }) async {
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
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw ApiException(
        statusCode: response.statusCode,
        message: error['detail'] ?? 'An error occurred',
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
    final response = await _request('GET', '/auth/me');
    return User.fromJson(response);
  }

  // ==================== LOCATIONS ====================

  /// Get all locker locations
  Future<List<Location>> getLocations({String? city}) async {
    final queryParams = <String, String>{};
    if (city != null) queryParams['city'] = city;

    final response = await _request(
      'GET',
      '/locations',
      queryParams: queryParams,
      requireAuth: false,
    );
    return (response['locations'] as List)
        .map((l) => Location.fromJson(l))
        .toList();
  }

  /// Get location by ID
  Future<Location> getLocationById(int locationId) async {
    final response = await _request(
      'GET',
      '/locations/$locationId',
      requireAuth: false,
    );
    return Location.fromJson(response);
  }

  /// Get pricing for a location
  Future<List<PricingTier>> getLocationPricing(int locationId) async {
    final response = await _request(
      'GET',
      '/locations/$locationId/pricing',
      requireAuth: false,
    );
    return (response['pricing_tiers'] as List)
        .map((p) => PricingTier.fromJson(p))
        .toList();
  }

  // ==================== LOCKERS ====================

  /// Get available lockers with filters
  Future<List<Locker>> getAvailableLockers({
    int? locationId,
    String? size,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    final queryParams = <String, String>{};
    if (locationId != null) queryParams['location_id'] = locationId.toString();
    if (size != null) queryParams['size'] = size;
    if (startTime != null) queryParams['start_time'] = startTime.toIso8601String();
    if (endTime != null) queryParams['end_time'] = endTime.toIso8601String();

    final response = await _request(
      'GET',
      '/lockers/available',
      queryParams: queryParams,
      requireAuth: false,
    );
    return (response as List).map((l) => Locker.fromJson(l)).toList();
  }

  /// Check locker availability for time slot
  Future<Map<String, dynamic>> checkLockerAvailability(
    int lockerId,
    DateTime startTime,
    DateTime endTime,
  ) async {
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
  }) async {
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
    final queryParams = <String, String>{};
    if (status != null) queryParams['status'] = status;

    final response = await _request(
      'GET',
      '/bookings',
      queryParams: queryParams,
    );
    return (response['bookings'] as List)
        .map((b) => Booking.fromJson(b))
        .toList();
  }

  /// Alias for getUserBookings (for backwards compatibility)
  Future<List<Booking>> getMyBookings({String? status}) => getUserBookings(status: status);

  /// Get booking by ID
  Future<Booking> getBookingById(int bookingId) async {
    final response = await _request('GET', '/bookings/$bookingId');
    return Booking.fromJson(response);
  }

  /// Generate QR code for booking
  Future<QRCode> generateBookingQR(int bookingId) async {
    final response = await _request('GET', '/bookings/$bookingId/qr');
    return QRCode.fromJson(response);
  }

  /// Cancel a booking
  Future<Map<String, dynamic>> cancelBooking(int bookingId, {String? reason}) async {
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
    String methodType = 'Cash',
    String? cardLastFour,
  }) async {
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
      userId: json['user_id'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      email: json['email'],
      phone: json['phone'],
      userType: json['user_type'],
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
      locationId: json['location_id'],
      name: json['name'],
      description: json['description'],
      imageUrl: json['image_url'],
      operatingHoursStart: json['operating_hours_start'],
      operatingHoursEnd: json['operating_hours_end'],
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
    return LocationAddress(
      addressId: json['address_id'],
      streetAddress: json['street_address'],
      city: json['city'],
      state: json['state'],
      zipCode: json['zip_code'],
      country: json['country'] ?? 'Egypt',
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
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
      tierId: json['tier_id'],
      name: json['name'],
      size: json['size'],
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
      lockerId: json['locker_id'],
      locationId: json['location_id'],
      locationName: json['location_name'],
      unitNumber: json['unit_number'],
      size: json['size'],
      status: json['status'],
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
      bookingId: json['booking_id'],
      userId: json['user_id'],
      lockerId: json['locker_id'],
      locationName: json['location_name'],
      unitNumber: json['unit_number'],
      size: json['size'],
      startTime: DateTime.parse(json['start_time']),
      endTime: DateTime.parse(json['end_time']),
      bookingType: json['booking_type'],
      subtotalAmount: (json['subtotal_amount'] ?? 0).toDouble(),
      discountAmount: (json['discount_amount'] ?? 0).toDouble(),
      totalAmount: (json['total_amount'] ?? 0).toDouble(),
      status: json['status'],
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
      paymentId: json['payment_id'],
      bookingId: json['booking_id'],
      amount: (json['amount'] ?? 0).toDouble(),
      status: json['status'],
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
      qrId: json['qr_id'],
      bookingId: json['booking_id'],
      code: json['code'],
      codeType: json['code_type'],
      expiresAt: DateTime.parse(json['expires_at']),
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
      reviewId: json['review_id'],
      bookingId: json['booking_id'],
      userName: json['user_name'],
      locationName: json['location_name'],
      rating: json['rating'],
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
