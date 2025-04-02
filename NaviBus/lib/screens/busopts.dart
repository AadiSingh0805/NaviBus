import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:navibus/screens/Feedback.dart';
import 'payment.dart'; // Import the Payment screen

class BusOptions extends StatefulWidget {
  const BusOptions({super.key});

  @override
  State<BusOptions> createState() => _BusOptionsState();
}

class _BusOptionsState extends State<BusOptions> {
  TextEditingController sourceController = TextEditingController();
  TextEditingController destinationController = TextEditingController();
  List<dynamic> allBuses = [];
  List<dynamic> filteredBuses = [];

  @override
  void initState() {
    super.initState();
    loadBuses();
  }

  Future<void> loadBuses() async {
    try {
      final String response = await rootBundle.loadString('assets/busdata.json');
      final data = json.decode(response);
      setState(() {
        allBuses = data;
      });
    } catch (e) {
      print("Error loading buses: $e");
    }
  }

  void filterBuses() {
    setState(() {
      filteredBuses = allBuses.where((bus) {
        return (sourceController.text.isEmpty ||
                bus["source"].toString().toLowerCase().trim() ==
                    sourceController.text.toLowerCase().trim()) &&
               (destinationController.text.isEmpty ||
                bus["destination"].toString().toLowerCase().trim() ==
                    destinationController.text.toLowerCase().trim());
      }).toList();
    });
  }

  void swapSourceDestination() {
    setState(() {
      String temp = sourceController.text;
      sourceController.text = destinationController.text;
      destinationController.text = temp;
    });
    filterBuses();
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
          IconButton(
            icon: const Icon(Icons.account_circle, color: Colors.white),
            onPressed: () {
              // Navigate to Profile Page (To be implemented)
            },
          ),
        ],
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: sourceController,
                    decoration: const InputDecoration(
                      labelText: "Enter Source",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_on, color: Colors.blueAccent),
                    ),
                    onChanged: (value) => filterBuses(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.swap_horiz, size: 30, color: Colors.blueAccent),
                  onPressed: swapSourceDestination,
                ),
                Expanded(
                  child: TextField(
                    controller: destinationController,
                    decoration: const InputDecoration(
                      labelText: "Enter Destination",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.flag, color: Colors.redAccent),
                    ),
                    onChanged: (value) => filterBuses(),
                  ),
                ),
              ],
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
                                    Payment(bus: bus), // Passing bus details to Payment
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
                                          "${bus['bus_number']} - ${bus['source']} → ${bus['destination']}",
                                          style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black),
                                        ),
                                        const SizedBox(height: 5),
                                        Text("🕒 Duration: ${bus['duration']}",
                                            style: const TextStyle(
                                                fontSize: 14, color: Colors.grey)),
                                        Text("💰 Fare: ₹${bus['fare']}",
                                            style: const TextStyle(
                                                fontSize: 14, color: Colors.green)),
                                        Text("⏳ Arriving in: ${bus['arriving_in']}",
                                            style: const TextStyle(
                                                fontSize: 14, color: Colors.orange)),
                                        Row(
                                          children: [
                                            const Icon(Icons.event_seat,
                                                color: Colors.purple, size: 18),
                                            const SizedBox(width: 5),
                                            Text("Availability: ${bus['availability']}%",
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: bus['availability'] > 50
                                                      ? Colors.green
                                                      : Colors.red,
                                                  fontWeight: FontWeight.bold,
                                                )),
                                          ],
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
