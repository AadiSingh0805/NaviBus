import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:navibus/screens/Feedback.dart';
import 'package:navibus/services/image_capture_service.dart';
import 'package:navibus/widgets/app_bottom_nav.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TicketsPage extends StatefulWidget {
  const TicketsPage({super.key});

  @override
  State<TicketsPage> createState() => _TicketsPageState();
}

class _TicketsPageState extends State<TicketsPage> {
  static const String _digitalPassesKey = 'digital_ticket_passes';
  final ImageCaptureService _imageCaptureService = ImageCaptureService.instance;

  int _tabIndex = 0;
  String _query = '';
  bool _isSavingPass = false;
  List<Map<String, dynamic>> _digitalPasses = [];

  final List<Map<String, dynamic>> _tickets = [
    {
      'route': 'C-1',
      'status': 'Active',
      'from': 'Vashi Station',
      'to': 'Nerul Sea Shore',
      'date': '28 Jan',
      'time': '02:30 PM',
      'pax': 1,
      'fare': 25,
      'type': 'active',
    },
    {
      'route': '305',
      'status': 'Upcoming',
      'from': 'CBD Belapur',
      'to': 'Kharghar',
      'date': '29 Jan',
      'time': '09:10 AM',
      'pax': 2,
      'fare': 40,
      'type': 'upcoming',
    },
    {
      'route': '302',
      'status': 'Past',
      'from': 'Nerul',
      'to': 'Vashi',
      'date': '21 Jan',
      'time': '06:45 PM',
      'pax': 1,
      'fare': 20,
      'type': 'past',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadDigitalPasses();
  }

  Future<void> _loadDigitalPasses() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_digitalPassesKey);
    if (encoded == null || encoded.isEmpty) {
      return;
    }

