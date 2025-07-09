import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:pinput/pinput.dart';
import 'package:local_auth/local_auth.dart';

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
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _isLoading = false;
  bool _loginPasscodeSet = false;
  bool _biometricEnabled = false;
  bool _isAuthenticating = false;

  final defaultPinTheme = PinTheme(
    width: 60,
    height: 60,
    textStyle: const TextStyle(
      fontSize: 24,
      color: Colors.black,
      fontWeight: FontWeight.w600,
    ),
    decoration: BoxDecoration(
      color: Colors.grey[200],
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade400),
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
    _checkLoginPasscodeAndBiometricStatus();
  }

  @override
  void dispose() {
    _currentPasscodeController.dispose();
    _newPasscodeController.dispose();
    _confirmNewPasscodeController.dispose();
    super.dispose();
  }

  String _hashPasscode(String passcode) {
    final bytes = utf8.encode(passcode);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _checkLoginPasscodeAndBiometricStatus() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _logger.e('No authenticated user found to check login passcode/biometric status.');
      if (mounted) _showMessageBox(context, 'Error', 'No authenticated user. Please log in again.');
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
            _biometricEnabled = userData['biometricEnabled'] ?? false;
          });
        }
        _logger.i('Login passcode status for ${currentUser.uid}: $_loginPasscodeSet, Biometric Enabled: $_biometricEnabled');
      } else {
        _logger.w('User document not found for UID: ${currentUser.uid}. Assuming no login passcode/biometric set.');
        if (mounted) {
          setState(() {
            _loginPasscodeSet = false;
            _biometricEnabled = false;
          });
        }
      }
    } on FirebaseException catch (e) {
      _logger.e('Firestore Error checking login passcode/biometric status: ${e.message}');
      if (mounted) _showMessageBox(context, 'Error', 'Error loading login settings: ${e.message}');
    } catch (e) {
      _logger.e('An unexpected error occurred checking login passcode/biometric status: $e');
      if (mounted) _showMessageBox(context, 'Error', 'An unexpected error occurred. Please try again.');
    }
  }

  Future<void> _setupNewLoginPasscode() async {
    final String newPasscode = _newPasscodeController.text;
    final String confirmPasscode = _confirmNewPasscodeController.text;

    if (newPasscode.length != 6 || confirmPasscode.length != 6) {
      _showMessageBox(context, 'Error', 'Please enter a 6-digit passcode for both fields.');
      return;
    }
    if (newPasscode != confirmPasscode) {
      _showMessageBox(context, 'Error', 'New passcodes do not match.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _logger.e('No authenticated user found to set login passcode.');
      _showMessageBox(context, 'Error', 'Error: No authenticated user. Please log in again.');
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
        SetOptions(merge: true),
      );

      if (mounted) {
        _showMessageBox(context, 'Success', 'Login passcode set successfully!');
        _newPasscodeController.clear();
        _confirmNewPasscodeController.clear();
        setState(() {
          _loginPasscodeSet = true;
        });
      }
    } on FirebaseException catch (e) {
      _logger.e('Firestore Error setting login passcode: ${e.message}');
      if (mounted) _showMessageBox(context, 'Error', 'Failed to set passcode: ${e.message}');
    } catch (e) {
      _logger.e('An unexpected error occurred setting login passcode: $e');
      if (mounted) _showMessageBox(context, 'Error', 'An unexpected error occurred. Please try again.');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _resetLoginPasscode() async {
    final String currentPasscode = _currentPasscodeController.text;
    final String newPasscode = _newPasscodeController.text;
    final String confirmPasscode = _confirmNewPasscodeController.text;

    if (currentPasscode.length != 6 || newPasscode.length != 6 || confirmPasscode.length != 6) {
      _showMessageBox(context, 'Error', 'Please enter a 6-digit passcode for all fields.');
      return;
    }
    if (newPasscode != confirmPasscode) {
      _showMessageBox(context, 'Error', 'New passcodes do not match.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _logger.e('No authenticated user found to reset login passcode.');
      _showMessageBox(context, 'Error', 'Error: No authenticated user. Please log in again.');
      setState(() { _isLoading = false; });
      return;
    }

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final storedLoginPasscodeHash = (userDoc.data() as Map<String, dynamic>?)?['loginPasscodeHash'];
      if (storedLoginPasscodeHash == null || _hashPasscode(currentPasscode) != storedLoginPasscodeHash) {
        _showMessageBox(context, 'Error', 'Incorrect current passcode.');
        setState(() { _isLoading = false; });
        return;
      }

      final String hashedNewPasscode = _hashPasscode(newPasscode);
      await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).update({
        'loginPasscodeHash': hashedNewPasscode,
      });

      if (mounted) {
        _showMessageBox(context, 'Success', 'Login passcode reset successfully!');
        _currentPasscodeController.clear();
        _newPasscodeController.clear();
        _confirmNewPasscodeController.clear();
      }
    } on FirebaseException catch (e) {
      _logger.e('Firestore Error resetting login passcode: ${e.message}');
      if (mounted) _showMessageBox(context, 'Error', 'Failed to reset passcode: ${e.message}');
    } catch (e) {
      _logger.e('An unexpected error occurred resetting login passcode: $e');
      if (mounted) _showMessageBox(context, 'Error', 'An unexpected error occurred. Please try again.');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleBiometricSetting(bool newValue) async {
    setState(() {
      _isAuthenticating = true;
    });

    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _logger.e('No current user found. Cannot toggle biometric setting.');
      if (mounted) _showMessageBox(context, 'Error', 'No authenticated user. Please log in again.');
      setState(() { _isAuthenticating = false; });
      return;
    }

    try {
      bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
      List<BiometricType> availableBiometrics = await _localAuth.getAvailableBiometrics();

      if (!canCheckBiometrics || availableBiometrics.isEmpty) {
        if (mounted) _showMessageBox(context, 'Biometric Not Available', 'Your device does not support biometric authentication or it\'s not set up.');
        setState(() { _isAuthenticating = false; });
        return;
      }

      bool authenticated = await _localAuth.authenticate(
        localizedReason: newValue
            ? 'Enable biometric login for your account'
            : 'Disable biometric login for your account',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (authenticated) {
        await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).update({
          'biometricEnabled': newValue,
        });
        if (mounted) {
          setState(() {
            _biometricEnabled = newValue;
          });
          _showMessageBox(context, 'Success', 'Biometric login has been ${newValue ? 'enabled' : 'disabled'}.');
        }
      } else {
        if (mounted) _showMessageBox(context, 'Authentication Failed', 'Biometric authentication failed or cancelled. Setting not changed.');
      }
    } catch (e) {
      _logger.e('Error during biometric authentication or update: $e');
      if (mounted) _showMessageBox(context, 'Error', 'An error occurred during biometric operation: $e');
    } finally {
      setState(() {
        _isAuthenticating = false;
      });
    }
  }

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
      length: 6,
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
        title: Text('Login Passcode', style: TextStyle(color: textColor)),
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

            Card(
              margin: EdgeInsets.zero,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: SwitchListTile(
                title: Text(
                  'Enable Fingerprint/Face ID',
                  style: TextStyle(fontSize: 16, color: textColor),
                ),
                value: _biometricEnabled,
                onChanged: _isAuthenticating ? null : _toggleBiometricSetting,
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