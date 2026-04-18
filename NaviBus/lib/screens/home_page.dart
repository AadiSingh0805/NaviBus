import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:navibus/screens/busopts_new.dart';
import 'package:navibus/screens/live_ride_page.dart';
import 'package:navibus/widgets/app_bottom_nav.dart';
import 'package:navibus/widgets/offline_widgets.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();

  bool _isFetchingGps = false;
  String? _gpsCoordinates;

  final List<Map<String, String>> _recentRoutes = [
    {'from': 'Vashi Station', 'to': 'Nerul Sea Shore'},
    {'from': 'CBD Belapur', 'to': 'Seawoods'},
    {'from': 'Airoli Sector 8', 'to': 'Ghansoli'},
  ];

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  void _swapStops() {
    final currentFrom = _fromController.text;
    _fromController.text = _toController.text;
    _toController.text = currentFrom;
    setState(() {});
  }

  Future<void> _useGpsCoordinates() async {
    if (_isFetchingGps) {
      return;
    }

    setState(() {
      _isFetchingGps = true;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled on this device');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('GPS permission denied');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) {
        return;
      }

      final lat = position.latitude.toStringAsFixed(6);
      final lon = position.longitude.toStringAsFixed(6);

      setState(() {
        _gpsCoordinates = '$lat, $lon';
        _fromController.text = 'My GPS Location';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('GPS captured: $lat, $lon'),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not fetch GPS coordinates: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingGps = false;
        });
      }
    }
  }

  void _searchRoutes({String? from, String? to}) {
    final source = (from ?? _fromController.text).trim();
    final destination = (to ?? _toController.text).trim();

    if (source.isEmpty || destination.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both source and destination'),
          backgroundColor: Color(0xFFD62828),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BusOptionsNew(
          initialSource: source,
          initialDestination: destination,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F5),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFFD62828),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 56, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome Back!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Where do you want to go?',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.circle, size: 9, color: Color(0xFF4CAF50)),
                          SizedBox(width: 5),
                          Text(
                            'Live',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      _buildStopField(
                        controller: _fromController,
                        hint: 'From (e.g., Vashi Station)',
                        icon: Icons.location_on_outlined,
                        iconColor: const Color(0xFFD62828),
                        suffix: _isFetchingGps
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : IconButton(
                                tooltip: 'Use GPS coordinates',
                                onPressed: _useGpsCoordinates,
                                icon: const Icon(Icons.gps_fixed, color: Color(0xFF2E7D32)),
                              ),
                      ),
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: _swapStops,
                        borderRadius: BorderRadius.circular(99),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F3F5),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: const Icon(Icons.swap_vert, color: Color(0xFFD62828)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildStopField(
                        controller: _toController,
                        hint: 'To (e.g., Nerul Sea Shore)',
                        icon: Icons.location_on_outlined,
                        iconColor: const Color(0xFFF77F00),
                      ),
                      if (_gpsCoordinates != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF7EC),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'GPS Coordinates: $_gpsCoordinates',
                            style: const TextStyle(
                              color: Color(0xFF2E7D32),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _searchRoutes(),
                          icon: const Icon(Icons.search_rounded),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE29191),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          label: const Text(
                            'Search Routes',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const OfflineNotificationBanner(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionCard(
                          icon: Icons.near_me_rounded,
                          title: 'Live Map',
                          subtitle: 'Track buses nearby',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LiveRidePage(
                                bus: {
                                  'route_number': 'C-1',
                                  'stops': [
                                    'Vashi Station',
                                    'Palm Beach Road',
                                    'Nerul Junction',
                                    'Nerul Sea Shore',
                                  ],
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildActionCard(
                          icon: Icons.schedule,
                          title: 'Schedule',
                          subtitle: 'View timetables',
                          iconColor: const Color(0xFFF77F00),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const BusOptionsNew(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildActionCard(
                    icon: Icons.notifications_active_outlined,
                    title: 'Notification Control',
                    subtitle: 'Send active alerts to your phone',
                    iconColor: const Color(0xFF2E7D32),
                    onTap: () => Navigator.pushNamed(context, '/notifications'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text(
                        'Recent Routes',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                      ),
                      const Spacer(),
                      Icon(Icons.access_time, color: Colors.grey.shade600),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ..._recentRoutes.map(
                    (route) => GestureDetector(
                      onTap: () => _searchRoutes(from: route['from'], to: route['to']),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFEEF0),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: const Icon(
                                Icons.location_on_outlined,
                                color: Color(0xFFD62828),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    route['from'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'to ${route['to']}',
                                    style: const TextStyle(
                                      color: Color(0xFF6B7280),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.swap_vert, color: Colors.grey.shade500),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }

  Widget _buildStopField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Color iconColor,
    Widget? suffix,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F3F5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          prefixIcon: Icon(icon, color: iconColor),
          suffixIcon: suffix,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color iconColor = const Color(0xFFD62828),
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
