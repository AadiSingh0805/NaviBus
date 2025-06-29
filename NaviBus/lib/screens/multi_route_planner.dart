import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';

class MultiRoutePlannerScreen extends StatefulWidget {
  const MultiRoutePlannerScreen({super.key});

  @override
  State<MultiRoutePlannerScreen> createState() => _MultiRoutePlannerScreenState();
}

class _MultiRoutePlannerScreenState extends State<MultiRoutePlannerScreen> {
  final TextEditingController sourceController = TextEditingController();
  final TextEditingController destinationController = TextEditingController();
  List<dynamic> plannedSegments = [];
  int totalStops = 0;
  int transfers = 0;
  bool loading = false;
  String? errorMsg;

  // For autocomplete
  List<String> sourceSuggestions = [];
  List<String> destinationSuggestions = [];
  Timer? _debounceSource;
  Timer? _debounceDestination;
  List<String> recentSources = [];
  List<String> recentDestinations = [];
  Map<String, int> frequentSources = {};
  Map<String, int> frequentDestinations = {};
  static const int maxRecent = 5;

  Future<List<String>> fetchStopSuggestions(String query) async {
    if (query.isEmpty) return [];
    final url = Uri.parse('http://10.0.2.2:8000/api/stops/autocomplete/?q=${Uri.encodeComponent(query)}');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<String>.from(data['results'] ?? []);
      }
    } catch (e) {
      print('Autocomplete error: $e');
    }
    return [];
  }

  void onSourceChanged(String value) {
    if (_debounceSource?.isActive ?? false) _debounceSource!.cancel();
    _debounceSource = Timer(const Duration(milliseconds: 300), () async {
      final suggestions = await fetchStopSuggestions(value);
      setState(() {
        sourceSuggestions = suggestions;
      });
    });
  }

  void onDestinationChanged(String value) {
    if (_debounceDestination?.isActive ?? false) _debounceDestination!.cancel();
    _debounceDestination = Timer(const Duration(milliseconds: 300), () async {
      final suggestions = await fetchStopSuggestions(value);
      setState(() {
        destinationSuggestions = suggestions;
      });
    });
  }

  void addRecentSource(String stop) {
    setState(() {
      recentSources.remove(stop);
      recentSources.insert(0, stop);
      if (recentSources.length > maxRecent) recentSources = recentSources.sublist(0, maxRecent);
      frequentSources[stop] = (frequentSources[stop] ?? 0) + 1;
    });
  }
  void addRecentDestination(String stop) {
    setState(() {
      recentDestinations.remove(stop);
      recentDestinations.insert(0, stop);
      if (recentDestinations.length > maxRecent) recentDestinations = recentDestinations.sublist(0, maxRecent);
      frequentDestinations[stop] = (frequentDestinations[stop] ?? 0) + 1;
    });
  }

  Future<void> searchBestJourney() async {
    final start = sourceController.text.trim();
    final end = destinationController.text.trim();
    if (start.isEmpty || end.isEmpty) {
      setState(() { errorMsg = 'Source or destination is empty'; });
      return;
    }
    setState(() { loading = true; errorMsg = null; });
    final url = Uri.parse('http://10.0.2.2:8000/api/routes/plan/?start=$start&end=$end');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          plannedSegments = data['segments'] ?? [];
          totalStops = data['total_stops'] ?? 0;
          transfers = data['transfers'] ?? 0;
          loading = false;
        });
      } else {
        setState(() {
          plannedSegments = [];
          totalStops = 0;
          transfers = 0;
          loading = false;
          errorMsg = 'No path found.';
        });
      }
    } catch (e) {
      setState(() {
        plannedSegments = [];
        totalStops = 0;
        transfers = 0;
        loading = false;
        errorMsg = 'Error fetching journey.';
      });
    }
  }

  @override
  void dispose() {
    _debounceSource?.cancel();
    _debounceDestination?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Multi-Route Journey Planner'),
        backgroundColor: const Color(0xFF042F40),
      ),
      body: Container(
        color: Colors.blue.shade50,
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Plan Your Journey",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Color(0xFF042F40)),
                      ),
                      const SizedBox(height: 18),
                      RawAutocomplete<String>(
                        textEditingController: sourceController,
                        focusNode: FocusNode(),
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          final input = textEditingValue.text.toLowerCase();
                          final List<String> recents = recentSources.where((s) => s.toLowerCase().contains(input)).toList();
                          final List<String> frequents = frequentSources.keys
                              .where((s) => !recents.contains(s) && s.toLowerCase().contains(input))
                              .toList()
                            ..sort((a, b) => frequentSources[b]!.compareTo(frequentSources[a]!));
                          final List<String> backend = sourceSuggestions
                              .where((s) => !recents.contains(s) && !frequents.contains(s) && s.toLowerCase().contains(input))
                              .toList();
                          return [...recents, ...frequents, ...backend];
                        },
                        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: const InputDecoration(
                              labelText: "Enter Source",
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.location_on, color: Colors.blueAccent),
                            ),
                            onChanged: (value) async {
                              onSourceChanged(value);
                              setState(() {});
                            },
                          );
                        },
                        optionsViewBuilder: (context, onSelected, options) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 4.0,
                              child: SizedBox(
                                height: 220.0,
                                child: ListView(
                                  padding: EdgeInsets.zero,
                                  children: [
                                    if (recentSources.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                        child: Text('Recent', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                                      ),
                                    ...options.where((s) => recentSources.contains(s)).map((s) => ListTile(
                                          leading: Icon(Icons.history, color: Colors.blueGrey),
                                          title: Text(s),
                                          onTap: () {
                                            onSelected(s);
                                            sourceController.text = s;
                                            addRecentSource(s);
                                          },
                                        )),
                                    if (frequentSources.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                        child: Text('Frequent', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                      ),
                                    ...options.where((s) => frequentSources.containsKey(s) && !recentSources.contains(s)).map((s) => ListTile(
                                          leading: Icon(Icons.star, color: Colors.green),
                                          title: Text(s),
                                          onTap: () {
                                            onSelected(s);
                                            sourceController.text = s;
                                            addRecentSource(s);
                                          },
                                        )),
                                    if (sourceSuggestions.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                        child: Text('Suggestions', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                                      ),
                                    ...options.where((s) => !recentSources.contains(s) && !frequentSources.containsKey(s)).map((option) => ListTile(
                                          title: Text(option),
                                          onTap: () {
                                            onSelected(option);
                                            sourceController.text = option;
                                            addRecentSource(option);
                                          },
                                        )),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      RawAutocomplete<String>(
                        textEditingController: destinationController,
                        focusNode: FocusNode(),
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          final input = textEditingValue.text.toLowerCase();
                          final List<String> recents = recentDestinations.where((s) => s.toLowerCase().contains(input)).toList();
                          final List<String> frequents = frequentDestinations.keys
                              .where((s) => !recents.contains(s) && s.toLowerCase().contains(input))
                              .toList()
                            ..sort((a, b) => frequentDestinations[b]!.compareTo(frequentDestinations[a]!));
                          final List<String> backend = destinationSuggestions
                              .where((s) => !recents.contains(s) && !frequents.contains(s) && s.toLowerCase().contains(input))
                              .toList();
                          return [...recents, ...frequents, ...backend];
                        },
                        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: const InputDecoration(
                              labelText: "Enter Destination",
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.flag, color: Colors.redAccent),
                            ),
                            onChanged: (value) async {
                              onDestinationChanged(value);
                              setState(() {});
                            },
                          );
                        },
                        optionsViewBuilder: (context, onSelected, options) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 4.0,
                              child: SizedBox(
                                height: 220.0,
                                child: ListView(
                                  padding: EdgeInsets.zero,
                                  children: [
                                    if (recentDestinations.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                        child: Text('Recent', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                                      ),
                                    ...options.where((s) => recentDestinations.contains(s)).map((s) => ListTile(
                                          leading: Icon(Icons.history, color: Colors.blueGrey),
                                          title: Text(s),
                                          onTap: () {
                                            onSelected(s);
                                            destinationController.text = s;
                                            addRecentDestination(s);
                                          },
                                        )),
                                    if (frequentDestinations.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                        child: Text('Frequent', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                      ),
                                    ...options.where((s) => frequentDestinations.containsKey(s) && !recentDestinations.contains(s)).map((s) => ListTile(
                                          leading: Icon(Icons.star, color: Colors.green),
                                          title: Text(s),
                                          onTap: () {
                                            onSelected(s);
                                            destinationController.text = s;
                                            addRecentDestination(s);
                                          },
                                        )),
                                    if (destinationSuggestions.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                        child: Text('Suggestions', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                                      ),
                                    ...options.where((s) => !recentDestinations.contains(s) && !frequentDestinations.containsKey(s)).map((option) => ListTile(
                                          title: Text(option),
                                          onTap: () {
                                            onSelected(option);
                                            destinationController.text = option;
                                            addRecentDestination(option);
                                          },
                                        )),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.alt_route, color: Colors.white),
                          label: const Text('Plan Journey', style: TextStyle(color: Colors.white)),
                          onPressed: () {
                            addRecentSource(sourceController.text.trim());
                            addRecentDestination(destinationController.text.trim());
                            searchBestJourney();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF042F40),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (loading) Center(child: CircularProgressIndicator()),
                      if (errorMsg != null) Text(errorMsg!, style: TextStyle(color: Colors.red)),
                      if (plannedSegments.isNotEmpty)
                        Card(
                          color: Colors.deepPurple.shade50,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Best Journey Plan",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.deepPurple),
                                ),
                                SizedBox(height: 6),
                                Text("Total Stops: $totalStops, Transfers: $transfers", style: TextStyle(color: Colors.black54)),
                                SizedBox(height: 8),
                                ...plannedSegments.map((seg) => Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Route: \\${seg['route_number']}", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8.0, bottom: 6.0),
                                      child: Text("Stops: \\${(seg['stops'] as List).join(' → ')}", style: TextStyle(color: Colors.black87)),
                                    ),
                                  ],
                                )),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
