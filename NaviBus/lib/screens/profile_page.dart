import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  User? currentUser;
  bool isLoading = true;
  String displayName = '';
  String displayEmail = '';
  String displayId = '';
  bool isGuest = false;

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
  }

  void _getCurrentUser() {
    try {
      currentUser = Supabase.instance.client.auth.currentUser;
      
      if (currentUser != null) {
        // Check if user is anonymous (guest)
        isGuest = currentUser!.isAnonymous;
        
        if (isGuest) {
          // For guest users
          displayName = 'Guest User';
          displayEmail = 'No email (Guest account)';
          displayId = 'Guest ID: ${currentUser!.id.substring(0, 8)}...';
        } else {
          // For regular users
          displayName = currentUser!.userMetadata?['name'] ?? 
                       currentUser!.userMetadata?['full_name'] ?? 
                       'User';
          displayEmail = currentUser!.email ?? 'No email provided';
          displayId = 'User ID: ${currentUser!.id.substring(0, 8)}...';
        }
      } else {
        // No user logged in
        displayName = 'Not logged in';
        displayEmail = 'Please log in to view profile';
        displayId = '';
      }
    } catch (e) {
      print('Error getting user: $e');
      displayName = 'Error loading profile';
      displayEmail = 'Please try again';
      displayId = '';
    }
    
    setState(() {
      isLoading = false;
    });
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard!'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF042F40), // Matching your app's theme
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (currentUser != null)
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: _signOut,
              tooltip: 'Sign Out',
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF042F40)))
          : Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFF5F5F5),
                    Color(0xFFEEEEEE),
                  ],
                ),
              ),
              child: Center(
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  margin: const EdgeInsets.all(24),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white,
                          Color(0xFFFAFAFA),
                        ],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Profile Avatar
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: isGuest 
                                  ? [Colors.orange.shade300, Colors.orange.shade500]
                                  : [const Color(0xFF042F40), const Color(0xFF0A3F50)],
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 48,
                              backgroundColor: Colors.transparent,
                              child: Icon(
                                isGuest ? Icons.person_outline : Icons.account_circle,
                                size: 80,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 18),
                          
                          // User Type Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isGuest 
                                  ? [Colors.orange.shade100, Colors.orange.shade200]
                                  : [const Color(0xFF042F40).withValues(alpha: 0.1), const Color(0xFF042F40).withValues(alpha: 0.2)],
                              ),
                              borderRadius: BorderRadius.circular(25),
                              boxShadow: [
                                BoxShadow(
                                  color: (isGuest ? Colors.orange : const Color(0xFF042F40)).withValues(alpha: 0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isGuest ? Icons.person_outline : Icons.verified_user,
                                  size: 16,
                                  color: isGuest ? Colors.orange.shade700 : const Color(0xFF042F40),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isGuest ? 'Guest Account' : 'Registered User',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isGuest ? Colors.orange.shade700 : const Color(0xFF042F40),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Display Name
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF042F40), // Matching your app theme
                            ),
                            textAlign: TextAlign.center,
                          ),
                          
                          const SizedBox(height: 8),
                          
                          // Email/Status
                          GestureDetector(
                            onTap: () => _copyToClipboard(displayEmail, 'Email'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8F9FA),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withValues(alpha: 0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isGuest ? Icons.info_outline : Icons.email_outlined,
                                    size: 18,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 12),
                                  Flexible(
                                    child: Text(
                                      displayEmail,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  if (!isGuest) ...[
                                    const SizedBox(width: 12),
                                    Icon(
                                      Icons.copy,
                                      size: 16,
                                      color: Colors.grey.shade500,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 12),
                          
                          // User/Guest ID
                          if (displayId.isNotEmpty)
                            GestureDetector(
                              onTap: () => _copyToClipboard(currentUser?.id ?? '', 'User ID'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8F9FA),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.fingerprint,
                                      size: 18,
                                      color: Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      displayId,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Icon(
                                      Icons.copy,
                                      size: 14,
                                      color: Colors.grey.shade500,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          
                          const SizedBox(height: 24),
                          
                          // Action Buttons
                          if (currentUser != null) ...[
                            if (isGuest) ...[
                              // Guest user - encourage registration
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF4CAF50), Color(0xFF388E3C)],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).pushReplacementNamed('/');
                                  },
                                  icon: const Icon(Icons.person_add, color: Colors.white),
                                  label: const Text('Create Account', style: TextStyle(color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            
                            // Sign Out Button
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF042F40), Color(0xFF0A3F50)],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF042F40).withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton.icon(
                                onPressed: _signOut,
                                icon: const Icon(Icons.logout, color: Colors.white),
                                label: Text(
                                  isGuest ? 'Exit Guest Mode' : 'Sign Out',
                                  style: const TextStyle(color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ] else ...[
                            // Not logged in
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF042F40), Color(0xFF0A3F50)],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF042F40).withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).pushReplacementNamed('/');
                                },
                                icon: const Icon(Icons.login, color: Colors.white),
                                label: const Text('Sign In', style: TextStyle(color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                          
                          const SizedBox(height: 16),
                          
                          // Additional Info
                          if (isGuest)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.orange.shade50, Colors.orange.shade100],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.orange.shade200),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.orange.withValues(alpha: 0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.orange.shade700,
                                    size: 24,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'You\'re using guest mode. Create an account to save your preferences and booking history.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.orange.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
