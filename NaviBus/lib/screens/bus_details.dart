import 'package:flutter/material.dart';
import 'paymentopts.dart';

class BusDetails extends StatefulWidget {
  final dynamic bus;
  const BusDetails({super.key, required this.bus});

  @override
  State<BusDetails> createState() => _BusDetailsState();
}

class _BusDetailsState extends State<BusDetails> {
  int adults = 1;
  int children = 0;

  int calculateTotalFare(int fare) {
    // First child is free, next children are half fare
    int childFare = 0;
    if (children > 0) {
      childFare = ((children - 1) * (fare * 0.5)).round();
    }
    return (adults * fare) + childFare;
  }

  @override
  Widget build(BuildContext context) {
    final bus = widget.bus;
    final stops = (bus['stops'] ?? bus['sub_path']) ?? [];
    final fare = bus['fare'] ?? 0;
    final busType = bus['bus_type'] ?? 'N/A';
    final isSunday = DateTime.now().weekday == DateTime.sunday;
    final freq = isSunday ? bus['frequency_sunday'] : bus['frequency_weekday'];
    final firstBus = isSunday ? bus['first_bus_time_sunday'] : bus['first_bus_time_weekday'];
    final lastBus = isSunday ? bus['last_bus_time_sunday'] : bus['last_bus_time_weekday'];
    String nextBusTime = 'N/A';
    try {
      if (firstBus != null && lastBus != null && freq != null) {
        final now = TimeOfDay.now();
        final first = _parseTimeOfDay(firstBus);
        final last = _parseTimeOfDay(lastBus);
        final freqInt = int.tryParse(freq.toString()) ?? 0;
        if (first != null && last != null && freqInt > 0) {
          final nowMinutes = now.hour * 60 + now.minute;
          final firstMinutes = first.hour * 60 + first.minute;
          final lastMinutes = last.hour * 60 + last.minute;
          if (nowMinutes > lastMinutes + freqInt) {
            nextBusTime = 'N/A';
          } else if (nowMinutes < firstMinutes) {
            nextBusTime = firstBus;
          } else {
            int nextMinutes = ((nowMinutes - firstMinutes) ~/ freqInt + 1) * freqInt + firstMinutes;
            if (nextMinutes > lastMinutes) {
              nextBusTime = 'N/A';
            } else {
              final h = (nextMinutes ~/ 60).toString().padLeft(2, '0');
              final m = (nextMinutes % 60).toString().padLeft(2, '0');
              nextBusTime = '$h:$m';
            }
          }
        }
      }
    } catch (e) {
      nextBusTime = 'N/A';
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bus Details', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF042F40),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 0,
              color: Colors.white.withOpacity(0.7),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [Colors.white.withOpacity(0.6), Colors.blue.shade50.withOpacity(0.5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.blueGrey.withOpacity(0.08),
                        blurRadius: 18,
                        spreadRadius: 4),
                  ],
                  border: Border.all(color: Colors.blueAccent.withOpacity(0.15), width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.directions_bus, size: 40, color: Colors.blueAccent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text('Route: ${bus['route_number']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(busType, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.green),
                        const SizedBox(width: 6),
                        Expanded(child: Text('From: ${stops.isNotEmpty ? stops.first : 'N/A'}')),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.flag, color: Colors.redAccent),
                        const SizedBox(width: 6),
                        Expanded(child: Text('To: ${stops.isNotEmpty ? stops.last : 'N/A'}')),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('Stops:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 6),
                    StopsTimeline(stops: stops),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Icon(Icons.access_time, color: Colors.blue),
                        const SizedBox(width: 6),
                        Text('First Bus: ${firstBus ?? 'N/A'}'),
                        const SizedBox(width: 18),
                        const Icon(Icons.repeat, color: Colors.orange),
                        const SizedBox(width: 6),
                        Text('Avg Frequency: ${freq ?? 'N/A'} min'),
                        const SizedBox(width: 18),
                        const Icon(Icons.schedule, color: Colors.deepPurple),
                        const SizedBox(width: 6),
                        Text('Next Bus: $nextBusTime'),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text('Fare per Adult: ₹$fare', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Text('Adults:'),
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: adults > 1 ? () => setState(() => adults--) : null,
                        ),
                        Text('$adults'),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () => setState(() => adults++),
                        ),
                        const SizedBox(width: 24),
                        const Text('Children:'),
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: children > 0 ? () => setState(() => children--) : null,
                        ),
                        Text('$children'),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () => setState(() => children++),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text('Total Fare: ₹${calculateTotalFare(fare)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => PaymentOptions(bus: bus)),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text(
                          "Proceed to Payment",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // --- Other Details Card ---
            Text('Other Details:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  colors: [Colors.blueGrey.shade50.withOpacity(0.7), Colors.white.withOpacity(0.6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueGrey.withOpacity(0.10),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
                border: Border.all(color: Colors.blueAccent.withOpacity(0.10), width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12), // reduced horizontal padding
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.calendar_today, size: 18, color: Colors.blueGrey),
                        const SizedBox(width: 8),
                        Expanded(child: InfoRow(label: 'Weekday First Bus', value: bus['first_bus_time_weekday'] ?? 'N/A')),
                      ],
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.nightlight_round, size: 18, color: Colors.blueGrey),
                        const SizedBox(width: 8),
                        Expanded(child: InfoRow(label: 'Weekday Last Bus', value: bus['last_bus_time_weekday'] ?? 'N/A')),
                      ],
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.sunny, size: 18, color: Colors.orangeAccent),
                        const SizedBox(width: 8),
                        Expanded(child: InfoRow(label: 'Sunday First Bus', value: bus['first_bus_time_sunday'] ?? 'N/A')),
                      ],
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.nightlight, size: 18, color: Colors.orangeAccent),
                        const SizedBox(width: 8),
                        Expanded(child: InfoRow(label: 'Sunday Last Bus', value: bus['last_bus_time_sunday'] ?? 'N/A')),
                      ],
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.timer, size: 18, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(child: InfoRow(label: 'Weekday Frequency', value: '${bus['frequency_weekday'] ?? 'N/A'} min')),
                      ],
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.timer, size: 18, color: Colors.orange),
                        const SizedBox(width: 8),
                        Expanded(child: InfoRow(label: 'Sunday Frequency', value: '${bus['frequency_sunday'] ?? 'N/A'} min')),
                      ],
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
}

