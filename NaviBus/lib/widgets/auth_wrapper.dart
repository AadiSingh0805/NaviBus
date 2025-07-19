import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/auth_page.dart';
import '../screens/home_page.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> with WidgetsBindingObserver {
  bool _isLoading = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAuthStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-check authentication when app resumes
      _checkAuthStatus();
    }
  }

  Future<void> _checkAuthStatus() async {
    try {
      // Check Supabase session first
      final session = Supabase.instance.client.auth.currentSession;
      
      if (session != null) {
        // User has active Supabase session
        setState(() {
          _isAuthenticated = true;
          _isLoading = false;
        });
        return;
      }

      // Check SharedPreferences for saved sessions
      final prefs = await SharedPreferences.getInstance();
      
      // Check regular user session
      final isUserLoggedIn = prefs.getBool('is_user_logged_in') ?? false;
      final userId = prefs.getString('user_id');
      final loginTimeStr = prefs.getString('login_time');
      
      if (isUserLoggedIn && userId != null && loginTimeStr != null) {
        // Check if session is still valid (optional: add expiration logic)
        final loginTime = DateTime.parse(loginTimeStr);
        final now = DateTime.now();
        final daysSinceLogin = now.difference(loginTime).inDays;
        
        // Session valid for 30 days
        if (daysSinceLogin < 30) {
          setState(() {
            _isAuthenticated = true;
            _isLoading = false;
          });
          return;
        } else {
          // Session expired, clear it
          await prefs.remove('is_user_logged_in');
          await prefs.remove('user_id');
          await prefs.remove('login_time');
        }
      }
      
      // Check guest session
      final isGuestLoggedIn = prefs.getBool('is_guest_logged_in') ?? false;
      final guestId = prefs.getString('guest_id');
      final guestLoginTimeStr = prefs.getString('guest_login_time');

      if (isGuestLoggedIn && guestId != null && guestLoginTimeStr != null) {
        // Check if guest session is still valid
        final guestLoginTime = DateTime.parse(guestLoginTimeStr);
        final now = DateTime.now();
        final daysSinceGuestLogin = now.difference(guestLoginTime).inDays;
        
        // Guest session valid for 7 days
        if (daysSinceGuestLogin < 7) {
          setState(() {
            _isAuthenticated = true;
            _isLoading = false;
          });
          return;
        } else {
          // Guest session expired, clear it
          await prefs.remove('is_guest_logged_in');
          await prefs.remove('guest_id');
          await prefs.remove('guest_login_time');
        }
      }

      // No valid session found
      setState(() {
        _isAuthenticated = false;
        _isLoading = false;
      });
    } catch (e) {
      print('Error checking auth status: $e');
      setState(() {
        _isAuthenticated = false;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Color(0xFF042F40),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App logo/name
              Text(
                'NAVI BUS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 30),
              // Loading indicator
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              SizedBox(height: 20),
              Text(
                'Loading...',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Return appropriate screen based on authentication status
    return _isAuthenticated ? const HomePage() : const AuthPage();
  }
}
