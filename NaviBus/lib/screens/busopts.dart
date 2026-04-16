import 'package:flutter/material.dart';
import 'package:navibus/screens/bus_details.dart';
import 'package:navibus/screens/payment.dart';
import 'package:navibus/services/data_service.dart';
import 'package:navibus/widgets/app_bottom_nav.dart';

class BusOptions extends StatefulWidget {
  final String? initialSource;
  final String? initialDestination;

  const BusOptions({
    super.key,
    this.initialSource,
    this.initialDestination,
  });

  @override
  State<BusOptions> createState() => _BusOptionsState();
}

class _BusOptionsState extends State<BusOptions> {
  final TextEditingController sourceController = TextEditingController();
  final TextEditingController destinationController = TextEditingController();
  final DataService _dataService = DataService.instance;

  bool _isLoading = false;
  String _activeFilter = 'Fastest';
  List<Map<String, dynamic>> _routes = [];

  int _mockWomenSeats(String routeNumber) {
    final hash = routeNumber.codeUnits.fold<int>(0, (sum, value) => sum + value);
    return 2 + (hash % 4);
  }

  int _mockPwdSeats(String routeNumber) {
    final hash = routeNumber.codeUnits.fold<int>(0, (sum, value) => sum + value);
    return 1 + (hash % 3);
  }

  @override
  void initState() {
    super.initState();
    sourceController.text = widget.initialSource ?? '';
    destinationController.text = widget.initialDestination ?? '';

    if (sourceController.text.trim().isNotEmpty &&
        destinationController.text.trim().isNotEmpty) {
      _searchRoutes();
    }
  }

  @override
  void dispose() {
    sourceController.dispose();
    destinationController.dispose();
    super.dispose();
  }

