import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

class RoleSelectionScreen extends StatelessWidget {
  final Logger _logger = Logger();

  RoleSelectionScreen({super.key});

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

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final buttonColor = isDarkMode ? const Color(0xFF2C2C2E) : Colors.white;
    final primaryColor = const Color(0xFF007AFF);

    // Extract phone number from arguments
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final String? phoneNumber = args?['phoneNumber'] as String?;

    if (phoneNumber == null) {
      _logger.w('No phone number provided in arguments. Navigating back.');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showMessageBox(context, 'Invalid access. Please enter a phone number.');
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      });
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: textColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: screenSize.width * 0.08),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'How would you like to log in?',
              style: TextStyle(
                fontSize: screenSize.width * 0.06,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: screenSize.height * 0.05),
            SizedBox(
              width: double.infinity,
              height: screenSize.height * 0.08,
              child: ElevatedButton(
                onPressed: phoneNumber == null
                    ? null
                    : () {
                        _logger.i('Login as User selected.');
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/login',
                          (route) => false,
                          arguments: {
                            'phoneNumber': phoneNumber,
                            'role': 'user',
                          },
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 5,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person, size: screenSize.width * 0.06),
                    SizedBox(width: screenSize.width * 0.03),
                    Text(
                      'Login as User',
                      style: TextStyle(
                        fontSize: screenSize.width * 0.045,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: screenSize.height * 0.03),
            SizedBox(
              width: double.infinity,
              height: screenSize.height * 0.08,
              child: OutlinedButton(
                onPressed: phoneNumber == null
                    ? null
                    : () {
                        _logger.i('Login as Merchant selected.');
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/merchant_login',
                          (route) => false,
                          arguments: {
                            'phoneNumber': phoneNumber,
                            'role': 'merchant',
                          },
                        );
                      },
                style: OutlinedButton.styleFrom(
                  backgroundColor: buttonColor,
                  foregroundColor: primaryColor,
                  side: BorderSide(color: primaryColor, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 2,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.store, size: screenSize.width * 0.06),
                    SizedBox(width: screenSize.width * 0.03),
                    Text(
                      'Login as Merchant',
                      style: TextStyle(
                        fontSize: screenSize.width * 0.045,
                        fontWeight: FontWeight.bold,
                      ),
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