import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:navibus/services/data_service.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

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

  // For autocomplete with performance optimizations
  List<String> sourceSuggestions = [];
  List<String> destinationSuggestions = [];
  Timer? _debounceSource;
  Timer? _debounceDestination;
  List<String> recentSources = [];
  List<String> recentDestinations = [];
  Map<String, int> frequentSources = {};
  Map<String, int> frequentDestinations = {};
  static const int maxRecent = 5;
  
  // Performance optimization fields
  Map<String, List<String>> _suggestionCache = {};
  bool _isSearching = false;
  String? _lastSourceQuery;
  String? _lastDestinationQuery;

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
  }

  /// Load recent searches from SharedPreferences
  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      recentSources = prefs.getStringList('multi_recent_sources') ?? ['Borivali Station', 'Andheri Station'];
      recentDestinations = prefs.getStringList('multi_recent_destinations') ?? ['Colaba Bus Station', 'Gateway of India'];
      
      // Load frequent searches (stored as JSON)
      final frequentSourcesJson = prefs.getString('multi_frequent_sources') ?? '{}';
      final frequentDestinationsJson = prefs.getString('multi_frequent_destinations') ?? '{}';
      
      frequentSources = Map<String, int>.from(json.decode(frequentSourcesJson));
      frequentDestinations = Map<String, int>.from(json.decode(frequentDestinationsJson));
      
      // Add some default frequent searches if empty
      if (frequentSources.isEmpty) {
        frequentSources = {'Borivali Station': 3, 'Andheri Station': 2};
      }
      if (frequentDestinations.isEmpty) {
        frequentDestinations = {'Colaba Bus Station': 3, 'Gateway of India': 2};
      }
    });
  }

  /// Save recent searches to SharedPreferences
  Future<void> _saveRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('multi_recent_sources', recentSources);
    await prefs.setStringList('multi_recent_destinations', recentDestinations);
    await prefs.setString('multi_frequent_sources', json.encode(frequentSources));
    await prefs.setString('multi_frequent_destinations', json.encode(frequentDestinations));
  }

  Future<List<String>> fetchStopSuggestions(String query) async {
    if (query.isEmpty) return [];
    
    // Check cache first for performance
    if (_suggestionCache.containsKey(query)) {
      return _suggestionCache[query]!;
    }
    
    // Prevent concurrent requests
    if (_isSearching) return [];
    
    try {
      _isSearching = true;
      
      // Use DataService to get the correct backend URL
      final dataService = DataService.instance;
      final backendUrl = await dataService.getCurrentBackendUrl();
      final url = Uri.parse('$backendUrl/stops/autocomplete/?q=${Uri.encodeComponent(query)}');
      
      print('Fetching suggestions from: $url');
      final response = await http.get(url).timeout(Duration(seconds: 3)); // Reduced timeout
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<String> results = List<String>.from(data['results'] ?? []);
        print('Got ${results.length} suggestions for "$query"');
        
        // Cache the results
        _suggestionCache[query] = results;
        
        // Limit cache size to prevent memory issues
        if (_suggestionCache.length > 50) {
          final keys = _suggestionCache.keys.toList();
          _suggestionCache.remove(keys.first);
        }
        
        return results;
      } else {
        print('Autocomplete API returned ${response.statusCode}');
      }
    } catch (e) {
      print('Autocomplete error: $e');
    } finally {
      _isSearching = false;
    }
    
    // Fallback: search through cached data
    try {
      final dataService = DataService.instance;
      final data = await dataService.getAllData();
      
      if (data['stops'] != null) {
        List<String> matches = [];
        for (var stop in data['stops']) {
          if (stop['name'] != null) {
            String stopName = stop['name'].toString();
            if (stopName.toLowerCase().contains(query.toLowerCase())) {
              matches.add(stopName);
            }
          }
        }
        // Sort matches and return top 10
        matches.sort();
        print('Fallback: Got ${matches.length} cached suggestions for "$query"');
        
        // Cache fallback results too
        final fallbackResults = matches.take(10).toList();
        _suggestionCache[query] = fallbackResults;
        
        return fallbackResults;
      }
    } catch (e) {
      print('Fallback autocomplete error: $e');
    }
    
    return [];
  }

  void onSourceChanged(String value) {
    // Avoid unnecessary API calls for duplicate queries
    if (value == _lastSourceQuery) return;
    _lastSourceQuery = value;
    
    if (_debounceSource?.isActive ?? false) _debounceSource!.cancel();
    
    // Use shorter debounce for initial typing to make suggestions appear faster
    final debounceTime = value.length <= 2 ? 400 : 600;
    _debounceSource = Timer(Duration(milliseconds: debounceTime), () async {
      // Only search if we have at least 1 character to show suggestions quickly
      if (mounted && value.length >= 1) {
        final suggestions = await fetchStopSuggestions(value);
        if (mounted) {
          setState(() {
            sourceSuggestions = suggestions;
          });
        }
      } else if (mounted && value.isEmpty) {
        // Clear suggestions when field is empty
        setState(() {
          sourceSuggestions = [];
        });
      }
    });
  }

  void onDestinationChanged(String value) {
    // Avoid unnecessary API calls for duplicate queries
    if (value == _lastDestinationQuery) return;
    _lastDestinationQuery = value;
    
    if (_debounceDestination?.isActive ?? false) _debounceDestination!.cancel();
    
    // Use shorter debounce for initial typing to make suggestions appear faster
    final debounceTime = value.length <= 2 ? 400 : 600;
    _debounceDestination = Timer(Duration(milliseconds: debounceTime), () async {
      // Only search if we have at least 1 character to show suggestions quickly
      if (mounted && value.length >= 1) {
        final suggestions = await fetchStopSuggestions(value);
        if (mounted) {
          setState(() {
            destinationSuggestions = suggestions;
          });
        }
      } else if (mounted && value.isEmpty) {
        // Clear suggestions when field is empty
        setState(() {
          destinationSuggestions = [];
        });
      }
    });
  }

  void addRecentSource(String stop) {
    setState(() {
      recentSources.remove(stop);
      recentSources.insert(0, stop);
      if (recentSources.length > maxRecent) recentSources = recentSources.sublist(0, maxRecent);
      frequentSources[stop] = (frequentSources[stop] ?? 0) + 1;
    });
    _saveRecentSearches(); // Persist to storage
  }
  
  void addRecentDestination(String stop) {
    setState(() {
      recentDestinations.remove(stop);
      recentDestinations.insert(0, stop);
      if (recentDestinations.length > maxRecent) recentDestinations = recentDestinations.sublist(0, maxRecent);
      frequentDestinations[stop] = (frequentDestinations[stop] ?? 0) + 1;
    });
    _saveRecentSearches(); // Persist to storage
  }

  Future<void> searchBestJourney() async {
    final start = sourceController.text.trim();
    final end = destinationController.text.trim();
    if (start.isEmpty || end.isEmpty) {
      setState(() { errorMsg = 'Source or destination is empty'; });
      return;
    }
    setState(() { loading = true; errorMsg = null; });
    
    try {
      // Use DataService to get the correct backend URL
      final dataService = DataService.instance;
      final backendUrl = await dataService.getCurrentBackendUrl();
      final url = Uri.parse('$backendUrl/routes/plan/?start=$start&end=$end');
      print('Calling multi-route planner API: $url');
      
      final response = await http.get(url).timeout(Duration(seconds: 10));
      print('Multi-route response status: ${response.statusCode}');
      print('Multi-route response body: ${response.body}');
      
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
      print('Error fetching multi-route journey: $e');
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
    // Cancel any pending debounce timers
    _debounceSource?.cancel();
    _debounceDestination?.cancel();
    
    // Dispose controllers for memory management
    sourceController.dispose();
    destinationController.dispose();
    
    // Clear caches to free memory
    _suggestionCache.clear();
    
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
            // Add mobile performance optimizations
            physics: const BouncingScrollPhysics(),
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
                          
                          // If input is empty, show recent and frequent stops
                          if (input.isEmpty) {
                            return [...recentSources.take(3), ...frequentSources.keys.take(5)];
                          }
                          
                          // Combine all available suggestions
                          final List<String> recents = recentSources.where((s) => s.toLowerCase().contains(input)).toList();
                          final List<String> frequents = frequentSources.keys
                              .where((s) => !recents.contains(s) && s.toLowerCase().contains(input))
                              .toList()
                            ..sort((a, b) => frequentSources[b]!.compareTo(frequentSources[a]!));
                          final List<String> backend = sourceSuggestions
                              .where((s) => !recents.contains(s) && !frequents.contains(s) && s.toLowerCase().contains(input))
                              .toList();
                          
                          // Always show suggestions even if only one character is typed
                          final allSuggestions = [...recents, ...frequents, ...backend];
                          
                          // If we don't have enough suggestions and input has at least 1 character, trigger fetch
                          if (allSuggestions.length < 3 && input.length >= 1) {
                            // Trigger suggestion fetch with a slight delay to avoid excessive calls
                            Future.delayed(Duration(milliseconds: 100), () {
                              onSourceChanged(textEditingValue.text);
                            });
                          }
                          
                          return allSuggestions.take(10).toList();
                        },
                        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            // Mobile optimizations for better performance
                            textInputAction: TextInputAction.next,
                            keyboardType: TextInputType.text,
                            autofocus: false,
                            // Fix backspace and performance issues
                            autocorrect: false,
                            enableSuggestions: false,
                            maxLines: 1,
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              labelText: "Enter Source",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Color(0xFF042F40), width: 2),
                              ),
                              prefixIcon: Icon(Icons.location_on, color: Colors.blueAccent),
                              // Optimized clear button
                              suffixIcon: controller.text.isNotEmpty 
                                ? IconButton(
                                    icon: Icon(Icons.clear, color: Colors.grey),
                                    onPressed: () {
                                      controller.clear();
                                      onSourceChanged('');
                                      // Don't call setState here to prevent lag
                                    },
                                  )
                                : null,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            ),
                            onChanged: (value) {
                              onSourceChanged(value);
                              // Removed unnecessary setState call
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
                          
                          // If input is empty, show recent and frequent stops
                          if (input.isEmpty) {
                            return [...recentDestinations.take(3), ...frequentDestinations.keys.take(5)];
                          }
                          
                          // Combine all available suggestions
                          final List<String> recents = recentDestinations.where((s) => s.toLowerCase().contains(input)).toList();
                          final List<String> frequents = frequentDestinations.keys
                              .where((s) => !recents.contains(s) && s.toLowerCase().contains(input))
                              .toList()
                            ..sort((a, b) => frequentDestinations[b]!.compareTo(frequentDestinations[a]!));
                          final List<String> backend = destinationSuggestions
                              .where((s) => !recents.contains(s) && !frequents.contains(s) && s.toLowerCase().contains(input))
                              .toList();
                          
                          // Always show suggestions even if only one character is typed
                          final allSuggestions = [...recents, ...frequents, ...backend];
                          
                          // If we don't have enough suggestions and input has at least 1 character, trigger fetch
                          if (allSuggestions.length < 3 && input.length >= 1) {
                            // Trigger suggestion fetch with a slight delay to avoid excessive calls
                            Future.delayed(Duration(milliseconds: 100), () {
                              onDestinationChanged(textEditingValue.text);
                            });
                          }
                          
                          return allSuggestions.take(10).toList();
                        },
                        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            // Mobile optimizations for better performance
                            textInputAction: TextInputAction.search,
                            keyboardType: TextInputType.text,
                            autofocus: false,
                            // Fix backspace and performance issues
                            autocorrect: false,
                            enableSuggestions: false,
                            maxLines: 1,
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              labelText: "Enter Destination",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Color(0xFF042F40), width: 2),
                              ),
                              prefixIcon: Icon(Icons.flag, color: Colors.redAccent),
                              // Optimized clear button
                              suffixIcon: controller.text.isNotEmpty 
                                ? IconButton(
                                    icon: Icon(Icons.clear, color: Colors.grey),
                                    onPressed: () {
                                      controller.clear();
                                      onDestinationChanged('');
                                      // Don't call setState here to prevent lag
                                    },
                                  )
                                : null,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            ),
                            onChanged: (value) {
                              onDestinationChanged(value);
                              // Removed unnecessary setState call
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
