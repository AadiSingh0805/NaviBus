import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:navibus/screens/feedback.dart';
import 'package:navibus/screens/bus_details.dart';
import 'package:navibus/services/data_service.dart';
import 'dart:async';
import 'package:navibus/screens/multi_route_planner.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BusOptions extends StatefulWidget {
  const BusOptions({super.key});

  @override
  State<BusOptions> createState() => _BusOptionsState();
}

class _BusOptionsState extends State<BusOptions> {
  TextEditingController sourceController = TextEditingController();
  TextEditingController destinationController = TextEditingController();
  FocusNode sourceFocusNode = FocusNode();
  FocusNode destinationFocusNode = FocusNode();
  List<dynamic> filteredBuses = [];

  // GPS position variable
  Position? currentPosition;

  // For expanding/collapsing stops
  List<bool> expandedStops = [];
  List<int> tapCounts = [];

  // For autocomplete with performance optimizations
  List<String> sourceSuggestions = [];
  List<String> destinationSuggestions = [];
  Timer? _debounceSource;
  Timer? _debounceDestination;
  
  // Performance optimizations
  Map<String, List<String>> _suggestionCache = {}; // Cache for suggestions
  bool _isSearching = false; // Prevent multiple concurrent searches
  String _lastSourceQuery = '';
  String _lastDestinationQuery = '';

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

  @override
  void initState() {
    super.initState();
    getCurrentLocation();
    _loadRecentSearches();
  }

  /// Load recent searches from SharedPreferences
  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      recentSources = prefs.getStringList('recent_sources') ?? ['Borivali Station', 'Andheri Station', 'Bandra Station'];
      recentDestinations = prefs.getStringList('recent_destinations') ?? ['Colaba Bus Station', 'Gateway of India', 'Marine Drive'];
      
      // Load frequent searches (stored as JSON)
      final frequentSourcesJson = prefs.getString('frequent_sources') ?? '{}';
      final frequentDestinationsJson = prefs.getString('frequent_destinations') ?? '{}';
      
      frequentSources = Map<String, int>.from(json.decode(frequentSourcesJson));
      frequentDestinations = Map<String, int>.from(json.decode(frequentDestinationsJson));
      
