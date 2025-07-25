import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:navibus/services/data_service.dart';
import 'package:navibus/screens/bus_details.dart';

class RouteSearchResultsPage extends StatefulWidget {
  final String searchQuery;
  final List<dynamic> initialResults;

  const RouteSearchResultsPage({
    super.key,
    required this.searchQuery,
    required this.initialResults,
  });

  @override
  State<RouteSearchResultsPage> createState() => _RouteSearchResultsPageState();
}

class _RouteSearchResultsPageState extends State<RouteSearchResultsPage> {
  List<dynamic> routes = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    routes = widget.initialResults;
    if (routes.isEmpty) {
      _searchRoutes();
    }
  }

  Future<void> _searchRoutes() async {
    setState(() {
      isLoading = true;
    });

    try {
      final dataService = DataService.instance;
      final backendUrl = await dataService.getCurrentBackendUrl();
      
      // Try fuzzy search first
      final fuzzyUrl = Uri.parse('$backendUrl/api/routes/fuzzy-search/?route_number=${Uri.encodeComponent(widget.searchQuery)}');
      final response = await http.get(fuzzyUrl).timeout(Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['routes'] != null) {
          setState(() {
            routes = data['routes'] as List;
          });
        }
      }
    } catch (e) {
      print('Error searching routes: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading route data'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Widget _buildRouteCard(dynamic route) {
    final routeNumber = route['route_number'] ?? 'Unknown';
    final busType = route['bus_type'] ?? 'Non-AC';
    final source = route['source'] ?? 'Unknown Source';
    final destination = route['destination'] ?? 'Unknown Destination';
    final totalStops = route['total_stops'] ?? 0;
    final fareValue = route['fare'] ?? route['average_fare'] ?? 0;
    final fare = fareValue is num ? fareValue : 0;
    final matchScore = route['match_score'] ?? 100;
    final isAC = busType.toUpperCase().contains('AC');
    final stops = route['stops'] as List? ?? [];

    return GestureDetector(
      onTap: () {
        // Navigate to bus details page with route information
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BusDetails(bus: route),
          ),
        );
      },
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: LinearGradient(
              colors: isAC 
                  ? [Colors.blue.shade100, Colors.white]
                  : [Colors.green.shade100, Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                blurRadius: 5,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.directions_bus,
                size: 50,
                color: isAC ? Colors.blueAccent : Colors.green,
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Route number with badge
                    Row(
                      children: [
                        Text(
                          "Route: $routeNumber",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isAC ? Colors.blue : Colors.green,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            busType,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (matchScore < 100) ...[
                          SizedBox(width: 4),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${matchScore}%',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    // Source to destination
                    Text(
                      "🛣 From: $source",
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      "🎯 To: $destination",
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    
                    // Fare and stops info
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            "💰 Fare: ₹${fare.toString()}",
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Flexible(
                          child: Text(
                            "🛑 $totalStops stops",
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.blueGrey,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    // Frequency information
                    if (route['frequency_weekday'] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        "⏱️ Every ${route['frequency_weekday']} min (weekdays)",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                    
                    // Expandable stops list
                    if (stops.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ExpansionTile(
                        title: Text(
                          'View All Stops (${stops.length})',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Color(0xFF042F40),
                          ),
                        ),
                        childrenPadding: EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          Container(
                            height: 150,
                            child: ListView.builder(
                              itemCount: stops.length,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: EdgeInsets.symmetric(vertical: 2),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color: isAC ? Colors.blue : Colors.green,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${index + 1}',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 8,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          stops[index],
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade700,
                                          ),
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
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Routes for "${widget.searchQuery}"',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Color(0xFF042F40),
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _searchRoutes,
          ),
        ],
      ),
      body: isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Searching for routes...'),
                ],
              ),
            )
          : routes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No routes found for "${widget.searchQuery}"',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Try searching for different route numbers',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                        ),
                      ),
                      SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF042F40),
                          foregroundColor: Colors.white,
                        ),
                        child: Text('Go Back'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Results header
                    Container(
                      padding: EdgeInsets.all(16),
                      color: Colors.grey.shade100,
                      child: Row(
                        children: [
                          Icon(Icons.search, color: Color(0xFF042F40)),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Found ${routes.length} route(s) for "${widget.searchQuery}"',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF042F40),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Results list
                    Expanded(
                      child: ListView.builder(
                        physics: BouncingScrollPhysics(),
                        itemCount: routes.length,
                        itemBuilder: (context, index) {
                          return _buildRouteCard(routes[index]);
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
