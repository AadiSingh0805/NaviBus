import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:navibus/screens/Feedback.dart';
import 'package:navibus/screens/paymentopts.dart';

class Payment extends StatefulWidget {
  final dynamic bus; // Bus details passed from BusOptions

  const Payment({super.key, required this.bus});

  @override
  _PaymentState createState() => _PaymentState();
}

class _PaymentState extends State<Payment> {
  List<String> stops = [];

  @override
  void initState() {
    super.initState();
    loadStops();
  }

  Future<void> loadStops() async {
    try {
      String data = await rootBundle.loadString('assets/stops.json');
      Map<String, dynamic> stopsJson = json.decode(data);
      String busNo = widget.bus['bus_no'];
      setState(() {
        stops = stopsJson[busNo]?.cast<String>() ?? ["Unknown"];
      });
    } catch (e) {
      print("Error loading stops: $e");
    }
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
              // Navigate to Profile Page
            },
          ),
        ],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: stops.isEmpty
          ? const Center(child: CircularProgressIndicator()) // Show loader while fetching stops
          : SingleChildScrollView( // ✅ Fixes overflow
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.directions_bus, size: 30, color: Colors.blueAccent),
                            const SizedBox(width: 10),
                            Expanded( // ✅ Ensures wrapping
                              child: Text(
                                stops.first, // Source Stop
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                                softWrap: true,
                                overflow: TextOverflow.visible,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (stops.length > 2)
                          Column(
                            children: stops.sublist(1, stops.length - 1).map((stop) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Text(stop, style: const TextStyle(color: Colors.grey)),
                              );
                            }).toList(),
                          ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.location_on, size: 30, color: Colors.green),
                            const SizedBox(width: 10),
                            Expanded( // ✅ Ensures wrapping
                              child: Text(
                                stops.last, // Destination Stop
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                                softWrap: true,
                                overflow: TextOverflow.visible,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 50),
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
                        const Text(
                          "Payment Details",
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        Image.asset("assets/logo.png", height: 200),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Table(
                            border: TableBorder.symmetric(
                              inside: const BorderSide(width: 1, color: Colors.grey),
                            ),
                            children: [
                              buildTableRow("Type", "Qty.", "Price", isHeader: true),
                              buildTableRow("Adult", "2", "₹20"),
                              buildTableRow("Child", "1", "₹5"),
                              buildTableRow("Total", "", "₹25", isTotal: true),
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

  TableRow buildTableRow(String type, String qty, String price, {bool isHeader = false, bool isTotal = false}) {
    return TableRow(
      decoration: BoxDecoration(
        color: isHeader ? Colors.grey[200] : Colors.white,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(type, style: TextStyle(fontWeight: isHeader || isTotal ? FontWeight.bold : FontWeight.normal)),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(qty, textAlign: TextAlign.center, style: TextStyle(fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(price, textAlign: TextAlign.right, style: TextStyle(fontWeight: isTotal ? FontWeight.bold : FontWeight.normal, color: isTotal ? Colors.green : Colors.black)),
        ),
      ],
    );
  }
}
