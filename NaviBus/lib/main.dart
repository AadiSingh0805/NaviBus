import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_page.dart';
import 'screens/busopts_new.dart';
import 'screens/payment.dart';
import 'screens/profile_page.dart';
import 'screens/tickets_page.dart';
import 'screens/Feedback.dart';
import 'screens/notification_control_page.dart';
import 'services/notification_service.dart';

// Ensure LoginPage is imported from the correct file

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Performance optimizations
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Color(0xFFD62828),
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  await NotificationService.instance.initialize();
  
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
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
          child: child!,
        );
      },
      theme: ThemeData(
        primaryColor: const Color(0xFFD62828),
        scaffoldBackgroundColor: const Color(0xFFF3F3F5),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD62828),
          primary: const Color(0xFFD62828),
          secondary: const Color(0xFFF77F00),
          surface: Colors.white,
        ),
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
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFD62828),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      initialRoute: '/home',
      routes: {
        '/': (context) => const HomePage(),
        '/home': (context) => HomePage(),
        '/busopts': (context) => const BusOptionsNew(),
        '/busopts_new': (context) => const BusOptionsNew(),
        '/payment': (context) => const Payment(bus: null),
        '/paymentconfirm': (context) => const Payment(bus: null),
        '/profile': (context) => const ProfilePage(),
        '/tickets': (context) => const TicketsPage(),
        '/feedback': (context) => const FeedbackPage(),
        '/notifications': (context) => const NotificationControlPage(),
      },
    );
  }
}
