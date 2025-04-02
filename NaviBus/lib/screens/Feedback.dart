import 'package:flutter/material.dart';

class FeedbackPage extends StatefulWidget {
  @override
  _FeedbackPageState createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedCategory;
  TextEditingController _descriptionController = TextEditingController();
  List<Map<String, String>> _tickets = []; // Only in-memory storage

  /// Submit a new ticket
  void _submitTicket() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _tickets.add({
          "category": _selectedCategory!,
          "description": _descriptionController.text,
        });
      });
      _descriptionController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Ticket Submitted Successfully!")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Feedback & Support", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: Color(0xFF042F40),
        centerTitle: true,
        elevation: 5,
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
                      Text("Submit a Problem Ticket", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87)),
                      SizedBox(height: 10),
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
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submitTicket,
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            backgroundColor: Color(0xFF042F40),
                          ),
                          child: Text("Submit Ticket", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            SizedBox(height: 20),

            Stack(
              children: [
                Opacity(
                  opacity: 0.1,
                  child: Center(
                    child: Image.asset(
                      "assets/logo.png",
                      width: 300,
                      height: 300,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Ongoing Tickets", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87)),
                    SizedBox(height: 10),
                    _tickets.isEmpty
                        ? Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text("No ongoing tickets", style: TextStyle(color: Colors.grey, fontSize: 16)),
                            ),
                          )
                        : Column(
                            children: _tickets.map((ticket) {
                              return Card(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 3,
                                margin: EdgeInsets.symmetric(vertical: 6),
                                child: ListTile(
                                  leading: Icon(Icons.confirmation_number, color: Colors.blueAccent),
                                  title: Text(ticket["category"]!, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                                  subtitle: Text(ticket["description"]!, style: TextStyle(color: Colors.black54)),
                                  trailing: Icon(Icons.check_circle, color: Colors.green),
                                ),
                              );
                            }).toList(),
                          ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
