import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lockspot/features/main_screen.dart';
import 'package:lockspot/services/api_service.dart';
import 'package:lockspot/shared/theme/colors.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';

class ActiveRentalDetailScreen extends StatefulWidget {
  final bool showSuccessFirst;
  final int? bookingId;

  const ActiveRentalDetailScreen({
    super.key,
    this.showSuccessFirst = false,
    this.bookingId,
  });

  @override
  State<ActiveRentalDetailScreen> createState() =>
      _ActiveRentalDetailScreenState();
}

class _ActiveRentalDetailScreenState extends State<ActiveRentalDetailScreen> {
  final ApiService _api = ApiService();
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  bool _showSuccess = false;
  Timer? _countdownTimer;
  Duration _remainingTime = Duration.zero;
  
  Booking? _booking;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBooking();

    if (widget.showSuccessFirst) {
      _showSuccess = true;
      Timer(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => _showSuccess = false);
        }
      });
    }
  }

  Future<void> _loadBooking() async {
    if (widget.bookingId == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final booking = await _api.getBookingById(widget.bookingId!);
      setState(() {
        _booking = booking;
        _isLoading = false;
      });
      _startCountdown(booking.endTime);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown(DateTime expiryTime) {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
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

  @override
  Widget build(BuildContext context) {
    if (_showSuccess) {
      return Scaffold(
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, size: 100, color: Colors.green),
              SizedBox(height: 16),
              Text(
                'Booking Confirmed!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('Your locker has been reserved.'),
            ],
          ),
        ),
      );
    }

    if (widget.bookingId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Active Rental')),
        body: const Center(child: Text('No booking selected.')),
      );
    }

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Active Rental')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Active Rental')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $_error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadBooking,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final booking = _booking!;

    return Scaffold(
      appBar: AppBar(title: const Text('Active Rental')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Rental Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      booking.locationName ?? 'Locker #${booking.lockerId}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'EGP ${booking.totalAmount.toStringAsFixed(2)}',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Countdown Timer
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: primaryBrown, width: 8),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _remainingTime == Duration.zero
                        ? const CircularProgressIndicator()
                        : Text(
                            _formatDuration(_remainingTime),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                    _remainingTime == Duration.zero
                        ? const Text('Loading...')
                        : const Text('remaining'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Unlock Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _scanQRCode,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Unlock'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Action Buttons Row
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Extend feature coming soon!'),
                        ),
                      );
                    },
                    child: const Text('Extend +1h'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _showQRCode,
                    child: const Text('Show Code'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _showQRCode() async {
    if (_booking == null) return;

    try {
      final qrCode = await _api.generateBookingQR(_booking!.bookingId);
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Access Code'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Show this code to unlock your locker:'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    qrCode.code,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate code: $e')),
        );
      }
    }
  }

  void _scanQRCode() {
    if (_booking == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No booking available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _QRScannerScreen(
          expectedLockerId: _booking!.lockerId.toString(),
          bookingId: _booking!.bookingId,
          api: _api,
        ),
      ),
    );
  }
}

class _QRScannerScreen extends StatefulWidget {
  final String expectedLockerId;
  final int bookingId;
  final ApiService api;

  const _QRScannerScreen({
    required this.expectedLockerId,
    required this.bookingId,
    required this.api,
  });

  @override
  State<_QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<_QRScannerScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        backgroundColor: const Color(0xFF8D6E63),
        foregroundColor: Colors.white,
      ),
      body: QRView(
        key: qrKey,
        onQRViewCreated: _onQRViewCreated,
        overlay: QrScannerOverlayShape(
          borderColor: const Color(0xFF8D6E63),
          borderRadius: 10,
          borderLength: 30,
          borderWidth: 10,
          cutOutSize: 300,
        ),
      ),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) async {
      final scannedCode = scanData.code ?? '';

      controller.pauseCamera();
      Navigator.of(context).pop();

      if (scannedCode.contains(widget.expectedLockerId) || scannedCode.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Locker Unlocked!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) =>
                const MainScreen(initialIndex: 2),
          ),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Wrong Locker! Please scan the correct QR code.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}
