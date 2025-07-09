import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:logger/logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart'; // For hashing passwords
import 'dart:convert'; // For utf8.encode

class MerchantSignupScreen extends StatefulWidget {
  const MerchantSignupScreen({super.key});

  @override
  State<MerchantSignupScreen> createState() => _MerchantSignupScreenState();
}

class _MerchantSignupScreenState extends State<MerchantSignupScreen> {
  final Logger _logger = Logger();
  final _formKey = GlobalKey<FormBuilderState>();
  final TextEditingController _merchantIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController(); // NEW: For user's phone number
  bool _isLoading = false;

  @override
  void dispose() {
    _merchantIdController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneNumberController.dispose(); // Dispose new controller
    super.dispose();
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Custom validator for Merchant ID format: 4 alphabets-3 numbers (e.g., ABCD-123)
  String? _merchantIdValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Merchant ID is required';
    }
    final RegExp regex = RegExp(r'^[A-Z]{4}-\d{3}$'); // Regex for 4 uppercase letters, hyphen, 3 digits
    if (!regex.hasMatch(value)) {
      return 'Format: ABCD-123 (4 letters, hyphen, 3 numbers)';
    }
    return null;
  }

  Future<void> _handleMerchantSignup() async {
    if (!(_formKey.currentState?.saveAndValidate() ?? false)) {
      _logger.w('Form validation failed for merchant signup.');
      return;
    }

    final String merchantId = _merchantIdController.text.trim();
    final String password = _passwordController.text;
    final String confirmPassword = _confirmPasswordController.text;
    final String rawPhoneNumber = _phoneNumberController.text.trim();
    final String fullPhoneNumber = '+234$rawPhoneNumber'; // Assuming +234 for Nigeria

    if (password != confirmPassword) {
      _showMessageBox(context, 'Passwords do not match.', 'Please ensure the password and confirm password fields are identical.');
      return;
    }

    if (password.length < 6) {
      _showMessageBox(context, 'Password too short.', 'Password must be at least 6 characters long.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Check if an authenticated user is logged in
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _showMessageBox(context, 'Authentication Required', 'You must be logged in as a user to create a merchant account.');
        setState(() { _isLoading = false; });
        return;
      }

      // 2. Verify the provided phone number matches the logged-in user's phone number
      //    And check if a user document exists for this authenticated user.
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();

      if (!userDoc.exists || (userDoc.data() as Map<String, dynamic>?)?['phoneNumber'] != fullPhoneNumber) {
        _showMessageBox(context, 'User Account Mismatch', 'The phone number provided must match your logged-in user account phone number.');
        setState(() { _isLoading = false; });
        return;
      }

      // 3. Check if merchant ID already exists
      final merchantIdQuery = await FirebaseFirestore.instance
          .collection('merchants')
          .where('merchantId', isEqualTo: merchantId)
          .limit(1)
          .get();

      if (merchantIdQuery.docs.isNotEmpty) {
        _showMessageBox(context, 'Merchant ID Exists', 'This Merchant ID is already taken. Please choose a different one.');
        setState(() { _isLoading = false; });
        return;
      }

      // 4. Check if a merchant account already exists for this user's UID
      final existingMerchantQuery = await FirebaseFirestore.instance
          .collection('merchants')
          .where('userUid', isEqualTo: currentUser.uid)
          .limit(1)
          .get();

      if (existingMerchantQuery.docs.isNotEmpty) {
        _showMessageBox(context, 'Existing Merchant Account', 'You already have a merchant account linked to your user account.');
        setState(() { _isLoading = false; });
        return;
      }

      final hashedPassword = _hashPassword(password);

      // Create a new merchant document in Firestore, using the user's UID as the document ID
      // This links the merchant account directly to the user's Firebase Auth UID.
      await FirebaseFirestore.instance.collection('merchants').doc(currentUser.uid).set({
        'merchantId': merchantId,
        'userUid': currentUser.uid, // Link to the user's UID
        'phoneNumber': fullPhoneNumber, // Store the full phone number
        'loginPasscodeHash': hashedPassword,
        'loginPasscodeSet': true, // Mark as set
        'merchantName': 'New Merchant', // Default name, can be updated later
        'biometricEnabled': false, // Biometrics disabled by default for merchant login
        'createdAt': FieldValue.serverTimestamp(),
      });

      _logger.i('Merchant account created successfully for ID: $merchantId, linked to user UID: ${currentUser.uid}');
      if (mounted) {
        _showMessageBox(context, 'Success!', 'Your merchant account has been created and linked to your user account. You can now log in as a merchant.');
        Navigator.pushNamedAndRemoveUntil(context, '/merchant_login', (route) => false); // Go to merchant login
      }
    } on FirebaseException catch (e) {
      _logger.e('Firestore Error during merchant signup: ${e.message}');
      if (mounted) _showMessageBox(context, 'Signup Failed', 'Error creating account: ${e.message}');
    } catch (e) {
      _logger.e('An unexpected error occurred during merchant signup: $e');
      if (mounted) _showMessageBox(context, 'Signup Failed', 'An unexpected error occurred. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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

  // Helper widget for input fields with consistent styling
  Widget _buildInputField({
    required String labelText,
    required String name,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    List<String? Function(String?)>? validators,
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
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Create Merchant Account',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.left,
            ),
            const SizedBox(height: 5),
            const Text(
              'Set up your unique Merchant ID and password.',
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
                  // User's Phone Number (must match logged-in user)
                  _buildInputField(
                    labelText: 'Your Registered Phone Number (User Account)',
                    name: 'phone_number',
                    controller: _phoneNumberController,
                    keyboardType: TextInputType.phone,
                    validators: [
                      FormBuilderValidators.required(errorText: 'Phone number is required'),
                      FormBuilderValidators.numeric(errorText: 'Enter a valid phone number'),
                      FormBuilderValidators.minLength(10, errorText: 'Phone number must be at least 10 digits'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Merchant ID Input
                  _buildInputField(
                    labelText: 'Unique Merchant ID (e.g., ABCD-123)',
                    name: 'merchant_id',
                    controller: _merchantIdController,
                    keyboardType: TextInputType.text,
                    validators: [
                      _merchantIdValidator, // Custom validator
                      FormBuilderValidators.required(errorText: 'Merchant ID is required'),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Password Input
                  _buildInputField(
                    labelText: 'Password',
                    name: 'password',
                    controller: _passwordController,
                    keyboardType: TextInputType.visiblePassword,
                    obscureText: true,
                    validators: [
                      FormBuilderValidators.required(errorText: 'Password is required'),
                      FormBuilderValidators.minLength(6, errorText: 'Password must be at least 6 characters'),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Confirm Password Input
                  _buildInputField(
                    labelText: 'Confirm Password',
                    name: 'confirm_password',
                    controller: _confirmPasswordController,
                    keyboardType: TextInputType.visiblePassword,
                    obscureText: true,
                    validators: [
                      FormBuilderValidators.required(errorText: 'Confirm password is required'),
                      (val) {
                        if (val != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Sign Up Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleMerchantSignup,
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
                        'Sign Up',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),

            // Already have an account? Login
            Center(
              child: TextButton(
                onPressed: () {
                  _logger.i('Already have an account? Login button pressed.');
                  Navigator.pop(context); // Go back to merchant login screen
                },
                child: const Text(
                  "Already have an account? Login",
                  style: TextStyle(
                    color: Color(0xFF00C853),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
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
