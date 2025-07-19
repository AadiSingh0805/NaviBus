import 'package:flutter/material.dart';
import 'otpverify.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController phoneController = TextEditingController();

  void sendOTP() {
    String phoneNumber = "+91${phoneController.text.trim()}";

    // Navigate to OTP screen (Mock verification)
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OTPVerificationScreen(
          phoneNumber: phoneNumber,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: 70),
            Image.asset('assets/logo.png', width: 150, height: 150, fit: BoxFit.contain),
            SizedBox(height: 10),
            Text(
              "Welcome to NAVI BUS",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 140),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Enter Your Mobile No.",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              decoration: InputDecoration(
                labelText: "Mobile Number",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
            ),
            SizedBox(height: 20),
            Padding(
              padding: EdgeInsets.all(15),
              child: ElevatedButton(
                onPressed: sendOTP,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF042F40),
                  padding: EdgeInsets.symmetric(vertical: 15),
                  fixedSize: Size(350, 70),
                ),
                child: Text("Get OTP", style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ),
            Text(
              "By Logging in, you agree to our Terms & Conditions and Privacy Policy.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
