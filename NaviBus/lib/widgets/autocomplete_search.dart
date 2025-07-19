import 'package:flutter/material.dart';
import 'package:navibus/services/data_service.dart';
import 'dart:async';

class AutocompleteSearchField extends StatefulWidget {
  final TextEditingController controller;
  final Function(String) onRouteSelected;
  final String hintText;

  const AutocompleteSearchField({
    Key? key,
    required this.controller,
    required this.onRouteSelected,
    this.hintText = "Search for Buses (Route No.)",
  }) : super(key: key);

  @override
  _AutocompleteSearchFieldState createState() => _AutocompleteSearchFieldState();
}

class _AutocompleteSearchFieldState extends State<AutocompleteSearchField> {
  List<String> _suggestions = [];
  bool _showSuggestions = false;
  Timer? _debounceTimer;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _debounceTimer?.cancel();
    _removeOverlay();
    super.dispose();
  }

  void _onTextChanged() {
    final text = widget.controller.text.trim();
    
    if (text.isEmpty) {
      _removeOverlay();
      return;
    }

    // Debounce search requests - improved for better performance
    _debounceTimer?.cancel();
    _debounceTimer = Timer(Duration(milliseconds: 500), () {
      if (mounted) {
        _searchRoutes(text);
      }
    });
  }

  Future<void> _searchRoutes(String query) async {
    if (!mounted) return;
    
    try {
      // Get real route suggestions from DataService
      final suggestions = await _getRouteSuggestions(query);
      
      if (mounted) {
        setState(() {
          _suggestions = suggestions;
          _showSuggestions = suggestions.isNotEmpty;
        });

        if (_showSuggestions) {
          _showOverlay();
        } else {
          _removeOverlay();
        }
      }
    } catch (e) {
      print('Error fetching suggestions: $e');
      if (mounted) {
        // Fallback to empty suggestions on error
        setState(() {
          _suggestions = [];
          _showSuggestions = false;
        });
        _removeOverlay();
      }
    }
  }

  Future<List<String>> _getRouteSuggestions(String query) async {
    try {
      // Use DataService to get all bus data
      final dataService = DataService.instance;
      final data = await dataService.getAllData();
      
      Set<String> suggestions = {};
      
      // Search through route numbers
      if (data['buses'] != null) {
        for (var bus in data['buses']) {
          if (bus['route_number'] != null) {
            String routeNumber = bus['route_number'].toString();
            if (routeNumber.toLowerCase().contains(query.toLowerCase())) {
              suggestions.add(routeNumber);
            }
          }
        }
      }
      
      // Also search through stop names if we have them
      if (data['stops'] != null) {
        for (var stop in data['stops']) {
          if (stop['name'] != null) {
            String stopName = stop['name'].toString();
            if (stopName.toLowerCase().contains(query.toLowerCase())) {
              // Add stop name as suggestion with a prefix to distinguish
              suggestions.add("📍 $stopName");
            }
          }
        }
      }
      
      // Convert to list and limit to 8 suggestions, prioritize routes
      List<String> routeSuggestions = suggestions.where((s) => !s.startsWith("📍")).toList();
      List<String> stopSuggestions = suggestions.where((s) => s.startsWith("📍")).toList();
      
      // Combine: routes first, then stops, max 8 total
      List<String> result = [];
      result.addAll(routeSuggestions.take(6));
      result.addAll(stopSuggestions.take(8 - result.length));
      
      return result;
    } catch (e) {
      print('Error getting route suggestions: $e');
    }
    
    // Fallback to empty list
    return [];
  }

  void _showOverlay() {
    _removeOverlay();
    
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: MediaQuery.of(context).size.width - 32, // Account for padding
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, 60), // Position below the text field
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: ListView.builder(
                // Performance optimizations
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const BouncingScrollPhysics(),
                itemCount: _suggestions.length,
                // Performance improvements
                addAutomaticKeepAlives: false,
                addRepaintBoundaries: true,
                addSemanticIndexes: false,
                itemBuilder: (context, index) {
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.directions_bus,
                      color: Color(0xFF042F40),
                      size: 20,
                    ),
                    title: Text(
                      'Route ${_suggestions[index]}',
                      style: TextStyle(fontSize: 14),
                    ),
                    onTap: () {
                      widget.controller.text = _suggestions[index];
                      _removeOverlay();
                      widget.onRouteSelected(_suggestions[index]);
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() {
      _showSuggestions = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: widget.controller,
        textInputAction: TextInputAction.search,
        keyboardType: TextInputType.text,
        // Fix backspace and performance issues
        autocorrect: false,
        enableSuggestions: false,
        maxLines: 1,
        autofocus: false,
        decoration: InputDecoration(
          hintText: widget.hintText,
          prefixIcon: Icon(Icons.search, color: Color(0xFF042F40)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(50),
            borderSide: BorderSide(color: Colors.grey),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(50),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(50),
            borderSide: BorderSide(color: Color(0xFF042F40), width: 2),
          ),
          suffixIcon: widget.controller.text.isNotEmpty 
            ? IconButton(
                icon: Icon(Icons.clear, color: Colors.grey),
                onPressed: () {
                  widget.controller.clear();
                  _removeOverlay();
                },
              )
            : null,
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        onSubmitted: (value) {
          _removeOverlay();
          if (value.trim().isNotEmpty) {
            widget.onRouteSelected(value.trim());
          }
        },
        onTap: () {
          if (widget.controller.text.isNotEmpty && _suggestions.isNotEmpty) {
            _showOverlay();
          }
        },
      ),
    );
  }
}
