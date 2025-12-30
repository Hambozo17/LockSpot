import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lockspot/features/lockers/locker_detail_screen.dart';
import 'package:lockspot/services/api_service.dart';
import 'package:lockspot/services/cache_service.dart';
import 'package:lockspot/shared/theme/colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final ApiService _api = ApiService();
  final CacheService _cache = CacheService();
  int _filterIndex = 0;
  int? _selectedLocationId;
  List<LockerLocation> _locations = [];
  List<LockerLocation> _filteredLocations = [];
  bool _isLoading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();
  Position? _currentPosition;
  bool _isGettingLocation = false;

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    print('🔄 Loading locations from API...');
    
    // ALWAYS fetch from API - fresh data on every navigation
    try {
      final locations = await _api.getLocations();
      print('📥 Received ${locations.length} locations from API');
      
      // Save to cache as backup
      await _cache.saveLocations(locations);
      
      setState(() {
        _locations = locations;
        _filteredLocations = locations;
        _isLoading = false;
      });
      _applyFilter();
    } catch (e) {
      print('❌ API failed: $e');
      // Only on network error, try cache as fallback
      final cachedLocations = await _cache.getLocations();
      if (cachedLocations != null && cachedLocations.isNotEmpty) {
        print('📦 Using cached data (${cachedLocations.length} locations)');
        setState(() {
          _locations = cachedLocations;
          _filteredLocations = cachedLocations;
          _isLoading = false;
        });
        _applyFilter();
      } else {
        print('💥 No cache available');
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  /// Calculate distance between two coordinates using Haversine formula
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0; // Earth's radius in km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _toRadians(double degree) => degree * pi / 180;

  /// Get user's current location
  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);
    
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enable location services')),
          );
        }
        setState(() => _isGettingLocation = false);
        return;
      }

      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied')),
            );
          }
          setState(() => _isGettingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are permanently denied')),
          );
        }
        setState(() => _isGettingLocation = false);
        return;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      
      setState(() {
        _currentPosition = position;
        _isGettingLocation = false;
      });

      // Sort by distance
      _sortByDistance();
      
    } catch (e) {
      setState(() => _isGettingLocation = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $e')),
        );
      }
    }
  }

  /// Sort locations by distance from current position
  void _sortByDistance() {
    if (_currentPosition == null) return;
    
    final userLat = _currentPosition!.latitude;
    final userLon = _currentPosition!.longitude;
    
    _filteredLocations.sort((a, b) {
      final distA = _calculateDistance(
        userLat, userLon,
        a.address?.latitude ?? 0, a.address?.longitude ?? 0,
      );
      final distB = _calculateDistance(
        userLat, userLon,
        b.address?.latitude ?? 0, b.address?.longitude ?? 0,
      );
      return distA.compareTo(distB);
    });
    
    setState(() {});
    
    if (_filteredLocations.isNotEmpty) {
      final nearest = _filteredLocations.first;
      final distance = _calculateDistance(
        userLat, userLon,
        nearest.address?.latitude ?? 0, nearest.address?.longitude ?? 0,
      );
      setState(() => _selectedLocationId = nearest.locationId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nearest: ${nearest.name} (${distance.toStringAsFixed(1)} km away)')),
      );
    }
  }

  void _applyFilter() {
    List<LockerLocation> result = List.from(_locations);
    
    // Apply search filter
    final searchQuery = _searchController.text.toLowerCase();
    if (searchQuery.isNotEmpty) {
      result = result.where((loc) => 
        loc.name.toLowerCase().contains(searchQuery) ||
        loc.city.toLowerCase().contains(searchQuery)
      ).toList();
    }
    
    // Apply sorting
    switch (_filterIndex) {
      case 0: // Near you - sort by distance if we have position, else by available
        if (_currentPosition != null) {
          final userLat = _currentPosition!.latitude;
          final userLon = _currentPosition!.longitude;
          result.sort((a, b) {
            final distA = _calculateDistance(userLat, userLon, a.address?.latitude ?? 0, a.address?.longitude ?? 0);
            final distB = _calculateDistance(userLat, userLon, b.address?.latitude ?? 0, b.address?.longitude ?? 0);
            return distA.compareTo(distB);
          });
        } else {
          result.sort((a, b) => b.availableLockers.compareTo(a.availableLockers));
        }
        break;
      case 1: // Low price - sort by availability (more available = likely cheaper)
        result.sort((a, b) => b.availableLockers.compareTo(a.availableLockers));
        break;
      case 2: // Availability - sort by availability count descending
        result.sort((a, b) => b.availableLockers.compareTo(a.availableLockers));
        break;
    }
    
    setState(() {
      _filteredLocations = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Padding(
          padding: const EdgeInsets.only(top: 30),
          child: Image.asset('assets/images/logotext.png', height: 150),
        ),
        centerTitle: true,
        toolbarHeight: 110,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: _isGettingLocation ? null : _getCurrentLocation,
              icon: _isGettingLocation 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.my_location),
              label: Text(_isGettingLocation ? 'Getting location...' : 'Find lockers near you'),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('Near you'),
                    selected: _filterIndex == 0,
                    onSelected: (selected) {
                      setState(() => _filterIndex = 0);
                      _applyFilter();
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Low price'),
                    selected: _filterIndex == 1,
                    onSelected: (selected) {
                      setState(() => _filterIndex = 1);
                      _applyFilter();
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Availability'),
                    selected: _filterIndex == 2,
                    onSelected: (selected) {
                      setState(() => _filterIndex = 2);
                      _applyFilter();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              onChanged: (_) => _applyFilter(),
              decoration: const InputDecoration(
                hintText: 'Search locations...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 200),
                        Center(child: CircularProgressIndicator()),
                      ],
                    )
                  : _error != null
                      ? RefreshIndicator(
                          onRefresh: _loadLocations,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('Error: $_error'),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed: _loadLocations,
                                      child: const Text('Retry'),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Or pull down to refresh',
                                      style: TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadLocations,
                          child: _filteredLocations.isEmpty
                              ? ListView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  children: const [
                                    SizedBox(height: 200),
                                    Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.search_off, size: 80, color: Colors.grey),
                                          SizedBox(height: 16),
                                          Text('No locations found'),
                                          SizedBox(height: 8),
                                          Text(
                                            'Pull down to refresh',
                                            style: TextStyle(fontSize: 12, color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.builder(
                                  itemCount: _filteredLocations.length,
                                  itemBuilder: (context, index) {
                                    final location = _filteredLocations[index];
                                    final isSelected = _selectedLocationId == location.locationId;
                                    
                                    // Calculate distance if we have user position
                                    double? distance;
                                    if (_currentPosition != null && location.address != null) {
                                      distance = _calculateDistance(
                                        _currentPosition!.latitude,
                                        _currentPosition!.longitude,
                                        location.address!.latitude ?? 0,
                                        location.address!.longitude ?? 0,
                                      );
                                    }
                                    
                                    return GestureDetector(
                                      onTap: () => setState(() => _selectedLocationId = location.locationId),
                                      child: _LocationCard(
                                        location: location,
                                        isSelected: isSelected,
                                        distance: distance,
                                      ),
                                    );
                                  },
                                ),
                        ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedLocationId == null
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => LockerDetailScreen(
                              locationId: _selectedLocationId!,
                            ),
                          ),
                        );
                      },
                child: const Text('Select Location'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  final LockerLocation location;
  final bool isSelected;
  final double? distance;

  const _LocationCard({required this.location, required this.isSelected, this.distance});

  @override
  Widget build(BuildContext context) {
    // Calculate availability from available lockers count
    String availability;
    Color availabilityColor;
    double availabilityValue;
    
    if (location.availableLockersCount > 10) {
      availability = 'Plenty';
      availabilityColor = statusGreen;
      availabilityValue = 0.3;
    } else if (location.availableLockersCount > 0) {
      availability = 'Limited';
      availabilityColor = statusOrange;
      availabilityValue = 0.7;
    } else {
      availability = 'Full';
      availabilityColor = statusRed;
      availabilityValue = 1.0;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
        side: BorderSide(
          color: isSelected ? primaryBrown : Colors.transparent,
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    location.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (distance != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: primaryBrown.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on, size: 14, color: primaryBrown),
                        const SizedBox(width: 2),
                        Text(
                          '${distance!.toStringAsFixed(1)} km',
                          style: const TextStyle(fontSize: 12, color: primaryBrown, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  )
                else
                  Text(location.city),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('${location.availableLockersCount} available'),
                const Spacer(),
                SizedBox(
                  width: 100,
                  child: LinearProgressIndicator(
                    value: availabilityValue,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      availabilityColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(availability),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
