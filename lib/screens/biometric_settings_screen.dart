import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart'; // Import local_auth for biometric authentication
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Cloud Firestore
import 'package:logger/logger.dart'; // Import logger

class BiometricSettingsScreen extends StatefulWidget {
  const BiometricSettingsScreen({super.key});

  @override
  State<BiometricSettingsScreen> createState() => _BiometricSettingsScreenState();
}

class _BiometricSettingsScreenState extends State<BiometricSettingsScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final Logger _logger = Logger();
  bool _biometricEnabled = false;
  bool _isAuthenticating = false; // To prevent multiple authentication prompts
  bool _isLoading = true; // To show loading state while fetching initial status

  @override
  void initState() {
    super.initState();
    _checkBiometricStatus(); // Check the current biometric status from Firestore on load
  }

  // Fetches the current biometricEnabled status for the user from Firestore
  Future<void> _checkBiometricStatus() async {
    setState(() {
      _isLoading = true;
    });

    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _logger.w('No current user found. Biometric settings cannot be loaded.');
      if (mounted) {
        setState(() {
          _biometricEnabled = false;
          _isLoading = false;
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
        if (mounted) {
          setState(() {
            _biometricEnabled = userData['biometricEnabled'] ?? false;
            _isLoading = false;
          });
        }
        _logger.i('Biometric status loaded for ${currentUser.uid}: $_biometricEnabled');
      } else {
        _logger.w('User document not found for ${currentUser.uid}. Assuming biometrics are disabled.');
        if (mounted) {
          setState(() {
            _biometricEnabled = false;
            _isLoading = false;
          });
        }
      }
    } on FirebaseException catch (e) {
      _logger.e('Firestore Error fetching biometric status: ${e.message}');
      if (mounted) {
        setState(() {
          _biometricEnabled = false;
          _isLoading = false;
        });
        _showMessageBox(context, 'Error loading biometric settings: ${e.message}');
      }
    } catch (e) {
      _logger.e('An unexpected error occurred while fetching biometric status: $e');
      if (mounted) {
        setState(() {
          _biometricEnabled = false;
          _isLoading = false;
        });
        _showMessageBox(context, 'An unexpected error occurred. Please try again.');
      }
    }
  }

  // Toggles the biometric setting and updates Firestore
  Future<void> _toggleBiometricSetting(bool newValue) async {
    if (_isAuthenticating) return; // Prevent multiple simultaneous authentications

    setState(() {
      _isAuthenticating = true;
    });

    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _logger.e('No authenticated user found to update biometric settings.');
      if (mounted) {
        _showMessageBox(context, 'Error: No authenticated user. Please log in again.');
      }
      setState(() { _isAuthenticating = false; });
      return;
    }

    bool authenticated = false;
    try {
      // Check if biometrics are available on the device
      bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
      List<BiometricType> availableBiometrics = await _localAuth.getAvailableBiometrics();

      if (!canCheckBiometrics || availableBiometrics.isEmpty) {
        _logger.w('No biometrics available on device or not set up.');
        if (mounted) {
          _showMessageBox(context, 'Biometric authentication is not available or not set up on this device.');
        }
        setState(() { _isAuthenticating = false; });
        return;
      }

      // Prompt for biometric authentication to confirm the change
      authenticated = await _localAuth.authenticate(
        localizedReason: newValue
            ? 'Please authenticate to enable biometric login'
            : 'Please authenticate to disable biometric login',
        options: const AuthenticationOptions(
          stickyAuth: true, // Keep authentication active after app is backgrounded
          biometricOnly: true, // Only allow biometric authentication
        ),
      );

      if (authenticated) {
        _logger.i('Biometric authentication successful. Updating Firestore...');
        await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).update({
          'biometricEnabled': newValue,
        });

        if (mounted) {
          setState(() {
            _biometricEnabled = newValue;
            _isAuthenticating = false;
          });
          _showMessageBox(context, newValue ? 'Biometric login enabled.' : 'Biometric login disabled.');
        }
      } else {
        _logger.w('Biometric authentication failed or cancelled.');
        if (mounted) {
          _showMessageBox(context, 'Biometric authentication failed or cancelled. Setting not changed.');
        }
        setState(() { _isAuthenticating = false; });
      }
    } on FirebaseException catch (e) {
      _logger.e('Firestore Error updating biometric setting: ${e.message}');
      if (mounted) {
        _showMessageBox(context, 'Error updating setting: ${e.message}');
      }
      setState(() { _isAuthenticating = false; });
    } catch (e) {
      _logger.e('An unexpected error occurred during biometric setting update: $e');
      if (mounted) {
        _showMessageBox(context, 'An unexpected error occurred. Please try again.');
      }
      setState(() { _isAuthenticating = false; });
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Adapts to phone theme
      appBar: AppBar(
        title: const Text('Biometric Security'),
        centerTitle: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Adapts to phone theme
        foregroundColor: Theme.of(context).textTheme.bodyLarge?.color, // Adapts to phone theme
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Theme.of(context).textTheme.bodyLarge?.color),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Manage your biometric login preferences.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    margin: EdgeInsets.zero,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SwitchListTile(
                      title: const Text(
                        'Enable Fingerprint/Face ID',
                        style: TextStyle(fontSize: 16, color: Colors.black87),
                      ),
                      value: _biometricEnabled,
                      onChanged: _isAuthenticating ? null : _toggleBiometricSetting, // Disable while authenticating
                      activeColor: Colors.blueAccent,
                      inactiveTrackColor: Colors.grey[300],
                      secondary: Icon(Icons.fingerprint, color: Colors.grey[600], size: 28),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_isAuthenticating)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(
                          'Please authenticate using your device biometrics...',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
