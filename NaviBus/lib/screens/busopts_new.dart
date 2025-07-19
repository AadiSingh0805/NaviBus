import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:navibus/screens/bus_details.dart';
import 'dart:async';
import 'package:navibus/services/data_service.dart';

class BusOptionsNew extends StatefulWidget {
  const BusOptionsNew({super.key});

  @override
  State<BusOptionsNew> createState() => _BusOptionsNewState();
}

class _BusOptionsNewState extends State<BusOptionsNew> {
  TextEditingController sourceController = TextEditingController();
  TextEditingController destinationController = TextEditingController();
  List<dynamic> filteredBuses = [];
  Position? currentPosition;

  // For expanding/collapsing stops
  List<bool> expandedStops = [];
  List<int> tapCounts = [];

  // For autocomplete
  List<String> sourceSuggestions = [];
  List<String> destinationSuggestions = [];
  Timer? _debounceSource;
  Timer? _debounceDestination;

  // Recent and frequent searches
  List<String> recentSources = [];
  List<String> recentDestinations = [];
  Map<String, int> frequentSources = {};
  Map<String, int> frequentDestinations = {};
  static const int maxRecent = 5;

  // For multi-route journey planner
  List<dynamic> plannedSegments = [];
  int totalStops = 0;
  int transfers = 0;

  // Data service instance
  final DataService _dataService = DataService.instance;
  
  // UI state
  bool _isLoading = false;
  String _dataSourceInfo = '';
  bool _isBackendAvailable = false;

  @override
  void initState() {
    super.initState();
    getCurrentLocation();
    _checkDataSourceInfo();
    _checkBackendStatus();
  }

  /// Check data source info for UI display
  Future<void> _checkDataSourceInfo() async {
    final info = await _dataService.getDataSourceInfo();
    setState(() {
      _dataSourceInfo = info;
    });
  }

  /// Check backend availability
  Future<void> _checkBackendStatus() async {
    final available = await _dataService.isBackendAvailable();
    setState(() {
      _isBackendAvailable = available;
    });
  }

