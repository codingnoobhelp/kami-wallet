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

class MerchantLoginPage extends StatefulWidget {
  const MerchantLoginPage({super.key});

  @override
  State<MerchantLoginPage> createState() => _MerchantLoginPageState();
}

class _MerchantLoginPageState extends State<MerchantLoginPage> {
  final Logger _logger = Logger();
  final _formKey = GlobalKey<FormBuilderState>();
  final TextEditingController _merchantIdController = TextEditingController();
  final TextEditingController _passcodeController = TextEditingController();
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _biometricEnabledForMerchant = false;
  String? _storedLoginPasscodeHash;
  bool _isLoginPasscodeSet = false;
  String _currentMerchantName = 'Merchant';
  String _currentMerchantUid = '';
  bool _isLoading = false;

  // Default theme for Pinput - adjusted for dark background
  final defaultPinTheme = PinTheme(
    width: 50, // Adjusted width
    height: 50, // Adjusted height
    textStyle: const TextStyle(
      fontSize: 20,
      color: Colors.white, // White text for dark background
      fontWeight: FontWeight.w600,
    ),
    decoration: BoxDecoration(
      color: Colors.grey[850], // Dark background for input fields
      borderRadius: BorderRadius.circular(8), // Slightly less rounded
      border: Border.all(color: Colors.grey.shade700), // Subtle border
    ),
  );

  // Focused theme for Pinput
  late final focusedPinTheme = defaultPinTheme.copyDecorationWith(
    border: Border.all(color: const Color(0xFF00C853), width: 2), // Green border when focused
    borderRadius: BorderRadius.circular(8),
  );

  // Submitted theme for Pinput (optional, can be same as default)
  late final submittedPinTheme = defaultPinTheme.copyWith(
    decoration: defaultPinTheme.decoration?.copyWith(
      color: Colors.grey[800], // Slightly different background when submitted
    ),
  );

  @override
  void initState() {
    super.initState();
    _checkCurrentMerchantAuthStatus();
  }

  @override
  void dispose() {
    _merchantIdController.dispose();
    _passcodeController.dispose();
    super.dispose();
  }

