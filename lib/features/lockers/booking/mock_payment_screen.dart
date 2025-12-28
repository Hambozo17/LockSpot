import 'package:flutter/material.dart';
import 'package:lockspot/features/main_screen.dart';
import 'package:lockspot/services/api_service.dart';
import 'package:lockspot/services/auth_service.dart';

class MockPaymentScreen extends StatefulWidget {
  final int locationId;
  final String locationName;
  final String selectedSize;
  final int duration;
  final double totalPrice;

  const MockPaymentScreen({
    super.key,
    required this.locationId,
    required this.locationName,
    required this.selectedSize,
    required this.duration,
    required this.totalPrice,
  });

  @override
  State<MockPaymentScreen> createState() => _MockPaymentScreenState();
}

class _MockPaymentScreenState extends State<MockPaymentScreen> {
  final ApiService _api = ApiService();
  final AuthService _auth = AuthService();
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _nameController = TextEditingController();
  bool _agreedToTerms = false;
  bool _isLoading = false;
  int _selectedCardTemplate = -1;

  // Test card templates
  final List<Map<String, String>> _cardTemplates = [
    {'name': 'Ahmed Mohamed', 'number': '4242424242424242', 'expiry': '12/27', 'cvv': '123'},
    {'name': 'Sara Ahmed', 'number': '5555555555554444', 'expiry': '06/28', 'cvv': '456'},
    {'name': 'Omar Hassan', 'number': '4000056655665556', 'expiry': '09/26', 'cvv': '789'},
    {'name': 'Fatima Ali', 'number': '5200828282828210', 'expiry': '03/29', 'cvv': '321'},
    {'name': 'Youssef Mahmoud', 'number': '4111111111111111', 'expiry': '11/27', 'cvv': '654'},
  ];

  void _selectCardTemplate(int index) {
    final template = _cardTemplates[index];
    setState(() {
      _selectedCardTemplate = index;
      _cardNumberController.text = template['number']!;
      _expiryController.text = template['expiry']!;
      _cvvController.text = template['cvv']!;
      _nameController.text = template['name']!;
    });
  }

  String _formatCardNumber(String number) {
    // Format as XXXX XXXX XXXX XXXX
    final cleaned = number.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (int i = 0; i < cleaned.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(cleaned[i]);
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Summary & Pay')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Rental Summary Section
                    const Text(
                      'Rental Summary',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Location:'),
                                Text(
                                  widget.locationName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Size:'),
                                Text(
                                  widget.selectedSize,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Duration:'),
                                Text(
                                  '${widget.duration} hours',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total:',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'EGP ${widget.totalPrice.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Payment Section
                    const Text(
                      'Payment Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Test Card Templates
                    const Text(
                      'Quick Fill (Test Cards):',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 40,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _cardTemplates.length,
                        itemBuilder: (context, index) {
                          final isSelected = _selectedCardTemplate == index;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(_cardTemplates[index]['name']!.split(' ')[0]),
                              selected: isSelected,
                              onSelected: (_) => _selectCardTemplate(index),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: _cardNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Card Number',
                        hintText: '1234 5678 9012 3456',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _expiryController,
                            decoration: const InputDecoration(
                              labelText: 'Expiry Date',
                              hintText: 'MM/YY',
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _cvvController,
                            decoration: const InputDecoration(
                              labelText: 'CVV',
                              hintText: '123',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Cardholder Name',
                        hintText: 'John Doe',
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Terms checkbox
                    Row(
                      children: [
                        Checkbox(
                          value: _agreedToTerms,
                          onChanged: (value) =>
                              setState(() => _agreedToTerms = value ?? false),
                        ),
                        const Expanded(
                          child: Text('I agree to the terms and conditions'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Pay & Confirm Button
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _canProceed() && !_isLoading
                    ? _handlePayment
                    : null,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Pay & Confirm'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _canProceed() {
    return _agreedToTerms &&
        _cardNumberController.text.replaceAll(' ', '').length >= 13 &&
        _expiryController.text.length >= 4 &&
        _cvvController.text.length >= 3 &&
        _nameController.text.isNotEmpty;
  }

  Future<void> _handlePayment() async {
    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      // First get an available locker at this location with selected size
      final lockers = await _api.getAvailableLockers(
        locationId: widget.locationId,
        size: widget.selectedSize,
      );

      if (lockers.isEmpty) {
        throw Exception('No available lockers of selected size');
      }

      final locker = lockers.first;

      // Calculate booking times
      final now = DateTime.now();
      final endTime = now.add(Duration(hours: widget.duration));

      // Create booking via API
      final booking = await _api.createBooking(
        lockerId: locker.lockerId,
        startTime: now,
        endTime: endTime,
      );

      // Process payment
      await _api.processPayment(bookingId: booking.bookingId);

      if (mounted) {
        // Show success message first
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking confirmed! Your locker has been reserved.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Navigate to main screen with Active tab selected (index 1)
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const MainScreen(initialIndex: 1),
          ),
          (route) => false,
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment failed: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
