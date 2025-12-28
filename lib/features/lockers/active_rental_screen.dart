import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lockspot/features/lockers/active_rental_detail_screen.dart';
import 'package:lockspot/services/api_service.dart';
import 'package:lockspot/services/auth_service.dart';
import 'package:lockspot/shared/theme/colors.dart';

class ActiveRentalScreen extends StatefulWidget {
  const ActiveRentalScreen({super.key});

  @override
  State<ActiveRentalScreen> createState() => _ActiveRentalScreenState();
}

class _ActiveRentalScreenState extends State<ActiveRentalScreen> {
  final ApiService _api = ApiService();
  final AuthService _auth = AuthService();
  List<Booking> _bookings = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
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

    try {
      final bookings = await _api.getMyBookings(status: 'Active');
      // Also get confirmed bookings
      final confirmedBookings = await _api.getMyBookings(status: 'Confirmed');
      
      setState(() {
        _bookings = [...bookings, ...confirmedBookings];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_auth.currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Active Rentals')),
        body: const Center(child: Text('Please log in to view your rentals.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Active Rentals')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadBookings,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _bookings.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_outlined, size: 100, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No active rentals',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 8),
                          Text('Your active locker rentals will appear here.'),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadBookings,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _bookings.length,
                        itemBuilder: (context, index) {
                          final booking = _bookings[index];

                          return ActiveRentalListItem(
                            booking: booking,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => ActiveRentalDetailScreen(
                                    bookingId: booking.bookingId,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
    );
  }
}

class ActiveRentalListItem extends StatefulWidget {
  final Booking booking;
  final VoidCallback onTap;

  const ActiveRentalListItem({
    super.key,
    required this.booking,
    required this.onTap,
  });

  @override
  State<ActiveRentalListItem> createState() => _ActiveRentalListItemState();
}

class _ActiveRentalListItemState extends State<ActiveRentalListItem> {
  Timer? _timer;
  Duration _remainingTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    final expiryTime = widget.booking.endTime;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        final now = DateTime.now();
        final remaining = expiryTime.difference(now);

        if (remaining.isNegative) {
          timer.cancel();
          setState(() => _remainingTime = Duration.zero);
        } else {
          setState(() => _remainingTime = remaining);
        }
      }
    });
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Location icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: primaryBrown.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.location_on,
                  color: primaryBrown,
                  size: 24,
                ),
              ),

              const SizedBox(width: 16),

              // Location details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.booking.locationName ?? 'Locker #${widget.booking.lockerId}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'EGP ${widget.booking.totalAmount.toStringAsFixed(2)}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
              ),

              // Timer
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _remainingTime == Duration.zero
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _formatDuration(_remainingTime),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: primaryBrown,
                          ),
                        ),
                  const SizedBox(height: 4),
                  Text(
                    'remaining',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),

              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
