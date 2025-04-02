import 'package:flutter/material.dart';
import 'package:navibus/screens/Feedback.dart';
import 'package:navibus/screens/paymentopts.dart';

class Payment extends StatelessWidget {
  final dynamic bus; // Bus details passed from BusOptions

  const Payment({super.key, required this.bus});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "NAVI BUS",
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Color(0xFF042F40), // Custom Hex Color
        actions: [
          IconButton(
            icon: Icon(Icons.support_agent, color: Colors.white), // Support Icon
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => FeedbackPage()),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.account_circle, color: Colors.white), // Profile Icon
            onPressed: () {
              // Navigate to Profile Page
            },
          ),
        ],
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          const SizedBox(height: 40),

          // Bus Route Details
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.directions_bus, size: 30, color: Colors.blueAccent),
                    const SizedBox(width: 10),
                    Text(
                      bus['source'],
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text("Some Stops", style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 30, color: Colors.green),
                    const SizedBox(width: 10),
                    Text(
                      bus['destination'],
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 50),

          // Payment Details Container
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF042F40),
                borderRadius: const BorderRadius.only(
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
                  Image.asset("assets/logo.png", height: 200), // Add your logo
                  const SizedBox(height: 10),

                  // Tickets Table
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

                  // Proceed to Payment Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => PaymentOptions(bus: bus)),
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
          ),
        ],
      ),
    );
  }

  // Helper function to create table rows
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
