import 'package:flutter/material.dart';
import 'screens/login.dart';
import 'screens/home_page.dart';
import 'screens/otpverify.dart';
import 'screens/busopts.dart';
import 'screens/payment.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bus Tracker',
      theme: ThemeData(primarySwatch: Colors.red),
      initialRoute: '/',
      routes: {
        '/': (context) => HomePage(),
        '/home': (context) => HomePage(),
        '/busopts': (context) => BusOptions(),
        '/payment': (context) => const Payment(bus: null),
        '/paymentconfirm': (context) => const Payment(bus: null),
      },
    );
  }
}
