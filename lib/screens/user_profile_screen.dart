import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Cloud Firestore for user data
import 'package:logger/logger.dart'; // Import logger
import 'package:shared_preferences/shared_preferences.dart'; // Import for local storage

// Import the new AccountSettingsScreen
import 'account_settings_screen.dart'; // Assuming it's in the same 'screens' directory

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final Logger _logger = Logger();
  String _userName = 'User';
  String _userEmail = 'user@example.com';
  String _userPhoneNumber = 'N/A'; // Will display the phone number as account number
  String _profileImageUrl = 'https://placehold.co/150x150/aabbcc/ffffff?text=User'; // Default placeholder
  bool _isLoginPasscodeSet = false; // To track if login passcode is set
  bool _hasMerchantAccount = false; // NEW: To track if user has a linked merchant account

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();

        if (userDoc.exists && userDoc.data() != null) {
          final userData = userDoc.data() as Map<String, dynamic>;
          if (mounted) {
            setState(() {
              _userName = userData['firstName'] ?? 'User';
              _userEmail = userData['email'] ?? 'user@example.com';
              // Display phone number as account number
              _userPhoneNumber = _formatPhoneNumberForDisplay(userData['phoneNumber'] ?? currentUser.phoneNumber ?? 'N/A');
              _isLoginPasscodeSet = userData['loginPasscodeSet'] ?? false; // Fetch login passcode status
              // If you have a profile image URL in Firestore, fetch it here:
              // _profileImageUrl = userData['profileImageUrl'] ?? _profileImageUrl;
            });
          }
          _logger.i('User profile data fetched: $_userName, $_userEmail, $_userPhoneNumber, Login Passcode Set: $_isLoginPasscodeSet');

          // NEW: Check for linked merchant account
          final merchantQuery = await FirebaseFirestore.instance
              .collection('merchants')
              .where('userUid', isEqualTo: currentUser.uid)
              .limit(1)
              .get();

          if (mounted) {
            setState(() {
              _hasMerchantAccount = merchantQuery.docs.isNotEmpty;
            });
          }
          _logger.i('User has linked merchant account: $_hasMerchantAccount');

        } else {
          _logger.w('User document not found for UID: ${currentUser.uid}. Assuming no login passcode set and no merchant account.');
          if (mounted) {
            setState(() {
              _userPhoneNumber = _formatPhoneNumberForDisplay(currentUser.phoneNumber ?? 'N/A'); // Fallback to auth phone
              _isLoginPasscodeSet = false; // Default to false if document not found
              _hasMerchantAccount = false;
            });
          }
        }
      } on FirebaseException catch (e) {
        _logger.e('Firestore Error fetching user profile: ${e.message}');
        if (mounted) _showMessageBox(context, 'Error loading profile: ${e.message}', 'Please try again later.');
      } catch (e) {
        _logger.e('An unexpected error fetching user profile: $e');
        if (mounted) _showMessageBox(context, 'An unexpected error occurred.', 'Please try again.');
      }
    } else {
      _logger.w('No current user found for profile screen.');
    }
  }

  // Helper function to format phone number for display (e.g., remove country code prefix)
  String _formatPhoneNumberForDisplay(String rawPhoneNumber) {
    if (rawPhoneNumber.startsWith('+234')) {
      if (rawPhoneNumber.length > 4 && rawPhoneNumber[4] == '0') {
        return rawPhoneNumber.substring(5); // Remove +234 and leading 0
      } else {
        return rawPhoneNumber.substring(4); // Remove +234
      }
    } else if (rawPhoneNumber.startsWith('0') && rawPhoneNumber.length >= 10) {
      return rawPhoneNumber.substring(1); // Remove leading 0
    }
    return rawPhoneNumber; // Return as is if no specific formatting applies
  }

  // Helper function to show a message box (instead of alert)
  void _showMessageBox(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // Helper function to build a settings list tile
  Widget _buildSettingsTile(BuildContext context, {required IconData icon, required String title, required VoidCallback onTap}) {
    return Card(
      margin: EdgeInsets.only(bottom: MediaQuery.of(context).size.height * 0.015), // Responsive margin
      elevation: 2, // Card shadow
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12), // Rounded corners for the card
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.grey[600], size: 28),
        title: Text(
          title,
          style: const TextStyle(fontSize: 16, color: Colors.black87),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  // Function to handle user logout with passcode check
  Future<void> _logout(BuildContext context) async {
    // Show confirmation dialog before logging out
    bool? confirmLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to log out? You will need your login passcode to sign back in.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false); // User cancelled
              },
            ),
            TextButton(
              child: const Text('Logout', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop(true); // User confirmed
              },
            ),
          ],
        );
      },
    );

    if (confirmLogout == true) {
      try {
        await FirebaseAuth.instance.signOut();
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('lastLoggedInPhoneNumber'); // Clear cached phone number on logout
        if (context.mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/phone', // Navigate back to the phone entry screen
            (route) => false,
          );
        }
      } catch (e) {
        debugPrint('Error during logout: $e');
        if (context.mounted) {
          _showMessageBox(context, 'Error logging out.', 'Please try again.');
        }
      }
    }
  }

  // NEW: Function to switch to merchant login
  Future<void> _switchToMerchantLogin(BuildContext context) async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _showMessageBox(context, 'Error', 'No authenticated user found. Please log in as a user first.');
      return;
    }

    // Check if a merchant account is linked to this user's UID
    try {
      DocumentSnapshot merchantDoc = await FirebaseFirestore.instance
          .collection('merchants')
          .doc(currentUser.uid)
          .get();

      if (merchantDoc.exists && merchantDoc.data() != null) {
        final merchantData = merchantDoc.data() as Map<String, dynamic>;
        final String merchantId = merchantData['merchantId'] ?? '';

        if (merchantId.isNotEmpty) {
          // Save the merchantId to SharedPreferences for the merchant login screen to pick up
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('lastLoggedInMerchantId', merchantId);

          _logger.i('Switching to merchant login with ID: $merchantId');
          if (context.mounted) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/merchant_login', // Navigate to the merchant login page
              (route) => false, // Clear all previous routes
            );
          }
        } else {
          _showMessageBox(context, 'Error', 'Linked merchant account found but Merchant ID is missing.');
        }
      } else {
        _showMessageBox(context, 'No Merchant Account', 'You do not have a merchant account linked to your user profile. Please create one first.');
        // Optionally navigate to merchant signup if desired:
        // if (context.mounted) {
        //   Navigator.pushNamed(context, '/merchant_signup');
        // }
      }
    } on FirebaseException catch (e) {
      _logger.e('Firestore Error checking merchant account: ${e.message}');
      if (mounted) _showMessageBox(context, 'Error', 'Failed to check merchant account: ${e.message}');
    } catch (e) {
      _logger.e('An unexpected error occurred checking merchant account: $e');
      if (mounted) _showMessageBox(context, 'Error', 'An unexpected error occurred. Please try again.');
    }
  }


  @override
  Widget build(BuildContext context) {
    // Get screen size for responsive design
    final Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: screenSize.width * 0.05), // Responsive horizontal padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: screenSize.height * 0.03), // Responsive vertical spacing

              // Profile Picture and Edit Button
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: screenSize.width * 0.15, // Responsive avatar size
                    backgroundColor: Colors.grey[200],
                    backgroundImage: NetworkImage(_profileImageUrl), // Use fetched image URL
                    onBackgroundImageError: (exception, stackTrace) {
                      _logger.e('Error loading profile image: $exception');
                      // Fallback to a local asset or a default icon if network fails
                      // Example: setState(() { _profileImageUrl = 'assets/default_avatar.png'; });
                    },
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: GestureDetector(
                      onTap: () {
                        _showMessageBox(context, 'Edit Profile Picture', 'Edit Profile Picture clicked!');
                      },
                      child: CircleAvatar(
                        radius: screenSize.width * 0.04, // Responsive edit icon size
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.edit,
                          color: Colors.grey[600],
                          size: screenSize.width * 0.03, // Responsive icon size
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: screenSize.height * 0.02),

              // User Name and Account Number/Email
              Text(
                _userName, // Display fetched user name
                style: TextStyle(
                  fontSize: screenSize.width * 0.06, // Responsive font size
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: screenSize.height * 0.01),
              Text(
                _userPhoneNumber, // Display fetched user phone number as account number
                style: TextStyle(
                  fontSize: screenSize.width * 0.04, // Responsive font size
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: screenSize.height * 0.03),

              // Edit Profile Button
              ElevatedButton(
                onPressed: () {
                  _showMessageBox(context, 'Edit Profile', 'Edit Profile clicked!');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: screenSize.width * 0.08,
                    vertical: screenSize.height * 0.015,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(screenSize.width * 0.03),
                  ),
                  elevation: 5,
                ),
                child: Text(
                  'Edit Profile',
                  style: TextStyle(fontSize: screenSize.width * 0.04),
                ),
              ),
              SizedBox(height: screenSize.height * 0.04),

              // Account Settings Section
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Account Settings',
                  style: TextStyle(
                    fontSize: screenSize.width * 0.045,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ),
              SizedBox(height: screenSize.height * 0.02),

              // List of Settings Options
              _buildSettingsTile(
                context,
                icon: Icons.settings,
                title: 'Account Settings',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AccountSettingsScreen()),
                  );
                },
              ),
              _buildSettingsTile(
                context,
                icon: Icons.people_alt,
                title: 'Privacy',
                onTap: () => _showMessageBox(context, 'Privacy', 'Privacy clicked!'),
              ),
              _buildSettingsTile(
                context,
                icon: Icons.handshake,
                title: 'Partners & Services',
                onTap: () => _showMessageBox(context, 'Partners & Services', 'Partners & Services clicked!'),
              ),
              _buildSettingsTile(
                context,
                icon: Icons.history,
                title: 'Login Activity',
                onTap: () => _showMessageBox(context, 'Login Activity', 'Login Activity clicked!'),
              ),
              _buildSettingsTile(
                context,
                icon: Icons.document_scanner,
                title: 'Documents',
                onTap: () => _showMessageBox(context, 'Documents', 'Documents clicked!'),
              ),
              _buildSettingsTile(
                context,
                icon: Icons.store,
                title: 'Store',
                onTap: () => _showMessageBox(context, 'Store', 'Store clicked!'),
              ),
              SizedBox(height: screenSize.height * 0.04),

              // NEW: Switch to Merchant Button (conditionally displayed)
              if (_hasMerchantAccount)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _switchToMerchantLogin(context),
                    icon: const Icon(Icons.storefront, color: Colors.white),
                    label: const Text(
                      'Switch to Merchant Account',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00C853), // Green accent
                      padding: EdgeInsets.symmetric(
                        horizontal: screenSize.width * 0.05,
                        vertical: screenSize.height * 0.015,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 5,
                    ),
                  ),
                ),
              SizedBox(height: _hasMerchantAccount ? screenSize.height * 0.02 : 0), // Add spacing only if button is visible

              // Logout Button at the bottom left
              Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: EdgeInsets.only(bottom: screenSize.height * 0.02),
                  child: ElevatedButton.icon(
                    onPressed: () => _logout(context), // Call the modified logout function
                    icon: const Icon(Icons.logout, color: Colors.redAccent),
                    label: const Text(
                      'Logout',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent.withOpacity(0.1),
                      foregroundColor: Colors.redAccent,
                      padding: EdgeInsets.symmetric(
                        horizontal: screenSize.width * 0.05,
                        vertical: screenSize.height * 0.015,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
