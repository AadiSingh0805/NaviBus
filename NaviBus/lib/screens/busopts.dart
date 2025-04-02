import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:navibus/screens/Feedback.dart';
import 'payment.dart';

class BusOptions extends StatefulWidget {
  const BusOptions({super.key});

  @override
  State<BusOptions> createState() => _BusOptionsState();
}

class _BusOptionsState extends State<BusOptions> {
  TextEditingController destinationController = TextEditingController();
  List<dynamic> allBuses = [];
  List<dynamic> filteredBuses = [];
  Position? currentPosition;

  @override
  void initState() {
    super.initState();
    loadBuses();
    getCurrentLocation();
  }

  /// Get User's GPS Location
  Future<void> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if GPS is enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print("Location services are disabled.");
      return;
    }

    // Request permission
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print("Location permission denied");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print("Location permissions are permanently denied.");
      return;
    }

    // Get current position
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    
    setState(() {
      currentPosition = position;
    });

    print("Current Location: ${position.latitude}, ${position.longitude}");
    filterBuses();
  }

  /// Load bus data from JSON
  Future<void> loadBuses() async {
    try {
      final String response = await rootBundle.loadString('assets/busdata.json');
      final data = json.decode(response);
      setState(() {
        allBuses = data;
        filteredBuses = allBuses; // Show all buses initially
      });
    } catch (e) {
      print("Error loading buses: $e");
    }
  }

  /// Filter buses based on the user's destination & nearest buses
  void filterBuses() {
    if (currentPosition == null) {
      return; // No location available yet
    }

    setState(() {
      filteredBuses = allBuses.where((bus) {
        double busLat = bus["latitude"] ?? 0;
        double busLng = bus["longitude"] ?? 0;
        double distance = Geolocator.distanceBetween(
          currentPosition!.latitude,
          currentPosition!.longitude,
          busLat,
          busLng,
        );

        bool matchesDestination = destinationController.text.isEmpty ||
            bus["destination"]
                .toString()
                .toLowerCase()
                .contains(destinationController.text.toLowerCase().trim());

        return matchesDestination && distance < 5000; // Buses within 5km radius
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "NAVI BUS",
          style: TextStyle(color: Colors.white),
        ),
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
              controller: destinationController,
              decoration: const InputDecoration(
                labelText: "Enter Destination",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.flag, color: Colors.redAccent),
              ),
              onChanged: (value) => filterBuses(),
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
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    Payment(bus: bus),
                              ),
                            );
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
                                          "Bus ${bus['bus_no']} → ${bus['destination']}",
                                          style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black),
                                        ),
                                        const SizedBox(height: 5),
                                        Text("🛣 Route Length: ${bus['route_length']} km",
                                            style: const TextStyle(
                                                fontSize: 14, color: Colors.grey)),
                                        Text("🕒 Duration: ${bus['journey_time']} min",
                                            style: const TextStyle(
                                                fontSize: 14, color: Colors.grey)),
                                        Text("💰 Fare: ₹${bus['fare']}",
                                            style: const TextStyle(
                                                fontSize: 14, color: Colors.green)),
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
