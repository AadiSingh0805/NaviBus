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
import 'package:navibus/services/data_service.dart';
import 'package:navibus/widgets/autocomplete_search.dart';

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
      
      // Use DataService to get the correct backend URL
      final dataService = DataService.instance;
      final backendUrl = await dataService.getCurrentBackendUrl();
      final url = Uri.parse('$backendUrl/routes/search/?route_number=$routeNumber');
      
      print('Using backend: $backendUrl');
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
              // Add performance optimizations
              physics: const BouncingScrollPhysics(), // Smoother scrolling
              child: Column(
                children: [
                  SizedBox(height: 30),

                  // 🔍 Search Box with autocomplete and mobile UX
                  Padding(
                    padding: EdgeInsets.all(16.0),
                    child: AutocompleteSearchField(
                      controller: _searchController,
                      hintText: "Search for Buses (Route No.)",
                      onRouteSelected: (String routeNumber) async {
                        // Show loading indicator
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                SizedBox(width: 12),
                                Text('Loading route $routeNumber...'),
                              ],
                            ),
                            duration: Duration(seconds: 2),
                          ),
                        );
                        
                        final bus = await fetchBusByRouteNumber(context, routeNumber);
                        
                        // Hide loading indicator
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        
                        if (bus != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BusDetails(bus: bus),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('No bus found for route $routeNumber'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
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
            color: Colors.black.withValues(alpha: 0.2), // Reduce shadow intensity
            blurRadius: 6, // Reduce blur for performance
            spreadRadius: 1, // Reduce spread
            offset: Offset(2, 2), // Smaller offset
          ),
        ],
      ),
      child: Material( // Add Material for better tap feedback
        borderRadius: BorderRadius.circular(10),
        color: Colors.white,
        child: InkWell( // Better touch feedback than ElevatedButton
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const BusOptions()),
            );
          },
          child: Padding(
            padding: EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  text, 
                  style: TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold, 
                    color: Colors.black
                  ),
                ),
                SizedBox(height: 10),
                // Optimize image loading for mobile
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    imagePath, 
                    width: 140, 
                    height: 80, 
                    fit: BoxFit.contain,
                    // Add caching and performance optimizations
                    cacheWidth: 280, // Optimize for mobile resolution
                    cacheHeight: 160,
                    filterQuality: FilterQuality.medium, // Balance quality/performance
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
