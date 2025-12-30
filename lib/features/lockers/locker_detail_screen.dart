import 'package:flutter/material.dart';
import 'package:lockspot/features/lockers/booking/mock_payment_screen.dart';
import 'package:lockspot/services/api_service.dart';
import 'package:lockspot/shared/theme/colors.dart';

class LockerDetailScreen extends StatefulWidget {
  final int locationId;

  const LockerDetailScreen({super.key, required this.locationId});

  @override
  State<LockerDetailScreen> createState() => _LockerDetailScreenState();
}

class _LockerDetailScreenState extends State<LockerDetailScreen> {
  final List<int> _presetDurations = [6, 12, 24];
  final ApiService _api = ApiService();
  String? _selectedSize;
  int _selectedHours = 1;
  bool _useTestDuration = false; // 5-minute test mode
  
  LockerLocation? _location;
  List<LockerUnit> _lockers = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLocationDetails();
  }

  Future<void> _loadLocationDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Fetch location and available lockers
      final locations = await _api.getLocations();
      _location = locations.firstWhere(
        (l) => l.locationId == widget.locationId,
        orElse: () => throw Exception('Location not found'),
      );
      
      _lockers = await _api.getAvailableLockers(
        locationId: widget.locationId,
      );
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // Group lockers by size and get pricing
  Map<String, Map<String, dynamic>> _getSizeData() {
    final Map<String, Map<String, dynamic>> sizes = {};
    
    for (final locker in _lockers) {
      final size = locker.size;
      if (!sizes.containsKey(size)) {
        sizes[size] = {
          'price': locker.hourlyRate,
          'count': 0,
          'availability': 'Full',
        };
      }
      sizes[size]!['count'] = (sizes[size]!['count'] as int) + 1;
    }
    
    // Update availability status based on count
    for (final size in sizes.keys) {
      final count = sizes[size]!['count'] as int;
      if (count > 5) {
        sizes[size]!['availability'] = 'Plenty';
      } else if (count > 0) {
        sizes[size]!['availability'] = 'Limited';
      } else {
        sizes[size]!['availability'] = 'Full';
      }
    }
    
    return sizes;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Locker Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Locker Details')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $_error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadLocationDetails,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final sizes = _getSizeData();

    return Scaffold(
      appBar: AppBar(title: const Text('Locker Details')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_location?.imageUrl != null && _location!.imageUrl!.isNotEmpty)
                      Image.network(
                        _location!.imageUrl!,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Container(
                              height: 200,
                              color: Colors.grey[300],
                              child: const Icon(Icons.image_not_supported, size: 50),
                            ),
                      ),
                    const SizedBox(height: 16),
                    Text(
                      _location?.name ?? '',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(_location?.city ?? ''),
                    const SizedBox(height: 16),
                    const Text(
                      'Choose Size',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: ['Small', 'Medium', 'Large'].map((size) {
                        final sizeData = sizes[size];
                        final price = sizeData?['price'] ?? 0.0;
                        final availability = sizeData?['availability'] ?? 'Full';
                        final isAvailable = sizeData != null && availability != 'Full';

                        return Expanded(
                          child: GestureDetector(
                            onTap: isAvailable
                                ? () => setState(() => _selectedSize = size)
                                : null,
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4.0),
                              padding: const EdgeInsets.all(16.0),
                              decoration: BoxDecoration(
                                color: _selectedSize == size
                                    ? Theme.of(context).primaryColor
                                    : (isAvailable ? Colors.white : Colors.grey[300]),
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    size[0], // S, M, L
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _selectedSize == size
                                          ? Colors.white
                                          : (isAvailable ? Colors.black : Colors.grey),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'EGP ${price.toStringAsFixed(0)}/hr',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _selectedSize == size
                                          ? Colors.white70
                                          : (isAvailable ? Colors.black54 : Colors.grey),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: availability == 'Plenty'
                                          ? statusGreen
                                          : availability == 'Limited'
                                              ? statusOrange
                                              : statusRed,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isAvailable ? availability : 'N/A',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    // Duration selector UI
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12.0, vertical: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Select Duration'),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove),
                                  onPressed: _selectedHours > 1
                                      ? () => setState(() => _selectedHours--)
                                      : null,
                                ),
                                Text('$_selectedHours hr'),
                                IconButton(
                                  icon: const Icon(Icons.add),
                                  onPressed: () =>
                                      setState(() => _selectedHours++),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Preset duration chips
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: _presetDurations.map((hours) {
                        final isSelected = _selectedHours == hours && !_useTestDuration;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: ChoiceChip(
                            label: Text('${hours}h'),
                            selected: isSelected,
                            selectedColor: primaryBrown,
                            backgroundColor: Colors.grey[200],
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                            onSelected: (_) {
                              setState(() {
                                _selectedHours = hours;
                                _useTestDuration = false;
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                    // Test duration toggle (1 minute for demo)
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.amber[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber[700]!, width: 1),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.science, color: Colors.amber[900], size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Test Mode (5 min)',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Switch(
                            value: _useTestDuration,
                            activeColor: Colors.amber[700],
                            onChanged: (value) {
                              setState(() {
                                _useTestDuration = value;
                                if (value) {
                                  _selectedHours = 1;
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    if (_useTestDuration)
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          '⚠️ Booking will expire in 1 minute for testing',
                          style: TextStyle(
                            color: Colors.amber[900],
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Continue and Back buttons
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedSize != null
                    ? () {
                        // Calculate total price
                        final sizeData = sizes[_selectedSize];
                        final price = sizeData?['price'] ?? 0.0;
                        final totalPrice = (price * _selectedHours).toDouble();

                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => MockPaymentScreen(
                              locationId: widget.locationId,
                              locationName: _location?.name ?? '',
                              selectedSize: _selectedSize!,
                              duration: _selectedHours,
                              totalPrice: totalPrice,
                              isTestDuration: _useTestDuration,
                            ),
                          ),
                        );
                      }
                    : null,
                child: const Text('Continue'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
