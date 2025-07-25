import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:navibus/screens/Feedback.dart';
import 'package:navibus/screens/paymentopts.dart';
import 'package:http/http.dart' as http;
import 'package:navibus/services/data_service.dart';

class Payment extends StatefulWidget {
  final dynamic bus;

  const Payment({super.key, required this.bus});

  @override
  State<Payment> createState() => _PaymentState();
}

class _PaymentState extends State<Payment> {
  List<String> stops = [];
  int fare = 0;
  int adults = 1;
  int children = 0;

  @override
  void initState() {
    super.initState();
    loadBusData();
  }

  Future<void> loadBusData() async {
    try {
      // Use backend API to get fare and stops
      final routeNumber = widget.bus['route_number'] ?? widget.bus['bus_no'];
      final stopsList = widget.bus['sub_path'] ?? [];
      final source = stopsList.isNotEmpty ? stopsList.first : '';
      final destination = stopsList.isNotEmpty ? stopsList.last : '';
      if (routeNumber == null || source == '' || destination == '') {
        setState(() {
          stops = ["Unknown"];
          fare = 0;
        });
        return;
      }
      
      // Use DataService to get the correct backend URL
      final dataService = DataService.instance;
      final backendUrl = await dataService.getCurrentBackendUrl();
      final url = Uri.parse(
        '$backendUrl/api/routes/fare/?route_number=$routeNumber&source_stop=$source&destination_stop=$destination'
      );
      
      final response = await http.get(url).timeout(Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          stops = List<String>.from(data['stops'] ?? []);
          fare = data['fare'] ?? 0;
        });
      } else {
        setState(() {
          stops = ["Unknown"];
          fare = 0;
        });
      }
    } catch (e) {
      setState(() {
        stops = ["Unknown"];
        fare = 0;
      });
      print("Error loading bus data: $e");
    }
  }

  int calculateTotalFare() {
    return (adults * fare) + (children * (fare * 0.5).round());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/logo.png', height: 40), // Added the logo
            const SizedBox(width: 10),
            const Text("NAVI BUS", style: TextStyle(color: Colors.white)),
          ],
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
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: stops.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        const Text(
                          "Selected Route",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 15),
                        Column(
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.directions_bus, size: 30, color: Colors.blueAccent),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    stops.first,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(Icons.location_on, size: 30, color: Colors.green),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    stops.last,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.blueGrey.shade100),
                          ),
                          child: Column(
                            children: stops
                                .map((stop) => Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.circle, size: 10, color: Colors.grey),
                                          const SizedBox(width: 10),
                                          Expanded(child: Text(stop)),
                                        ],
                                      ),
                                    ))
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF042F40),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(25),
                        topRight: Radius.circular(25),
                      ),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Text("Payment Details", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              buildPassengerRow("Adults", adults, (value) => setState(() => adults = value)),
                              buildPassengerRow("Children", children, (value) => setState(() => children = value)),
                              const Divider(),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text("Total", style: TextStyle(fontWeight: FontWeight.bold)),
                                    Text("₹${calculateTotalFare()}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => PaymentOptions(bus: widget.bus)),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text(
                              "Proceed to Payment",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget buildPassengerRow(String label, int count, Function(int) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove, color: Colors.red),
                onPressed: count > 0 ? () => onChanged(count - 1) : null,
              ),
              Text('$count', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.add, color: Colors.green),
                onPressed: () => onChanged(count + 1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
