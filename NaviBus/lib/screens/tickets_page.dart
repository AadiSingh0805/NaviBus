import 'package:flutter/material.dart';
import 'package:navibus/widgets/app_bottom_nav.dart';

class TicketsPage extends StatefulWidget {
  const TicketsPage({super.key});

  @override
  State<TicketsPage> createState() => _TicketsPageState();
}

class _TicketsPageState extends State<TicketsPage> {
  int _tabIndex = 0;
  String _query = '';

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
              ],
            ),
          ),
          Expanded(
            child: _filteredTickets.isEmpty
                ? const Center(
                    child: Text(
                      'No tickets found',
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: _filteredTickets.length,
                    itemBuilder: (context, index) => _buildTicketCard(_filteredTickets[index]),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 2),
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