    try {
      final decoded = List<dynamic>.from(json.decode(encoded));
      if (!mounted) {
        return;
      }

      setState(() {
        _digitalPasses = decoded
            .whereType<Map>()
            .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
            .toList()
            .cast<Map<String, dynamic>>();
      });
    } catch (_) {
      await prefs.remove(_digitalPassesKey);
    }
  }

  Future<void> _persistDigitalPasses() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_digitalPassesKey, json.encode(_digitalPasses));
  }

  Future<void> _capturePassFromCamera() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isSavingPass = true;
    });

    try {
      final imagePath = await _imageCaptureService.captureFromCamera(
        folderName: 'ticket_passes',
        filePrefix: 'pass_camera',
      );

      if (imagePath == null) {
        return;
      }

      await _storeCapturedPass(imagePath, 'camera');
    } finally {
      if (mounted) {
        setState(() {
          _isSavingPass = false;
        });
      }
    }
  }

  Future<void> _pickPassFromGallery() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isSavingPass = true;
    });

    try {
      final imagePath = await _imageCaptureService.pickFromGallery(
        folderName: 'ticket_passes',
        filePrefix: 'pass_gallery',
      );

      if (imagePath == null) {
        return;
      }

      await _storeCapturedPass(imagePath, 'gallery');
    } finally {
      if (mounted) {
        setState(() {
          _isSavingPass = false;
        });
      }
    }
  }

  Future<void> _storeCapturedPass(String imagePath, String source) async {
    final routeHint = _filteredTickets.isNotEmpty
        ? (_filteredTickets.first['route'] ?? 'N/A').toString()
        : 'N/A';

    final pass = <String, dynamic>{
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'image_path': imagePath,
      'captured_at': DateTime.now().toIso8601String(),
      'source': source,
      'route_hint': routeHint,
    };

    if (!mounted) {
      return;
    }

    setState(() {
      _digitalPasses.insert(0, pass);
    });
    await _persistDigitalPasses();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Digital pass saved on this phone.'),
        backgroundColor: Color(0xFF2E7D32),
      ),
    );
  }

  Future<void> _deleteDigitalPass(String passId) async {
    Map<String, dynamic>? removedPass;

    setState(() {
      for (final pass in _digitalPasses) {
        if ((pass['id'] ?? '').toString() == passId) {
          removedPass = pass;
          break;
        }
      }
      _digitalPasses.removeWhere((pass) => (pass['id'] ?? '').toString() == passId);
    });

    await _persistDigitalPasses();

    final imagePath = removedPass?['image_path']?.toString() ?? '';
    if (imagePath.isNotEmpty) {
      final file = File(imagePath);
      if (file.existsSync()) {
        await file.delete();
      }
    }
  }

  void _openPassPreview(String imagePath) {
    final file = File(imagePath);
    if (!file.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stored pass image not found.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(14),
          child: Stack(
            children: [
              InteractiveViewer(
                child: Image.file(file, fit: BoxFit.contain),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openAddPassSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Save Ticket Pass',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _capturePassFromCamera();
                    },
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Use Camera'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: const Color(0xFFD62828),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _pickPassFromGallery();
                    },
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Pick From Gallery'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openFeedbackPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FeedbackPage()),
    );
  }

  String _formatCapturedAt(String? isoValue) {
    if (isoValue == null || isoValue.isEmpty) {
      return 'Unknown time';
    }

    try {
      final capturedAt = DateTime.parse(isoValue).toLocal();
      final hour = capturedAt.hour.toString().padLeft(2, '0');
      final minute = capturedAt.minute.toString().padLeft(2, '0');
      final day = capturedAt.day.toString().padLeft(2, '0');
      final month = capturedAt.month.toString().padLeft(2, '0');
      return '$day/$month $hour:$minute';
    } catch (_) {
      return 'Unknown time';
    }
  }

  String get _activeType {
    switch (_tabIndex) {
      case 0:
        return 'active';
      case 1:
        return 'upcoming';
      default:
        return 'past';
    }
  }

  List<Map<String, dynamic>> get _filteredTickets {
    return _tickets.where((ticket) {
      final matchesType = ticket['type'] == _activeType;
      final route = (ticket['route'] ?? '').toString().toLowerCase();
      final from = (ticket['from'] ?? '').toString().toLowerCase();
      final to = (ticket['to'] ?? '').toString().toLowerCase();
      final query = _query.toLowerCase();
      final matchesQuery =
          query.isEmpty || route.contains(query) || from.contains(query) || to.contains(query);
      return matchesType && matchesQuery;
    }).toList();
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
            padding: const EdgeInsets.fromLTRB(16, 56, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'My Tickets',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    onChanged: (value) {
                      setState(() {
                        _query = value;
                      });
                    },
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      prefixIcon: Icon(Icons.search_rounded),
                      hintText: 'Search by ticket ID or route',
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _buildTabChip('Active (1)', 0),
                    const SizedBox(width: 8),
                    _buildTabChip('Upcoming (1)', 1),
                    const SizedBox(width: 8),
                    _buildTabChip('Past (1)', 2),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isSavingPass ? null : _openAddPassSheet,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          backgroundColor: const Color(0xFFF77F00),
                          foregroundColor: Colors.white,
                        ),
                        icon: _isSavingPass
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.photo_camera_outlined),
                        label: Text(_isSavingPass ? 'Saving...' : 'Save Pass'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _openFeedbackPage,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white),
                        ),
                        icon: const Icon(Icons.report_problem_outlined),
                        label: const Text('Raise Complaint'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                _buildDigitalPassVault(),
                Expanded(
                  child: _filteredTickets.isEmpty
                      ? const Center(
                          child: Text(
                            'No tickets found',
                            style: TextStyle(color: Color(0xFF6B7280), fontSize: 16),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                          itemCount: _filteredTickets.length,
                          itemBuilder: (context, index) => _buildTicketCard(_filteredTickets[index]),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 2),
    );
  }

  Widget _buildDigitalPassVault() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.wallet_membership_outlined, color: Color(0xFFD62828)),
              const SizedBox(width: 8),
              const Text(
                'Digital Pass Vault',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                '${_digitalPasses.length} saved',
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_digitalPasses.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FB),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'No digital pass stored yet. Tap Save Pass to capture from camera.',
                style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
              ),
            )
          else
            SizedBox(
              height: 114,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _digitalPasses.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) => _buildPassCard(_digitalPasses[index]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPassCard(Map<String, dynamic> pass) {
    final imagePath = (pass['image_path'] ?? '').toString();
    final routeHint = (pass['route_hint'] ?? 'N/A').toString();
    final capturedAt = _formatCapturedAt(pass['captured_at']?.toString());
    final source = (pass['source'] ?? 'camera').toString();
    final imageFile = File(imagePath);
    final hasImage = imagePath.isNotEmpty && imageFile.existsSync();

    return GestureDetector(
      onTap: hasImage ? () => _openPassPreview(imagePath) : null,
      child: Container(
        width: 148,
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: hasImage
                    ? Image.file(imageFile, fit: BoxFit.cover)
                    : Container(
                        color: const Color(0xFFF3F4F6),
                        alignment: Alignment.center,
                        child: const Icon(Icons.image_not_supported_outlined, color: Color(0xFF9CA3AF)),
                      ),
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: CircleAvatar(
                radius: 13,
                backgroundColor: Colors.black54,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 14,
                  onPressed: () => _deleteDigitalPass((pass['id'] ?? '').toString()),
                  icon: const Icon(Icons.delete_outline, color: Colors.white),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                color: Colors.black54,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Route: $routeHint',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$capturedAt • $source',
                      style: const TextStyle(color: Colors.white70, fontSize: 10),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabChip(String label, int index) {
    final isSelected = index == _tabIndex;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _tabIndex = index;
          });
        },
        child: Container(
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFF8D9D9) : Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isSelected ? const Color(0xFFD62828) : Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> ticket) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFD62828),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  ticket['route'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  ticket['status'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '#TKT001',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: const [
                  Icon(Icons.circle, size: 8, color: Color(0xFF4CAF50)),
                  SizedBox(height: 18),
                  Icon(Icons.circle, size: 8, color: Color(0xFFFFA000)),
                ],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticket['from'],
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      ticket['to'],
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FB),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                _buildMeta('Date', ticket['date']),
                _buildMeta('Time', ticket['time']),
                _buildMeta('Pax', '${ticket['pax']}'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '₹ ${ticket['fare']}',
                style: const TextStyle(
                  color: Color(0xFFD62828),
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF4CAF50),
                  side: const BorderSide(color: Color(0xFF4CAF50)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.near_me_rounded, size: 16),
                label: const Text('Share'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD62828),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Show QR'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMeta(String label, String value) {
    return Expanded(
      child: Row(
        children: [
          Icon(
            label == 'Date'
                ? Icons.calendar_today_outlined
                : label == 'Time'
                    ? Icons.access_time
                    : Icons.people_outline,
            size: 14,
            color: const Color(0xFF8A8FA3),
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Color(0xFF8A8FA3), fontSize: 11),
              ),
              Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
