import 'package:flutter/material.dart';
import 'package:navibus/screens/paymentopts.dart';

class Payment extends StatefulWidget {
  final dynamic bus;

  const Payment({super.key, required this.bus});

  @override
  State<Payment> createState() => _PaymentState();
}

class _PaymentState extends State<Payment> {
  int adults = 1;
  int children = 0;
  int seniors = 0;
  DateTime travelDate = DateTime.now();

  late final String routeNumber;
  late final String source;
  late final String destination;
  late final int farePerPerson;

  @override
  void initState() {
    super.initState();
    final bus = widget.bus ?? {};
    final path = List<dynamic>.from(bus['sub_path'] ?? bus['stops'] ?? []);

    routeNumber = (bus['route_number'] ?? bus['bus_no'] ?? 'C-1').toString();
    source = path.isNotEmpty ? path.first.toString() : 'Vashi Station';
    destination = path.length > 1 ? path.last.toString() : 'Nerul Sea Shore';
    farePerPerson = ((bus['fare'] ?? 25) as num).toInt();
  }

  int get totalPassengers => adults + children + seniors;

  int get totalAmount {
    final adultAmount = adults * farePerPerson;
    final childAmount = (children * farePerPerson * 0.5).round();
    final seniorAmount = (seniors * farePerPerson * 0.7).round();
    return adultAmount + childAmount + seniorAmount;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: travelDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 45)),
    );

    if (picked != null) {
      setState(() {
        travelDate = picked;
      });
    }
  }

  void _goToPaymentOptions() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentOptions(
          bus: {
            ...(widget.bus ?? {}),
            'route_number': routeNumber,
            'source': source,
            'destination': destination,
          },
          totalAmount: totalAmount,
          passengerCount: totalPassengers,
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
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
            ),
            padding: const EdgeInsets.fromLTRB(14, 56, 14, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                    ),
                    const Text(
                      'Book Ticket',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              routeNumber,
                              style: const TextStyle(
                                color: Color(0xFFD62828),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '$farePerPerson',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '$source  →  $destination',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _cardContainer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select Passengers',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 10),
                        _counterRow(
                          icon: Icons.person_outline,
                          title: 'Adults',
                          subtitle: '12+ years',
                          count: adults,
                          onMinus: adults > 1 ? () => setState(() => adults--) : null,
                          onPlus: () => setState(() => adults++),
                        ),
                        const Divider(height: 20),
                        _counterRow(
                          icon: Icons.child_care_outlined,
                          title: 'Children',
                          subtitle: '5-11 years (50% off)',
                          count: children,
                          onMinus: children > 0 ? () => setState(() => children--) : null,
                          onPlus: () => setState(() => children++),
                        ),
                        const Divider(height: 20),
                        _counterRow(
                          icon: Icons.elderly_outlined,
                          title: 'Seniors',
                          subtitle: '60+ years (30% off)',
                          count: seniors,
                          onMinus: seniors > 0 ? () => setState(() => seniors--) : null,
                          onPlus: () => setState(() => seniors++),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _cardContainer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Journey Details',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 12),
                        const Row(
                          children: [
                            Icon(Icons.calendar_today_outlined, color: Color(0xFF6B7280), size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Travel Date',
                              style: TextStyle(
                                color: Color(0xFF6B7280),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: _pickDate,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F3F5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${travelDate.day.toString().padLeft(2, '0')}-${travelDate.month.toString().padLeft(2, '0')}-${travelDate.year}',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$totalPassengers Passenger(s)',
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '₹$totalAmount',
                    style: const TextStyle(
                      color: Color(0xFFD62828),
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _goToPaymentOptions,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF77F00),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Proceed to Payment',
                    style: TextStyle(fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }

  Widget _counterRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required int count,
    required VoidCallback? onMinus,
    required VoidCallback onPlus,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFFFEEF0),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(icon, color: const Color(0xFFD62828)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        _counterButton(icon: Icons.remove, onTap: onMinus),
        SizedBox(
          width: 30,
          child: Text(
            '$count',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
          ),
        ),
        _counterButton(icon: Icons.add, onTap: onPlus, highlighted: true),
      ],
    );
  }

  Widget _counterButton({
    required IconData icon,
    required VoidCallback? onTap,
    bool highlighted = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: highlighted ? const Color(0xFFD62828) : const Color(0xFFE6E7EA),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Icon(
          icon,
          color: highlighted ? Colors.white : const Color(0xFF6B7280),
          size: 18,
        ),
      ),
    );
  }
}
