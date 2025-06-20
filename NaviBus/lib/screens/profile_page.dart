import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  final String userName;
  final String userEmail;
  final String? userPhone;

  const ProfilePage({
    super.key,
    this.userName = 'John Doe',
    this.userEmail = 'john.doe@example.com',
    this.userPhone = '+91 9876543210',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF042F40),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        color: Colors.blue.shade50,
        child: Center(
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: Colors.deepPurple.shade100,
                    child: const Icon(Icons.account_circle, size: 80, color: Color(0xFF042F40)),
                  ),
                  const SizedBox(height: 18),
                  Text(userName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF042F40))),
                  const SizedBox(height: 8),
                  Text(userEmail, style: const TextStyle(fontSize: 16, color: Colors.black54)),
                  if (userPhone != null) ...[
                    const SizedBox(height: 8),
                    Text(userPhone!, style: const TextStyle(fontSize: 16, color: Colors.black54)),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.logout, color: Colors.white),
                    label: const Text('Logout', style: TextStyle(color: Colors.white)),
                    onPressed: () {
                      // TODO: Implement logout logic
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF042F40),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
