import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:navibus/services/data_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DataSyncUtil {
  static const String _busDataFileName = 'busdata.json';
  static const String _stopsDataFileName = 'stops.json';
  
  /// Download and cache latest data from backend for offline use
  static Future<Map<String, dynamic>> downloadLatestData() async {
    try {
      final dataService = DataService.instance;
      
      // Try to fetch fresh data from backend
      final backendData = await dataService.fetchFromBackend();
      if (backendData == null) {
        return {
          'success': false,
          'message': 'Backend is not available. Please try again later.',
          'isOffline': true
        };
      }
      
      print('Backend data structure: ${backendData.keys}');
      print('Routes type: ${backendData['routes'].runtimeType}');
      print('Stops type: ${backendData['stops'].runtimeType}');
      
      // Handle different response formats safely
      dynamic routes = backendData['routes'];
      dynamic stops = backendData['stops'];
      
      // Ensure routes is a List
      if (routes is! List) {
        print('Converting routes from ${routes.runtimeType} to List');
        if (routes is Map) {
          // Convert map values to list if needed
          routes = routes.values.toList();
        } else {
          print('Warning: Routes is neither List nor Map, setting to empty list');
          routes = [];
        }
      }
      
      // Ensure stops is a Map
      if (stops is! Map) {
        print('Converting stops from ${stops.runtimeType} to Map');
        if (stops is List) {
          // Convert list to map if needed (using index as key)
          Map<String, dynamic> convertedStops = {};
          for (int i = 0; i < stops.length; i++) {
            convertedStops[i.toString()] = stops[i];
          }
          stops = convertedStops;
        } else {
          print('Warning: Stops is neither Map nor List, setting to empty map');
          stops = <String, dynamic>{};
        }
      }
      
      // Save to cache with extended expiry (24 hours for offline mode)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_routes', json.encode(routes));
      await prefs.setString('cached_stops', json.encode(stops));
      
      // Set download timestamp and offline mode flag
      final now = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt('offline_data_timestamp', now);
      await prefs.setBool('offline_mode_enabled', true);
      
      final routeCount = routes.length;
      final stopCount = stops.length;
      
      print('Successfully processed: $routeCount routes, $stopCount stops');
      
      return {
        'success': true,
        'message': 'Downloaded $routeCount routes and $stopCount stops for offline use',
        'routeCount': routeCount,
        'stopCount': stopCount,
        'timestamp': now
      };
    } catch (e) {
      print('Download error details: $e');
      return {
        'success': false,
        'message': 'Download failed: ${e.toString()}',
        'error': e.toString()
      };
    }
  }
  
  /// Check if offline data is available and valid
  static Future<bool> hasOfflineData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasRoutes = prefs.containsKey('cached_routes');
      final hasStops = prefs.containsKey('cached_stops');
      final offlineModeEnabled = prefs.getBool('offline_mode_enabled') ?? false;
      
      return hasRoutes && hasStops && offlineModeEnabled;
    } catch (e) {
      return false;
    }
  }
  
  /// Get offline data info for display
  static Future<Map<String, dynamic>> getOfflineDataInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt('offline_data_timestamp') ?? 0;
      final hasData = await hasOfflineData();
      
      if (!hasData) {
        return {
          'hasData': false,
          'message': 'No offline data available'
        };
      }
      
      final downloadTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      final difference = now.difference(downloadTime);
      
      String timeAgo;
      if (difference.inDays > 0) {
        timeAgo = '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
      } else if (difference.inHours > 0) {
        timeAgo = '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
      } else {
        timeAgo = '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
      }
      
      return {
        'hasData': true,
        'downloadTime': downloadTime,
        'timeAgo': timeAgo,
        'message': 'Downloaded $timeAgo'
      };
    } catch (e) {
      return {
        'hasData': false,
        'message': 'Error checking offline data'
      };
    }
  }
  
  /// Clear offline data
  static Future<bool> clearOfflineData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_routes');
      await prefs.remove('cached_stops');
      await prefs.remove('offline_data_timestamp');
      await prefs.setBool('offline_mode_enabled', false);
      return true;
    } catch (e) {
      return false;
    }
  }
  static Future<bool> exportDataToDownloads() async {
    try {
      final dataService = DataService.instance;
      final data = await dataService.getAllData();
      
      // Get downloads directory (Android)
      final Directory downloadsDir = Directory('/storage/emulated/0/Download');
      if (!await downloadsDir.exists()) {
        print('Downloads directory not accessible');
        return false;
      }
      
      // Create timestamped backup files
      final timestamp = DateTime.now().toIso8601String().split('T')[0];
      final busFile = File('${downloadsDir.path}/navibus_routes_$timestamp.json');
      final stopsFile = File('${downloadsDir.path}/navibus_stops_$timestamp.json');
      
      await busFile.writeAsString(json.encode(data['routes']));
      await stopsFile.writeAsString(json.encode(data['stops']));
      
      print('Data exported to Downloads folder');
      return true;
    } catch (e) {
      print('Export failed: $e');
      return false;
    }
  }
  
  /// Check if local assets need updating by comparing with backend
  static Future<bool> shouldUpdateAssets() async {
    try {
      final dataService = DataService.instance;
      
      // Load current assets
      final busDataString = await rootBundle.loadString('assets/$_busDataFileName');
      final stopsDataString = await rootBundle.loadString('assets/$_stopsDataFileName');
      final localBusData = json.decode(busDataString) as List;
      final localStopsData = json.decode(stopsDataString) as Map;
      
      // Try to get fresh backend data
      final backendData = await dataService.fetchFromBackend();
      if (backendData == null) return false;
      
      // Compare data sizes/lengths as a simple check
      final backendBusData = backendData['routes'] as List;
      final backendStopsData = backendData['stops'] as Map;
      
      return localBusData.length != backendBusData.length ||
             localStopsData.length != backendStopsData.length;
    } catch (e) {
      print('Asset comparison failed: $e');
      return false;
    }
  }
  
  /// Get data freshness info for UI display
  static Future<String> getDataFreshnessInfo() async {
    try {
      final dataService = DataService.instance;
      final isBackendAvailable = await dataService.isBackendAvailable();
      
      if (!isBackendAvailable) {
        return '📱 Using local assets (offline)';
      }
      
      // Check cache age
      final cacheValid = await dataService.isCacheValid();
      if (cacheValid) {
        return '💾 Using cached data (fresh)';
      } else {
        return '🌐 Loading from server...';
      }
    } catch (e) {
      return '❓ Data status unknown';
    }
  }
  
  /// Generate a simple data update script for developers
  static String generateUpdateScript() {
    return '''
# NaviBus Data Update Script
# Run this to update local assets with latest backend data

import requests
import json

# Backend URLs
ROUTES_URL = "https://navibus-lwpp.onrender.com/api/routes/"
STOPS_URL = "https://navibus-lwpp.onrender.com/api/stops/"

# Asset file paths
ASSETS_DIR = "d:/NMMT_FLUTTER/NaviBus/NaviBus/assets/"
BUS_DATA_FILE = ASSETS_DIR + "busdata.json"
STOPS_FILE = ASSETS_DIR + "stops.json"

try:
    print("📥 Fetching routes data...")
    routes_response = requests.get(ROUTES_URL, timeout=30)
    routes_response.raise_for_status()
    routes_data = routes_response.json()
    
    print("📥 Fetching stops data...")
    stops_response = requests.get(STOPS_URL, timeout=30)
    stops_response.raise_for_status()
    stops_data = stops_response.json()
    
    print("💾 Saving routes to", BUS_DATA_FILE)
    with open(BUS_DATA_FILE, "w", encoding="utf-8") as f:
        json.dump(routes_data, f, indent=2, ensure_ascii=False)
    
    print("💾 Saving stops to", STOPS_FILE)
    with open(STOPS_FILE, "w", encoding="utf-8") as f:
        json.dump(stops_data, f, indent=2, ensure_ascii=False)
    
    print("✅ Local assets updated successfully!")
    print(f"Routes: {len(routes_data)} items")
    print(f"Stops: {len(stops_data)} items")
    
except Exception as e:
    print(f"❌ Update failed: {e}")
    print("💡 Tip: Check your internet connection and backend URL")
''';
  }
}