  String _hashPasscode(String passcode) {
    final bytes = utf8.encode(passcode);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _checkCurrentMerchantAuthStatus() async {
    // In a real app, you might check for a logged-in merchant here
    // For now, we'll assume no pre-filled data.
  }

  // Fetch merchant data (name, login passcode hash, biometric enabled status) from Firestore
  // based on the provided Merchant ID.
  Future<void> _fetchMerchantDataById(String merchantId) async {
    setState(() {
      _isLoading = true; // Show loading indicator while fetching merchant data
    });
    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('merchants') // Assuming a 'merchants' collection
          .where('merchantId', isEqualTo: merchantId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final merchantDoc = querySnapshot.docs.first;
        final merchantData = merchantDoc.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _currentMerchantUid = merchantDoc.id; // Store the UID
            _currentMerchantName = merchantData['merchantName'] ?? 'Merchant';
            _storedLoginPasscodeHash = merchantData['loginPasscodeHash'];
            _isLoginPasscodeSet = merchantData['loginPasscodeSet'] ?? false;
            _biometricEnabledForMerchant = merchantData['biometricEnabled'] ?? false;
          });
        }
        _logger.i('Merchant data loaded for $merchantId: Name: $_currentMerchantName, Login Passcode Set: $_isLoginPasscodeSet, Biometric Enabled: $_biometricEnabledForMerchant');
      } else {
        _logger.w('No merchant found for ID: $merchantId');
        if (mounted) {
          _showMessageBox(context, 'No merchant account found for this ID. Please check the ID or register.');
        }
        // Clear any previously loaded merchant data if ID doesn't match
        if (mounted) {
          setState(() {
            _currentMerchantName = 'Merchant';
            _currentMerchantUid = '';
            _storedLoginPasscodeHash = null;
            _isLoginPasscodeSet = false;
            _biometricEnabledForMerchant = false;
          });
        }
      }
    } on FirebaseException catch (e) {
      _logger.e('Firestore Error fetching merchant data by ID: ${e.message}');
      if (mounted) _showMessageBox(context, 'Error loading merchant data: ${e.message}');
    } catch (e) {
      _logger.e('An unexpected error occurred fetching merchant data by ID: $e');
      if (mounted) _showMessageBox(context, 'An unexpected error occurred. Please try again.');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleLoginAttempt() async {
    if (!(_formKey.currentState?.saveAndValidate() ?? false)) {
      _showMessageBox(context, 'Please enter a valid Merchant ID and passcode.');
      return;
    }

    final String enteredMerchantId = _merchantIdController.text.trim();
    final String enteredPasscode = _passcodeController.text;

    if (enteredPasscode.length != 6) {
      _showMessageBox(context, 'Please enter a 6-digit login passcode.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Fetch merchant data to get the UID and stored passcode hash
      await _fetchMerchantDataById(enteredMerchantId);

      if (_currentMerchantUid.isEmpty) {
        _showMessageBox(context, 'Merchant account not found for this ID. Please check the ID or register.');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // In a real app, you'd authenticate the merchant with Firebase Auth here
      // For simplicity, we'll proceed with local passcode verification using the fetched hash.
      // This implies that Firebase Auth for merchants would be handled separately (e.g., email/password or custom tokens).

      if (!_isLoginPasscodeSet || _storedLoginPasscodeHash == null) {
        _showMessageBox(context, 'Login passcode not set for this merchant account. Please set it up in Account Settings.');
        _passcodeController.clear();
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final String hashedEnteredPasscode = _hashPasscode(enteredPasscode);

      if (hashedEnteredPasscode == _storedLoginPasscodeHash) {
        _showMessageBox(context, 'Merchant Login successful!');
        // Save the merchant ID to local storage for future quick logins
        await _saveLastLoggedInMerchantId(enteredMerchantId);

        // Navigate to merchant home screen or dashboard
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/merchant_home', // Assuming a merchant home route
          (route) => false,
          arguments: {
            'merchantId': enteredMerchantId,
            // Pass other relevant merchant data
          },
        );
      } else {
        _showMessageBox(context, 'Incorrect login passcode. Please try again.');
        _passcodeController.clear(); // Clear the input on failure
      }
    } catch (e) {
      _logger.e('An unexpected error occurred during merchant login: $e');
      if (mounted) _showMessageBox(context, 'An unexpected error occurred during login. Please try again.');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    if (_currentMerchantUid.isEmpty) {
      _showMessageBox(context, 'Please enter your Merchant ID first to enable biometric login.');
      return;
    }
    if (!_biometricEnabledForMerchant) {
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

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text('Biometric Authentication'),
          content: const Text('Please authenticate using your device biometrics to log in.'),
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
        localizedReason: 'Scan your biometrics to log in as merchant',
        options: const AuthenticationOptions(biometricOnly: true),
      );
      if (mounted) {
        Navigator.pop(context);
        if (authenticated) {
          _showMessageBox(context, 'Biometric authentication successful!');
          await _saveLastLoggedInMerchantId(_merchantIdController.text.trim());

          Navigator.pushNamedAndRemoveUntil(
            context,
            '/merchant_home',
            (route) => false,
            arguments: {
              'merchantId': _merchantIdController.text.trim(),
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

  Future<void> _saveLastLoggedInMerchantId(String merchantId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastLoggedInMerchantId', merchantId);
  }

  // Helper widget for input fields with consistent styling
  Widget _buildInputField({
    required String labelText,
    required String name,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    List<String? Function(String?)>? validators,
    Function(String?)? onChanged,
    bool obscureText = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          labelText,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        FormBuilderTextField(
          name: name,
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white),
          obscureText: obscureText,
          decoration: InputDecoration(
            hintStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: Colors.grey[850],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: const BorderSide(color: Color(0xFF00C853), width: 2.0),
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
          validator: validators != null ? FormBuilderValidators.compose(validators) : null,
          onChanged: onChanged,
        ),
      ],
    );
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Message
            Text(
              'Welcome back ${_currentMerchantName},',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.left,
            ),
            const SizedBox(height: 5),
            const Text(
              'Login to your merchant account',
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Merchant ID Input
                  _buildInputField(
                    labelText: 'Enter your Merchant ID',
                    name: 'merchant_id',
                    controller: _merchantIdController,
                    keyboardType: TextInputType.text,
                    validators: [
                      FormBuilderValidators.required(errorText: 'Merchant ID is required'),
                    ],
                    onChanged: (value) {
                      if (value != null && value.isNotEmpty) {
                        _fetchMerchantDataById(value);
                      } else {
                        setState(() {
                          _currentMerchantName = 'Merchant';
                          _currentMerchantUid = '';
                          _storedLoginPasscodeHash = null;
                          _isLoginPasscodeSet = false;
                          _biometricEnabledForMerchant = false;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 20),

                  // 6-digit Passcode Input
                  const Text(
                    'Enter 6-digit Password',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Pinput(
                      controller: _passcodeController,
                      length: 6,
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
                            color: const Color(0xFF00C853),
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
                  _showMessageBox(context, 'Forgot Passcode functionality for merchants not yet implemented.');
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
              child: TextButton(
                onPressed: _authenticateWithBiometrics,
                child: const Text(
                  'Click to log in with Fingerprint',
                  style: TextStyle(
                    color: Color(0xFF00C853),
                    fontSize: 16,
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
