import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart'; // Import qr_flutter for QR code generation
import 'package:logger/logger.dart'; // Import logger
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Cloud Firestore

class QrGeneratorScreen extends StatefulWidget {
  const QrGeneratorScreen({super.key});

  @override
  State<QrGeneratorScreen> createState() => _QrGeneratorScreenState();
}

class _QrGeneratorScreenState extends State<QrGeneratorScreen> {
  final Logger _logger = Logger();
  String _qrData = 'No user data available'; // Default data for QR code
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserDataForQr();
  }

  Future<void> _fetchUserDataForQr() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _logger.w('No current user found for QR code generation.');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _qrData = 'Error: User not logged in.';
        });
      }
      return;
    }

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (userDoc.exists && userDoc.data() != null) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final phoneNumber = userData['phoneNumber'] as String? ?? '';
        final firstName = userData['firstName'] as String? ?? '';
        final lastName = userData['lastName'] as String? ?? '';

        // You can customize what data goes into the QR code.
        // For example, a JSON string containing user ID, phone number, and name.
        // This makes it easy for the scanner to parse structured data.
        _qrData = '''{
          "type": "user_profile",
          "uid": "${currentUser.uid}",
          "phoneNumber": "$phoneNumber",
          "name": "$firstName $lastName"
        }''';
        _logger.i('QR data generated for user: ${currentUser.uid}');
      } else {
        _logger.w('User document not found for QR code generation: ${currentUser.uid}');
        _qrData = 'Error: User data not found.';
      }
    } on FirebaseException catch (e) {
      _logger.e('Firestore Error fetching user data for QR: ${e.message}');
      _qrData = 'Error loading user data: ${e.message}';
    } catch (e) {
      _logger.e('An unexpected error occurred fetching user data for QR: $e');
      _qrData = 'An unexpected error occurred.';
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final backgroundColor = isDarkMode ? const Color(0xFF1C1C1E) : Colors.white;
    final cardColor = isDarkMode ? const Color(0xFF2C2C2E) : Colors.grey[100];

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text('My QR Code', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: textColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Scan this QR code to receive payments or share your profile.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: textColor.withOpacity(0.8),
                    ),
                  ),
                  SizedBox(height: screenSize.height * 0.04),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: _qrData,
                      version: QrVersions.auto,
                      size: screenSize.width * 0.6,
                      gapless: true,
                      backgroundColor: Colors.white, // QR code background
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Colors.black,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Colors.black,
                      ),
                      errorStateBuilder: (cxt, err) {
                        _logger.e('QR Generation Error: $err');
                        return Center(
                          child: Text(
                            'Uh oh! Something went wrong generating QR code.\nError: $err',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.red, fontSize: 16),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: screenSize.height * 0.04),
                  Text(
                    'Your unique QR code',
                    style: TextStyle(
                      fontSize: 14,
                      color: textColor.withOpacity(0.6),
                    ),
                  ),
                  SizedBox(height: screenSize.height * 0.02),
                  ElevatedButton.icon(
                    onPressed: () {
                      // In a real app, you might implement sharing functionality here
                      _showMessageBox(context, 'Share QR Code', 'Share functionality not yet implemented.');
                      _logger.i('Share QR Code button pressed.');
                    },
                    icon: Icon(Icons.share, color: Colors.white),
                    label: const Text(
                      'Share QR Code',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007AFF),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
