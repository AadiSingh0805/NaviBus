import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:navibus/services/data_service.dart';
import 'package:navibus/services/image_capture_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  static const String _localComplaintsKey = 'local_complaint_tickets';

  final _formKey = GlobalKey<FormState>();
  final ImageCaptureService _imageCaptureService = ImageCaptureService.instance;
  String? _selectedCategory;
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  List<Map<String, dynamic>> _tickets = [];
  List<Map<String, dynamic>> _backendTickets = [];
  List<Map<String, dynamic>> _localTickets = [];
  String? _complaintImagePath;
  bool _isSubmitting = false;

  void _refreshDisplayedTickets() {
    _tickets = [..._localTickets, ..._backendTickets];
  }

  Future<void> _loadLocalTickets() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_localComplaintsKey);
    if (encoded == null || encoded.isEmpty) {
      return;
    }

    try {
      final decoded = List<dynamic>.from(json.decode(encoded));
      if (!mounted) {
        return;
      }

      setState(() {
        _localTickets = decoded
            .whereType<Map>()
            .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
            .toList()
            .cast<Map<String, dynamic>>();
        _refreshDisplayedTickets();
      });
    } catch (_) {
      await prefs.remove(_localComplaintsKey);
    }
  }

  Future<void> _persistLocalTickets() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localComplaintsKey, json.encode(_localTickets));
  }

  Future<void> _captureComplaintPhoto() async {
    final path = await _imageCaptureService.captureFromCamera(
      folderName: 'complaint_photos',
      filePrefix: 'complaint_camera',
    );

    if (path == null || !mounted) {
      return;
    }

    setState(() {
      _complaintImagePath = path;
    });
  }

  Future<void> _pickComplaintPhoto() async {
    final path = await _imageCaptureService.pickFromGallery(
      folderName: 'complaint_photos',
      filePrefix: 'complaint_gallery',
    );

    if (path == null || !mounted) {
      return;
    }

    setState(() {
      _complaintImagePath = path;
    });
  }

  void _openComplaintPhotoPreview(String imagePath) {
    final file = File(imagePath);
    if (!file.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attached image not found on device.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
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

  /// ✅ Fetch feedback from the Django backend
  Future<void> _fetchFeedbacks() async {
    try {
      // Use DataService to get the correct backend URL
      final dataService = DataService.instance;
      final backendUrl = await dataService.getCurrentBackendUrl();
      final apiUrl = "$backendUrl/feedback/feedback";
      
      final response = await http.get(Uri.parse(apiUrl)).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final feedbackList = List<dynamic>.from(json.decode(response.body));
        final backendTickets = feedbackList
            .whereType<Map>()
            .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
            .toList()
            .cast<Map<String, dynamic>>();

        if (!mounted) {
          return;
        }

        setState(() {
          _backendTickets = backendTickets;
          _refreshDisplayedTickets();
        });
      } else {
        throw Exception("Failed to load feedback");
      }
    } catch (error) {
      print("Error fetching feedback: $error");
    }
  }

  /// ✅ Submit feedback to Django backend
  Future<void> _submitTicket() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSubmitting = true;
      });

      final feedbackData = <String, String>{
        "name": _customerNameController.text,
        "category": _selectedCategory!,
        "description": _descriptionController.text,
      };

      var submittedToBackend = false;

      try {
        // Use DataService to get the correct backend URL
        final dataService = DataService.instance;
        final backendUrl = await dataService.getCurrentBackendUrl();
        final apiUrl = "$backendUrl/feedback/feedback";
        
        final response = await http.post(
          Uri.parse(apiUrl),
          headers: {"Content-Type": "application/json"},
          body: json.encode(feedbackData),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 201) {
          submittedToBackend = true;
        } else {
          throw Exception("Failed to submit feedback");
        }
      } catch (error) {
        print("Error submitting feedback: $error");
      }

      final localTicket = <String, dynamic>{
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'name': _customerNameController.text,
        'category': _selectedCategory,
        'description': _descriptionController.text,
        'image_path': _complaintImagePath,
        'created_at': DateTime.now().toIso8601String(),
        'sync_status': submittedToBackend ? 'Submitted' : 'Queued (Offline)',
      };

      if (mounted) {
        setState(() {
          _localTickets.insert(0, localTicket);
          _refreshDisplayedTickets();
          _isSubmitting = false;
        });
      }

      await _persistLocalTickets();

      if (submittedToBackend) {
        _fetchFeedbacks();
      }

      if (!mounted) {
        return;
      }

      _customerNameController.clear();
      _descriptionController.clear();
      setState(() {
        _selectedCategory = null;
        _complaintImagePath = null;
      });

      if (submittedToBackend) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Feedback submitted and stored on your phone.")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Saved locally. Will remain available on this phone."),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadLocalTickets();
    _fetchFeedbacks(); // Load feedback on page load
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Feedback & Support", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: Color(0xFF042F40),
        iconTheme: IconThemeData(color: Colors.white), // This fixes the back button color
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              elevation: 5,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Submit a Problem Ticket", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      SizedBox(height: 10),

                      // Name Field
                      TextFormField(
                        controller: _customerNameController,
                        decoration: InputDecoration(
                          labelText: "Your Name",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        validator: (value) => value!.isEmpty ? "Please enter your name" : null,
                      ),
                      SizedBox(height: 10),

                      // Category Dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: InputDecoration(
                          labelText: "Select Issue Category",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        items: ["Bus Delay", "App Bug", "Payment Issue", "Driver Behavior", "Other"].map((category) {
                          return DropdownMenuItem<String>(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                        onChanged: (value) => setState(() => _selectedCategory = value),
                        validator: (value) => value == null ? "Please select a category" : null,
                      ),
                      SizedBox(height: 10),

                      // Description Field
                      TextFormField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          labelText: "Describe the issue",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        maxLines: 4,
                        validator: (value) => value!.isEmpty ? "Please enter a description" : null,
                      ),
                      SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _captureComplaintPhoto,
                              icon: const Icon(Icons.photo_camera_outlined),
                              label: const Text('Capture Photo'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD62828),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickComplaintPhoto,
                              icon: const Icon(Icons.photo_library_outlined),
                              label: const Text('Pick Image'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),

                      if (_complaintImagePath != null) ...[
                        SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          height: 170,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.file(
                                    File(_complaintImagePath!),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: CircleAvatar(
                                  backgroundColor: Colors.black54,
                                  child: IconButton(
                                    icon: const Icon(Icons.close, color: Colors.white),
                                    onPressed: () {
                                      setState(() {
                                        _complaintImagePath = null;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      SizedBox(height: 15),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitTicket,
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 15),
                            backgroundColor: Color(0xFF042F40),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Text("Submit Ticket", style: TextStyle(color: Colors.white, fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            SizedBox(height: 20),

            // Display feedback tickets
            Text("Ongoing Tickets", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            SizedBox(height: 10),
            _tickets.isEmpty
                ? Center(child: Text("No ongoing tickets", style: TextStyle(color: Colors.grey, fontSize: 16)))
                : Column(
                    children: _tickets.map((ticket) {
                      final name = (ticket["name"] ?? 'Anonymous').toString();
                      final category = (ticket["category"] ?? 'General').toString();
                      final description = (ticket["description"] ?? 'No description').toString();
                      final imagePath = (ticket['image_path'] ?? '').toString();
                      final hasImage = imagePath.isNotEmpty && File(imagePath).existsSync();
                      final syncStatus = (ticket['sync_status'] ?? '').toString();
                      final queued = syncStatus.toLowerCase().contains('queued');

                      return Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 3,
                        margin: EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          onTap: hasImage ? () => _openComplaintPhotoPreview(imagePath) : null,
                          leading: Icon(hasImage ? Icons.photo_camera : Icons.person, color: Colors.blueAccent),
                          title: Text(name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Issue: $category", style: TextStyle(fontWeight: FontWeight.bold)),
                              Text(description, style: TextStyle(color: Colors.black54)),
                              if (hasImage)
                                const Text(
                                  'Photo attached • tap to view',
                                  style: TextStyle(color: Color(0xFF2E7D32), fontSize: 12),
                                ),
                              if (syncStatus.isNotEmpty)
                                Text(
                                  syncStatus,
                                  style: TextStyle(
                                    color: queued ? Colors.orange : Colors.green,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                          trailing: Icon(
                            queued ? Icons.cloud_off : Icons.check_circle,
                            color: queued ? Colors.orange : Colors.green,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ],
        ),
      ),
    );
  }
}
