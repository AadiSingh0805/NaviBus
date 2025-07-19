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
        backgroundColor: Colors.red,
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
          ? const Center(child: CircularProgressIndicator())
          : Container(
              color: Colors.grey.shade50,
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
                        // Profile Avatar
                        CircleAvatar(
                          radius: 48,
                          backgroundColor: isGuest ? Colors.orange.shade100 : Colors.blue.shade100,
                          child: Icon(
                            isGuest ? Icons.person_outline : Icons.account_circle,
                            size: 80,
                            color: isGuest ? Colors.orange : Colors.blue,
                          ),
                        ),
                        
                        const SizedBox(height: 18),
                        
                        // User Type Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isGuest ? Colors.orange.shade100 : Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isGuest ? '👤 Guest Account' : '👨‍💼 Registered User',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isGuest ? Colors.orange.shade700 : Colors.blue.shade700,
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Display Name
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // Email/Status
                        GestureDetector(
                          onTap: () => _copyToClipboard(displayEmail, 'Email'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isGuest ? Icons.info_outline : Icons.email_outlined,
                                  size: 16,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    displayEmail,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                if (!isGuest) ...[
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.copy,
                                    size: 14,
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
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.fingerprint,
                                    size: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    displayId,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  const SizedBox(width: 8),
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
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(context).pushReplacementNamed('/');
                              },
                              icon: const Icon(Icons.person_add),
                              label: const Text('Create Account'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          
                          // Sign Out Button
                          ElevatedButton.icon(
                            onPressed: _signOut,
                            icon: const Icon(Icons.logout),
                            label: Text(isGuest ? 'Exit Guest Mode' : 'Sign Out'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                          ),
                        ] else ...[
                          // Not logged in
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pushReplacementNamed('/');
                            },
                            icon: const Icon(Icons.login),
                            label: const Text('Sign In'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                          ),
                        ],
                        
                        const SizedBox(height: 16),
                        
                        // Additional Info
                        if (isGuest)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.orange.shade700,
                                  size: 20,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'You\'re using guest mode. Create an account to save your preferences and booking history.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange.shade700,
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
    );
  }
}
