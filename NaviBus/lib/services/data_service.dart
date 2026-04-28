import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class DataService {
  static const String _baseUrl = 'http://10.0.2.2:8000';
  static const String _productionUrl =
      'https://navibus-lwpp.onrender.com'; // Your live Render backend
  static const Duration _requestTimeout = Duration(seconds: 10);
  static const Duration _cacheTimeout = Duration(hours: 6); // Cache for 6 hours
  static const Duration _backendResolutionCacheTimeout = Duration(minutes: 5);

  // Cache keys
  static const String _lastUpdateKey = 'last_data_update';
  static const String _routesDataKey = 'routes_data_cache';
  static const String _stopsDataKey = 'stops_data_cache';
  static const String _useProductionKey = 'use_production_backend';

  static const List<Map<String, dynamic>> _mockRouteCatalog = [
    {
      'route_number': 'C-1',
      'bus_no': 'C-1',
      'bus_type': 'NON_AC',
      'fare': 20,
      'fare_general': 20,
      'fare_ladies': 14,
      'frequency_weekday': '12',
      'frequency_sunday': '18',
      'first_bus_time_weekday': '05:45',
      'last_bus_time_weekday': '22:50',
      'first_bus_time_sunday': '06:15',
      'last_bus_time_sunday': '22:20',
      'stops': ['Vashi Station', 'Sanpada', 'Nerul', 'Seawoods', 'CBD Belapur'],
    },
    {
      'route_number': 'AC-12',
      'bus_no': 'AC-12',
      'bus_type': 'AC',
      'fare': 35,
      'fare_general': 35,
      'fare_ladies': 26,
      'frequency_weekday': '18',
      'frequency_sunday': '25',
      'first_bus_time_weekday': '06:10',
      'last_bus_time_weekday': '23:15',
      'first_bus_time_sunday': '06:45',
      'last_bus_time_sunday': '22:35',
      'stops': [
        'Airoli Sector 8',
        'Rabale',
        'Ghansoli',
        'Kopar Khairane',
        'Vashi Station',
      ],
    },
    {
      'route_number': 'NMMT-44',
      'bus_no': 'NMMT-44',
      'bus_type': 'NON_AC',
      'fare': 24,
      'fare_general': 24,
      'fare_ladies': 18,
      'frequency_weekday': '15',
      'frequency_sunday': '22',
      'first_bus_time_weekday': '05:30',
      'last_bus_time_weekday': '22:40',
      'first_bus_time_sunday': '06:00',
      'last_bus_time_sunday': '22:00',
      'stops': ['Panvel', 'Kharghar', 'CBD Belapur', 'Nerul', 'Vashi Station'],
    },
    {
      'route_number': 'S-77',
      'bus_no': 'S-77',
      'bus_type': 'NON_AC',
      'fare': 26,
      'fare_general': 26,
      'fare_ladies': 20,
      'frequency_weekday': '14',
      'frequency_sunday': '20',
      'first_bus_time_weekday': '05:50',
      'last_bus_time_weekday': '22:55',
      'first_bus_time_sunday': '06:20',
      'last_bus_time_sunday': '22:25',
      'stops': [
        'Thane Station',
        'Airoli',
        'Rabale',
        'Ghansoli',
        'Kopar Khairane',
      ],
    },
    {
      'route_number': 'AC-88',
      'bus_no': 'AC-88',
      'bus_type': 'AC',
      'fare': 42,
      'fare_general': 42,
      'fare_ladies': 32,
      'frequency_weekday': '20',
      'frequency_sunday': '28',
      'first_bus_time_weekday': '06:20',
      'last_bus_time_weekday': '23:00',
      'first_bus_time_sunday': '06:50',
      'last_bus_time_sunday': '22:30',
      'stops': ['Belapur Depot', 'Seawoods', 'Nerul', 'Sanpada', 'Vashi Plaza'],
    },
    {
      'route_number': 'R-15',
      'bus_no': 'R-15',
      'bus_type': 'NON_AC',
      'fare': 18,
      'fare_general': 18,
      'fare_ladies': 13,
      'frequency_weekday': '10',
      'frequency_sunday': '16',
      'first_bus_time_weekday': '05:40',
      'last_bus_time_weekday': '22:20',
      'first_bus_time_sunday': '06:10',
      'last_bus_time_sunday': '21:55',
      'stops': [
        'Nerul East',
        'Juinagar',
        'Sanpada',
        'Vashi Station',
        'Mankhurd Check Naka',
      ],
    },
  ];

  static DataService? _instance;
  static DataService get instance => _instance ??= DataService._();
  DataService._();

  String? _cachedBackendUrl;
  DateTime? _cachedBackendUrlAt;

  /// Determine which backend URL to use
  /// Automatically uses production in release mode, development in debug mode
  /// Can be overridden by user preference
  Future<String> _getBackendUrl() async {
    final cachedUrl = _cachedBackendUrl;
    final cachedAt = _cachedBackendUrlAt;
    if (cachedUrl != null && cachedAt != null) {
      if (DateTime.now().difference(cachedAt) <
          _backendResolutionCacheTimeout) {
        return cachedUrl;
      }
    }

    final prefs = await SharedPreferences.getInstance();

    // Check if user has manually set a preference
    if (prefs.containsKey(_useProductionKey)) {
      final useProduction = prefs.getBool(_useProductionKey) ?? false;
      final resolvedUrl = useProduction ? _productionUrl : _baseUrl;
      _cachedBackendUrl = resolvedUrl;
      _cachedBackendUrlAt = DateTime.now();
      return resolvedUrl;
    }

    // Auto-detect based on availability. For now prefer local PC Django backend
    // unless the user explicitly set the production preference.
    if (await _isLocalBackendAvailable()) {
      _cachedBackendUrl = _baseUrl;
      _cachedBackendUrlAt = DateTime.now();
      return _baseUrl;
    } else {
      _cachedBackendUrl = _productionUrl;
      _cachedBackendUrlAt = DateTime.now();
      return _productionUrl;
    }
  }

  /// Check if local backend is available
  Future<bool> _isLocalBackendAvailable() async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/api/health/'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Toggle between local and production backend
  Future<void> setBackendMode({required bool useProduction}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useProductionKey, useProduction);
    _cachedBackendUrl = useProduction ? _productionUrl : _baseUrl;
    _cachedBackendUrlAt = DateTime.now();
  }

  /// Get current backend information
  Future<Map<String, dynamic>> getBackendInfo() async {
    final currentUrl = await _getBackendUrl();
    final isProduction = currentUrl.contains('onrender.com');
    final isLocal =
        currentUrl.contains('10.0.2.2') || currentUrl.contains('localhost');

    return {
      'url': currentUrl,
      'isProduction': isProduction,
      'isLocal': isLocal,
      'mode': isProduction ? 'Production' : 'Development',
      'status': await _isBackendReachable(currentUrl),
    };
  }

  /// Get current backend URL (public method for search)
  Future<String> getCurrentBackendUrl() async {
    return await _getBackendUrl();
  }

  /// Check if backend is reachable
  Future<bool> _isBackendReachable(String baseUrl) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/health/'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Check if cached data is still valid (public for utils)
  Future<bool> isCacheValid() async {
    final prefs = await SharedPreferences.getInstance();
    final lastUpdate = prefs.getInt(_lastUpdateKey);
    if (lastUpdate == null) return false;

    final lastUpdateTime = DateTime.fromMillisecondsSinceEpoch(lastUpdate);
    final now = DateTime.now();
    return now.difference(lastUpdateTime) < _cacheTimeout;
  }

  /// Load data from local assets as fallback
  Future<Map<String, dynamic>> _loadLocalAssets() async {
    try {
      final busDataString = await rootBundle.loadString('assets/busdata.json');
      final stopsDataString = await rootBundle.loadString('assets/stops.json');

      return {
        'routes': json.decode(busDataString),
        'stops': json.decode(stopsDataString),
        'source': 'local_assets',
      };
    } catch (e) {
      print('Error loading local assets: $e');
      return {'routes': [], 'stops': {}, 'source': 'error'};
    }
  }

  /// Load data from cache
  Future<Map<String, dynamic>?> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final routesData = prefs.getString(_routesDataKey);
      final stopsData = prefs.getString(_stopsDataKey);

      if (routesData != null && stopsData != null) {
        return {
          'routes': json.decode(routesData),
          'stops': json.decode(stopsData),
          'source': 'cache',
        };
      }
    } catch (e) {
      print('Error loading from cache: $e');
    }
    return null;
  }

  /// Save data to cache
  Future<void> _saveToCache(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_routesDataKey, json.encode(data['routes']));
      await prefs.setString(_stopsDataKey, json.encode(data['stops']));
      await prefs.setInt(_lastUpdateKey, DateTime.now().millisecondsSinceEpoch);
      print('Data cached successfully');
    } catch (e) {
      print('Error saving to cache: $e');
    }
  }

  /// Fetch data from backend with timeout (public for utils)
  Future<Map<String, dynamic>?> fetchFromBackend() async {
    try {
      final baseUrl = await _getBackendUrl();

      // Fetch routes and stops in parallel
      final routesFuture = http
          .get(Uri.parse('$baseUrl/api/routes/'))
          .timeout(_requestTimeout);

      final stopsFuture = http
          .get(Uri.parse('$baseUrl/api/stops/'))
          .timeout(_requestTimeout);

      final responses = await Future.wait([routesFuture, stopsFuture]);

      if (responses[0].statusCode == 200 && responses[1].statusCode == 200) {
        final routesData = json.decode(responses[0].body);
        final stopsData = json.decode(responses[1].body);

        final result = {
          'routes': routesData,
          'stops': stopsData,
          'source': 'backend',
        };

        // Cache the fresh data
        await _saveToCache(result);
        return result;
      } else {
        print(
          'Backend returned error: Routes ${responses[0].statusCode}, Stops ${responses[1].statusCode}',
        );
      }
    } catch (e) {
      print('Error fetching from backend: $e');
    }
    return null;
  }

  /// Main method to get data with fallback strategy
  Future<Map<String, dynamic>> getAllData() async {
    // Strategy 1: Try backend first if cache is invalid
    if (!await isCacheValid()) {
      print('Cache invalid, trying backend...');
      final backendData = await fetchFromBackend();
      if (backendData != null) {
        print('✅ Data loaded from backend');
        return backendData;
      }
    }

    // Strategy 2: Use cache if available
    print('Trying cache...');
    final cachedData = await _loadFromCache();
    if (cachedData != null && await isCacheValid()) {
      print('✅ Data loaded from cache');
      return cachedData;
    }

    // Strategy 3: Try backend one more time (in case cache was old)
    print('Cache miss, trying backend again...');
    final backendData = await fetchFromBackend();
    if (backendData != null) {
      print('✅ Data loaded from backend (second attempt)');
      return backendData;
    }

    // Strategy 4: Fallback to local assets
    print('⚠️ Backend unavailable, using local assets');
    return await _loadLocalAssets();
  }

  /// Force refresh data from backend
  Future<Map<String, dynamic>> forceRefresh() async {
    print('Force refreshing data...');
    final backendData = await fetchFromBackend();
    if (backendData != null) {
      return backendData;
    }
    // If backend fails, return cached or local data
    return await getAllData();
  }

  /// Search routes with fallback
  Future<List<dynamic>> searchRoutes(String start, String end) async {
    try {
      final baseUrl = await _getBackendUrl();
      final url = Uri.parse(
        '$baseUrl/api/routes/search/?start=$start&end=$end',
      );

      final response = await http.get(url).timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final decoded = List<dynamic>.from(json.decode(response.body));
        if (decoded.isNotEmpty) {
          return decoded;
        }
      }
    } catch (e) {
      print('Backend search failed: $e, using local fallback');
    }

    // Fallback: Search in local data
    return await _searchRoutesLocally(start, end);
  }

  /// Local route search implementation
  Future<List<dynamic>> _searchRoutesLocally(String start, String end) async {
    final data = await getAllData();
    final routes = data['routes'] as List<dynamic>;
    final stops = data['stops'] as Map<String, dynamic>;

    List<dynamic> matchingRoutes = [];

    for (var route in routes) {
      final routeNumber = route['bus_no'].toString();
      final routeStops = stops[routeNumber] as List<dynamic>?;

      if (routeStops != null) {
        final startIndex = routeStops.indexWhere(
          (stop) => stop.toString().toLowerCase().contains(start.toLowerCase()),
        );
        final endIndex = routeStops.indexWhere(
          (stop) => stop.toString().toLowerCase().contains(end.toLowerCase()),
        );

        if (startIndex != -1 && endIndex != -1 && startIndex < endIndex) {
          final subPath = routeStops.sublist(startIndex, endIndex + 1);
          final busType =
              (route['bus_type'] ??
                      (routeNumber.contains('AC') ? 'AC' : 'NON_AC'))
                  .toString();
          final fareGeneral =
              int.tryParse(
                (route['fare_general'] ?? route['fare'] ?? 20).toString(),
              ) ??
              20;
          final fareLadies = int.tryParse(
            (route['fare_ladies'] ?? '').toString(),
          );

          matchingRoutes.add({
            ...route,
            ..._buildMockOperationalFields(
              routeNumber: routeNumber,
              busType: busType,
              fareGeneral: fareGeneral,
              fareLadies: fareLadies,
            ),
            'sub_path': subPath,
            'route_number': routeNumber,
          });
        }
      }
    }

    if (matchingRoutes.isNotEmpty) {
      return matchingRoutes;
    }

    return _searchRoutesFromMockCatalog(start, end);
  }

  List<dynamic> _searchRoutesFromMockCatalog(String start, String end) {
    final normalizedStart = start.toLowerCase();
    final normalizedEnd = end.toLowerCase();

    final exactMatches = <Map<String, dynamic>>[];
    final fuzzyMatches = <Map<String, dynamic>>[];

    for (final mockRoute in _mockRouteCatalog) {
      final routeStops = List<String>.from(mockRoute['stops'] as List<dynamic>);
      final startIndex = routeStops.indexWhere(
        (stop) => stop.toLowerCase().contains(normalizedStart),
      );
      final endIndex = routeStops.indexWhere(
        (stop) => stop.toLowerCase().contains(normalizedEnd),
      );

      if (startIndex != -1 && endIndex != -1 && startIndex < endIndex) {
        final subPath = routeStops.sublist(startIndex, endIndex + 1);
        exactMatches.add(_buildMockRouteResult(mockRoute, subPath, true));
        continue;
      }

      final hasPartialStart = routeStops.any(
        (stop) => stop.toLowerCase().contains(normalizedStart),
      );
      final hasPartialEnd = routeStops.any(
        (stop) => stop.toLowerCase().contains(normalizedEnd),
      );

      if (hasPartialStart || hasPartialEnd) {
        fuzzyMatches.add(_buildMockRouteResult(mockRoute, routeStops, false));
      }
    }

    if (exactMatches.isNotEmpty) {
      return exactMatches;
    }

    if (fuzzyMatches.isNotEmpty) {
      return fuzzyMatches;
    }

    return _mockRouteCatalog
        .map(
          (route) => _buildMockRouteResult(
            route,
            List<String>.from(route['stops'] as List<dynamic>),
            false,
          ),
        )
        .toList();
  }

  Map<String, dynamic> _buildMockRouteResult(
    Map<String, dynamic> route,
    List<String> subPath,
    bool exactMatch,
  ) {
    final routeNumber = route['route_number'].toString();
    final busType = (route['bus_type'] ?? 'NON_AC').toString();
    final fareGeneral =
        int.tryParse(
          (route['fare_general'] ?? route['fare'] ?? 20).toString(),
        ) ??
        20;
    final fareLadies = int.tryParse((route['fare_ladies'] ?? '').toString());

    return {
      ...route,
      ..._buildMockOperationalFields(
        routeNumber: routeNumber,
        busType: busType,
        fareGeneral: fareGeneral,
        fareLadies: fareLadies,
      ),
      'route_number': routeNumber,
      'bus_no': routeNumber,
      'sub_path': subPath,
      'stops': subPath,
      'num_stops': subPath.length,
      'source': exactMatch ? 'mock_exact_match' : 'mock_fallback',
    };
  }

  Map<String, dynamic> _buildMockOperationalFields({
    required String routeNumber,
    required String busType,
    required int fareGeneral,
    int? fareLadies,
  }) {
    final rnd = Random();
    final womenSeatsTotal = 6;
    final womenSeatsAvailable = rnd.nextInt(womenSeatsTotal + 1);
    final pwdSeatsTotal = 2;
    final pwdSeatsAvailable = rnd.nextInt(pwdSeatsTotal + 1);
    final pregnantSeatsAvailable = rnd.nextBool();
    final occupancy = 20 + rnd.nextInt(80); // 20-99%
    final delayExpected = rnd.nextBool();
    final delayMinutes = delayExpected ? 1 + rnd.nextInt(15) : 0;
    final etaMinutes = 3 + rnd.nextInt(20) + delayMinutes;
    final ladiesFare = fareLadies ?? (fareGeneral * 0.75).round();

    return {
      'eta_minutes': etaMinutes,
      'passenger_occupancy_percent': occupancy,
      'passenger_occupancy_level':
          occupancy >= 85
              ? 'High'
              : occupancy >= 60
              ? 'Moderate'
              : 'Low',
      'women_reserved_seats_total': womenSeatsTotal,
      'women_reserved_seats_available': womenSeatsAvailable,
      'women_reserved_available': womenSeatsAvailable > 0,
      'pwd_reserved_seats_total': pwdSeatsTotal,
      'pwd_reserved_seats_available': pwdSeatsAvailable,
      'pwd_reserved_available': pwdSeatsAvailable > 0,
      'pregnant_women_special_seat_available': pregnantSeatsAvailable,
      'delay_expected': delayExpected,
      'delay_minutes': delayMinutes,
      'bus_type': busType,
      'fare_general': fareGeneral,
      'fare_ladies': ladiesFare,
      'fare': fareGeneral,
    };
  }

  /// Get fare information with fallback
  Future<Map<String, dynamic>> getFare({
    required String routeNumber,
    required String sourceStop,
    required String destinationStop,
  }) async {
    try {
      final baseUrl = await _getBackendUrl();
      final url = Uri.parse(
        '$baseUrl/api/routes/fare/?route_number=$routeNumber&source_stop=$sourceStop&destination_stop=$destinationStop',
      );

      final response = await http.get(url).timeout(_requestTimeout);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print('Backend fare lookup failed: $e, using local calculation');
    }

    // Fallback: Calculate fare locally
    return await _calculateFareLocally(
      routeNumber,
      sourceStop,
      destinationStop,
    );
  }

  /// Local fare calculation
  Future<Map<String, dynamic>> _calculateFareLocally(
    String routeNumber,
    String sourceStop,
    String destinationStop,
  ) async {
    final data = await getAllData();
    final routes = data['routes'] as List<dynamic>;
    final stops = data['stops'] as Map<String, dynamic>;

    // Find the route
    final route = routes.firstWhere(
      (r) => r['bus_no'].toString() == routeNumber,
      orElse: () => null,
    );

    if (route == null) {
      return {
        'error': 'Route not found',
        'fare': 0,
        'fare_general': 0,
        'fare_ladies': 0,
        'stops': [],
      };
    }

    final routeStops = stops[routeNumber] as List<dynamic>?;
    if (routeStops == null) {
      return {
        'error': 'Route stops not found',
        'fare': 0,
        'fare_general': 0,
        'fare_ladies': 0,
        'stops': [],
      };
    }

    // Find stop indices
    final startIndex = routeStops.indexWhere(
      (stop) =>
          stop.toString().toLowerCase().contains(sourceStop.toLowerCase()),
    );
    final endIndex = routeStops.indexWhere(
      (stop) =>
          stop.toString().toLowerCase().contains(destinationStop.toLowerCase()),
    );

    if (startIndex == -1 || endIndex == -1 || startIndex >= endIndex) {
      return {
        'error': 'Invalid stops',
        'fare': 0,
        'fare_general': 0,
        'fare_ladies': 0,
        'stops': [],
      };
    }

    final numStops = endIndex - startIndex;
    final subPath = routeStops.sublist(startIndex, endIndex + 1);

    // Simple fare calculation (you can make this more sophisticated)
    final baseFare =
        int.tryParse(
          (route['fare_general'] ?? route['fare'] ?? 20).toString(),
        ) ??
        20;
    final calculatedFare = (baseFare * (numStops / 5)).round().clamp(
      5,
      baseFare,
    );
    final ladiesFare =
        int.tryParse((route['fare_ladies'] ?? '').toString()) ??
        (calculatedFare * 0.75).round();

    return {
      'fare': calculatedFare,
      'fare_general': calculatedFare,
      'fare_ladies': ladiesFare,
      'stops': subPath,
      'num_stops': numStops,
      'bus_type':
          (route['bus_type'] ?? (routeNumber.contains('AC') ? 'AC' : 'NON_AC'))
              .toString(),
    };
  }

  /// Get stop suggestions for autocomplete
  Future<List<String>> getStopSuggestions(String query) async {
    if (query.isEmpty) return [];

    try {
      final baseUrl = await _getBackendUrl();
      final url = Uri.parse(
        '$baseUrl/api/stops/autocomplete/?q=${Uri.encodeComponent(query)}',
      );

      final response = await http.get(url).timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<String>.from(data['results'] ?? []);
      }
    } catch (e) {
      print('Backend autocomplete failed: $e, using local search');
    }

    // Fallback: Search locally
    return await _getStopSuggestionsLocally(query);
  }

  /// Local stop suggestions
  Future<List<String>> _getStopSuggestionsLocally(String query) async {
    final data = await getAllData();
    final stops = data['stops'] as Map<String, dynamic>;

    Set<String> suggestions = {};
    final queryLower = query.toLowerCase();

    stops.forEach((routeNumber, routeStops) {
      if (routeStops is List) {
        for (var stop in routeStops) {
          final stopName = stop.toString();
          if (stopName.toLowerCase().contains(queryLower)) {
            suggestions.add(stopName);
          }
        }
      }
    });

    for (final route in _mockRouteCatalog) {
      final routeStops = route['stops'] as List<dynamic>;
      for (final stop in routeStops) {
        final stopName = stop.toString();
        if (stopName.toLowerCase().contains(queryLower)) {
          suggestions.add(stopName);
        }
      }
    }

    return suggestions.take(10).toList();
  }

  /// Check backend connectivity
  Future<bool> isBackendAvailable() async {
    try {
      final baseUrl = await _getBackendUrl();
      final response = await http
          .get(Uri.parse('$baseUrl/api/health/'))
          .timeout(Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Get data source info for UI display
  Future<String> getDataSourceInfo() async {
    final data = await getAllData();
    final source = data['source'] as String;

    switch (source) {
      case 'backend':
        return '🟢 Live Data';
      case 'cache':
        return '🟡 Cached Data';
      case 'local_assets':
        return '🔴 Offline Mode';
      default:
        return '❓ Unknown Source';
    }
  }
}
