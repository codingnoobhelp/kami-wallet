import 'package:flutter/material.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'package:logger/logger.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Cloud Firestore

class PhoneEntryPage extends StatefulWidget {
  const PhoneEntryPage({super.key});

  @override
  State<PhoneEntryPage> createState() => _PhoneEntryPageState();
}

class _PhoneEntryPageState extends State<PhoneEntryPage> {
  final TextEditingController _phoneNumberController = TextEditingController();
  final Logger _logger = Logger();
  String _selectedCountryCode = '+234';
  bool _isLoading = false;

  // Store the selected country code from intl_phone_number_input
  String _currentCountryCode = '+234'; // Initial value

  // Function to validate phone number, check existence, and send OTP
  // The 'isLoginAttempt' flag differentiates between 'Continue' (signup/login) and 'Login' (login only)
  Future<void> _validateAndProceed({required bool isLoginAttempt}) async {
    setState(() {
      _isLoading = true; // Show loading indicator while validating
    });

    final String rawPhoneNumber = _phoneNumberController.text.trim();
    final String fullPhoneNumber = _currentCountryCode + rawPhoneNumber;
    _logger.i('Processing phone number: $fullPhoneNumber (isLoginAttempt: $isLoginAttempt)');

    if (rawPhoneNumber.isEmpty) {
      _showMessageBox(context, 'Please enter your phone number.');
      setState(() { _isLoading = false; });
      return;
    }

    try {
      // Step 1: Check if the phone number is already registered in Firestore
      final usersCollection = FirebaseFirestore.instance.collection('users');
      final querySnapshot = await usersCollection
          .where('phoneNumber', isEqualTo: fullPhoneNumber)
          .limit(1)
          .get();

      bool userExists = querySnapshot.docs.isNotEmpty;
      _logger.i('User existence for $fullPhoneNumber: $userExists');

      // If this is a 'Login' attempt and user does NOT exist, show error and stop.
      if (isLoginAttempt && !userExists) {
        _showMessageBox(context, 'This phone number is not registered. Please sign up first.');
        setState(() { _isLoading = false; });
        return;
      }

      // If this is a 'Continue' attempt and user DOES exist, show message and stop.
      // This prevents existing users from accidentally going through signup flow again.
      if (!isLoginAttempt && userExists) {
        _showMessageBox(context, 'An account already exists with this phone number. Please use the "Login" button.');
        setState(() { _isLoading = false; });
        return;
      }


      // Step 2: Send OTP
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: fullPhoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          _logger.i('Verification completed automatically: $credential');
          // Auto-sign in the user
          UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
          _logger.i('User signed in via auto-verification: ${userCredential.user?.uid}');

          if (mounted) {
            if (userExists) {
              // Existing user: go to role selection
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/role_selection',
                (route) => false,
                arguments: {
                  'phoneNumber': fullPhoneNumber,
                  'userExists': userExists, // Still pass userExists for OTP screen's logic
                },
              );
            } else {
              // New user: go to personal info setup
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/personal',
                (route) => false,
                arguments: {
                  'phoneNumber': fullPhoneNumber,
                },
              );
            }
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          _logger.e('Phone number verification failed: ${e.message}');
          if (mounted) {
            _showMessageBox(context, 'Verification Failed: ${e.message}');
          }
          setState(() { _isLoading = false; });
        },
        codeSent: (String verificationId, int? resendToken) {
          _logger.i('OTP code sent to $fullPhoneNumber. Verification ID: $verificationId');
          if (mounted) {
            // If it's a login attempt and user exists, navigate to RoleSelection after OTP.
            // Otherwise, proceed to OTP verification page.
            if (isLoginAttempt && userExists) {
              Navigator.pushNamed(
                context,
                '/otp',
                arguments: {
                  'phoneNumber': fullPhoneNumber,
                  'verificationId': verificationId,
                  'userExists': userExists, // Pass user existence status
                },
              );
            } else {
              Navigator.pushNamed(
                context,
                '/otp',
                arguments: {
                  'phoneNumber': fullPhoneNumber,
                  'verificationId': verificationId,
                  'userExists': userExists, // Pass user existence status
                },
              );
            }
          }
          setState(() { _isLoading = false; });
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _logger.w('Code auto-retrieval timeout for ID: $verificationId');
          setState(() { _isLoading = false; });
        },
        timeout: const Duration(seconds: 60), // OTP timeout
      );
    } on FirebaseException catch (e) {
      _logger.e('Firebase Error during phone validation/OTP sending: ${e.message}');
      if (mounted) {
        _showMessageBox(context, 'Firebase Error: ${e.message}');
      }
    } catch (e) {
      _logger.e('An unexpected error occurred during phone validation/OTP sending: $e');
      if (mounted) {
        _showMessageBox(context, 'An unexpected error occurred. Please try again.');
      }
    } finally {
      setState(() {
        _isLoading = false; // Ensure loading indicator is hidden
      });
    }
  }

  // Helper function to show a message box
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
      backgroundColor: const Color(0xFF1C1C1E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // Removed leading back button as this is the first screen
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your phone number',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'We will send a verification code to this number',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 30),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: InternationalPhoneNumberInput(
                textFieldController: _phoneNumberController,
                onInputChanged: (PhoneNumber number) {
                  _currentCountryCode = number.dialCode!; // Update the country code
                  _logger.d('Phone number input changed: ${number.phoneNumber}');
                },
                selectorConfig: const SelectorConfig(
                  selectorType: PhoneInputSelectorType.BOTTOM_SHEET,
                ),
                ignoreBlank: false,
                autoValidateMode: AutovalidateMode.disabled,
                selectorTextStyle: const TextStyle(color: Colors.white),
                initialValue: PhoneNumber(isoCode: 'NG'),
                formatInput: false,
                keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                inputBorder: InputBorder.none,
                inputDecoration: const InputDecoration(
                  hintText: 'Phone Number',
                  hintStyle: TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                textStyle: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(height: 20), // Space after the input field

            // "Already have an account? Login" message
            Align(
              alignment: Alignment.center, // Center the row
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center, // Center items in the row
                children: [
                  const Text(
                    'Already have an account?',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            // Call _validateAndProceed with isLoginAttempt: true for the 'Login' button
                            _validateAndProceed(isLoginAttempt: true);
                          },
                    child: const Text(
                      'Login',
                      style: TextStyle(
                        color: Color(0xFF007AFF), // Blue color for the link
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                // Call _validateAndProceed with isLoginAttempt: false for the 'Continue' button
                onPressed: _isLoading ? null : () => _validateAndProceed(isLoginAttempt: false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007AFF),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Continue',
                        style: TextStyle(
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
