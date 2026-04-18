import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:navibus/screens/bus_details.dart';
import 'dart:async';
import 'package:navibus/services/data_service.dart';
import 'package:navibus/services/sensor_input_service.dart';

class BusOptionsNew extends StatefulWidget {
  final String? initialSource;
  final String? initialDestination;

  const BusOptionsNew({
    super.key,
    this.initialSource,
    this.initialDestination,
  });

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
  final SensorInputService _sensorInputService = SensorInputService.instance;
  
  // UI state
  bool _isLoading = false;
  String _dataSourceInfo = '';
  bool _isBackendAvailable = false;

  StreamSubscription<SensorInput>? _sensorSubscription;
  SensorInput? _latestSensorInput;
  DateTime _lastSensorUiUpdate = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _startSensorInputStream();
    sourceController.text = widget.initialSource ?? '';
    destinationController.text = widget.initialDestination ?? '';
    getCurrentLocation();
    _checkDataSourceInfo();
    _checkBackendStatus();

    if (sourceController.text.trim().isNotEmpty &&
        destinationController.text.trim().isNotEmpty) {
      Future.microtask(searchRoutes);
    }
  }

  void _startSensorInputStream() {
    _sensorSubscription?.cancel();
    _sensorSubscription = _sensorInputService.accelerometerInputStream().listen(
      (sensorInput) {
        final now = DateTime.now();
        if (now.difference(_lastSensorUiUpdate).inMilliseconds < 250) {
          return;
        }

        _lastSensorUiUpdate = now;

        if (!mounted) {
          return;
        }

        setState(() {
          _latestSensorInput = sensorInput;
        });
      },
      onError: (_) {
        if (!mounted) {
          return;
        }

        setState(() {
          _latestSensorInput = null;
        });
      },
    );
  }

  Map<String, dynamic> _currentSensorSnapshot() {
    final sensorInput = _latestSensorInput;

    if (sensorInput == null) {
      return {
        'available': false,
        'accelerometer': {
          'x': 0.0,
          'y': 0.0,
          'z': 0.0,
          'magnitude': 0.0,
          'shake_level': 0.0,
        },
        'captured_at': DateTime.now().toIso8601String(),
      };
    }

    return {
      'available': true,
      'accelerometer': sensorInput.toMap(),
      'captured_at': sensorInput.timestamp.toIso8601String(),
    };
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
      final sensorSnapshot = _currentSensorSnapshot();
      
      // Add fare information to each route
      List<dynamic> routesWithFare = await Future.wait(routes.map((route) async {
        try {
          final routeNumber =
              (route['route_number'] ?? route['bus_no'] ?? '').toString();
          final normalizedRouteNumber =
              routeNumber.trim().isEmpty ? 'N/A' : routeNumber;
          final path = _extractStops(route['sub_path'] ?? route['stops']);
          final isMockRoute =
              (route['source']?.toString().contains('mock') ?? false);
          final fareBase = route['fare_general'] ?? route['fare'] ?? 20;

          if (path.isEmpty) {
            return {
              ...route,
              'route_number': normalizedRouteNumber,
              'sub_path': const <dynamic>[],
              'stops': const <dynamic>[],
              ..._buildOperationalMockMeta(
                routeNumber: normalizedRouteNumber,
                busType: route['bus_type'],
                fareGeneralRaw: fareBase,
                fareLadiesRaw: route['fare_ladies'],
                numStops: 0,
              ),
              'sensor_input': sensorSnapshot,
            };
          }

          if (isMockRoute) {
            final parsedNumStops =
                int.tryParse((route['num_stops'] ?? path.length).toString()) ??
                    path.length;

            return {
              ...route,
              'route_number': normalizedRouteNumber,
              'sub_path': path,
              'stops': path,
              'fare': route['fare_general'] ?? route['fare'] ?? fareBase,
              'num_stops': parsedNumStops,
              ..._buildOperationalMockMeta(
                routeNumber: normalizedRouteNumber,
                busType: route['bus_type'],
                fareGeneralRaw: route['fare_general'] ?? route['fare'] ?? fareBase,
                fareLadiesRaw: route['fare_ladies'],
                numStops: parsedNumStops,
              ),
              'sensor_input': sensorSnapshot,
            };
          }

          final fareData = await _dataService.getFare(
            routeNumber: normalizedRouteNumber,
            sourceStop: path.first.toString(),
            destinationStop: path.last.toString(),
          );

          final resolvedStops = _resolveStops(fareData['stops'], path);
          final resolvedNumStops =
              int.tryParse((fareData['num_stops'] ?? resolvedStops.length).toString()) ??
                  resolvedStops.length;
          
          return {
            ...route,
            'route_number': normalizedRouteNumber,
            'sub_path': resolvedStops,
            'stops': resolvedStops,
            'fare': fareData['fare'] ?? route['fare'] ?? 20,
            'bus_type': fareData['bus_type'] ?? route['bus_type'],
            'num_stops': resolvedNumStops,
            'first_bus_time_weekday': route['first_bus_time_weekday'],
            'last_bus_time_weekday': route['last_bus_time_weekday'],
            'first_bus_time_sunday': route['first_bus_time_sunday'],
            'last_bus_time_sunday': route['last_bus_time_sunday'],
            'frequency_weekday': route['frequency_weekday'],
            'frequency_sunday': route['frequency_sunday'],
            ..._buildOperationalMockMeta(
              routeNumber: normalizedRouteNumber,
              busType: fareData['bus_type'] ?? route['bus_type'],
              fareGeneralRaw: fareData['fare_general'] ?? fareData['fare'] ?? fareBase,
              fareLadiesRaw: fareData['fare_ladies'] ?? route['fare_ladies'],
              numStops: resolvedNumStops,
            ),
            'sensor_input': sensorSnapshot,
          };
        } catch (e) {
          print('Error fetching fare: $e');
          final routeNumber =
              (route['route_number'] ?? route['bus_no'] ?? '').toString();
          final normalizedRouteNumber =
              routeNumber.trim().isEmpty ? 'N/A' : routeNumber;
          final path = _extractStops(route['sub_path'] ?? route['stops']);

          return {
            ...route,
            'route_number': normalizedRouteNumber,
            'sub_path': path,
            'stops': path,
            ..._buildOperationalMockMeta(
              routeNumber: normalizedRouteNumber,
              busType: route['bus_type'],
              fareGeneralRaw: route['fare_general'] ?? route['fare'] ?? 20,
              fareLadiesRaw: route['fare_ladies'],
              numStops: path.length,
            ),
            'sensor_input': sensorSnapshot,
          };
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

  List<dynamic> _extractStops(dynamic rawStops) {
    if (rawStops is List) {
      return List<dynamic>.from(rawStops);
    }
    return <dynamic>[];
  }

  List<dynamic> _resolveStops(dynamic candidateStops, List<dynamic> fallbackStops) {
    final parsed = _extractStops(candidateStops);
    if (parsed.isNotEmpty) {
      return parsed;
    }
    return fallbackStops;
  }

  Map<String, dynamic> _buildOperationalMockMeta({
    required String routeNumber,
    required dynamic busType,
    required dynamic fareGeneralRaw,
    required dynamic fareLadiesRaw,
    required int numStops,
  }) {
    final hash = routeNumber.codeUnits.fold<int>(0, (sum, value) => sum + value);
    final parsedFareGeneral = int.tryParse(fareGeneralRaw.toString()) ?? 20;
    final parsedFareLadies =
        int.tryParse((fareLadiesRaw ?? '').toString()) ??
            (parsedFareGeneral * 0.75).round();

    final womenAvailable = hash % 7;
    final pwdAvailable = hash % 3;
    final pregnantSeatAvailable = (hash % 4) != 0;
    final occupancy = 42 + (hash % 53);
    final delayExpected = hash % 5 == 0;
    final delayMinutes = delayExpected ? 3 + (hash % 10) : 0;
    final etaMinutes = (5 + (hash % 13) + (numStops ~/ 4)) + delayMinutes;

    return {
      'eta_minutes': etaMinutes,
      'passenger_occupancy_percent': occupancy,
      'passenger_occupancy_level': occupancy >= 85
          ? 'High'
          : occupancy >= 60
              ? 'Moderate'
              : 'Low',
      'women_reserved_seats_available': womenAvailable,
      'women_reserved_available': womenAvailable > 0,
      'pwd_reserved_seats_available': pwdAvailable,
      'pwd_reserved_available': pwdAvailable > 0,
      'pregnant_women_special_seat_available': pregnantSeatAvailable,
      'delay_expected': delayExpected,
      'delay_minutes': delayMinutes,
      'bus_type': (busType ?? (routeNumber.contains('AC') ? 'AC' : 'NON_AC')).toString(),
      'fare_general': parsedFareGeneral,
      'fare_ladies': parsedFareLadies,
      'fare': parsedFareGeneral,
    };
  }

  Widget _availabilityPill({
    required String label,
    required bool available,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: available ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        '$label: ${available ? 'Yes' : 'No'}',
        style: TextStyle(
          color: available ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _sensorSubscription?.cancel();
    _debounceSource?.cancel();
    _debounceDestination?.cancel();
    super.dispose();
  }

  Widget _sensorInputPanel() {
    final sensorInput = _latestSensorInput;

    if (sensorInput == null) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          children: [
            Icon(Icons.sensors_off, color: Colors.black54, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Sensor input unavailable right now.',
                style: TextStyle(fontSize: 12, color: Colors.black87),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7EC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.sensors, color: Color(0xFF2E7D32), size: 18),
              SizedBox(width: 6),
              Text(
                'Live Sensor Input (Accelerometer)',
                style: TextStyle(
                  color: Color(0xFF2E7D32),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'x: ${sensorInput.x.toStringAsFixed(2)}  y: ${sensorInput.y.toStringAsFixed(2)}  z: ${sensorInput.z.toStringAsFixed(2)}  shake: ${sensorInput.shakeLevel.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Color(0xFF1B4332),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricChip({
    required IconData icon,
    required String label,
    required String value,
    Color color = const Color(0xFF0F172A),
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            '$label: $value',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  void _showStopsSheet({
    required String routeNumber,
    required List<dynamic> routeStops,
  }) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Route $routeNumber Stops',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                if (routeStops.isEmpty)
                  const Text(
                    'Stops unavailable for this route.',
                    style: TextStyle(color: Colors.grey),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: routeStops.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final stopName = routeStops[index].toString();
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 12,
                            backgroundColor: const Color(0xFFFFEEF0),
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Color(0xFFD62828),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          title: Text(stopName),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRouteCard(Map<String, dynamic> bus) {
    final routeStops = _extractStops(bus['sub_path'] ?? bus['stops']);
    final firstStop = routeStops.isNotEmpty ? routeStops.first.toString() : 'Unknown Source';
    final lastStop = routeStops.isNotEmpty ? routeStops.last.toString() : 'Unknown Destination';

    final routeNumber =
        (bus['route_number'] ?? bus['bus_no'] ?? 'N/A').toString();
    final nextBusTime = getNextBusTime(bus);
    final etaMinutes = bus['eta_minutes'] ?? 'N/A';
    final occupancyPercent = bus['passenger_occupancy_percent'] ?? 'N/A';
    final occupancyLevel = (bus['passenger_occupancy_level'] ?? 'Unknown').toString();
    final delayExpected = bus['delay_expected'] == true;
    final delayMinutes = bus['delay_minutes'] ?? 0;

    final generalFare = (bus['fare_general'] ?? bus['fare'] ?? 'N/A').toString();
    final ladiesFare = (bus['fare_ladies'] ?? 'N/A').toString();

    final womenSeatsAvailable = bus['women_reserved_available'] == true;
    final pwdSeatsAvailable = bus['pwd_reserved_available'] == true;
    final pregnantSeatAvailable = bus['pregnant_women_special_seat_available'] == true;

    final womenSeatsCount =
        int.tryParse((bus['women_reserved_seats_available'] ?? 0).toString()) ?? 0;
    final pwdSeatsCount =
        int.tryParse((bus['pwd_reserved_seats_available'] ?? 0).toString()) ?? 0;

    final busType = (bus['bus_type'] ?? 'NON_AC').toString();
    final delayLabel = delayExpected ? 'Delayed +${delayMinutes}m' : 'On Time';
    final delayColor = delayExpected ? const Color(0xFFB45309) : const Color(0xFF2E7D32);
    final delayBg = delayExpected ? const Color(0xFFFEF3C7) : const Color(0xFFE8F5E9);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFD62828),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  routeNumber,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: busType.toUpperCase().contains('AC')
                      ? const Color(0xFFE0F2FE)
                      : const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  busType.toUpperCase().contains('AC') ? 'AC' : 'NON AC',
                  style: TextStyle(
                    color: busType.toUpperCase().contains('AC')
                        ? const Color(0xFF0369A1)
                        : const Color(0xFF5B21B6),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: delayBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  delayLabel,
                  style: TextStyle(
                    color: delayColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.alt_route, color: Color(0xFF334155), size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$firstStop → $lastStop',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metricChip(icon: Icons.schedule, label: 'ETA', value: '$etaMinutes min'),
              _metricChip(
                icon: Icons.people_alt_outlined,
                label: 'Occupancy',
                value: '$occupancyPercent% ($occupancyLevel)',
              ),
              _metricChip(
                icon: Icons.currency_rupee,
                label: 'Fare',
                value: '$generalFare / $ladiesFare',
              ),
              _metricChip(icon: Icons.access_time_filled_rounded, label: 'Next', value: nextBusTime),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _availabilityPill(
                label: 'Women $womenSeatsCount',
                available: womenSeatsAvailable,
              ),
              _availabilityPill(
                label: 'PWD $pwdSeatsCount',
                available: pwdSeatsAvailable,
              ),
              _availabilityPill(
                label: 'Pregnancy',
                available: pregnantSeatAvailable,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _showStopsSheet(
                      routeNumber: routeNumber,
                      routeStops: routeStops,
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF334155),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  icon: const Icon(Icons.list_alt_outlined, size: 16),
                  label: const Text('Stops'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BusDetails(bus: bus),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF334155),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  icon: const Icon(Icons.info_outline, size: 16),
                  label: const Text('Details'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/payment', arguments: bus);
              },
              icon: const Icon(Icons.confirmation_number_outlined, size: 16),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD62828),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              label: const Text('Book Ticket'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.directions_bus, color: Colors.white),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Bus Routes',
                style: TextStyle(color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            // Data source indicator
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 128),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _dataSourceInfo,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
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

          _sensorInputPanel(),
          
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
                              onTap: () =>
                                  onSourceSuggestionSelected(sourceSuggestions[index]),
                            );
                          },
                        ),
                      ),
                    ],

                    // Recent sources
                    if (recentSources.isNotEmpty && sourceController.text.isEmpty) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Recent searches:',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Wrap(
                        spacing: 8,
                        children: recentSources
                            .map(
                              (stop) => ActionChip(
                                label: Text(
                                  stop,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                onPressed: () => onSourceSuggestionSelected(stop),
                              ),
                            )
                            .toList(),
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
                        _debounceDestination =
                            Timer(const Duration(milliseconds: 300), () async {
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
                              onTap: () => onDestinationSuggestionSelected(
                                destinationSuggestions[index],
                              ),
                            );
                          },
                        ),
                      ),
                    ],

                    // Recent destinations
                    if (recentDestinations.isNotEmpty &&
                        destinationController.text.isEmpty) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Recent destinations:',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Wrap(
                        spacing: 8,
                        children: recentDestinations
                            .map(
                              (stop) => ActionChip(
                                label: Text(
                                  stop,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                onPressed: () =>
                                    onDestinationSuggestionSelected(stop),
                              ),
                            )
                            .toList(),
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
                        padding: const EdgeInsets.only(bottom: 14),
                        itemCount: filteredBuses.length,
                        itemBuilder: (context, index) {
                          final bus =
                              filteredBuses[index].cast<String, dynamic>();
                          return _buildRouteCard(bus);
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
