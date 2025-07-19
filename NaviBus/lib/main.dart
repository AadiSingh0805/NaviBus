import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:navibus/screens/auth_page.dart';
import 'package:navibus/widgets/auth_wrapper.dart';
import 'screens/home_page.dart';
import 'screens/busopts.dart';
import 'screens/busopts_new.dart';
import 'screens/payment.dart';

// Ensure LoginPage is imported from the correct file

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Performance optimizations
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Color(0xFF042F40),
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF042F40),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  
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
      title: 'NaviBus',
      // Performance optimizations
      builder: (context, child) {
        // Disable font scaling for better performance and consistent UI
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
          child: child!,
        );
      },
      theme: ThemeData(
        primarySwatch: Colors.blue,
        primaryColor: Color(0xFF042F40),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        // Performance optimizations for animations
        pageTransitionsTheme: PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
        // Reduce overdraw with efficient text themes
        textTheme: Theme.of(context).textTheme.apply(
          bodyColor: Colors.black87,
          displayColor: Colors.black87,
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => AuthWrapper(),
        '/auth': (context) => AuthPage(),
        '/home': (context) => HomePage(),
        '/busopts': (context) => BusOptions(),
        '/busopts_new': (context) => BusOptionsNew(),
        '/payment': (context) => const Payment(bus: null),
        '/paymentconfirm': (context) => const Payment(bus: null),
      },
    );
  }
}