class StopsTimeline extends StatelessWidget {
  final List stops;
  const StopsTimeline({super.key, required this.stops});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: [Colors.blue.shade50.withOpacity(0.7), Colors.white.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withOpacity(0.07),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
        border: Border.all(color: Colors.blueAccent.withOpacity(0.10), width: 1),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: stops.length,
        separatorBuilder: (context, index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Divider(height: 1, color: Colors.blueGrey.shade100),
        ),
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: index == 0
                        ? Colors.green.withOpacity(0.15)
                        : index == stops.length - 1
                            ? Colors.redAccent.withOpacity(0.15)
                            : Colors.blueGrey.withOpacity(0.10),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    index == 0
                        ? Icons.radio_button_checked
                        : index == stops.length - 1
                            ? Icons.flag
                            : Icons.circle,
                    color: index == 0
                        ? Colors.green
                        : index == stops.length - 1
                            ? Colors.redAccent
                            : Colors.blueGrey,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      stops[index],
                      style: TextStyle(
                        fontWeight: index == 0 || index == stops.length - 1 ? FontWeight.bold : FontWeight.normal,
                        color: index == 0
                            ? Colors.green
                            : index == stops.length - 1
                                ? Colors.redAccent
                                : Colors.black87,
                        fontSize: 15,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                ),
                if (index == 0)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Text('Start', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500, fontSize: 12)),
                  ),
                if (index == stops.length - 1)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Text('End', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w500, fontSize: 12)),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const InfoRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: Colors.black54), overflow: TextOverflow.ellipsis)),
          Flexible(child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

// Helper function at bottom of file:
TimeOfDay? _parseTimeOfDay(String? time) {
  if (time == null) return null;
  final parts = time.split(":");
  if (parts.length < 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  return TimeOfDay(hour: hour, minute: minute);
}
