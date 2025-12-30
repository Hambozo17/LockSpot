import 'package:flutter/material.dart';
import 'package:lockspot/services/api_service.dart';
import 'package:lockspot/services/auth_service.dart';
import 'package:lockspot/services/cache_service.dart';
import 'package:lockspot/shared/theme/colors.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with AutomaticKeepAliveClientMixin {
  final ApiService _api = ApiService();
  final AuthService _auth = AuthService();
  final CacheService _cache = CacheService();
  List<Booking> _bookings = [];
  bool _isLoading = true;
  String? _error;
  int _selectedFilter = 0; // 0: This month, 1: Last month

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    if (_auth.currentUser == null) {
      setState(() {
        _isLoading = false;
        _bookings = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    print('🔄 Loading history from API...');
    
    // ALWAYS fetch from API - fresh data on every navigation
    try {
      final bookings = await _api.getMyBookings(status: 'Completed');
      print('📥 Received ${bookings.length} completed bookings from API');
      
      // Save to cache as backup
      await _cache.saveCompletedBookings(bookings);
      
      setState(() {
        _bookings = bookings;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ API failed: $e');
      // Only on network error, try cache as fallback
      final cachedBookings = await _cache.getCompletedBookings();
      if (cachedBookings != null && cachedBookings.isNotEmpty) {
        print('📦 Using cached data (${cachedBookings.length} bookings)');
        setState(() {
          _bookings = cachedBookings;
          _isLoading = false;
        });
      } else {
        print('💥 No cache available');
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_auth.currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Rental History')),
        body: const Center(child: Text('Please log in to view your history.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Rental History')),
      body: Column(
        children: [
          // Filter chips
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('This month'),
                  selected: _selectedFilter == 0,
                  onSelected: (selected) => setState(() => _selectedFilter = 0),
                  selectedColor: primaryBrown,
                  backgroundColor: Colors.grey[200],
                  labelStyle: TextStyle(
                    color: _selectedFilter == 0 ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Last month'),
                  selected: _selectedFilter == 1,
                  onSelected: (selected) => setState(() => _selectedFilter = 1),
                  selectedColor: primaryBrown,
                  backgroundColor: Colors.grey[200],
                  labelStyle: TextStyle(
                    color: _selectedFilter == 1 ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // History list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Error: $_error'),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadHistory,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _bookings.isEmpty
                        ? RefreshIndicator(
                            onRefresh: _loadHistory,
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                                const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.history, size: 100, color: Colors.grey),
                                      SizedBox(height: 16),
                                      Text(
                                        'No rental history',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 32),
                                        child: Text(
                                          'Bookings appear here when:\n'
                                          '• Rental time expires\n'
                                          '• You complete a booking\n'
                                          '• Booking is cancelled',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                      ),
                                      SizedBox(height: 16),
                                      Text(
                                        'Pull down to refresh',
                                        style: TextStyle(fontSize: 14, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadHistory,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _bookings.length,
                              itemBuilder: (context, index) {
                                final booking = _bookings[index];
                                return HistoryCard(booking: booking);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class HistoryCard extends StatelessWidget {
  final Booking booking;

  const HistoryCard({super.key, required this.booking});

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day.toString().padLeft(2, '0')}, ${date.year}';
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final bookingDate = booking.startTime;
    final expiryDate = booking.endTime;
    final durationHours = expiryDate.difference(bookingDate).inHours;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with location and date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    booking.locationName ?? 'Locker #${booking.lockerId}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  _formatDate(bookingDate),
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Details row
            Row(
              children: [
                // Price
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total',
                        style: TextStyle(color: Colors.grey[700], fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'EGP ${booking.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: primaryBrown,
                        ),
                      ),
                    ],
                  ),
                ),

                // Duration
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Duration',
                        style: TextStyle(color: Colors.grey[700], fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${durationHours}h',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // Time range
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Time',
                        style: TextStyle(color: Colors.grey[700], fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_formatTime(bookingDate)} - ${_formatTime(expiryDate)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Status indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, size: 16, color: Colors.green),
                  const SizedBox(width: 4),
                  Text(
                    booking.status,
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
