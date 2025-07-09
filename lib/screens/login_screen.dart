import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:pinput/pinput.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';

class LoginPage extends StatefulWidget {
  final String? phoneNumber; // NEW: Added phoneNumber argument

  const LoginPage({super.key, this.phoneNumber}); // NEW: Constructor updated

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final Logger _logger = Logger();
  final _formKey = GlobalKey<FormBuilderState>();
  final TextEditingController _accountNumberController = TextEditingController();
  final TextEditingController _passcodeController = TextEditingController(); // This is for the 6-digit login passcode
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _biometricEnabledForUser = false;
  String? _storedLoginPasscodeHash;
  bool _isLoginPasscodeSet = false; // Tracks if login passcode is set
  bool _isTransactionPinSet = false; // Tracks if transaction PIN is set
  String _currentUserName = 'User';
  String _currentUserUid = '';
  bool _isLoading = false;

  // Default theme for Pinput - adjusted for dark background
  final defaultPinTheme = PinTheme(
    width: 50,
    height: 50,
    textStyle: const TextStyle(
      fontSize: 20,
      color: Colors.white,
      fontWeight: FontWeight.w600,
    ),
    decoration: BoxDecoration(
      color: Colors.grey[850],
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.grey.shade700),
    ),
  );

  // Focused theme for Pinput
  late final focusedPinTheme = defaultPinTheme.copyDecorationWith(
    border: Border.all(color: const Color(0xFF00C853), width: 2),
    borderRadius: BorderRadius.circular(8),
  );

  // Submitted theme for Pinput (optional, can be same as default)
  late final submittedPinTheme = defaultPinTheme.copyWith(
    decoration: defaultPinTheme.decoration?.copyWith(
      color: Colors.grey[800],
    ),
  );

  @override
  void initState() {
    super.initState();
    if (widget.phoneNumber != null && widget.phoneNumber!.isNotEmpty) {
      // Pre-fill the phone number if passed from arguments (e.g., from merchant profile)
      _accountNumberController.text = _formatPhoneNumberForDisplay(widget.phoneNumber!);
      _fetchUserDataByPhoneNumber(widget.phoneNumber!); // Fetch user data immediately
    } else {
      _checkCurrentUserAuthStatus(); // Otherwise, check for existing Firebase Auth user
    }
  }

  @override
  void dispose() {
    _accountNumberController.dispose();
    _passcodeController.dispose();
    super.dispose();
  }

  // Function to hash the passcode using SHA-256
  String _hashPasscode(String passcode) {
    final bytes = utf8.encode(passcode);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Check if there's an already authenticated Firebase user and fetch their data
  Future<void> _checkCurrentUserAuthStatus() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      _logger.i('Current Firebase user detected: ${currentUser.uid}');
      if (currentUser.phoneNumber != null) {
        _accountNumberController.text = _formatPhoneNumberForDisplay(currentUser.phoneNumber!);
        await _fetchUserDataByPhoneNumber(currentUser.phoneNumber!);
      }
    } else {
      _logger.i('No current Firebase user. User needs to enter account number.');
    }
  }

  // Fetch user data (name, login passcode hash, biometric enabled status, transaction pin status) from Firestore
  // based on the provided phone number.
  Future<void> _fetchUserDataByPhoneNumber(String fullPhoneNumber) async {
    setState(() {
      _isLoading = true;
    });
    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('phoneNumber', isEqualTo: fullPhoneNumber)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final userDoc = querySnapshot.docs.first;
        final userData = userDoc.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _currentUserUid = userDoc.id;
            _currentUserName = userData['firstName'] ?? 'User';
            _storedLoginPasscodeHash = userData['loginPasscodeHash'];
            _isLoginPasscodeSet = userData['loginPasscodeSet'] ?? false;
            _biometricEnabledForUser = userData['biometricEnabled'] ?? false;
            _isTransactionPinSet = userData['transactionPinSet'] ?? false;
          });
        }
        _logger.i('User data loaded for $fullPhoneNumber: Name: $_currentUserName, Login Passcode Set: $_isLoginPasscodeSet, Biometric Enabled: $_biometricEnabledForUser, Transaction PIN Set: $_isTransactionPinSet');
      } else {
        _logger.w('No user found for phone number: $fullPhoneNumber');
        if (mounted) {
          _showMessageBox(context, 'No account found for this phone number. Please register.');
        }
        if (mounted) {
          setState(() {
            _currentUserName = 'User';
            _currentUserUid = '';
            _storedLoginPasscodeHash = null;
            _isLoginPasscodeSet = false;
            _biometricEnabledForUser = false;
            _isTransactionPinSet = false;
          });
        }
      }
    } on FirebaseException catch (e) {
      _logger.e('Firestore Error fetching user data by phone number: ${e.message}');
      if (mounted) _showMessageBox(context, 'Error loading user data: ${e.message}');
    } catch (e) {
      _logger.e('An unexpected error occurred fetching user data by phone number: $e');
      if (mounted) _showMessageBox(context, 'An unexpected error occurred. Please try again.');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Main login attempt function
  Future<void> _handleLoginAttempt() async {
    if (!(_formKey.currentState?.saveAndValidate() ?? false)) {
      _showMessageBox(context, 'Please enter a valid account number.');
      return;
    }

    final String enteredPhoneNumber = _accountNumberController.text.trim();
    final String fullEnteredPhoneNumber = '+234$enteredPhoneNumber';
    final String enteredPasscode = _passcodeController.text;

    if (enteredPasscode.length != 6) { // 6-digit login passcode
      _showMessageBox(context, 'Please enter a 6-digit login passcode.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Ensure user data is fetched for the entered phone number
      await _fetchUserDataByPhoneNumber(fullEnteredPhoneNumber);

      if (_currentUserUid.isEmpty) {
        _showMessageBox(context, 'Account not found for this number. Please check the account number or register.');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Ensure Firebase Auth user is the same as the one we are trying to log in
      User? firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null || firebaseUser.uid != _currentUserUid) {
        // If the Firebase Auth user is not the one associated with the entered phone number,
        // we need to sign them in. This might involve re-verifying the phone number
        // or using a custom token if available. For now, we'll assume the user
        // is already authenticated via phone_entry_screen or needs to be.
        // If a different user is logged in, sign them out first.
        if (firebaseUser != null && firebaseUser.uid != _currentUserUid) {
          await FirebaseAuth.instance.signOut();
          _logger.w('Signed out previous Firebase user due to mismatch.');
        }

        // Attempt to sign in the user if not already signed in with the correct UID
        // This is a simplified approach. In a production app, you might need
        // to re-trigger phone verification or use a custom token flow.
        // For this scenario, we assume the user has already gone through phone verification
        // and their Firebase Auth session is active or can be re-established.
        // If not, the user would need to go back through the OTP flow.
        // For now, we'll assume a successful Firebase Auth login happened earlier.
      }

      if (!_isLoginPasscodeSet || _storedLoginPasscodeHash == null) {
        _showMessageBox(context, 'Login passcode not set for this account. Please set it up in Account Settings.');
        _passcodeController.clear();
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final String hashedEnteredPasscode = _hashPasscode(enteredPasscode);

      if (hashedEnteredPasscode == _storedLoginPasscodeHash) {
        _showMessageBox(context, 'Login successful!');
        await _saveLastLoggedInPhoneNumber(fullEnteredPhoneNumber);

        Navigator.pushNamedAndRemoveUntil(
          context,
          '/home',
          (route) => false,
          arguments: {
            'phoneNumber': fullEnteredPhoneNumber,
            'initialBalance': 0.0, // You might fetch actual balance here
          },
        );
      } else {
        _showMessageBox(context, 'Incorrect login passcode. Please try again.');
        _passcodeController.clear();
      }
    } catch (e) {
      _logger.e('An unexpected error occurred during login: $e');
      if (mounted) _showMessageBox(context, 'An unexpected error occurred during login. Please try again.');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Function to handle fingerprint authentication
  Future<void> _authenticateWithBiometrics() async {
    // Ensure an account number is entered and data is fetched
    if (_accountNumberController.text.trim().isEmpty) {
      _showMessageBox(context, 'Please enter your account number first to enable biometric login.');
      return;
    }
    final String fullEnteredPhoneNumber = '+234${_accountNumberController.text.trim()}';
    await _fetchUserDataByPhoneNumber(fullEnteredPhoneNumber); // Fetch data based on entered number

    if (_currentUserUid.isEmpty) {
      _showMessageBox(context, 'No user account found for this number.');
      return;
    }
    if (!_biometricEnabledForUser) {
      _showMessageBox(context, 'Biometric login is not enabled for your account. Please enable it in settings.');
      return;
    }
    if (!_isLoginPasscodeSet) {
      _showMessageBox(context, 'Please set up your Login Passcode first before using biometrics.');
      return;
    }

    bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
    List<BiometricType> availableBiometrics = await _localAuth.getAvailableBiometrics();

    if (!canCheckBiometrics || availableBiometrics.isEmpty) {
      _showMessageBox(context, 'Biometric authentication not available or not set up on this device.');
      return;
    }

    BiometricType? preferredBiometric;
    if (availableBiometrics.contains(BiometricType.fingerprint)) {
      preferredBiometric = BiometricType.fingerprint;
    } else if (availableBiometrics.contains(BiometricType.face)) {
      preferredBiometric = BiometricType.face;
    } else if (availableBiometrics.isNotEmpty) {
      preferredBiometric = availableBiometrics.first;
    }

    if (preferredBiometric == null) {
      _showMessageBox(context, 'No suitable biometric authentication method found on this device.');
      return;
    }

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text('Biometric Authentication'),
          content: Text('Please authenticate using your device ${preferredBiometric == BiometricType.fingerprint ? 'fingerprint' : preferredBiometric == BiometricType.face ? 'Face ID' : 'biometrics'} to log in.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    }

    try {
      bool authenticated = await _localAuth.authenticate(
        localizedReason: 'Scan your ${preferredBiometric == BiometricType.fingerprint ? 'fingerprint' : preferredBiometric == BiometricType.face ? 'Face ID' : 'biometrics'} to log in',
        options: const AuthenticationOptions(biometricOnly: true),
      );
      if (mounted) {
        Navigator.pop(context);
        if (authenticated) {
          _showMessageBox(context, 'Biometric authentication successful!');
          await _saveLastLoggedInPhoneNumber(fullEnteredPhoneNumber);

          Navigator.pushNamedAndRemoveUntil(
            context,
            '/home',
            (route) => false,
            arguments: {
              'phoneNumber': fullEnteredPhoneNumber,
              'initialBalance': 0.0,
            },
          );
        } else {
          _showMessageBox(context, 'Biometric authentication failed or cancelled.');
        }
      }
    } catch (e) {
      _logger.e('Error during biometric authentication: $e');
      if (mounted) {
        Navigator.pop(context);
        _showMessageBox(context, 'Error during biometric authentication: $e');
      }
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

  // Save the last logged-in phone number to local storage
  Future<void> _saveLastLoggedInPhoneNumber(String phoneNumber) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastLoggedInPhoneNumber', phoneNumber);
  }

  // Clear the last logged-in phone number from local storage
  // Not used in this context, but kept for completeness
  // Future<void> _clearLastLoggedInPhoneNumber() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   await prefs.remove('lastLoggedInPhoneNumber');
  // }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Dark background as per image
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white), // White icon for dark background
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, // Changed to start for left alignment of labels
          children: [
            // Welcome Message
            Text(
              'Welcome back ${_currentUserName},',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.left,
            ),
            const SizedBox(height: 5),
            const Text(
              'Login to your account',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white70,
              ),
              textAlign: TextAlign.left,
            ),
            const SizedBox(height: 30),

            FormBuilder(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, // Align labels to start
                children: [
                  // Label for Mobile No./Email
                  const Text(
                    'Enter your Mobile No./Email',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Account Number (Phone Number) Input
                  FormBuilderTextField(
                    name: 'account_number',
                    controller: _accountNumberController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Colors.white), // White text for input
                    decoration: InputDecoration(
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: Colors.grey[850], // Dark background for input field
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: BorderSide.none, // No border initially
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: const BorderSide(color: Color(0xFF00C853), width: 2.0), // Green border on focus
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: BorderSide(color: Theme.of(context).colorScheme.error, width: 2.0),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: BorderSide(color: Theme.of(context).colorScheme.error, width: 2.0),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    validator: FormBuilderValidators.compose([
                      FormBuilderValidators.required(errorText: 'Account number or email is required'),
                      // Note: For email, you'd need to adjust validation.
                      // For now, keeping phone number validation.
                      // FormBuilderValidators.numeric(errorText: 'Enter a valid phone number'),
                      // FormBuilderValidators.minLength(10, errorText: 'Phone number must be 10 digits'),
                      // FormBuilderValidators.maxLength(10, errorText: 'Phone number must be 10 digits'),
                    ]),
                    onChanged: (value) {
                      if (value != null && value.length >= 10) {
                        _fetchUserDataByPhoneNumber('+234$value');
                      } else {
                        setState(() {
                          _currentUserName = 'User';
                          _currentUserUid = '';
                          _storedLoginPasscodeHash = null;
                          _isLoginPasscodeSet = false;
                          _biometricEnabledForUser = false;
                          _isTransactionPinSet = false;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 20),

                  // Label for 6-digit Password
                  const Text(
                    'Enter 6-digit Password',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Passcode Input (Pinput)
                  Center(
                    child: Pinput(
                      controller: _passcodeController,
                      length: 6, // 6-digit passcode
                      defaultPinTheme: defaultPinTheme,
                      focusedPinTheme: focusedPinTheme,
                      submittedPinTheme: submittedPinTheme,
                      obscureText: true,
                      onCompleted: (pin) {
                        _logger.d('Passcode Pinput completed: $pin');
                        _handleLoginAttempt();
                      },
                      onChanged: (value) {
                        _logger.d('Passcode Pinput changed: $value');
                      },
                      cursor: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(bottom: 9),
                            width: 22,
                            height: 1,
                            color: const Color(0xFF00C853), // Green cursor
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Forgot Passcode Button (aligned to right)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  _showMessageBox(context, 'Forgot Passcode functionality not yet implemented.');
                },
                child: const Text(
                  'Forgot Password?',
                  style: TextStyle(color: Color(0xFF00C853)),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Login Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleLoginAttempt,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C853),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Login',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),

            // "Click to log in with Fingerprint"
            Center(
              child: ElevatedButton.icon(
                onPressed: _authenticateWithBiometrics,
                icon: const Icon(Icons.fingerprint, color: Colors.white),
                label: const Text(
                  'Login with Fingerprint',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C853),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
