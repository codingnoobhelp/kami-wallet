import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart'; // Import local_auth for biometric authentication
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Cloud Firestore
import 'package:logger/logger.dart'; // Import logger
import 'package:flutter/services.dart'; // NEW: Import for PlatformException

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
  bool _fingerprintAvailable = false; // NEW: To track if fingerprint is available

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

    // Check for available biometrics on the device
    try {
      bool canCheck = await _localAuth.canCheckBiometrics;
      List<BiometricType> availableTypes = await _localAuth.getAvailableBiometrics();
      if (mounted) {
        setState(() {
          _fingerprintAvailable = canCheck && availableTypes.contains(BiometricType.fingerprint);
          if (!_fingerprintAvailable) {
            _logger.i('Fingerprint not available on this device or not enrolled.');
            // If fingerprint is not available, force biometricEnabled to false in UI
            _biometricEnabled = false;
          }
        });
      }
    } on PlatformException catch (e) {
      _logger.e('Error checking biometric availability: ${e.message}');
      if (mounted) {
        setState(() {
          _fingerprintAvailable = false;
          _biometricEnabled = false; // Disable if error occurs
        });
      }
      _showMessageBox(context, 'Error checking biometric availability: ${e.message}');
    } catch (e) {
      _logger.e('Unexpected error checking biometric availability: $e');
      if (mounted) {
        setState(() {
          _fingerprintAvailable = false;
          _biometricEnabled = false; // Disable if error occurs
        });
      }
      _showMessageBox(context, 'An unexpected error occurred checking biometrics.');
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
            // Only set _biometricEnabled to true if fingerprint is actually available on device AND user enabled it
            _biometricEnabled = (userData['biometricEnabled'] ?? false) && _fingerprintAvailable;
            _isLoading = false;
          });
        }
        _logger.i('Biometric status loaded for ${currentUser.uid}: $_biometricEnabled (Fingerprint available: $_fingerprintAvailable)');
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

    // Ensure fingerprint is available before attempting to toggle
    if (!_fingerprintAvailable) {
      _showMessageBox(context, 'Fingerprint authentication is not available or not set up on this device.');
      setState(() { _isAuthenticating = false; });
      return;
    }

    bool authenticated = false;
    try {
      // Prompt for biometric authentication to confirm the change
      authenticated = await _localAuth.authenticate(
        localizedReason: newValue
            ? 'Please authenticate to enable fingerprint login'
            : 'Please authenticate to disable fingerprint login',
        options: const AuthenticationOptions(
          stickyAuth: true, // Keep authentication active after app is backgrounded
          biometricOnly: true, // Only allow biometric authentication (fingerprint in this case)
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
          _showMessageBox(context, newValue ? 'Fingerprint login enabled.' : 'Fingerprint login disabled.');
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
    } on PlatformException catch (e) {
      _logger.e('Platform Error during biometric authentication: ${e.code} - ${e.message}');
      String errorMessage = 'Biometric error: ${e.message}';
      if (e.code == 'notAvailable' || e.code == 'notEnrolled' || e.code == 'passcodeNotSet') {
        errorMessage = 'Fingerprint not set up on device. Please enroll a fingerprint in your device settings.';
      } else if (e.code == 'lockedOut' || e.code == 'permanentlyLockedOut') {
        errorMessage = 'Fingerprint authentication locked. Please try again later or use an alternative login method.';
      } else if (e.code == 'auth_error') {
        errorMessage = 'Fingerprint authentication failed. Please try again.';
      } else if (e.code == 'no_face_id') { // Specific check for no Face ID, though biometricOnly should handle this
        errorMessage = 'Face ID is not available or enabled. Please use Fingerprint.';
      }
      if (mounted) {
        _showMessageBox(context, errorMessage);
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
                    'Manage your fingerprint login preferences.', // Updated text
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
                        'Enable Fingerprint', // Updated text
                        style: TextStyle(fontSize: 16, color: Colors.black87),
                      ),
                      value: _biometricEnabled,
                      // Disable switch if fingerprint is not available on device
                      onChanged: _fingerprintAvailable && !_isAuthenticating ? _toggleBiometricSetting : null,
                      activeColor: Colors.blueAccent,
                      inactiveTrackColor: Colors.grey[300],
                      secondary: Icon(Icons.fingerprint, color: Colors.grey[600], size: 28),
                    ),
                  ),
                  if (!_fingerprintAvailable)
                    Padding(
                      padding: const EdgeInsets.only(top: 10.0, left: 16.0, right: 16.0),
                      child: Text(
                        'Fingerprint authentication is not available or not set up on this device. Please enroll a fingerprint in your device settings to enable this feature.',
                        style: TextStyle(
                          color: Colors.redAccent.withOpacity(0.8),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  if (_isAuthenticating)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(
                          'Please authenticate using your device fingerprint...', // Updated text
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
