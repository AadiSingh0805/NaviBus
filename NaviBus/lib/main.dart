import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:navibus/screens/auth_page.dart';
import 'screens/home_page.dart';
import 'screens/busopts.dart';
import 'screens/payment.dart';

// Ensure LoginPage is imported from the correct file

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://gbkbvwbzwehpioqzleup.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imdia2J2d2J6d2VocGlvcXpsZXVwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTAzNTU2MjksImV4cCI6MjA2NTkzMTYyOX0.1WA5rcsSQMcejlkJcGJqxHpAajw_9lXSdsBXaKNgUSE',
  );
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
        '/': (context) => AuthPage(),
        '/home': (context) => HomePage(),
        '/busopts': (context) => BusOptions(),
        '/payment': (context) => const Payment(bus: null),
        '/paymentconfirm': (context) => const Payment(bus: null),
      },
    );
  }
}
