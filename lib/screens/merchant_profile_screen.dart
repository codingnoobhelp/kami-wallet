import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Cloud Firestore for merchant data
import 'package:logger/logger.dart'; // Import logger
import 'package:shared_preferences/shared_preferences.dart'; // Import for local storage

// Import the AccountSettingsScreen (if merchants have similar settings)
import 'account_settings_screen.dart'; // Assuming it's in the same 'screens' directory

class MerchantProfileScreen extends StatefulWidget {
  const MerchantProfileScreen({super.key});

  @override
  State<MerchantProfileScreen> createState() => _MerchantProfileScreenState();
}

class _MerchantProfileScreenState extends State<MerchantProfileScreen> {
  final Logger _logger = Logger();
  String _merchantName = 'Merchant';
  String _merchantId = 'N/A';
  String _merchantPhoneNumber = 'N/A'; // Assuming merchants also have a phone number
  String _profileImageUrl = 'https://placehold.co/150x150/aabbcc/ffffff?text=Merchant'; // Default placeholder

  @override
  void initState() {
    super.initState();
    _fetchMerchantProfile();
  }

  Future<void> _fetchMerchantProfile() async {
    // In the current setup, merchants log in using a custom merchant ID.
    // We need to retrieve the merchant's UID or their merchantId from a persistent storage
    // or from the arguments if passed from the login screen.
    // For simplicity, let's assume we can get the logged-in merchant's ID from SharedPreferences
    // or from the Firebase Auth UID if you later integrate Firebase Auth for merchants.

    final prefs = await SharedPreferences.getInstance();
    final String? loggedInMerchantId = prefs.getString('lastLoggedInMerchantId');

    if (loggedInMerchantId == null || loggedInMerchantId.isEmpty) {
      _logger.w('No logged-in merchant ID found in SharedPreferences.');
      return;
    }

    try {
      // Query the 'merchants' collection by 'merchantId' field
      QuerySnapshot merchantQuery = await FirebaseFirestore.instance
          .collection('merchants')
          .where('merchantId', isEqualTo: loggedInMerchantId)
          .limit(1)
          .get();

      if (merchantQuery.docs.isNotEmpty) {
        DocumentSnapshot merchantDoc = merchantQuery.docs.first;
        final merchantData = merchantDoc.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _merchantName = merchantData['merchantName'] ?? 'Merchant';
            _merchantId = merchantData['merchantId'] ?? 'N/A';
            _merchantPhoneNumber = _formatPhoneNumberForDisplay(merchantData['phoneNumber'] ?? 'N/A');
            // If you have a profile image URL in Firestore, fetch it here:
            // _profileImageUrl = merchantData['profileImageUrl'] ?? _profileImageUrl;
          });
        }
        _logger.i('Merchant profile data fetched: $_merchantName, ID: $_merchantId, Phone: $_merchantPhoneNumber');
      } else {
        _logger.w('Merchant document not found for ID: $loggedInMerchantId.');
      }
    } on FirebaseException catch (e) {
      _logger.e('Firestore Error fetching merchant profile: ${e.message}');
      if (mounted) _showMessageBox(context, 'Error loading profile: ${e.message}');
    } catch (e) {
      _logger.e('An unexpected error fetching merchant profile: $e');
      if (mounted) _showMessageBox(context, 'An unexpected error occurred. Please try again.');
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
  void _showMessageBox(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text('Information'),
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
    // Determine if the current theme is dark or light
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: EdgeInsets.only(bottom: MediaQuery.of(context).size.height * 0.015),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white, // Card background adapts to theme
      child: ListTile(
        leading: Icon(icon, color: isDarkMode ? Colors.white70 : Colors.grey[600], size: 28), // Icon color adapts
        title: Text(
          title,
          style: TextStyle(fontSize: 16, color: isDarkMode ? Colors.white : Colors.black87), // Text color adapts
        ),
        trailing: Icon(Icons.chevron_right, color: isDarkMode ? Colors.white54 : Colors.grey), // Trailing icon color adapts
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  // Function to handle merchant logout
  Future<void> _logout(BuildContext context) async {
    // Show confirmation dialog before logging out
    bool? confirmLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to log out of your merchant account?'),
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
        // Clear merchant-specific login data
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('lastLoggedInMerchantId'); // Clear cached merchant ID

        // If you had Firebase Auth for merchants, you'd sign them out here
        // await FirebaseAuth.instance.signOut();

        if (context.mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/role_selection', // Navigate back to the role selection screen
            (route) => false,
          );
        }
      } catch (e) {
        _logger.e('Error during merchant logout: $e');
        if (context.mounted) {
          _showMessageBox(context, 'Error logging out. Please try again.');
        }
      }
    }
  }

  // Function to switch to user login
  Future<void> _switchToUserLogin(BuildContext context) async {
    // Capture the merchant's phone number
    final String phoneNumber = _merchantPhoneNumber; // This is the formatted 080... or 090... number

    // Log out the current merchant session (optional, depending on desired flow)
    // For seamless switch, we might not sign out Firebase Auth if it's the same user account.
    // But we should clear the merchant-specific session.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('lastLoggedInMerchantId'); // Clear merchant ID from prefs

    _logger.i('Switching to user login with phone number: $phoneNumber');

    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/login', // Navigate to the user login page
        (route) => false, // Clear all previous routes
        arguments: {
          'phoneNumber': '+234$phoneNumber', // Pass the full international format to the user login page
        },
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    // Get screen size for responsive design
    final Size screenSize = MediaQuery.of(context).size;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final primaryColor = const Color(0xFF007AFF); // Blue accent

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Adapts to phone theme
      appBar: AppBar(
        title: Text('Merchant Profile', style: TextStyle(color: textColor)),
        centerTitle: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Adapts to phone theme
        foregroundColor: textColor, // Adapts to phone theme
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: textColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
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
                        _showMessageBox(context, 'Edit Merchant Profile Picture clicked!');
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

              // Merchant Name and ID/Phone Number
              Text(
                _merchantName, // Display fetched merchant name
                style: TextStyle(
                  fontSize: screenSize.width * 0.06, // Responsive font size
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              SizedBox(height: screenSize.height * 0.01),
              Text(
                'ID: $_merchantId | Phone: $_merchantPhoneNumber', // Display merchant ID and phone number
                style: TextStyle(
                  fontSize: screenSize.width * 0.04, // Responsive font size
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: screenSize.height * 0.03),

              // Edit Profile Button
              ElevatedButton(
                onPressed: () {
                  _showMessageBox(context, 'Edit Merchant Profile clicked!');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
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
                  'Edit Merchant Profile',
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
                    color: textColor,
                  ),
                ),
              ),
              SizedBox(height: screenSize.height * 0.02),

              // List of Settings Options (can be expanded for merchant-specific settings)
              _buildSettingsTile(
                context,
                icon: Icons.settings,
                title: 'Merchant Settings',
                onTap: () {
                  _showMessageBox(context, 'Merchant Settings not yet implemented.');
                  // Navigator.push(
                  //   context,
                  //   MaterialPageRoute(builder: (context) => const MerchantAccountSettingsScreen()),
                  // );
                },
              ),
              _buildSettingsTile(
                context,
                icon: Icons.security,
                title: 'Security Settings',
                onTap: () {
                  _showMessageBox(context, 'Merchant Security Settings not yet implemented.');
                },
              ),
              SizedBox(height: screenSize.height * 0.04),

              // Switch to User Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _switchToUserLogin(context),
                  icon: const Icon(Icons.switch_account, color: Colors.white),
                  label: const Text(
                    'Switch to User Account',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF), // Blue accent
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
              SizedBox(height: screenSize.height * 0.02),

              // Logout Button
              Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: EdgeInsets.only(bottom: screenSize.height * 0.02),
                  child: ElevatedButton.icon(
                    onPressed: () => _logout(context),
                    icon: const Icon(Icons.logout, color: Colors.redAccent),
                    label: const Text(
                      'Logout Merchant',
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
