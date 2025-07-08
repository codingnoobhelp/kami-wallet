import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/biometric_settings_screen.dart';
import 'package:logger/logger.dart'; // Import logger
import 'login_passcode_screen.dart'; // Import LoginPasscodeScreen (renamed)

class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key});

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

  @override
  Widget build(BuildContext context) {
    final Logger logger = Logger();
    final Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Adapts to phone theme
      appBar: AppBar(
        title: const Text('Account Settings'),
        centerTitle: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Adapts to phone theme
        foregroundColor: Theme.of(context).textTheme.bodyLarge?.color, // Adapts to phone theme
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Theme.of(context).textTheme.bodyLarge?.color),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: screenSize.width * 0.05),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: screenSize.height * 0.03),
              Text(
                'Manage your account preferences.',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                ),
              ),
              SizedBox(height: screenSize.height * 0.02),

              _buildSettingsTile(
                context,
                icon: Icons.lock_outline,
                title: 'Login Passcode', // Updated title
                onTap: () {
                  logger.i('Login Passcode clicked! Navigating to LoginPasscodeScreen.');
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPasscodeScreen()), // Navigate to LoginPasscodeScreen
                  );
                },
              ),
              _buildSettingsTile(
                context,
                icon: Icons.credit_card,
                title: 'Payment Methods',
                onTap: () {
                  logger.i('Payment Methods clicked!');
                  _showMessageBox(context, 'Payment Methods settings not yet implemented.');
                },
              ),
              _buildSettingsTile(
                context,
                icon: Icons.color_lens_outlined,
                title: 'Themes & Appearance',
                onTap: () {
                  logger.i('Themes & Appearance clicked!');
                  _showMessageBox(context, 'Themes & Appearance settings not yet implemented.');
                },
              ),
              _buildSettingsTile(
                context,
                icon: Icons.fingerprint,
                title: 'Biometric Security',
                onTap: () {
                  logger.i('Biometric Security clicked!');
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const BiometricSettingsScreen()),
                  );
                },
              ),
              SizedBox(height: screenSize.height * 0.04),
            ],
          ),
        ),
      ),
    );
  }
}
