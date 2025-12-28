import 'package:flutter/material.dart';
import 'package:lockspot/features/lockers/locker_detail_screen.dart';
import 'package:lockspot/services/api_service.dart';
import 'package:lockspot/shared/theme/colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _api = ApiService();
  int _filterIndex = 0;
  int? _selectedLocationId;
  List<LockerLocation> _locations = [];
  List<LockerLocation> _filteredLocations = [];
  bool _isLoading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();

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

    try {
      final locations = await _api.getLocations();
      setState(() {
        _locations = locations;
        _filteredLocations = locations;
        _isLoading = false;
        _applyFilter();
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
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
      case 0: // Near you - sort by available lockers (higher first)
        result.sort((a, b) => b.availableLockers.compareTo(a.availableLockers));
        break;
      case 1: // Low price - sort by rating (as proxy for value)
        result.sort((a, b) => a.averageRating.compareTo(b.averageRating));
        break;
      case 2: // Availability - sort by availability count
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
            ElevatedButton(
              onPressed: () {
                // Auto-select first available location
                if (_filteredLocations.isNotEmpty) {
                  final bestLocation = _filteredLocations.reduce((a, b) => 
                    a.availableLockers > b.availableLockers ? a : b);
                  setState(() => _selectedLocationId = bestLocation.locationId);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Found: ${bestLocation.name} with ${bestLocation.availableLockers} lockers')),
                  );
                }
              },
              child: const Text('Find lockers near you'),
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
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Error: $_error'),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadLocations,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadLocations,
                          child: _filteredLocations.isEmpty
                              ? const Center(
                                  child: Text('No locations found'),
                                )
                              : ListView.builder(
                                  itemCount: _filteredLocations.length,
                                  itemBuilder: (context, index) {
                                    final location = _filteredLocations[index];
                                    final isSelected = _selectedLocationId == location.locationId;
                                    return GestureDetector(
                                      onTap: () => setState(() => _selectedLocationId = location.locationId),
                                      child: _LocationCard(
                                        location: location,
                                        isSelected: isSelected,
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

  const _LocationCard({required this.location, required this.isSelected});

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
