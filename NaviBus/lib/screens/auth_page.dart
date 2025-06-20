import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool isLogin = true;
  bool isPhoneLogin = false;
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  bool isLoading = false;
  String? errorMsg;
  String? smsSessionId;
  final TextEditingController otpController = TextEditingController();

  void toggleForm() {
    setState(() {
      isLogin = !isLogin;
      errorMsg = null;
    });
  }

  void switchToPhoneLogin() {
    setState(() {
      isPhoneLogin = true;
      errorMsg = null;
    });
  }

  void switchToEmailLogin() {
    setState(() {
      isPhoneLogin = false;
      errorMsg = null;
    });
  }

  Future<void> handleAuth() async {
    setState(() { isLoading = true; errorMsg = null; });
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final name = nameController.text.trim();
    final phone = phoneController.text.trim();
    if (isPhoneLogin) {
      final phonePattern = RegExp(r'^[0-9]{10}');
      if (!phonePattern.hasMatch(phone)) {
        setState(() { errorMsg = 'Enter a valid 10-digit phone number.'; isLoading = false; });
        return;
      }
      if (smsSessionId == null) {
        // Step 1: Request OTP
        try {
          final supabase = Supabase.instance.client;
          await supabase.auth.signInWithOtp(phone: '+91$phone');
          setState(() {
            smsSessionId = 'sent'; // Just a flag to show OTP field
            errorMsg = 'OTP sent to +91$phone';
            isLoading = false;
          });
        } catch (e) {
          setState(() { errorMsg = 'Failed to send OTP: $e'; isLoading = false; });
        }
        return;
      } else {
        // Step 2: Verify OTP
        final otp = otpController.text.trim();
        if (otp.isEmpty) {
          setState(() { errorMsg = 'Enter the OTP sent to your phone.'; isLoading = false; });
          return;
        }
        try {
          final supabase = Supabase.instance.client;
          final res = await supabase.auth.verifyOTP(
            type: OtpType.sms,
            phone: '+91$phone',
            token: otp,
          );
          if (res.user != null) {
            setState(() { smsSessionId = null; });
            Navigator.of(context).pushReplacementNamed('/home');
          } else {
            setState(() { errorMsg = 'OTP verification failed.'; });
          }
        } catch (e) {
          setState(() { errorMsg = 'OTP verification failed: $e'; });
        } finally {
          setState(() { isLoading = false; });
        }
        return;
      }
    } else {
      if (email.isEmpty || password.isEmpty || (!isLogin && name.isEmpty)) {
        setState(() { errorMsg = 'Please fill all fields.'; isLoading = false; });
        return;
      }
      try {
        final supabase = Supabase.instance.client;
        AuthResponse res;
        if (isLogin) {
          res = await supabase.auth.signInWithPassword(email: email, password: password);
        } else {
          res = await supabase.auth.signUp(email: email, password: password, data: {'name': name});
        }
        if (res.user != null) {
          Navigator.of(context).pushReplacementNamed('/home');
        } else {
          setState(() { errorMsg = 'Authentication failed.'; });
        }
      } catch (e) {
        setState(() { errorMsg = 'Error: $e'; });
      } finally {
        setState(() { isLoading = false; });
      }
    }
  }

  void guestLogin() async {
    setState(() { isLoading = true; errorMsg = null; });
    try {
      final supabase = Supabase.instance.client;
      final res = await supabase.auth.signInAnonymously();
      if (res.user != null) {
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        setState(() { errorMsg = 'Guest login failed.'; });
      }
    } catch (e) {
      setState(() { errorMsg = 'Guest login failed: $e'; });
    } finally {
      setState(() { isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mainColor = const Color(0xFF042F40);
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 70),
            Image.asset('assets/logo.png', width: 150, height: 150, fit: BoxFit.contain),
            const SizedBox(height: 10),
            Text(
              "Welcome to NAVI BUS",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: mainColor),
            ),
            const SizedBox(height: 40),
            Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isPhoneLogin
                        ? (isLogin ? 'Phone Login' : 'Phone Sign Up')
                        : (isLogin ? 'Login' : 'Sign Up'),
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: mainColor)),
                    const SizedBox(height: 24),
                    if (!isPhoneLogin && !isLogin)
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Name', prefixIcon: Icon(Icons.person)),
                      ),
                    if (isPhoneLogin)
                      Column(
                        children: [
                          TextField(
                            controller: phoneController,
                            keyboardType: TextInputType.phone,
                            maxLength: 10,
                            decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone)),
                            enabled: smsSessionId == null,
                          ),
                          if (smsSessionId != null) ...[
                            const SizedBox(height: 12),
                            TextField(
                              controller: otpController,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              decoration: const InputDecoration(labelText: 'Enter OTP', prefixIcon: Icon(Icons.sms)),
                            ),
                          ],
                        ],
                      ),
                    if (!isPhoneLogin)
                      ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: emailController,
                          decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email)),
                        ),
                      ],
                    if (!isPhoneLogin)
                      const SizedBox(height: 12),
                    if (!isPhoneLogin)
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock)),
                      ),
                    const SizedBox(height: 18),
                    if (errorMsg != null)
                      Text(errorMsg!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: mainColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: isLoading ? null : handleAuth,
                        child: isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(isPhoneLogin
                              ? (smsSessionId == null ? 'Send OTP' : 'Verify OTP')
                              : (isLogin ? 'Login' : 'Sign Up'),
                            style: const TextStyle(color: Colors.white)),
                      ),
                    ),
                    TextButton(
                      onPressed: isLoading ? null : toggleForm,
                      child: Text(isLogin ? "Don't have an account? Sign Up" : "Already have an account? Login", style: TextStyle(color: mainColor)),
                    ),
                    if (isLogin && !isPhoneLogin)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: isLoading
                              ? null
                              : () async {
                                  final email = emailController.text.trim();
                                  if (email.isEmpty) {
                                    setState(() { errorMsg = 'Enter your email to reset password.'; });
                                    return;
                                  }
                                  try {
                                    final supabase = Supabase.instance.client;
                                    await supabase.auth.resetPasswordForEmail(email);
                                    setState(() { errorMsg = 'Password reset email sent!'; });
                                  } catch (e) {
                                    setState(() { errorMsg = 'Failed to send reset email.'; });
                                  }
                                },
                          child: Text('Forgot Password?', style: TextStyle(color: mainColor, fontWeight: FontWeight.w500)),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: isLoading ? null : guestLogin,
                            icon: const Icon(Icons.person_outline),
                            label: const Text('Continue as Guest'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: mainColor,
                              side: BorderSide(color: mainColor),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: isLoading ? null : () {
                              if (isPhoneLogin) {
                                switchToEmailLogin();
                              } else {
                                switchToPhoneLogin();
                              }
                            },
                            icon: const Icon(Icons.phone_android),
                            label: Text(isPhoneLogin ? 'Email Login' : 'Phone Login'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: mainColor,
                              side: BorderSide(color: mainColor),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "By Logging in, you agree to our Terms & Conditions and Privacy Policy.",
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
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
}