  /// Get User's GPS Location
  Future<void> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print("Location services are disabled.");
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print("Location permission denied");
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print("Location permissions permanently denied.");
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        currentPosition = position;
      });
    } catch (e) {
      print("Error fetching location: $e");
    }
  }

  /// Search routes using DataService with fallback
  Future<void> searchRoutes() async {
    final start = sourceController.text.trim();
    final end = destinationController.text.trim();
    if (start.isEmpty || end.isEmpty) {
      print('Source or destination is empty');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final routes = await _dataService.searchRoutes(start, end);
      
      // Add fare information to each route
      List<dynamic> routesWithFare = await Future.wait(routes.map((route) async {
        try {
          final fareData = await _dataService.getFare(
            routeNumber: route['route_number'] ?? route['bus_no'].toString(),
            sourceStop: route['sub_path'][0],
            destinationStop: route['sub_path'][route['sub_path'].length - 1],
          );
          
          return {
            ...route,
            'fare': fareData['fare'],
            'stops': fareData['stops'],
            'bus_type': fareData['bus_type'],
            'num_stops': fareData['num_stops'],
            'first_bus_time_weekday': route['first_bus_time_weekday'],
            'last_bus_time_weekday': route['last_bus_time_weekday'],
            'first_bus_time_sunday': route['first_bus_time_sunday'],
            'last_bus_time_sunday': route['last_bus_time_sunday'],
            'frequency_weekday': route['frequency_weekday'],
            'frequency_sunday': route['frequency_sunday'],
          };
        } catch (e) {
          print('Error fetching fare: $e');
          return route;
        }
      }).toList());

      setState(() {
        filteredBuses = routesWithFare;
        expandedStops = List.filled(routesWithFare.length, false);
        tapCounts = List.filled(routesWithFare.length, 0);
        _isLoading = false;
      });

      // Update recent searches
      addToRecentSources(start);
      addToRecentDestinations(end);
      
      // Update data source info
      _checkDataSourceInfo();
      
    } catch (e) {
      setState(() {
        filteredBuses = [];
        expandedStops = [];
        _isLoading = false;
      });
      print("Error searching routes: $e");
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Search failed. Using offline data if available.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  /// Get stop suggestions using DataService
  Future<List<String>> fetchStopSuggestions(String query) async {
    if (query.isEmpty) return [];
    return await _dataService.getStopSuggestions(query);
  }

  /// Force refresh data from backend
  Future<void> _forceRefresh() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _dataService.forceRefresh();
      await _checkDataSourceInfo();
      await _checkBackendStatus();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Data refreshed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Refresh failed. Using cached data.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Toggle backend mode (local vs production)
  Future<void> _toggleBackendMode() async {
    // For now, just toggle between available modes
    // You can implement a proper settings dialog here
    await _dataService.setBackendMode(useProduction: !_isBackendAvailable);
    await _checkBackendStatus();
    await _checkDataSourceInfo();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backend mode updated'),
        ),
      );
    }
  }

  void onSourceSuggestionSelected(String suggestion) {
    sourceController.text = suggestion;
    sourceSuggestions.clear();
    addToRecentSources(suggestion);
    setState(() {});
  }

  void onDestinationSuggestionSelected(String suggestion) {
    destinationController.text = suggestion;
    destinationSuggestions.clear();
    addToRecentDestinations(suggestion);
    setState(() {});
  }

  void addToRecentSources(String stop) {
    setState(() {
      recentSources.remove(stop);
      recentSources.insert(0, stop);
      if (recentSources.length > maxRecent) recentSources = recentSources.sublist(0, maxRecent);
      frequentSources[stop] = (frequentSources[stop] ?? 0) + 1;
    });
  }

  void addToRecentDestinations(String stop) {
    setState(() {
      recentDestinations.remove(stop);
      recentDestinations.insert(0, stop);
      if (recentDestinations.length > maxRecent) recentDestinations = recentDestinations.sublist(0, maxRecent);
      frequentDestinations[stop] = (frequentDestinations[stop] ?? 0) + 1;
    });
  }

  Future<void> searchBestJourney() async {
    final start = sourceController.text.trim();
    final end = destinationController.text.trim();
    if (start.isEmpty || end.isEmpty) {
      print('Source or destination is empty');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // This would need to be implemented in DataService
      // For now, just clear the segments
      setState(() {
        plannedSegments = [];
        totalStops = 0;
        transfers = 0;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        plannedSegments = [];
        totalStops = 0;
        transfers = 0;
        _isLoading = false;
      });
      print("Error planning journey: $e");
    }
  }

  String getNextBusTime(dynamic bus) {
    final now = DateTime.now();
    final isSunday = now.weekday == DateTime.sunday;
    final freq = isSunday ? bus['frequency_sunday'] : bus['frequency_weekday'];
    final firstBus = isSunday ? bus['first_bus_time_sunday'] : bus['first_bus_time_weekday'];
    final lastBus = isSunday ? bus['last_bus_time_sunday'] : bus['last_bus_time_weekday'];

    String nextBusTime = 'N/A';
    try {
      if (firstBus != null && lastBus != null && freq != null) {
        final now = TimeOfDay.now();
        final first = _parseTimeOfDay(firstBus);
        final last = _parseTimeOfDay(lastBus);
        final freqInt = int.tryParse(freq.toString()) ?? 0;

        if (first != null && last != null && freqInt > 0) {
          final nowMinutes = now.hour * 60 + now.minute;
          final firstMinutes = first.hour * 60 + first.minute;
          final lastMinutes = last.hour * 60 + last.minute;

          if (nowMinutes > lastMinutes + freqInt) {
            nextBusTime = 'N/A';
          } else if (nowMinutes < firstMinutes) {
            nextBusTime = firstBus;
          } else {
            final minutesSinceFirst = nowMinutes - firstMinutes;
            final nextBusOffset = ((minutesSinceFirst / freqInt).ceil()) * freqInt;
            final nextBusMinutes = firstMinutes + nextBusOffset;
            final nextBusHour = nextBusMinutes ~/ 60;
            final nextBusMin = nextBusMinutes % 60;
            nextBusTime = '${nextBusHour.toString().padLeft(2, '0')}:${nextBusMin.toString().padLeft(2, '0')}';
          }
        }
      }
    } catch (e) {
      nextBusTime = 'N/A';
    }
    return nextBusTime;
  }

  TimeOfDay? _parseTimeOfDay(String time) {
    try {
      if (time.contains('-')) {
        time = time.split('-').first;
      }
      final parts = time.split(':');
      if (parts.length == 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        return TimeOfDay(hour: hour, minute: minute);
      }
    } catch (e) {
      // Ignore parsing errors
    }
    return null;
  }

  @override
  void dispose() {
    _debounceSource?.cancel();
    _debounceDestination?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.directions_bus, color: Colors.white),
            const SizedBox(width: 8),
            const Text('Bus Routes', style: TextStyle(color: Colors.white)),
            const Spacer(),
            // Data source indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _dataSourceInfo,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        actions: [
          // Refresh button
          IconButton(
            icon: _isLoading 
              ? const SizedBox(
                  width: 20, 
                  height: 20, 
                  child: CircularProgressIndicator(
                    strokeWidth: 2, 
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.refresh, color: Colors.white),
            onPressed: _isLoading ? null : _forceRefresh,
          ),
          // Settings menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == 'toggle_backend') {
                _toggleBackendMode();
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'toggle_backend',
                child: Row(
                  children: [
                    Icon(_isBackendAvailable ? Icons.cloud_off : Icons.cloud),
                    const SizedBox(width: 8),
                    Text(_isBackendAvailable ? 'Use Offline Mode' : 'Use Online Mode'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Status banner
          if (!_isBackendAvailable)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: Colors.orange,
              child: const Text(
                '⚠️ Offline Mode: Using cached/local data',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          
          // Search section
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Source input with autocomplete
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: sourceController,
                      decoration: InputDecoration(
                        labelText: 'From',
                        prefixIcon: const Icon(Icons.my_location, color: Colors.red),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        suffixIcon: sourceController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  sourceController.clear();
                                  sourceSuggestions.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                      ),
                      onChanged: (value) {
                        _debounceSource?.cancel();
                        _debounceSource = Timer(const Duration(milliseconds: 300), () async {
                          if (value.isNotEmpty) {
                            final suggestions = await fetchStopSuggestions(value);
                            setState(() {
                              sourceSuggestions = suggestions;
                            });
                          } else {
                            setState(() {
                              sourceSuggestions = [];
                            });
                          }
                        });
                      },
                    ),
                    
                    // Source suggestions
                    if (sourceSuggestions.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 150),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: sourceSuggestions.length,
                          itemBuilder: (context, index) {
                            return ListTile(
                              dense: true,
                              title: Text(sourceSuggestions[index]),
                              onTap: () => onSourceSuggestionSelected(sourceSuggestions[index]),
                            );
                          },
                        ),
                      ),
                    ],

                    // Recent sources
                    if (recentSources.isNotEmpty && sourceController.text.isEmpty) ...[
                      const SizedBox(height: 8),
                      const Text('Recent searches:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Wrap(
                        spacing: 8,
                        children: recentSources.map((stop) => ActionChip(
                          label: Text(stop, style: const TextStyle(fontSize: 12)),
                          onPressed: () => onSourceSuggestionSelected(stop),
                        )).toList(),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 16),

                // Destination input with autocomplete
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: destinationController,
                      decoration: InputDecoration(
                        labelText: 'To',
                        prefixIcon: const Icon(Icons.location_on, color: Colors.red),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        suffixIcon: destinationController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  destinationController.clear();
                                  destinationSuggestions.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                      ),
                      onChanged: (value) {
                        _debounceDestination?.cancel();
                        _debounceDestination = Timer(const Duration(milliseconds: 300), () async {
                          if (value.isNotEmpty) {
                            final suggestions = await fetchStopSuggestions(value);
                            setState(() {
                              destinationSuggestions = suggestions;
                            });
                          } else {
                            setState(() {
                              destinationSuggestions = [];
                            });
                          }
                        });
                      },
                    ),
                    
                    // Destination suggestions
                    if (destinationSuggestions.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 150),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: destinationSuggestions.length,
                          itemBuilder: (context, index) {
                            return ListTile(
                              dense: true,
                              title: Text(destinationSuggestions[index]),
                              onTap: () => onDestinationSuggestionSelected(destinationSuggestions[index]),
                            );
                          },
                        ),
                      ),
                    ],

                    // Recent destinations
                    if (recentDestinations.isNotEmpty && destinationController.text.isEmpty) ...[
                      const SizedBox(height: 8),
                      const Text('Recent destinations:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Wrap(
                        spacing: 8,
                        children: recentDestinations.map((stop) => ActionChip(
                          label: Text(stop, style: const TextStyle(fontSize: 12)),
                          onPressed: () => onDestinationSuggestionSelected(stop),
                        )).toList(),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 16),

                // Search buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : searchRoutes,
                        icon: _isLoading 
                          ? const SizedBox(
                              width: 16, 
                              height: 16, 
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.search),
                        label: Text(_isLoading ? 'Searching...' : 'Search Routes'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : searchBestJourney,
                        icon: const Icon(Icons.route),
                        label: const Text('Best Route'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Results section
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredBuses.isEmpty
                    ? const Center(
                        child: Text(
                          'No routes found.\nTry searching for different stops.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredBuses.length,
                        itemBuilder: (context, index) {
                          final bus = filteredBuses[index];
                          final nextBusTime = getNextBusTime(bus);
                          
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: ExpansionTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.red,
                                child: Text(
                                  bus['route_number']?.toString() ?? bus['bus_no']?.toString() ?? '?',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(
                                '${bus['sub_path']?.first ?? 'Unknown'} → ${bus['sub_path']?.last ?? 'Unknown'}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Fare: ₹${bus['fare'] ?? 'N/A'}'),
                                  Text('Next Bus: $nextBusTime'),
                                  if (bus['bus_type'] != null)
                                    Text('Type: ${bus['bus_type']}'),
                                ],
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Route Stops:', style: TextStyle(fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 8),
                                      if (bus['sub_path'] != null)
                                        ...bus['sub_path'].map<Widget>((stop) => Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 2),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.circle, size: 8, color: Colors.red),
                                              const SizedBox(width: 8),
                                              Text(stop.toString()),
                                            ],
                                          ),
                                        )).toList(),
                                      
                                      const SizedBox(height: 16),
                                      
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => BusDetails(bus: bus),
                                                  ),
                                                );
                                              },
                                              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                                              child: const Text('Details', style: TextStyle(color: Colors.white)),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: () {
                                                Navigator.pushNamed(context, '/payment', arguments: bus);
                                              },
                                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                              child: const Text('Book Ticket', style: TextStyle(color: Colors.white)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
