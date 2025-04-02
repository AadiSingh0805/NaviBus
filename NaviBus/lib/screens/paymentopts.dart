import 'package:flutter/material.dart';
import 'package:navibus/screens/Feedback.dart';

class PaymentOptions extends StatelessWidget {
  final dynamic bus; // Bus details

  const PaymentOptions({super.key, required this.bus});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "NAVI BUS",
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Color(0xFF042F40), // Custom Hex Color
        actions: [
          IconButton(
            icon: Icon(Icons.support_agent, color: Colors.white), // Support Icon
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => FeedbackPage()),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.account_circle, color: Colors.white), // Profile Icon
            onPressed: () {
              // Navigate to Profile Page
            },
          ),
        ],
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            // Payment Options Title
            const Center(
              child: Text(
                "Choose a Payment Method",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87, // Darker text for contrast
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),

            // Outer Box
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF042F40),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Payment Options
                    _buildPaymentOption("Credit / Debit Card", ["assets/visa.jpg", "assets/mastercard.png"]),
                    _buildPaymentOption("Wallets", ["assets/razorpay.png", "assets/paytm.png"]),
                    _buildPaymentOption("UPI", ["assets/gpay.png", "assets/phonepe.png", "assets/paytm.png"]),

                    const Spacer(),

                    // Pay Now Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          // Proceed to payment confirmation
                          Navigator.pushNamed(context, "/payment-confirm", arguments: bus);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text(
                          "Pay Now",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
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

  // Widget for each payment option box
  Widget _buildPaymentOption(String title, List<String> imagePaths) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0), // Increased padding for better spacing
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20), // Increased padding for aesthetics
        decoration: BoxDecoration(
          color: Colors.grey[100], // Softer background for payment boxes
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.withOpacity(0.5)),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 20, // Bigger text for clarity
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: imagePaths.map((path) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: Image.asset(path, width: 70, height: 70), // Standardized logo size
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
