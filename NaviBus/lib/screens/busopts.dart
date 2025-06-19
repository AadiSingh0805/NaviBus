import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:navibus/screens/Feedback.dart';
import 'package:navibus/screens/paymentopts.dart';
import 'package:navibus/screens/bus_details.dart';

class BusOptions extends StatefulWidget {
  const BusOptions({super.key});

  @override
  State<BusOptions> createState() => _BusOptionsState();
}

class _BusOptionsState extends State<BusOptions> {
  TextEditingController sourceController = TextEditingController();
  TextEditingController destinationController = TextEditingController();
  List<dynamic> filteredBuses = [];
  Position? currentPosition;

  // For expanding/collapsing stops
  List<bool> expandedStops = [];

  // Track tap count for each card
  List<int> tapCounts = [];

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

  /// Search routes using Django API
  Future<void> searchRoutes() async {
    final start = sourceController.text.trim();
    final end = destinationController.text.trim();
    if (start.isEmpty || end.isEmpty) {
      print('Source or destination is empty');
      return;
    }
    final url = Uri.parse('http://10.0.2.2:8000/api/routes/search/?start=$start&end=$end');
    print('Calling API: ' + url.toString());
    try {
      final response = await http.get(url);
      print('API response status: ${response.statusCode}');
      print('API response body: ${response.body}');
      if (response.statusCode == 200) {
        List<dynamic> routes = json.decode(response.body);
        List<dynamic> routesWithFare = await Future.wait(routes.map((route) async {
          try {
            final fareUrl = Uri.parse(
              'http://10.0.2.2:8000/api/routes/fare/?route_number=${route['route_number']}&source_stop=${Uri.encodeComponent(route['sub_path'][0])}&destination_stop=${Uri.encodeComponent(route['sub_path'][route['sub_path'].length-1])}'
            );
            final fareRes = await http.get(fareUrl);
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
      setState(() {
        filteredBuses = [];
        expandedStops = [];
      });
      print("Error fetching routes: $e");
    }
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
        child: Column(
          children: [
            TextField(
              controller: sourceController,
              decoration: const InputDecoration(
                labelText: "Enter Source",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on, color: Colors.blueAccent),
              ),
              onChanged: (value) => searchRoutes(),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: destinationController,
              decoration: const InputDecoration(
                labelText: "Enter Destination",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.flag, color: Colors.redAccent),
              ),
              onChanged: (value) => searchRoutes(),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: searchRoutes,
              child: const Text("Search"),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.my_location),
              label: const Text("Use My Location"),
              onPressed: getCurrentLocation,
            ),
            const SizedBox(height: 20),
            Expanded(
              child: filteredBuses.isEmpty
                  ? Column(
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
                  : ListView.builder(
                      itemCount: filteredBuses.length,
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
                                      color: Colors.grey.withOpacity(0.3),
                                      blurRadius: 5,
                                      spreadRadius: 2),
                                ],
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.directions_bus,
                                      size: 50, color: Colors.blueAccent),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Route: ${bus['route_number']}",
                                          style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black),
                                        ),
                                        const SizedBox(height: 5),
                                        // Stops preview with ellipsis
                                        Builder(
                                          builder: (_) {
                                            final stops = (bus['stops'] ?? bus['sub_path']) ?? [];
                                            if (expandedStops[index] || stops.length <= 5) {
                                              return Text("🛣 Stops: ${stops.join(' → ')}",
                                                  style: const TextStyle(fontSize: 14, color: Colors.grey));
                                            } else {
                                              // Show first, up to 2 middle, last with ...
                                              String preview = stops.first;
                                              if (stops.length > 3) {
                                                int mid1 = (stops.length / 2).floor() - 1;
                                                int mid2 = (stops.length / 2).ceil();
                                                preview += ' → ... → ' + stops[mid1] + ' → ... → ' + stops[mid2];
                                              }
                                              preview += ' → ' + stops.last;
                                              return Text("🛣 Stops: $preview",
                                                  style: const TextStyle(fontSize: 14, color: Colors.grey));
                                            }
                                          },
                                        ),
                                        Text("💰 Fare: ₹${bus['fare'] ?? 'N/A'}",
                                            style: const TextStyle(
                                                fontSize: 14, color: Colors.green)),
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
                                                  eta = 'Next bus at ${firstBus}';
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
                                                Text("🕒 $eta", style: const TextStyle(fontSize: 14, color: Colors.blue)),
                                                Text("⏱️ Avg Frequency: ${freq ?? 'N/A'} min", style: const TextStyle(fontSize: 14, color: Colors.grey)),
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
            ),
          ],
        ),
      ),
    );
  }
}
