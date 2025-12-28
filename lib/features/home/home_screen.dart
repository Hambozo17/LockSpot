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
  bool _isLoading = true;
  String? _error;

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
              onPressed: () {},
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
                    onSelected: (selected) => setState(() => _filterIndex = 0),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Low price'),
                    selected: _filterIndex == 1,
                    onSelected: (selected) => setState(() => _filterIndex = 1),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Availability'),
                    selected: _filterIndex == 2,
                    onSelected: (selected) => setState(() => _filterIndex = 2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const TextField(
              decoration: InputDecoration(
                hintText: 'Search',
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
                          child: ListView.builder(
                            itemCount: _locations.length,
                            itemBuilder: (context, index) {
                              final location = _locations[index];
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
