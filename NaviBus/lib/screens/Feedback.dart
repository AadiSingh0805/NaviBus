import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class FeedbackPage extends StatefulWidget {
  @override
  _FeedbackPageState createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedCategory;
  TextEditingController _customerNameController = TextEditingController();
  TextEditingController _descriptionController = TextEditingController();
  List<Map<String, dynamic>> _tickets = []; // Feedback data

  // Django API URL
  final String apiUrl = "http://10.0.2.2:8000/feedback/feedback";// Change to your backend URL

  /// ✅ Fetch feedback from the Django backend
  Future<void> _fetchFeedbacks() async {
    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        List<dynamic> feedbackList = json.decode(response.body);
        setState(() {
          _tickets = feedbackList.cast<Map<String, dynamic>>();
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
      final Map<String, String> feedbackData = {
        "name": _customerNameController.text,
        "category": _selectedCategory!,
        "description": _descriptionController.text,
      };

      try {
        final response = await http.post(
          Uri.parse(apiUrl),
          headers: {"Content-Type": "application/json"},
          body: json.encode(feedbackData),
        );

        if (response.statusCode == 201) {
          _fetchFeedbacks(); // Refresh the list after submitting
          _customerNameController.clear();
          _descriptionController.clear();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Feedback submitted successfully!")),
          );
        } else {
          throw Exception("Failed to submit feedback");
        }
      } catch (error) {
        print("Error submitting feedback: $error");
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchFeedbacks(); // Load feedback on page load
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Feedback & Support", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: Color(0xFF042F40),
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
                      SizedBox(height: 15),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submitTicket,
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 15),
                            backgroundColor: Color(0xFF042F40),
                          ),
                          child: Text("Submit Ticket", style: TextStyle(color: Colors.white, fontSize: 16)),
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
                      return Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 3,
                        margin: EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          leading: Icon(Icons.person, color: Colors.blueAccent),
                          title: Text(ticket["name"]!, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Issue: ${ticket["category"]!}", style: TextStyle(fontWeight: FontWeight.bold)),
                              Text(ticket["description"]!, style: TextStyle(color: Colors.black54)),
                            ],
                          ),
                          trailing: Icon(Icons.check_circle, color: Colors.green),
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
