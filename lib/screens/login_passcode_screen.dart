import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart'; // Import for hashing
import 'dart:convert'; // Import for utf8.encode
import 'package:pinput/pinput.dart'; // For passcode input

// Renamed from LoginSecurityScreen to LoginPasscodeScreen for clarity
class LoginPasscodeScreen extends StatefulWidget {
  const LoginPasscodeScreen({super.key});

  @override
  State<LoginPasscodeScreen> createState() => _LoginPasscodeScreenState();
}

class _LoginPasscodeScreenState extends State<LoginPasscodeScreen> {
  final Logger _logger = Logger();
  final TextEditingController _currentPasscodeController = TextEditingController();
  final TextEditingController _newPasscodeController = TextEditingController();
  final TextEditingController _confirmNewPasscodeController = TextEditingController();
  bool _isLoading = false;
  bool _loginPasscodeSet = false; // Tracks if a login passcode is already set

  // Pinput themes (can be reused or customized)
  final defaultPinTheme = PinTheme(
    width: 60,
    height: 60,
    textStyle: const TextStyle(
      fontSize: 24,
      color: Colors.black, // Adjust text color for white background
      fontWeight: FontWeight.w600,
    ),
    decoration: BoxDecoration(
      color: Colors.grey[200], // Light grey background for input fields
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade400), // Subtle border
    ),
  );

  late final focusedPinTheme = defaultPinTheme.copyDecorationWith(
    border: Border.all(color: const Color(0xFF007AFF), width: 2),
    borderRadius: BorderRadius.circular(12),
  );

  late final submittedPinTheme = defaultPinTheme.copyWith(
    decoration: defaultPinTheme.decoration?.copyWith(
      color: Colors.grey[100],
    ),
  );

  @override
  void initState() {
    super.initState();
    _checkLoginPasscodeStatus();
  }

  @override
  void dispose() {
    _currentPasscodeController.dispose();
    _newPasscodeController.dispose();
    _confirmNewPasscodeController.dispose();
    super.dispose();
  }

  // Function to hash the passcode using SHA-256
  String _hashPasscode(String passcode) {
    final bytes = utf8.encode(passcode);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Check if login passcode is already set for the current user
  Future<void> _checkLoginPasscodeStatus() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _logger.e('No authenticated user found to check login passcode status.');
      if (mounted) _showMessageBox(context, 'Error: No authenticated user. Please log in again.');
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
            _loginPasscodeSet = userData['loginPasscodeSet'] ?? false;
          });
        }
        _logger.i('Login passcode status for ${currentUser.uid}: $_loginPasscodeSet');
      } else {
        _logger.w('User document not found for UID: ${currentUser.uid}. Assuming no login passcode set.');
        if (mounted) {
          setState(() {
            _loginPasscodeSet = false;
          });
        }
      }
    } on FirebaseException catch (e) {
      _logger.e('Firestore Error checking login passcode status: ${e.message}');
      if (mounted) _showMessageBox(context, 'Error loading login settings: ${e.message}');
    } catch (e) {
      _logger.e('An unexpected error occurred checking login passcode status: $e');
      if (mounted) _showMessageBox(context, 'An unexpected error occurred. Please try again.');
    }
  }

  // Handle setting up a new login passcode
  Future<void> _setupNewLoginPasscode() async {
    final String newPasscode = _newPasscodeController.text;
    final String confirmPasscode = _confirmNewPasscodeController.text;

    if (newPasscode.length != 6 || confirmPasscode.length != 6) { // 6 digits
      _showMessageBox(context, 'Please enter a 6-digit passcode for both fields.');
      return;
    }
    if (newPasscode != confirmPasscode) {
      _showMessageBox(context, 'New passcodes do not match.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _logger.e('No authenticated user found to set login passcode.');
      _showMessageBox(context, 'Error: No authenticated user. Please log in again.');
      setState(() { _isLoading = false; });
      return;
    }

    try {
      final String hashedNewPasscode = _hashPasscode(newPasscode);
      await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).set(
        {
          'loginPasscodeHash': hashedNewPasscode,
          'loginPasscodeSet': true,
        },
        SetOptions(merge: true), // Use merge to only update specified fields
      );

      if (mounted) {
        _showMessageBox(context, 'Login passcode set successfully!');
        _newPasscodeController.clear();
        _confirmNewPasscodeController.clear();
        setState(() {
          _loginPasscodeSet = true; // Update state to reflect passcode is now set
        });
      }
    } on FirebaseException catch (e) {
      _logger.e('Firestore Error setting login passcode: ${e.message}');
      if (mounted) _showMessageBox(context, 'Failed to set passcode: ${e.message}');
    } catch (e) {
      _logger.e('An unexpected error occurred setting login passcode: $e');
      if (mounted) _showMessageBox(context, 'An unexpected error occurred. Please try again.');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Handle resetting an existing login passcode
  Future<void> _resetLoginPasscode() async {
    final String currentPasscode = _currentPasscodeController.text;
    final String newPasscode = _newPasscodeController.text;
    final String confirmPasscode = _confirmNewPasscodeController.text;

    if (currentPasscode.length != 6 || newPasscode.length != 6 || confirmPasscode.length != 6) { // 6 digits
      _showMessageBox(context, 'Please enter a 6-digit passcode for all fields.');
      return;
    }
    if (newPasscode != confirmPasscode) {
      _showMessageBox(context, 'New passcodes do not match.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _logger.e('No authenticated user found to reset login passcode.');
      _showMessageBox(context, 'Error: No authenticated user. Please log in again.');
      setState(() { _isLoading = false; });
      return;
    }

    try {
      // Verify current passcode
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final storedLoginPasscodeHash = (userDoc.data() as Map<String, dynamic>?)?['loginPasscodeHash'];
      if (storedLoginPasscodeHash == null || _hashPasscode(currentPasscode) != storedLoginPasscodeHash) {
        _showMessageBox(context, 'Incorrect current passcode.');
        setState(() { _isLoading = false; });
        return;
      }

      // Update with new hashed passcode
      final String hashedNewPasscode = _hashPasscode(newPasscode);
      await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).update({
        'loginPasscodeHash': hashedNewPasscode,
      });

      if (mounted) {
        _showMessageBox(context, 'Login passcode reset successfully!');
        _currentPasscodeController.clear();
        _newPasscodeController.clear();
        _confirmNewPasscodeController.clear();
      }
    } on FirebaseException catch (e) {
      _logger.e('Firestore Error resetting login passcode: ${e.message}');
      if (mounted) _showMessageBox(context, 'Failed to reset passcode: ${e.message}');
    } catch (e) {
      _logger.e('An unexpected error occurred resetting login passcode: $e');
      if (mounted) _showMessageBox(context, 'An unexpected error occurred. Please try again.');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

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

  Widget _buildPasscodeInput({
    required TextEditingController controller,
    required String hintText,
    required Function(String) onCompleted,
    required Function(String) onChanged,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final hintColor = isDarkMode ? Colors.white54 : Colors.grey[600];

    return Pinput(
      controller: controller,
      length: 6, // 6-digit passcode
      defaultPinTheme: defaultPinTheme.copyWith(
        textStyle: TextStyle(color: textColor),
        decoration: defaultPinTheme.decoration?.copyWith(
          color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.grey[100],
        ),
      ),
      focusedPinTheme: focusedPinTheme,
      submittedPinTheme: submittedPinTheme,
      obscureText: true,
      onCompleted: onCompleted,
      onChanged: onChanged,
      cursor: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 9),
            width: 22,
            height: 1,
            color: const Color(0xFF007AFF),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final hintColor = isDarkMode ? Colors.white70 : Colors.black54;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Login Passcode', style: TextStyle(color: textColor)), // Updated title
        centerTitle: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: textColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: textColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _loginPasscodeSet ? 'Reset your Login Passcode' : 'Set up your Login Passcode',
              style: TextStyle(
                color: textColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _loginPasscodeSet
                  ? 'Enter your current passcode, then your new 6-digit passcode.'
                  : 'Please set up a 6-digit passcode for secure login.',
              style: TextStyle(
                color: hintColor,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 30),

            if (_loginPasscodeSet) ...[
              Text(
                'Current Passcode',
                style: TextStyle(color: textColor, fontSize: 16),
              ),
              const SizedBox(height: 10),
              _buildPasscodeInput(
                controller: _currentPasscodeController,
                hintText: 'Current Passcode',
                onCompleted: (pin) => _logger.d('Current passcode completed: $pin'),
                onChanged: (value) => _logger.d('Current passcode changed: $value'),
              ),
              const SizedBox(height: 20),
            ],

            Text(
              'New Passcode',
              style: TextStyle(color: textColor, fontSize: 16),
            ),
            const SizedBox(height: 10),
            _buildPasscodeInput(
              controller: _newPasscodeController,
              hintText: 'New Passcode',
              onCompleted: (pin) => _logger.d('New passcode completed: $pin'),
              onChanged: (value) => _logger.d('New passcode changed: $value'),
            ),
            const SizedBox(height: 20),

            Text(
              'Confirm New Passcode',
              style: TextStyle(color: textColor, fontSize: 16),
            ),
            const SizedBox(height: 10),
            _buildPasscodeInput(
              controller: _confirmNewPasscodeController,
              hintText: 'Confirm New Passcode',
              onCompleted: (pin) => _logger.d('Confirm new passcode completed: $pin'),
              onChanged: (value) => _logger.d('Confirm new passcode changed: $value'),
            ),
            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : (_loginPasscodeSet ? _resetLoginPasscode : _setupNewLoginPasscode),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007AFF),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        _loginPasscodeSet ? 'Reset Passcode' : 'Set Passcode',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
