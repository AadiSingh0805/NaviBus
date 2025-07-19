import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class DataService {
  static const String _baseUrl = 'http://10.0.2.2:8000/api';
  static const String _productionUrl = 'https://navibus-lwpp.onrender.com/api'; // Your live Render backend
  static const Duration _requestTimeout = Duration(seconds: 10);
  static const Duration _cacheTimeout = Duration(hours: 6); // Cache for 6 hours
  
  // Cache keys
  static const String _lastUpdateKey = 'last_data_update';
  static const String _routesDataKey = 'routes_data_cache';
  static const String _stopsDataKey = 'stops_data_cache';
  static const String _useProductionKey = 'use_production_backend';

  static DataService? _instance;
  static DataService get instance => _instance ??= DataService._();
  DataService._();

  /// Determine which backend URL to use
  /// Automatically uses production in release mode, development in debug mode
  /// Can be overridden by user preference
  Future<String> _getBackendUrl() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check if user has manually set a preference
    if (prefs.containsKey(_useProductionKey)) {
      final useProduction = prefs.getBool(_useProductionKey) ?? false;
      print('Using manual preference: ${useProduction ? 'Production' : 'Development'}');
      return useProduction ? _productionUrl : _baseUrl;
    }
    
    // Auto-detect based on build mode
    if (kReleaseMode) {
      // Production build - use production backend
      print('Release mode: Using production backend');
      return _productionUrl;
    } else {
      // Debug build - try local first, fallback to production
      print('Debug mode: Checking local backend availability...');
      if (await _isLocalBackendAvailable()) {
        print('Local backend available: Using local backend');
        return _baseUrl;
      } else {
        print('Local backend not available: Falling back to production backend');
        return _productionUrl;
      }
    }
  }

  /// Check if local backend is available
  Future<bool> _isLocalBackendAvailable() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/health/'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Toggle between local and production backend
  Future<void> setBackendMode({required bool useProduction}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useProductionKey, useProduction);
  }

  /// Get current backend information
  Future<Map<String, dynamic>> getBackendInfo() async {
    final currentUrl = await _getBackendUrl();
    final isProduction = currentUrl.contains('onrender.com');
    final isLocal = currentUrl.contains('10.0.2.2') || currentUrl.contains('localhost');
    
    return {
      'url': currentUrl,
      'isProduction': isProduction,
      'isLocal': isLocal,
      'mode': isProduction ? 'Production' : 'Development',
      'status': await _isBackendReachable(currentUrl),
    };
  }

  /// Check if backend is reachable
  Future<bool> _isBackendReachable(String baseUrl) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health/'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(Duration(seconds: 5));
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
        'source': 'local_assets'
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
          'source': 'cache'
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
      final routesFuture = http.get(
        Uri.parse('$baseUrl/routes/'),
      ).timeout(_requestTimeout);
      
      final stopsFuture = http.get(
        Uri.parse('$baseUrl/stops/'),
      ).timeout(_requestTimeout);

      final responses = await Future.wait([routesFuture, stopsFuture]);
      
      if (responses[0].statusCode == 200 && responses[1].statusCode == 200) {
        final routesData = json.decode(responses[0].body);
        final stopsData = json.decode(responses[1].body);
        
        final result = {
          'routes': routesData,
          'stops': stopsData,
          'source': 'backend'
        };
        
        // Cache the fresh data
        await _saveToCache(result);
        return result;
      } else {
        print('Backend returned error: Routes ${responses[0].statusCode}, Stops ${responses[1].statusCode}');
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
      final url = Uri.parse('$baseUrl/routes/search/?start=$start&end=$end');
      
      final response = await http.get(url).timeout(_requestTimeout);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
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
          (stop) => stop.toString().toLowerCase().contains(start.toLowerCase())
        );
        final endIndex = routeStops.indexWhere(
          (stop) => stop.toString().toLowerCase().contains(end.toLowerCase())
        );
        
        if (startIndex != -1 && endIndex != -1 && startIndex < endIndex) {
          final subPath = routeStops.sublist(startIndex, endIndex + 1);
          matchingRoutes.add({
            ...route,
            'sub_path': subPath,
            'route_number': routeNumber,
          });
        }
      }
    }
    
    return matchingRoutes;
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
        '$baseUrl/routes/fare/?route_number=$routeNumber&source_stop=$sourceStop&destination_stop=$destinationStop'
      );
      
      final response = await http.get(url).timeout(_requestTimeout);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print('Backend fare lookup failed: $e, using local calculation');
    }
    
    // Fallback: Calculate fare locally
    return await _calculateFareLocally(routeNumber, sourceStop, destinationStop);
  }

  /// Local fare calculation
  Future<Map<String, dynamic>> _calculateFareLocally(
    String routeNumber, String sourceStop, String destinationStop
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
      return {'error': 'Route not found', 'fare': 0, 'stops': []};
    }
    
    final routeStops = stops[routeNumber] as List<dynamic>?;
    if (routeStops == null) {
      return {'error': 'Route stops not found', 'fare': 0, 'stops': []};
    }
    
    // Find stop indices
    final startIndex = routeStops.indexWhere(
      (stop) => stop.toString().toLowerCase().contains(sourceStop.toLowerCase())
    );
    final endIndex = routeStops.indexWhere(
      (stop) => stop.toString().toLowerCase().contains(destinationStop.toLowerCase())
    );
    
    if (startIndex == -1 || endIndex == -1 || startIndex >= endIndex) {
      return {'error': 'Invalid stops', 'fare': 0, 'stops': []};
    }
    
    final numStops = endIndex - startIndex;
    final subPath = routeStops.sublist(startIndex, endIndex + 1);
    
    // Simple fare calculation (you can make this more sophisticated)
    int baseFare = route['fare'] ?? 20;
    int calculatedFare = (baseFare * (numStops / 5)).round().clamp(5, baseFare);
    
    return {
      'fare': calculatedFare,
      'stops': subPath,
      'num_stops': numStops,
      'bus_type': routeNumber.contains('AC') ? 'AC' : 'NON_AC',
    };
  }

  /// Get stop suggestions for autocomplete
  Future<List<String>> getStopSuggestions(String query) async {
    if (query.isEmpty) return [];
    
    try {
      final baseUrl = await _getBackendUrl();
      final url = Uri.parse('$baseUrl/stops/autocomplete/?q=${Uri.encodeComponent(query)}');
      
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
    
    return suggestions.take(10).toList();
  }

  /// Check backend connectivity
  Future<bool> isBackendAvailable() async {
    try {
      final baseUrl = await _getBackendUrl();
      final response = await http.get(
        Uri.parse('$baseUrl/routes/'),
      ).timeout(Duration(seconds: 5));
      
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