  Future<void> _searchRoutes() async {
    final source = sourceController.text.trim();
    final destination = destinationController.text.trim();

    if (source.isEmpty || destination.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter source and destination'),
          backgroundColor: Color(0xFFD62828),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final foundRoutes = await _dataService.searchRoutes(source, destination);

      final enrichedRoutes = await Future.wait(
        foundRoutes.map((route) async {
          final routeNumber =
              (route['route_number'] ?? route['bus_no'] ?? 'N/A').toString();
          final path = List<dynamic>.from(route['sub_path'] ?? route['stops'] ?? []);

          if (path.isNotEmpty && routeNumber != 'N/A') {
            final fareData = await _dataService.getFare(
              routeNumber: routeNumber,
              sourceStop: path.first.toString(),
              destinationStop: path.last.toString(),
            );

            return {
              ...route,
              'route_number': routeNumber,
              'sub_path': fareData['stops'] ?? path,
              'stops': fareData['stops'] ?? path,
              'fare': fareData['fare'] ?? route['fare'] ?? 20,
              'num_stops': fareData['num_stops'] ?? path.length,
              'women_reserved_seats': _mockWomenSeats(routeNumber),
              'pwd_reserved_seats': _mockPwdSeats(routeNumber),
            };
          }

          return {
            ...route,
            'route_number': routeNumber,
            'sub_path': path,
            'stops': path,
            'fare': route['fare'] ?? 20,
            'num_stops': path.length,
            'women_reserved_seats': _mockWomenSeats(routeNumber),
            'pwd_reserved_seats': _mockPwdSeats(routeNumber),
          };
        }),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _routes = enrichedRoutes.cast<Map<String, dynamic>>();
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not fetch routes: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _routes = [];
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _sortedRoutes {
    final list = List<Map<String, dynamic>>.from(_routes);

    if (_activeFilter == 'Cheapest') {
      list.sort(
        (a, b) => ((a['fare'] ?? 999) as num).compareTo((b['fare'] ?? 999) as num),
      );
    } else if (_activeFilter == 'Least Stops') {
      list.sort(
        (a, b) => ((a['num_stops'] ?? 999) as num).compareTo((b['num_stops'] ?? 999) as num),
      );
    } else {
      list.sort((a, b) {
        final aFreq = int.tryParse((a['frequency_weekday'] ?? '999').toString()) ?? 999;
        final bFreq = int.tryParse((b['frequency_weekday'] ?? '999').toString()) ?? 999;
        return aFreq.compareTo(bFreq);
      });
    }

    return list;
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
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
            ),
            padding: const EdgeInsets.fromLTRB(12, 56, 12, 14),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                    ),
                    const Text(
                      'Available Routes',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _searchField(
                        controller: sourceController,
                        hint: 'From',
                        icon: Icons.location_on_outlined,
                        iconColor: const Color(0xFF4CAF50),
                      ),
                      const SizedBox(height: 8),
                      _searchField(
                        controller: destinationController,
                        hint: 'To',
                        icon: Icons.location_on_outlined,
                        iconColor: const Color(0xFFF77F00),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _searchRoutes,
                          icon: const Icon(Icons.search),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE29191),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          label: const Text('Search Routes'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                const Icon(Icons.filter_alt_outlined, color: Color(0xFF8A8FA3)),
                const SizedBox(width: 8),
                Expanded(child: _filterChip('Fastest')),
                const SizedBox(width: 8),
                Expanded(child: _filterChip('Cheapest')),
                const SizedBox(width: 8),
                Expanded(child: _filterChip('Least Stops')),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFD62828)))
                : _sortedRoutes.isEmpty
                    ? const Center(
                        child: Text(
                          'No routes found. Try another source/destination pair.',
                          style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                        itemCount: _sortedRoutes.length,
                        itemBuilder: (context, index) => _routeCard(_sortedRoutes[index]),
                      ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
    );
  }

  Widget _searchField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          prefixIcon: Icon(icon, color: iconColor),
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
        ),
      ),
    );
  }

  Widget _filterChip(String label) {
    final isSelected = _activeFilter == label;

    return GestureDetector(
      onTap: () {
        setState(() {
          _activeFilter = label;
        });
      },
      child: Container(
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD62828) : const Color(0xFFE9EAEC),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF1F2937),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _routeCard(Map<String, dynamic> route) {
    final routeNumber = (route['route_number'] ?? route['bus_no'] ?? 'N/A').toString();
    final path = List<dynamic>.from(route['sub_path'] ?? route['stops'] ?? []);
    final source = path.isNotEmpty ? path.first.toString() : 'Unknown Source';
    final destination = path.length > 1 ? path.last.toString() : 'Unknown Destination';
    final nextStop = path.length > 2 ? path[1].toString() : destination;
    final fare = route['fare'] ?? 0;
    final stopsCount = route['num_stops'] ?? path.length;
    final womenReservedSeats = route['women_reserved_seats'] ?? 3;
    final pwdReservedSeats = route['pwd_reserved_seats'] ?? 2;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFD62828),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  routeNumber,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Live',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3D6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$stopsCount stops',
                  style: const TextStyle(
                    color: Color(0xFFA97A0B),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.access_time, size: 18, color: Color(0xFF6B7280)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  source,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  destination,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF7EC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Next stop: $nextStop',
              style: const TextStyle(
                color: Color(0xFF2E7D32),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEEF0),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.woman_2_outlined, size: 14, color: Color(0xFFD62828)),
                    const SizedBox(width: 5),
                    Text(
                      'Women seats: $womenReservedSeats',
                      style: const TextStyle(
                        color: Color(0xFFD62828),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.accessible_outlined, size: 14, color: Color(0xFF1D4ED8)),
                    const SizedBox(width: 5),
                    Text(
                      'PWD seats: $pwdReservedSeats',
                      style: const TextStyle(
                        color: Color(0xFF1D4ED8),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                '₹ $fare',
                style: const TextStyle(
                  color: Color(0xFFD62828),
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Text(
                '/person',
                style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => BusDetails(bus: route)),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1F2937),
                  side: const BorderSide(color: Color(0xFFD1D5DB)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.near_me_rounded, size: 16),
                label: const Text('Track'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => Payment(bus: route)),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF77F00),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Book Now'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
