import 'package:flutter/material.dart';
import 'package:navibus/screens/Feedback.dart';
import 'package:navibus/screens/busopts.dart';

class HomePage extends StatelessWidget {
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
          SizedBox(height: 30),

          // 🔍 Search Box
          Padding(
            padding: EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search for Buses",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(50),
                ),
              ),
            ),
          ),

          SizedBox(height: 50),

          // 🚍 AC & Non-AC Options
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildBusButton("AC Bus", "assets/acbus.png", context),
                _buildBusButton("Non-AC Bus", "assets/nonacbus.png", context),
              ],
            ),
          ),

          SizedBox(height: 80),

          // 🎫 My Tickets/Passes Button
          ElevatedButton(
            onPressed: () {
              print("Navigate to My Tickets");
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF042F40), // Custom Color
              padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
            ),
            child: Text("My Tickets/Passes", style: TextStyle(fontSize: 18, color: Colors.white)),
          ),

          SizedBox(height: 20),

          // 📌 Logo & App Name
          Column(
            children: [
              Image.asset("assets/logo.png", width: 200, height: 200),
              SizedBox(height: 10),
              Text("NAVI BUS", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              Text("Driving Navi Mumbai Forward", style: TextStyle(color: Colors.black.withOpacity(0.3), fontSize: 18, fontWeight: FontWeight.w400)),
              SizedBox(height: 20),
            ],
          ),
        ],
      ),
    );
  }

  // Function to create AC / Non-AC options as buttons
  Widget _buildBusButton(String text, String imagePath, BuildContext context) {
    return Container(
      width: 160,
      height: 150,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 2,
            offset: Offset(4, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const BusOptions()),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(text, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
            SizedBox(height: 10),
            Image.asset(imagePath, width: 160, height: 100, fit: BoxFit.contain),
          ],
        ),
      ),
    );
  }
}