      // Add some default frequent searches if empty
      if (frequentSources.isEmpty) {
        frequentSources = {'Borivali Station': 5, 'Andheri Station': 3, 'Bandra Station': 2};
      }
      if (frequentDestinations.isEmpty) {
        frequentDestinations = {'Colaba Bus Station': 4, 'Gateway of India': 3, 'Marine Drive': 2};
      }
    });
  }

  /// Save recent searches to SharedPreferences
  Future<void> _saveRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('recent_sources', recentSources);
    await prefs.setStringList('recent_destinations', recentDestinations);
    await prefs.setString('frequent_sources', json.encode(frequentSources));
    await prefs.setString('frequent_destinations', json.encode(frequentDestinations));
  }

  /// Get User's GPS Location
  Future<void> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print("Location services are disabled. Using test coordinates for PC.");
        // Use test coordinates for desktop testing (Kalamboli area)
        setState(() {
          currentPosition = Position(
            latitude: 19.031784,
            longitude: 73.0994121,
            timestamp: DateTime.now(),
            accuracy: 10.0,
            altitude: 0.0,
            altitudeAccuracy: 0.0,
            heading: 0.0,
            headingAccuracy: 0.0,
            speed: 0.0,
            speedAccuracy: 0.0,
          );
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print("Location permission denied. Using test coordinates for PC.");
          // Use test coordinates when permission denied
          setState(() {
            currentPosition = Position(
              latitude: 19.031784,
              longitude: 73.0994121,
              timestamp: DateTime.now(),
              accuracy: 10.0,
              altitude: 0.0,
              altitudeAccuracy: 0.0,
              heading: 0.0,
              headingAccuracy: 0.0,
              speed: 0.0,
              speedAccuracy: 0.0,
            );
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print("Location permissions permanently denied. Using test coordinates for PC.");
        setState(() {
          currentPosition = Position(
            latitude: 19.031784,
            longitude: 73.0994121,
            timestamp: DateTime.now(),
            accuracy: 10.0,
            altitude: 0.0,
            altitudeAccuracy: 0.0,
            heading: 0.0,
            headingAccuracy: 0.0,
            speed: 0.0,
            speedAccuracy: 0.0,
          );
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        currentPosition = position;
      });
      print("✅ Got real GPS location: ${position.latitude}, ${position.longitude}");
    } catch (e) {
      print("Error fetching location: $e. Using test coordinates for PC.");
      // Fallback to test coordinates on any error (common on PC)
      setState(() {
        currentPosition = Position(
          latitude: 19.031784,
          longitude: 73.0994121,
          timestamp: DateTime.now(),
          accuracy: 10.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        );
      });
    }
  }

  /// Fetch nearby stops from backend API
  Future<List<Map<String, dynamic>>> fetchNearbyStops(double lat, double lng) async {
    try {
      final dataService = DataService.instance;
      final backendUrl = await dataService.getCurrentBackendUrl();
      final url = Uri.parse('$backendUrl/api/stops/nearby/?lat=$lat&lon=$lng&radius=2');
      
      print('🔍 Fetching nearby stops from: $url');
      
      final response = await http.get(url).timeout(Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<Map<String, dynamic>> stops = List<Map<String, dynamic>>.from(data['stops'] ?? []);
        print('✅ Found ${stops.length} nearby stops');
        return stops;
      } else {
        print('❌ API returned status: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error fetching nearby stops: $e');
      return [];
    }
  }

  /// Show modal with nearby stops
  void showNearbyStopsModal() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => FutureBuilder<List<Map<String, dynamic>>>(
        future: fetchNearbyStopsFromCurrentLocation(),
        builder: (context, snapshot) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.blueAccent, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Nearby Bus Stops',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF042F40),
                      ),
                    ),
                    Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close),
                    ),
                  ],
                ),
                if (currentPosition != null)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your location: ${currentPosition!.latitude.toStringAsFixed(4)}, ${currentPosition!.longitude.toStringAsFixed(4)}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        // Check if using test coordinates
                        if (currentPosition!.latitude == 19.031784 && 
                            currentPosition!.longitude == 73.0994121)
                          Container(
                            margin: EdgeInsets.only(top: 4),
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange),
                            ),
                            child: Text(
                              "⚠️ Using test coordinates (PC mode)",
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.orange[800],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                Divider(),
                Expanded(
                  child: snapshot.connectionState == ConnectionState.waiting
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('Finding nearby stops...'),
                            ],
                          ),
                        )
                      : snapshot.hasError
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                                  SizedBox(height: 16),
                                  Text('Error: ${snapshot.error}'),
                                  SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      showNearbyStopsModal();
                                    },
                                    child: Text('Retry'),
                                  ),
                                ],
                              ),
                            )
                          : snapshot.data!.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.location_off, size: 64, color: Colors.grey),
                                      SizedBox(height: 16),
                                      Text(
                                        'No bus stops found nearby',
                                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Try increasing search radius or check GPS',
                                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: snapshot.data!.length,
                                  itemBuilder: (context, index) {
                                    final stop = snapshot.data![index];
                                    return Card(
                                      margin: EdgeInsets.symmetric(vertical: 4),
                                      child: ListTile(
                                        leading: Container(
                                          padding: EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.blueAccent.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            Icons.directions_bus,
                                            color: Colors.blueAccent,
                                            size: 20,
                                          ),
                                        ),
                                        title: Text(
                                          stop['name'] ?? 'Unknown Stop',
                                          style: TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                        subtitle: Text(
                                          '${stop['distance']} km away',
                                          style: TextStyle(
                                            color: Colors.green,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              onPressed: () {
                                                sourceController.text = stop['name'];
                                                Navigator.pop(context);
                                                addRecentSource(stop['name']);
                                              },
                                              icon: Icon(Icons.my_location, color: Colors.blue),
                                              tooltip: 'Set as source',
                                            ),
                                            IconButton(
                                              onPressed: () {
                                                destinationController.text = stop['name'];
                                                Navigator.pop(context);
                                                addRecentDestination(stop['name']);
                                              },
                                              icon: Icon(Icons.flag, color: Colors.red),
                                              tooltip: 'Set as destination',
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Fetch nearby stops using current position
  Future<List<Map<String, dynamic>>> fetchNearbyStopsFromCurrentLocation() async {
    if (currentPosition == null) {
      await getCurrentLocation();
    }
    
    if (currentPosition == null) {
      throw Exception('Could not get your location');
    }
    
    return await fetchNearbyStops(currentPosition!.latitude, currentPosition!.longitude);
  }

  /// Search routes using Django API
  Future<void> searchRoutes() async {
    final start = sourceController.text.trim();
    final end = destinationController.text.trim();
    if (start.isEmpty || end.isEmpty) {
      print('Source or destination is empty');
      return;
    }
    
    try {
      // Use DataService to get the correct backend URL
      final dataService = DataService.instance;
      final backendUrl = await dataService.getCurrentBackendUrl();
      final url = Uri.parse('$backendUrl/routes/search/?start=$start&end=$end');
      print('Calling API: $url');
      
      final response = await http.get(url).timeout(Duration(seconds: 10));
      print('API response status: ${response.statusCode}');
      print('API response body: ${response.body}');
      if (response.statusCode == 200) {
        List<dynamic> routes = json.decode(response.body);
        List<dynamic> routesWithFare = await Future.wait(routes.map((route) async {
          try {
            final fareUrl = Uri.parse(
              '$backendUrl/routes/fare/?route_number=${route['route_number']}&source_stop=${Uri.encodeComponent(route['sub_path'][0])}&destination_stop=${Uri.encodeComponent(route['sub_path'][route['sub_path'].length-1])}'
            );
            final fareRes = await http.get(fareUrl).timeout(Duration(seconds: 8));
            if (fareRes.statusCode == 200) {
              final fareData = json.decode(fareRes.body);
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
            } else {
              return route;
            }
          } catch (e) {
            print('Error fetching fare: $e');
            return route;
          }
        }).toList());
        setState(() {
          filteredBuses = routesWithFare;
          expandedStops = List.filled(routesWithFare.length, false);
          tapCounts = List.filled(routesWithFare.length, 0);
        });
      } else {
        setState(() {
          filteredBuses = [];
          expandedStops = [];
        });
      }
    } catch (e) {
      print('Error searching routes: $e');
      setState(() {
        filteredBuses = [];
        expandedStops = [];
      });
      print("Error fetching routes: $e");
    }
  }

  Future<List<String>> fetchStopSuggestions(String query) async {
    if (query.isEmpty) return [];
    
    // Check cache first for performance
    if (_suggestionCache.containsKey(query.toLowerCase())) {
      print('Returning cached suggestions for "$query"');
      return _suggestionCache[query.toLowerCase()]!;
    }
    
    // Prevent multiple concurrent searches
    if (_isSearching) {
      print('Search already in progress, skipping...');
      return [];
    }
    
    _isSearching = true;
    List<String> results = [];
    
    try {
      // Use DataService to get the correct backend URL
      final dataService = DataService.instance;
      final backendUrl = await dataService.getCurrentBackendUrl();
      final url = Uri.parse('$backendUrl/stops/autocomplete/?q=${Uri.encodeComponent(query)}');
      
      final response = await http.get(url).timeout(Duration(seconds: 3)); // Reduced timeout
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        results = List<String>.from(data['results'] ?? []);
        
        // Cache the results for better performance
        _suggestionCache[query.toLowerCase()] = results;
        
        // Limit cache size to prevent memory issues
        if (_suggestionCache.length > 50) {
          _suggestionCache.clear();
        }
        
        print('Got ${results.length} suggestions for "$query" from API');
      } else {
        print('Autocomplete API returned ${response.statusCode}');
      }
    } catch (e) {
      print('Autocomplete error: $e');
    }
    
    // Fallback: search through cached data only if API failed
    if (results.isEmpty) {
      try {
        final dataService = DataService.instance;
        final data = await dataService.getAllData();
        
        if (data['stops'] != null) {
          List<String> matches = [];
          for (var stop in data['stops']) {
            if (stop['name'] != null) {
              String stopName = stop['name'].toString();
              if (stopName.toLowerCase().contains(query.toLowerCase())) {
                matches.add(stopName);
              }
            }
          }
          // Sort matches and return top 8
          matches.sort();
          results = matches.take(8).toList();
          
          // Cache fallback results too
          _suggestionCache[query.toLowerCase()] = results;
          
          print('Fallback: Got ${results.length} cached suggestions for "$query"');
        }
      } catch (e) {
        print('Fallback autocomplete error: $e');
      }
    }
    
    _isSearching = false;
    return results;
  }

  void onSourceChanged(String value) {
    // Prevent unnecessary calls if value hasn't changed
    if (value == _lastSourceQuery) return;
    _lastSourceQuery = value;
    
    if (_debounceSource?.isActive ?? false) _debounceSource!.cancel();
    
    // Use shorter debounce for initial typing to make suggestions appear faster
    final debounceTime = value.length <= 2 ? 400 : 600;
    _debounceSource = Timer(Duration(milliseconds: debounceTime), () async {
      if (mounted && value.trim().length >= 1) { // Start showing suggestions from 1 character
        final suggestions = await fetchStopSuggestions(value);
        if (mounted) {
          setState(() {
            sourceSuggestions = suggestions;
          });
        }
      } else if (mounted) {
        setState(() {
          sourceSuggestions = [];
        });
      }
    });
  }

  void onDestinationChanged(String value) {
    // Prevent unnecessary calls if value hasn't changed
    if (value == _lastDestinationQuery) return;
    _lastDestinationQuery = value;
    
    if (_debounceDestination?.isActive ?? false) _debounceDestination!.cancel();
    
    // Use shorter debounce for initial typing to make suggestions appear faster
    final debounceTime = value.length <= 2 ? 400 : 600;
    _debounceDestination = Timer(Duration(milliseconds: debounceTime), () async {
      if (mounted && value.trim().length >= 1) { // Start showing suggestions from 1 character
        final suggestions = await fetchStopSuggestions(value);
        if (mounted) {
          setState(() {
            destinationSuggestions = suggestions;
          });
        }
      } else if (mounted) {
        setState(() {
          destinationSuggestions = [];
        });
      }
    });
  }

  void addRecentSource(String stop) {
    setState(() {
      recentSources.remove(stop);
      recentSources.insert(0, stop);
      if (recentSources.length > maxRecent) recentSources = recentSources.sublist(0, maxRecent);
      frequentSources[stop] = (frequentSources[stop] ?? 0) + 1;
    });
    _saveRecentSearches(); // Persist to storage
  }
  
  void addRecentDestination(String stop) {
    setState(() {
      recentDestinations.remove(stop);
      recentDestinations.insert(0, stop);
      if (recentDestinations.length > maxRecent) recentDestinations = recentDestinations.sublist(0, maxRecent);
      frequentDestinations[stop] = (frequentDestinations[stop] ?? 0) + 1;
    });
    _saveRecentSearches(); // Persist to storage
  }

  Future<void> searchBestJourney() async {
    final start = sourceController.text.trim();
    final end = destinationController.text.trim();
    if (start.isEmpty || end.isEmpty) {
      print('Source or destination is empty');
      return;
    }
    
    try {
      // Use DataService to get the correct backend URL
      final dataService = DataService.instance;
      final backendUrl = await dataService.getCurrentBackendUrl();
      final url = Uri.parse('$backendUrl/routes/plan/?start=$start&end=$end');
      print('Calling planner API: $url');
      
      final response = await http.get(url).timeout(Duration(seconds: 10));
      print('Planner response status: ${response.statusCode}');
      print('Planner response body: ${response.body}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          plannedSegments = data['segments'] ?? [];
          totalStops = data['total_stops'] ?? 0;
          transfers = data['transfers'] ?? 0;
        });
      } else {
        setState(() {
          plannedSegments = [];
          totalStops = 0;
          transfers = 0;
        });
      }
    } catch (e) {
      print('Error fetching planned journey: $e');
      setState(() {
        plannedSegments = [];
        totalStops = 0;
        transfers = 0;
      });
    }
  }

  @override
  void dispose() {
    _debounceSource?.cancel();
    _debounceDestination?.cancel();
    sourceController.dispose();
    destinationController.dispose();
    sourceFocusNode.dispose();
    destinationFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("NAVI BUS", style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: const Color(0xFF042F40),
        actions: [
          IconButton(
            icon: const Icon(Icons.support_agent, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => FeedbackPage()),
              );
            },
          ),
        ],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          // Add mobile performance optimizations
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RawAutocomplete<String>(
                textEditingController: sourceController,
                focusNode: sourceFocusNode,
                optionsBuilder: (TextEditingValue textEditingValue) {
                  final input = textEditingValue.text.toLowerCase().trim();
                  
                  // Debug print to see what's happening
                  print('Source input: "$input", suggestions: ${sourceSuggestions.length}, recents: ${recentSources.length}');
                  print('Available suggestions: $sourceSuggestions');
                  
                  if (input.isEmpty) {
                    // Show recent searches when empty
                    return recentSources.take(5).toList();
                  }
                  
                  final List<String> allOptions = <String>[];
                  
                  // Add recent matches first (more lenient matching)
                  allOptions.addAll(recentSources.where((s) => 
                    s.toLowerCase().contains(input)).take(3));
                  
                  // Add frequent matches (more lenient matching)
                  final frequentMatches = frequentSources.keys.where((s) => 
                    s.toLowerCase().contains(input) && !allOptions.contains(s)).toList()
                    ..sort((a, b) => frequentSources[b]!.compareTo(frequentSources[a]!));
                  allOptions.addAll(frequentMatches.take(3));
                  
                  // Add ALL backend suggestions without strict filtering - let user see everything from API
                  allOptions.addAll(sourceSuggestions.where((s) => 
                    !allOptions.contains(s)).take(8));
                  
                  print('Returning ${allOptions.length} options for "$input": $allOptions');
                  return allOptions.take(10).toList();
                },
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    // Mobile optimizations for better performance
                    textInputAction: TextInputAction.next,
                    keyboardType: TextInputType.text,
                    autofocus: false,
                    // Fix backspace and performance issues
                    autocorrect: false,
                    enableSuggestions: false,
                    maxLines: 1,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: "Enter Source",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Color(0xFF042F40), width: 2),
                      ),
                      prefixIcon: Icon(Icons.location_on, color: Colors.blueAccent),
                      // GPS and Clear buttons
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.near_me, color: Colors.blueAccent),
                            tooltip: 'Find nearby stops',
                            onPressed: () => showNearbyStopsModal(),
                          ),
                          if (controller.text.isNotEmpty)
                            IconButton(
                              icon: Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                controller.clear();
                                onSourceChanged('');
                              },
                            ),
                        ],
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    onChanged: (value) {
                      onSourceChanged(value);
                      // Only rebuild if really needed
                      if (sourceSuggestions.isNotEmpty || value.isEmpty) {
                        setState(() {});
                      }
                    },
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4.0,
                      child: SizedBox(
                        height: 220.0,
                        child: ListView(
                          padding: EdgeInsets.zero,
                          children: [
                            if (recentSources.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                child: Text('Recent', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                              ),
                            ...options.where((s) => recentSources.contains(s)).map((s) => ListTile(
                                  leading: Icon(Icons.history, color: Colors.blueGrey),
                                  title: Text(s),
                                  onTap: () {
                                    onSelected(s);
                                    sourceController.text = s;
                                    addRecentSource(s);
                                    searchRoutes();
                                  },
                                )),
                            if (frequentSources.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                child: Text('Frequent', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                              ),
                            ...options.where((s) => frequentSources.containsKey(s) && !recentSources.contains(s)).map((s) => ListTile(
                                  leading: Icon(Icons.star, color: Colors.green),
                                  title: Text(s),
                                  onTap: () {
                                    onSelected(s);
                                    sourceController.text = s;
                                    addRecentSource(s);
                                    searchRoutes();
                                  },
                                )),
                            if (sourceSuggestions.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                child: Text('Suggestions', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                              ),
                            ...options.where((s) => !recentSources.contains(s) && !frequentSources.containsKey(s)).map((option) => ListTile(
                                  title: Text(option),
                                  onTap: () {
                                    onSelected(option);
                                    sourceController.text = option;
                                    addRecentSource(option);
                                    searchRoutes();
                                  },
                                )),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              RawAutocomplete<String>(
                textEditingController: destinationController,
                focusNode: destinationFocusNode,
                optionsBuilder: (TextEditingValue textEditingValue) {
                  final input = textEditingValue.text.toLowerCase().trim();
                  
                  // Debug print to see what's happening
                  print('Destination input: "$input", suggestions: ${destinationSuggestions.length}, recents: ${recentDestinations.length}');
                  print('Available suggestions: $destinationSuggestions');
                  
                  if (input.isEmpty) {
                    // Show recent searches when empty
                    return recentDestinations.take(5).toList();
                  }
                  
                  final List<String> allOptions = <String>[];
                  
                  // Add recent matches first (more lenient matching)
                  allOptions.addAll(recentDestinations.where((s) => 
                    s.toLowerCase().contains(input)).take(3));
                  
                  // Add frequent matches (more lenient matching)
                  final frequentMatches = frequentDestinations.keys.where((s) => 
                    s.toLowerCase().contains(input) && !allOptions.contains(s)).toList()
                    ..sort((a, b) => frequentDestinations[b]!.compareTo(frequentDestinations[a]!));
                  allOptions.addAll(frequentMatches.take(3));
                  
                  // Add ALL backend suggestions without strict filtering - let user see everything from API
                  allOptions.addAll(destinationSuggestions.where((s) => 
                    !allOptions.contains(s)).take(8));
                  
                  print('Returning ${allOptions.length} options for "$input": $allOptions');
                  return allOptions.take(10).toList();
                },
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    // Mobile optimizations for better performance
                    textInputAction: TextInputAction.search,
                    keyboardType: TextInputType.text,
                    autofocus: false,
                    // Fix backspace and performance issues
                    autocorrect: false,
                    enableSuggestions: false,
                    maxLines: 1,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: "Enter Destination",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Color(0xFF042F40), width: 2),
                      ),
                      prefixIcon: Icon(Icons.flag, color: Colors.redAccent),
                      // Optimized clear button
                      suffixIcon: controller.text.isNotEmpty 
                        ? IconButton(
                            icon: Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              controller.clear();
                              onDestinationChanged('');
                              // Don't call setState here to prevent lag
                            },
                          )
                        : null,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    onChanged: (value) {
                      onDestinationChanged(value);
                      // Only rebuild if really needed
                      if (destinationSuggestions.isNotEmpty || value.isEmpty) {
                        setState(() {});
                      }
                    },
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4.0,
                      child: SizedBox(
                        height: 220.0,
                        child: ListView(
                          padding: EdgeInsets.zero,
                          children: [
                            if (recentDestinations.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                child: Text('Recent', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                              ),
                            ...options.where((s) => recentDestinations.contains(s)).map((s) => ListTile(
                                  leading: Icon(Icons.history, color: Colors.blueGrey),
                                  title: Text(s),
                                  onTap: () {
                                    onSelected(s);
                                    destinationController.text = s;
                                    addRecentDestination(s);
                                    searchRoutes();
                                  },
                                )),
                            if (frequentDestinations.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                child: Text('Frequent', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                              ),
                            ...options.where((s) => frequentDestinations.containsKey(s) && !recentDestinations.contains(s)).map((s) => ListTile(
                                  leading: Icon(Icons.star, color: Colors.green),
                                  title: Text(s),
                                  onTap: () {
                                    onSelected(s);
                                    destinationController.text = s;
                                    addRecentDestination(s);
                                    searchRoutes();
                                  },
                                )),
                            if (destinationSuggestions.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                child: Text('Suggestions', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                              ),
                            ...options.where((s) => !recentDestinations.contains(s) && !frequentDestinations.containsKey(s)).map((option) => ListTile(
                                  title: Text(option),
                                  onTap: () {
                                    onSelected(option);
                                    destinationController.text = option;
                                    addRecentDestination(option);
                                    searchRoutes();
                                  },
                                )),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: searchRoutes,
                child: const Text("Search Direct Routes"),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  icon: Icon(Icons.alt_route, color: Colors.white),
                  label: Text("Multi-Route Journey Planner", style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF042F40),
                    minimumSize: Size(0, 40),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => MultiRoutePlannerScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              if (filteredBuses.isEmpty)
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.bus_alert, size: 80, color: Colors.redAccent),
                    SizedBox(height: 10),
                    Text("No buses available",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black54)),
                  ],
                )
              else
                ListView.builder(
                  // Performance optimizations
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(), // Better mobile scroll feel
                  itemCount: filteredBuses.length,
                  // Add performance improvements
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: true,
                  addSemanticIndexes: false,
                  itemBuilder: (context, index) {
                    var bus = filteredBuses[index];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          tapCounts[index] += 1;
                          if (tapCounts[index] == 1) {
                            expandedStops[index] = !expandedStops[index];
                          } else if (tapCounts[index] == 2) {
                            tapCounts[index] = 0;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => BusDetails(bus: bus),
                              ),
                            );
                          }
                        });
                      },
                      child: Card(
                        elevation: 6,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15)),
                        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        child: Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            gradient: LinearGradient(
                              colors: [Colors.blue.shade100, Colors.white],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.grey.withValues(alpha: 0.3),
                                  blurRadius: 5,
                                  spreadRadius: 2),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.directions_bus,
                                  size: 50, color: Colors.blueAccent),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Route: "+(bus['route_number'] ?? ''),
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 5),
                                    // Stops preview with ellipsis
                                    Builder(
                                      builder: (_) {
                                        final stops = (bus['stops'] ?? bus['sub_path']) ?? [];
                                        if (expandedStops[index] || stops.length <= 5) {
                                          return Text(
                                            "🛣 Stops: ${stops.join(' → ')}",
                                            style: const TextStyle(fontSize: 14, color: Colors.grey),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          );
                                        } else {
                                          // Show first, up to 2 middle, last with ...
                                          String preview = stops.first;
                                          if (stops.length > 3) {
                                            int mid1 = (stops.length / 2).floor() - 1;
                                            int mid2 = (stops.length / 2).ceil();
                                            preview += ' → ... → ' + stops[mid1] + ' → ... → ' + stops[mid2];
                                          }
                                          preview += ' → ' + stops.last;
                                          return Text(
                                            "🛣 Stops: $preview",
                                            style: const TextStyle(fontSize: 14, color: Colors.grey),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          );
                                        }
                                      },
                                    ),
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            "💰 Fare: ₹${bus['fare'] ?? 'N/A'}",
                                            style: const TextStyle(
                                                fontSize: 14, color: Colors.green),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        GestureDetector(
                                          onTap: () {
                                            showDialog(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: const Text('Fare Information'),
                                                content: const Text('This is an approximate calculated fare. Please contact NMMT authorities for exact fare prices.'),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.of(context).pop(),
                                                    child: const Text('OK'),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                          child: const Icon(Icons.info_outline, size: 16, color: Colors.blueGrey),
                                        ),
                                      ],
                                    ),
                                    // ETA and frequency
                                    Builder(
                                      builder: (_) {
                                        final now = DateTime.now();
                                        final isSunday = now.weekday == DateTime.sunday;
                                        final firstBus = isSunday ? bus['first_bus_time_sunday'] : bus['first_bus_time_weekday'];
                                        final lastBus = isSunday ? bus['last_bus_time_sunday'] : bus['last_bus_time_weekday'];
                                        final freq = isSunday ? bus['frequency_sunday'] : bus['frequency_weekday'];
                                        String eta = 'N/A';
                                        if (firstBus != null && lastBus != null && freq != null && firstBus != 'N/A' && lastBus != 'N/A' && freq != 'N/A') {
                                          try {
                                            final today = DateTime(now.year, now.month, now.day);
                                            final firstParts = firstBus.split(":");
                                            final lastParts = lastBus.split(":");
                                            final firstBusTime = DateTime(today.year, today.month, today.day, int.parse(firstParts[0]), int.parse(firstParts[1]));
                                            final lastBusTime = DateTime(today.year, today.month, today.day, int.parse(lastParts[0]), int.parse(lastParts[1]));
                                            final freqInt = int.tryParse(freq.toString()) ?? 0;
                                            final diff = now.difference(firstBusTime).inMinutes;
                                            final afterLast = now.isAfter(lastBusTime.add(Duration(minutes: freqInt)));
                                            if (afterLast) {
                                              eta = 'Next bus: N/A';
                                            } else if (now.isBefore(firstBusTime)) {
                                              eta = 'Next bus at $firstBus';
                                            } else {
                                              int nextBusIn = freqInt - (diff % freqInt);
                                              final nextBusTime = now.add(Duration(minutes: nextBusIn));
                                              if (nextBusTime.isAfter(lastBusTime)) {
                                                eta = 'Next bus: N/A';
                                              } else {
                                                eta = 'Next bus in $nextBusIn min';
                                              }
                                            }
                                          } catch (e) {
                                            eta = 'N/A';
                                          }
                                        }
                                        return Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "🕒 $eta",
                                              style: const TextStyle(fontSize: 14, color: Colors.blue),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              "⏱️ Avg Frequency: ${freq ?? 'N/A'} min",
                                              style: const TextStyle(fontSize: 14, color: Colors.grey),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
