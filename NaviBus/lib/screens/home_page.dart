import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:navibus/screens/feedback.dart';
import 'package:navibus/screens/busopts.dart';
import 'package:navibus/screens/login.dart';
import 'package:navibus/screens/bus_details.dart';
import 'package:navibus/screens/profile_page.dart';
import 'package:navibus/widgets/offline_widgets.dart';
import 'package:navibus/widgets/backend_settings.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();

  Future<dynamic> fetchBusByRouteNumber(BuildContext context, String routeNumber) async {
    try {
      print('Searching for route: $routeNumber');
      final url = Uri.parse('http://10.0.2.2:8000/api/routes/search/?route_number=$routeNumber');
      final response = await http.get(url);
      print('API status: ${response.statusCode}, body: ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Decoded data: $data');
        if (data is List && data.isNotEmpty) {
          final bus = data[0];
          if (bus['stops'] != null && bus['stops'].isNotEmpty) {
            bus['source'] = bus['stops'][0];
            bus['destination'] = bus['stops'].last;
          }
          return bus;
        }
      }
    } catch (e) {
      print('Error fetching bus: $e');
    }
    return null;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfilePage()),
              );
            },
          ),
        ],
        iconTheme: IconThemeData(color: Colors.white),
      ),

      body: Column(
        children: [
          // Offline notification banner
          const OfflineNotificationBanner(),
          
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(height: 30),

                  // 🔍 Search Box
                  Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: "Search for Buses (Route No.)",
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(50),
                              ),
                            ),
                            onSubmitted: (value) async {
                              if (value.trim().isEmpty) return;
                              final bus = await fetchBusByRouteNumber(context, value.trim());
                              if (bus != null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => BusDetails(bus: bus),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('No bus found for route $value')),
                                );
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            final value = _searchController.text.trim();
                            if (value.isEmpty) return;
                            final bus = await fetchBusByRouteNumber(context, value);
                            if (bus != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => BusDetails(bus: bus),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('No bus found for route $value')),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF042F40),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          ),
                          child: const Text('Search', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 50),

                  // 🚍 AC & Non-AC Options
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Flexible(child: _buildBusButton("AC Bus", "assets/acbus.png", context)),
                        Flexible(child: _buildBusButton("Non-AC Bus", "assets/nonacbus.png", context)),
                      ],
                    ),
                  ),

                  SizedBox(height: 80),

                  // 🎫 My Tickets/Passes Button
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => LoginScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF042F40), // Custom Color
                      padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                    ),
                    child: Text("My Tickets/Passes", style: TextStyle(fontSize: 18, color: Colors.white)),
                  ),

                  SizedBox(height: 20),
                  
                  // 📱 Offline Data Download Section
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: DataDownloadWidget(),
                  ),

                  SizedBox(height: 20),

                  // ⚙️ Backend Settings Section
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: BackendSettingsWidget(),
                  ),

                  SizedBox(height: 20),

                  // 📌 Logo & App Name
                  Column(
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: 200, maxHeight: 200),
                        child: Image.asset("assets/logo.png", width: 200, height: 200),
                      ),
                      SizedBox(height: 10),
                      Text("NAVI BUS", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      Text("Driving Navi Mumbai Forward", style: TextStyle(color: Colors.black.withValues(alpha: 0.3), fontSize: 18, fontWeight: FontWeight.w400), maxLines: 1, overflow: TextOverflow.ellipsis),
                      SizedBox(height: 20),
                    ],
                  ),
                ],
              ),
            ),
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
            color: Colors.black.withValues(alpha: 0.3),
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
