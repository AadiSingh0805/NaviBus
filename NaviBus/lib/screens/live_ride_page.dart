import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LiveRidePage extends StatefulWidget {
  final dynamic bus;

  const LiveRidePage({super.key, required this.bus});

  @override
  State<LiveRidePage> createState() => _LiveRidePageState();
}

class _LiveRidePageState extends State<LiveRidePage> {
  GoogleMapController? _mapController;
  Timer? _busMovementTimer;

  late final String _routeNumber;
  late final String _source;
  late final String _destination;

  bool _isBusMoving = true;
  int _mockBusIndex = 0;

  LatLng? _busLatLng;
  late List<LatLng> _mockPath;

  String _statusText = 'Simulation mode: moving mock bus';

  @override
  void initState() {
    super.initState();

    final bus = widget.bus ?? {};
    final path = List<dynamic>.from(bus['stops'] ?? bus['sub_path'] ?? []);

    _routeNumber = (bus['route_number'] ?? bus['bus_no'] ?? 'C-1').toString();
    _source = path.isNotEmpty ? path.first.toString() : 'Vashi Station';
    _destination = path.length > 1 ? path.last.toString() : 'Nerul Sea Shore';

    _mockPath = _defaultMockPath();
    _busLatLng = _mockPath.first;

    _startBusMovement();
  }

  @override
  void dispose() {
    _busMovementTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  List<LatLng> _defaultMockPath() {
    return const [
      LatLng(19.0330, 73.0297),
      LatLng(19.0352, 73.0266),
      LatLng(19.0381, 73.0239),
      LatLng(19.0412, 73.0222),
      LatLng(19.0448, 73.0208),
      LatLng(19.0475, 73.0185),
    ];
  }

  void _startBusMovement() {
    _busMovementTimer?.cancel();
    _busMovementTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!_isBusMoving || _mockPath.isEmpty || !mounted) {
        return;
      }

      setState(() {
        _mockBusIndex = (_mockBusIndex + 1) % _mockPath.length;
        _busLatLng = _mockPath[_mockBusIndex];
      });

      if (_busLatLng != null) {
        _focusOn(_busLatLng!);
      }
    });
  }

  void _focusOn(LatLng target) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: target, zoom: 14.6),
      ),
    );
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    if (_busLatLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('bus'),
          position: _busLatLng!,
          infoWindow: InfoWindow(
            title: 'Bus $_routeNumber',
            snippet: 'Simulated movement',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }

    if (_mockPath.isNotEmpty) {
      markers.add(
        Marker(
          markerId: const MarkerId('start'),
          position: _mockPath.first,
          infoWindow: InfoWindow(title: 'Start: $_source'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );

      markers.add(
        Marker(
          markerId: const MarkerId('end'),
          position: _mockPath.last,
          infoWindow: InfoWindow(title: 'End: $_destination'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final initialTarget = _busLatLng ?? const LatLng(19.0330, 73.0297);

    return Scaffold(
      appBar: AppBar(
        title: Text('Live Ride • $_routeNumber'),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: initialTarget, zoom: 14.6),
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            markers: _buildMarkers(),
            polylines: {
              Polyline(
                polylineId: const PolylineId('route-path'),
                points: _mockPath,
                color: const Color(0xFFD62828),
                width: 5,
              ),
            },
            onMapCreated: (controller) {
              _mapController = controller;
            },
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD62828),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _routeNumber,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '$_source → $_destination',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF7EC),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'Simulated',
                      style: TextStyle(
                        color: Color(0xFF2E7D32),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 14,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _statusText,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'No live GPS tracking is used on this screen.',
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busLatLng == null
                              ? null
                              : () {
                                  _focusOn(_busLatLng!);
                                },
                          icon: const Icon(Icons.directions_bus),
                          label: const Text('Focus Bus'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _isBusMoving = !_isBusMoving;
                              _statusText = _isBusMoving
                                  ? 'Simulation mode: moving mock bus'
                                  : 'Simulation paused';
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD62828),
                            foregroundColor: Colors.white,
                          ),
                          icon: Icon(_isBusMoving ? Icons.pause : Icons.play_arrow),
                          label: Text(_isBusMoving ? 'Pause Mock Bus' : 'Resume Mock Bus'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFD62828),
        onPressed: () {
          if (_busLatLng != null) {
            _focusOn(_busLatLng!);
          }
        },
        child: const Icon(Icons.my_location, color: Colors.white),
      ),
    );
  }
}
