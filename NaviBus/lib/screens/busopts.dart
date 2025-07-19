import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:navibus/screens/feedback.dart';
import 'package:navibus/screens/bus_details.dart';
import 'dart:async';
import 'package:navibus/screens/multi_route_planner.dart';

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
    print('Calling API: $url');
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

  Future<List<String>> fetchStopSuggestions(String query) async {
    if (query.isEmpty) return [];
    final url = Uri.parse('http://10.0.2.2:8000/api/stops/autocomplete/?q=${Uri.encodeComponent(query)}');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<String>.from(data['results'] ?? []);
      }
    } catch (e) {
      print('Autocomplete error: $e');
    }
    return [];
  }

  void onSourceChanged(String value) {
    if (_debounceSource?.isActive ?? false) _debounceSource!.cancel();
    _debounceSource = Timer(const Duration(milliseconds: 300), () async {
      final suggestions = await fetchStopSuggestions(value);
      setState(() {
        sourceSuggestions = suggestions;
      });
    });
  }

  void onDestinationChanged(String value) {
    if (_debounceDestination?.isActive ?? false) _debounceDestination!.cancel();
    _debounceDestination = Timer(const Duration(milliseconds: 300), () async {
      final suggestions = await fetchStopSuggestions(value);
      setState(() {
        destinationSuggestions = suggestions;
      });
    });
  }

  void addRecentSource(String stop) {
    setState(() {
      recentSources.remove(stop);
      recentSources.insert(0, stop);
      if (recentSources.length > maxRecent) recentSources = recentSources.sublist(0, maxRecent);
      frequentSources[stop] = (frequentSources[stop] ?? 0) + 1;
    });
  }
  void addRecentDestination(String stop) {
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
    final url = Uri.parse('http://10.0.2.2:8000/api/routes/plan/?start=$start&end=$end');
    print('Calling planner API: $url');
    try {
      final response = await http.get(url);
      print('Planner response status: \\${response.statusCode}');
      print('Planner response body: \\${response.body}');
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
      setState(() {
        plannedSegments = [];
        totalStops = 0;
        transfers = 0;
      });
      print('Error fetching planned journey: $e');
    }
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RawAutocomplete<String>(
                textEditingController: sourceController,
                focusNode: FocusNode(),
                optionsBuilder: (TextEditingValue textEditingValue) {
                  final input = textEditingValue.text.toLowerCase();
                  final List<String> recents = recentSources.where((s) => s.toLowerCase().contains(input)).toList();
                  final List<String> frequents = frequentSources.keys
                      .where((s) => !recents.contains(s) && s.toLowerCase().contains(input))
                      .toList()
                    ..sort((a, b) => frequentSources[b]!.compareTo(frequentSources[a]!));
                  final List<String> backend = sourceSuggestions
                      .where((s) => !recents.contains(s) && !frequents.contains(s) && s.toLowerCase().contains(input))
                      .toList();
                  return [...recents, ...frequents, ...backend];
                },
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: "Enter Source",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_on, color: Colors.blueAccent),
                    ),
                    onChanged: (value) async {
                      onSourceChanged(value);
                      // Optionally, force dropdown to update
                      setState(() {});
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
                focusNode: FocusNode(),
                optionsBuilder: (TextEditingValue textEditingValue) {
                  final input = textEditingValue.text.toLowerCase();
                  final List<String> recents = recentDestinations.where((s) => s.toLowerCase().contains(input)).toList();
                  final List<String> frequents = frequentDestinations.keys
                      .where((s) => !recents.contains(s) && s.toLowerCase().contains(input))
                      .toList()
                    ..sort((a, b) => frequentDestinations[b]!.compareTo(frequentDestinations[a]!));
                  final List<String> backend = destinationSuggestions
                      .where((s) => !recents.contains(s) && !frequents.contains(s) && s.toLowerCase().contains(input))
                      .toList();
                  return [...recents, ...frequents, ...backend];
                },
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: "Enter Destination",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.flag, color: Colors.redAccent),
                    ),
                    onChanged: (value) async {
                      onDestinationChanged(value);
                      setState(() {});
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
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
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
