import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:navibus/screens/feedback.dart';
import 'package:navibus/screens/busopts.dart';
import 'package:navibus/screens/login.dart';
import 'package:navibus/screens/profile_page.dart';
import 'package:navibus/screens/route_search_results.dart';
import 'package:navibus/widgets/offline_widgets.dart';
import 'package:navibus/widgets/backend_settings.dart';
import 'package:navibus/services/data_service.dart';
import 'package:geolocator/geolocator.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  Position? currentPosition;

  @override
  void initState() {
    super.initState();
    getCurrentLocation();
  }

  /// Get User's GPS Location
  Future<void> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print("Location services are disabled. Using test coordinates for PC.");
        currentPosition = Position(
          latitude: 19.031784,
          longitude: 73.0994121,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print("Location permission denied. Using test coordinates for PC.");
          currentPosition = Position(
            latitude: 19.031784,
            longitude: 73.0994121,
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            altitudeAccuracy: 0,
            heading: 0,
            headingAccuracy: 0,
            speed: 0,
            speedAccuracy: 0,
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print("Location permissions permanently denied. Using test coordinates for PC.");
        currentPosition = Position(
          latitude: 19.031784,
          longitude: 73.0994121,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
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
      currentPosition = Position(
        latitude: 19.031784,
        longitude: 73.0994121,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    }
  }

  /// Navigate to BusOptions with GPS functionality
  void _navigateWithGPS() async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('Finding nearby bus stops...'),
            ],
          ),
          duration: Duration(seconds: 5),
          backgroundColor: Color(0xFF042F40),
        ),
      );

      // Get current location if not available
      if (currentPosition == null) {
        await getCurrentLocation();
      }

      if (currentPosition == null) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not get your location. Please enable GPS and try again.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Fetch nearby stops
      final nearbyStops = await _fetchNearbyStops();
      
      // Hide loading indicator
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (nearbyStops.isNotEmpty) {
        _showNearbyStopsModal(nearbyStops);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No bus stops found nearby. Try increasing the search radius.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error finding nearby stops: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Fetch nearby stops from backend API
  Future<List<Map<String, dynamic>>> _fetchNearbyStops() async {
    try {
      final dataService = DataService.instance;
      final backendUrl = await dataService.getCurrentBackendUrl();
      final url = Uri.parse('$backendUrl/api/stops/nearby/?lat=${currentPosition!.latitude}&lon=${currentPosition!.longitude}&radius=2');
      
      print('🔍 Fetching nearby stops from: $url');
      
      final response = await http.get(url).timeout(Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
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
  void _showNearbyStopsModal(List<Map<String, dynamic>> stops) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.near_me, color: Color(0xFF042F40)),
                  SizedBox(width: 10),
                  Text(
                    'Nearby Bus Stops',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF042F40),
                    ),
                  ),
                  Spacer(),
                  Text(
                    '${stops.length} stops',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            // Stops list
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 20),
                itemCount: stops.length,
                itemBuilder: (context, index) {
                  final stop = stops[index];
                  return Card(
                    margin: EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Color(0xFF042F40),
                        child: Icon(Icons.bus_alert, color: Colors.white, size: 20),
                      ),
                      title: Text(
                        stop['name'] ?? 'Unknown Stop',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${stop['distance']?.toStringAsFixed(2) ?? '0.0'} km away',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      trailing: Icon(Icons.directions, color: Color(0xFF042F40)),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BusOptions(),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Enhanced route search with fuzzy matching and comprehensive data
  Future<List<dynamic>> searchRoutesByNumber(String routeNumber) async {
    try {
      print('Searching for route with fuzzy matching: $routeNumber');
      
      // Use DataService to get the correct backend URL
      final dataService = DataService.instance;
      final backendUrl = await dataService.getCurrentBackendUrl();
      
      // Try fuzzy search first for better user experience
      final fuzzyUrl = Uri.parse('$backendUrl/api/routes/fuzzy-search/?route_number=${Uri.encodeComponent(routeNumber)}');
      
      print('Using fuzzy search URL: $fuzzyUrl');
      final response = await http.get(fuzzyUrl).timeout(Duration(seconds: 10));
      print('Fuzzy search API status: ${response.statusCode}, body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['routes'] != null && data['routes'].isNotEmpty) {
          final routes = data['routes'] as List;
          print('Found ${routes.length} fuzzy matches');
          
          // Process routes and add fare calculation for each route segment
          List<dynamic> routesWithFare = await Future.wait(routes.map((route) async {
            try {
              print('Processing route: ${route['route_number']}');
              
              // If the route already has average_fare, use it, otherwise calculate
              if (route['average_fare'] != null && route['average_fare'] > 0) {
                return {
                  ...route,
                  'fare': route['average_fare'],
                  'stops': route['stops'] ?? [],
                  'source': route['source'],
                  'destination': route['destination'],
                  'frequency_weekday': route['frequency_weekday'],
                  'frequency_sunday': route['frequency_sunday'],
                  'match_score': route['match_score'] ?? 100,
                  'search_type': 'fuzzy'
                };
              }
              
              // Calculate fare based on total stops
              final totalStops = route['total_stops'] ?? (route['stops']?.length ?? 0);
              final busType = route['bus_type'] ?? 'Non-AC';
              final isAC = busType.toUpperCase().contains('AC');
              
              double calculatedFare;
              if (isAC) {
                // AC fare pattern
                final acFares = [10, 12, 15, 18, 20, 22, 25, 27, 30, 32, 35, 40, 45, 50, 50, 55, 55, 60, 60, 65, 70, 70, 75, 75, 80, 80, 85, 85, 90, 90, 95, 95, 100, 100, 105, 105, 110, 110, 115, 115, 120];
                calculatedFare = (totalStops <= acFares.length) ? acFares[totalStops - 1].toDouble() : 120.0;
              } else {
                // Non-AC fare pattern
                final nonAcFares = [7, 9, 11, 13, 15, 17, 19, 21, 23, 25, 27, 29, 31, 33, 35, 37, 39, 41, 43, 45, 47];
                calculatedFare = (totalStops <= nonAcFares.length) ? nonAcFares[totalStops - 1].toDouble() : 47.0;
              }

              return {
                ...route,
                'fare': calculatedFare,
                'stops': route['stops'] ?? [],
                'source': route['source'],
                'destination': route['destination'],
                'frequency_weekday': route['frequency_weekday'],
                'frequency_sunday': route['frequency_sunday'],
                'match_score': route['match_score'] ?? 100,
                'search_type': 'fuzzy'
              };
            } catch (e) {
              print('Error processing fuzzy route: $e');
              return route;
            }
          }).toList());
          
          return routesWithFare;
        }
      }
      
      // If fuzzy search didn't work or returned no results, try exact search
      print('Fuzzy search returned no results, trying exact search...');
      final exactUrl = Uri.parse('$backendUrl/api/routes/details/?route_number=${Uri.encodeComponent(routeNumber)}');
      
      print('Using exact search URL: $exactUrl');
      final exactResponse = await http.get(exactUrl).timeout(Duration(seconds: 10));
      print('Exact search API status: ${exactResponse.statusCode}, body: ${exactResponse.body}');
      
      if (exactResponse.statusCode == 200) {
        final exactData = jsonDecode(exactResponse.body);
        print('Found exact match: ${exactData['route_number']}');
        
        // Process the exact match
        final totalStops = exactData['total_stops'] ?? (exactData['stops']?.length ?? 0);
        final busType = exactData['bus_type'] ?? 'Non-AC';
        final isAC = busType.toUpperCase().contains('AC');
        
        double calculatedFare;
        if (exactData['average_fare'] != null && exactData['average_fare'] > 0) {
          calculatedFare = exactData['average_fare'].toDouble();
        } else {
          if (isAC) {
            final acFares = [10, 12, 15, 18, 20, 22, 25, 27, 30, 32, 35, 40, 45, 50, 50, 55, 55, 60, 60, 65, 70, 70, 75, 75, 80, 80, 85, 85, 90, 90, 95, 95, 100, 100, 105, 105, 110, 110, 115, 115, 120];
            calculatedFare = (totalStops <= acFares.length) ? acFares[totalStops - 1].toDouble() : 120.0;
          } else {
            final nonAcFares = [7, 9, 11, 13, 15, 17, 19, 21, 23, 25, 27, 29, 31, 33, 35, 37, 39, 41, 43, 45, 47];
            calculatedFare = (totalStops <= nonAcFares.length) ? nonAcFares[totalStops - 1].toDouble() : 47.0;
          }
        }

        return [{
          ...exactData,
          'fare': calculatedFare,
          'stops': exactData['stops'] ?? [],
          'source': exactData['source'],
          'destination': exactData['destination'],
          'frequency_weekday': exactData['frequency_weekday'],
          'frequency_sunday': exactData['frequency_sunday'],
          'match_score': 100,
          'search_type': 'exact'
        }];
      }
      
      print('No routes found for: $routeNumber');
      return [];
      
    } catch (e) {
      print('Error searching routes: $e');
      return [];
    }
  }

  // Method to handle route search and navigation with fuzzy search feedback
  Future<void> _performRouteSearch(String routeNumber) async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('Searching for route $routeNumber...'),
            ],
          ),
          duration: Duration(seconds: 3),
          backgroundColor: Color(0xFF042F40),
        ),
      );

      // Search for routes
      final routes = await searchRoutesByNumber(routeNumber);
      
      // Hide loading indicator
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (routes.isNotEmpty) {
        // Show results summary with match information
        final exactMatches = routes.where((r) => r['search_type'] == 'exact').length;
        final fuzzyMatches = routes.where((r) => r['search_type'] == 'fuzzy').length;
        
        String resultMessage;
        if (exactMatches > 0) {
          resultMessage = 'Found exact match for route $routeNumber';
        } else if (fuzzyMatches > 0) {
          resultMessage = 'Found ${fuzzyMatches} similar route(s) for "$routeNumber"';
        } else {
          resultMessage = 'Found ${routes.length} route(s)';
        }
        
        // Navigate to route search results page with pre-filled search results
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RouteSearchResultsPage(
              searchQuery: routeNumber,
              initialResults: routes,
            ),
          ),
        ).then((_) {
          // Show success message with match details
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(resultMessage),
                  if (fuzzyMatches > 0) 
                    Text(
                      'Showing routes similar to "$routeNumber"',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No routes found for "$routeNumber"'),
                Text(
                  'Try different variations like "59", "EL AC 59", or "404"',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      print('Error in route search: $e');
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error searching for routes. Please check your connection and try again.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // Keep the old function for backward compatibility but mark as deprecated
  @deprecated
  Future<dynamic> fetchBusByRouteNumber(BuildContext context, String routeNumber) async {
    try {
      print('Searching for route: $routeNumber');
      
      // Use DataService to get the correct backend URL
      final dataService = DataService.instance;
      final backendUrl = await dataService.getCurrentBackendUrl();
      final url = Uri.parse('$backendUrl/api/routes/search/?route_number=$routeNumber');
      
      print('Using backend: $backendUrl');
      final response = await http.get(url);
      print('API status: ${response.statusCode}, body: ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Decoded data: $data');
        if (data is List && data.isNotEmpty) {
          final bus = data[0];
          if (bus['stops'] != null && bus['stops'].isNotEmpty) {
            bus['source'] = bus['stops'][0];
            bus['destination'] = bus['stops'].last;
          }
          return bus;
        }
      }
    } catch (e) {
      print('Error fetching bus: $e');
    }
    return null;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "NAVI BUS",
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Color(0xFF042F40), // Custom Hex Color
        actions: [
          IconButton(
            icon: Icon(Icons.support_agent, color: Colors.white), // Support Icon
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => FeedbackPage()),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.account_circle, color: Colors.white), // Profile Icon
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfilePage()),
              );
            },
          ),
        ],
        iconTheme: IconThemeData(color: Colors.white),
      ),

      body: Column(
        children: [
          // Offline notification banner
          const OfflineNotificationBanner(),
          
          Expanded(
            child: SingleChildScrollView(
              // Add performance optimizations
              physics: const BouncingScrollPhysics(), // Smoother scrolling
              child: Column(
                children: [
                  SizedBox(height: 30),

                  // 🔍 Simple Route Number Search
                  Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.2),
                                spreadRadius: 2,
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: "Enter Route Number (e.g., 59, EL AC 59, 404)",
                              hintStyle: TextStyle(color: Colors.grey[600]),
                              prefixIcon: Icon(Icons.directions_bus, color: Color(0xFF042F40)),
                              suffixIcon: IconButton(
                                icon: Icon(Icons.near_me, color: Color(0xFF042F40)),
                                tooltip: 'Find nearby stops',
                                onPressed: _navigateWithGPS,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            ),
                            textInputAction: TextInputAction.search,
                            onSubmitted: (routeNumber) async {
                              if (routeNumber.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Please enter a route number'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                return;
                              }
                              await _performRouteSearch(routeNumber.trim());
                            },
                          ),
                        ),
                        SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () async {
                            final routeNumber = _searchController.text.trim();
                            if (routeNumber.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Please enter a route number'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              return;
                            }
                            await _performRouteSearch(routeNumber);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF042F40),
                            foregroundColor: Colors.white,
                            minimumSize: Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Search Route',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 50),

                  // 🚍 AC & Non-AC Options
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Flexible(child: _buildBusButton("AC Bus", "assets/acbus.png", context)),
                        Flexible(child: _buildBusButton("Non-AC Bus", "assets/nonacbus.png", context)),
                      ],
                    ),
                  ),

                  SizedBox(height: 80),

                  // 🎫 My Tickets/Passes Button
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => LoginScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF042F40), // Custom Color
                      padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                    ),
                    child: Text("My Tickets/Passes", style: TextStyle(fontSize: 18, color: Colors.white)),
                  ),

                  SizedBox(height: 20),
                  
                  // 📱 Offline Data Download Section
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: DataDownloadWidget(),
                  ),

                  SizedBox(height: 20),

                  // ⚙️ Backend Settings Section
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: BackendSettingsWidget(),
                  ),

                  SizedBox(height: 20),

                  // 📌 Logo & App Name
                  Column(
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: 200, maxHeight: 200),
                        child: Image.asset("assets/logo.png", width: 200, height: 200),
                      ),
                      SizedBox(height: 10),
                      Text("NAVI BUS", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      Text("Driving Navi Mumbai Forward", style: TextStyle(color: Colors.black.withValues(alpha: 0.3), fontSize: 18, fontWeight: FontWeight.w400), maxLines: 1, overflow: TextOverflow.ellipsis),
                      SizedBox(height: 20),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Function to create AC / Non-AC options as buttons
  Widget _buildBusButton(String text, String imagePath, BuildContext context) {
    return Container(
      width: 160,
      height: 150,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2), // Reduce shadow intensity
            blurRadius: 6, // Reduce blur for performance
            spreadRadius: 1, // Reduce spread
            offset: Offset(2, 2), // Smaller offset
          ),
        ],
      ),
      child: Material( // Add Material for better tap feedback
        borderRadius: BorderRadius.circular(10),
        color: Colors.white,
        child: InkWell( // Better touch feedback than ElevatedButton
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const BusOptions()),
            );
          },
          child: Padding(
            padding: EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  text, 
                  style: TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold, 
                    color: Colors.black
                  ),
                ),
                SizedBox(height: 10),
                // Optimize image loading for mobile
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    imagePath, 
                    width: 140, 
                    height: 80, 
                    fit: BoxFit.contain,
                    // Add caching and performance optimizations
                    cacheWidth: 280, // Optimize for mobile resolution
                    cacheHeight: 160,
                    filterQuality: FilterQuality.medium, // Balance quality/performance
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
