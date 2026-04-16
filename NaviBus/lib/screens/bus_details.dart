import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:navibus/screens/live_ride_page.dart';
import 'package:navibus/screens/payment.dart';
import 'package:navibus/services/notification_service.dart';
import 'package:share_plus/share_plus.dart';

class BusDetails extends StatefulWidget {
  final dynamic bus;

  const BusDetails({super.key, required this.bus});

  @override
  State<BusDetails> createState() => _BusDetailsState();
}

class _BusDetailsState extends State<BusDetails> {
  bool _isSharing = false;
  String? _lastSharedLocation;

  int _computeEta(dynamic bus) {
    final freq = int.tryParse((bus['frequency_weekday'] ?? '15').toString()) ?? 15;
    return freq > 4 ? freq - 4 : freq;
  }

  int _mockWomenSeats(String routeNumber) {
    final hash = routeNumber.codeUnits.fold<int>(0, (sum, value) => sum + value);
    return 2 + (hash % 4);
  }

  int _mockPwdSeats(String routeNumber) {
    final hash = routeNumber.codeUnits.fold<int>(0, (sum, value) => sum + value);
    return 1 + (hash % 3);
  }

  Future<bool> _ensureLocationPermission() async {
    final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!isServiceEnabled) {
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  Future<void> _shareLocationAndBusInfo({
    required String routeNumber,
    required String source,
    required String destination,
    required String nextStop,
    required int etaMinutes,
  }) async {
    if (_isSharing) {
      return;
    }

    setState(() {
      _isSharing = true;
    });

    try {
      final hasPermission = await _ensureLocationPermission();
      if (!hasPermission) {
        throw Exception('GPS permission denied or location is disabled');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) {
        return;
      }

      final lat = position.latitude.toStringAsFixed(6);
      final lon = position.longitude.toStringAsFixed(6);
      final mapsLink = 'https://maps.google.com/?q=$lat,$lon';

      final message =
          'I am currently on NaviBus $routeNumber\n'
          'Route: $source -> $destination\n'
          'Next stop: $nextStop (ETA ~$etaMinutes min)\n'
          'My live location: $lat, $lon\n'
          '$mapsLink';

      await Share.share(
        message,
        subject: 'Live bus location update',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _lastSharedLocation = '$lat, $lon';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Shared bus and live location successfully.'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not share location: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSharing = false;
        });
      }
    }
  }

  Future<void> _sendArrivalAlert({
    required String routeNumber,
    required String nextStop,
    required int etaMinutes,
  }) async {
    final delaySeconds = etaMinutes > 1 ? 10 : 5;

    await NotificationService.instance.sendAfter(
      title: 'Bus $routeNumber arrival alert',
      body: 'Bus $routeNumber is approaching $nextStop. ETA around $etaMinutes min.',
      delay: Duration(seconds: delaySeconds),
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Arrival alert scheduled in $delaySeconds seconds.'),
        backgroundColor: const Color(0xFF2E7D32),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bus = widget.bus ?? {};
    final routeNumber = (bus['route_number'] ?? bus['bus_no'] ?? 'C-1').toString();
    final path = List<dynamic>.from(bus['stops'] ?? bus['sub_path'] ?? []);
    final source = path.isNotEmpty ? path.first.toString() : 'Vashi Station';
    final destination = path.length > 1 ? path.last.toString() : 'Nerul Sea Shore';
    final nextStop = path.length > 2 ? path[1].toString() : destination;
    final fare = bus['fare'] ?? 25;
    final capacity = (bus['bus_type'] ?? 'Medium').toString();
    final etaMinutes = _computeEta(bus);
    final frequency = int.tryParse((bus['frequency_weekday'] ?? '12').toString()) ?? 12;
    final womenReservedSeats = bus['women_reserved_seats'] ?? _mockWomenSeats(routeNumber);
    final pwdReservedSeats = bus['pwd_reserved_seats'] ?? _mockPwdSeats(routeNumber);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F5),
      body: Column(
        children: [
          Expanded(
            flex: 46,
            child: Stack(
              children: [
                Container(
                  color: const Color(0xFFF3D7DC),
                  child: CustomPaint(
                    painter: _RouteLinePainter(),
                    child: const SizedBox.expand(),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        _circleIconButton(
                          icon: Icons.arrow_back_ios_new,
                          onTap: () => Navigator.pop(context),
                        ),
                        const Spacer(),
                        _circleIconButton(
                          icon: Icons.map_outlined,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => LiveRidePage(bus: bus),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        _circleIconButton(
                          icon: Icons.share_outlined,
                          onTap: () {
                            _shareLocationAndBusInfo(
                              routeNumber: routeNumber,
                              source: source,
                              destination: destination,
                              nextStop: nextStop,
                              etaMinutes: etaMinutes,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 84,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _labelPill(source),
                  ),
                ),
                Positioned(
                  top: 138,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.circle, size: 10, color: Color(0xFFD62828)),
                        const SizedBox(height: 34),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD62828),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Bus $routeNumber',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFFCCD5)),
                          ),
                          child: const Icon(Icons.near_me_rounded, color: Color(0xFFD62828)),
                        ),
                        const SizedBox(height: 34),
                        const Icon(Icons.circle_outlined, size: 10, color: Color(0xFFD62828)),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 30,
                  left: 0,
                  right: 0,
                  child: Center(child: _labelPill(destination)),
                ),
                Positioned(
                  top: 122,
                  right: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.circle, size: 8, color: Color(0xFF4CAF50)),
                        SizedBox(width: 6),
                        Text('Live • Just now', style: TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 54,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD62828),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            routeNumber,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bus $routeNumber',
                                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                              ),
                              Text(
                                '$source → $destination',
                                style: const TextStyle(
                                  color: Color(0xFF6B7280),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Live',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _metricCard(
                            icon: Icons.timer_outlined,
                            label: 'ETA',
                            value: '$etaMinutes min',
                            iconColor: const Color(0xFFD62828),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _metricCard(
                            icon: Icons.location_on_outlined,
                            label: 'Distance',
                            value: '${(etaMinutes * 0.28).toStringAsFixed(1)} km',
                            iconColor: const Color(0xFFE77F00),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _metricCard(
                            icon: Icons.people_outline,
                            label: 'Capacity',
                            value: capacity,
                            iconColor: const Color(0xFFD62828),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF7EC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCAE6CF)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: const Icon(Icons.near_me_rounded, color: Colors.white),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Next Stop', style: TextStyle(color: Color(0xFF2E7D32))),
                                Text(
                                  nextStop,
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${frequency > 2 ? frequency - 2 : frequency} min',
                                style: const TextStyle(
                                  color: Color(0xFFD62828),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Text(
                                '${0.5} km',
                                style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEEF0),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.woman_2_outlined, color: Color(0xFFD62828), size: 17),
                                const SizedBox(width: 6),
                                Text(
                                  'Women seats: $womenReservedSeats',
                                  style: const TextStyle(
                                    color: Color(0xFFD62828),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F0FF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.accessible_outlined, color: Color(0xFF1D4ED8), size: 17),
                                const SizedBox(width: 6),
                                Text(
                                  'PWD seats: $pwdReservedSeats',
                                  style: const TextStyle(
                                    color: Color(0xFF1D4ED8),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_lastSharedLocation != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F7F8),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Last shared location: $_lastSharedLocation',
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => LiveRidePage(bus: bus),
                                ),
                              );
                            },
                            icon: const Icon(Icons.map_outlined),
                            label: const Text('Live Ride Map'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF111827),
                              side: const BorderSide(color: Color(0xFFD1D5DB)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isSharing
                                ? null
                                : () {
                                    _shareLocationAndBusInfo(
                                      routeNumber: routeNumber,
                                      source: source,
                                      destination: destination,
                                      nextStop: nextStop,
                                      etaMinutes: etaMinutes,
                                    );
                                  },
                            icon: _isSharing
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.share_outlined),
                            label: const Text('Share to Family'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2E7D32),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Upcoming Stops',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: path.length > 1 ? path.length - 1 : 0,
                        itemBuilder: (context, index) {
                          final stop = path[index + 1].toString();
                          final stopEta = (index + 1) * frequency;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            child: Row(
                              children: [
                                Icon(Icons.location_on_outlined, color: Colors.grey.shade400),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    stop,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '$stopEta min',
                                  style: const TextStyle(
                                    color: Color(0xFFD62828),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => Payment(bus: bus)),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF77F00),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          'Book Ticket on This Bus • ₹$fare',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          _sendArrivalAlert(
                            routeNumber: routeNumber,
                            nextStop: nextStop,
                            etaMinutes: etaMinutes,
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF111827),
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Set Arrival Alert'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleIconButton({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(99),
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Icon(icon, size: 18, color: const Color(0xFF333333)),
      ),
    );
  }

  Widget _labelPill(String label) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }

  Widget _metricCard({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8A8FA3),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _RouteLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE06A7A)
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke;

    final centerX = size.width / 2;
    canvas.drawLine(Offset(centerX, 120), Offset(centerX, size.height - 54), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
