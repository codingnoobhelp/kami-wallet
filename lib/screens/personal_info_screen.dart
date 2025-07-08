import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:logger/logger.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Cloud Firestore

class PersonalInfoPage extends StatefulWidget {
  const PersonalInfoPage({super.key});

  @override
  State<PersonalInfoPage> createState() => _PersonalInfoPageState();
}

class _PersonalInfoPageState extends State<PersonalInfoPage> {
  final _formKey = GlobalKey<FormBuilderState>();
  final Logger _logger = Logger();
  bool _isLoading = false;

  // Controllers for form fields
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _dobController = TextEditingController(); // For Date of Birth
  DateTime? _selectedDate; // To store selected Date of Birth

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith( // Apply dark theme to date picker
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF007AFF), // Primary color for selected date
              onPrimary: Colors.white,
              surface: Color(0xFF2C2C2E), // Background of the picker
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF1C1C1E), // Dialog background
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dobController.text = "${picked.toLocal()}".split(' ')[0]; // Format date as YYYY-MM-DD
      });
      _logger.d('Date of Birth selected: $_selectedDate');
    }
  }

  Future<void> _savePersonalInfo() async {
    if (_formKey.currentState?.saveAndValidate() ?? false) {
      setState(() {
        _isLoading = true;
      });

      final User? currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        _logger.e('No authenticated user found to save personal info.');
        _showMessageBox(context, 'Error: No authenticated user. Please try logging in again.');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final String uid = currentUser.uid;
      final String firstName = _firstNameController.text.trim();
      final String lastName = _lastNameController.text.trim();
      final String email = _emailController.text.trim();
      final String dob = _dobController.text.trim(); // Date of Birth as string

      _logger.i('Attempting to save user info for UID: $uid');

      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'firstName': firstName,
          'lastName': lastName,
          'email': email,
          'dateOfBirth': dob, // Store as string, or as Timestamp if preferred
          'phoneNumber': currentUser.phoneNumber, // Store phone number from Firebase Auth
          'accountBalance': 0.0, // Initial balance
          'transactionPinSet': false, // Initialize transaction PIN status
          'transactionPinHash': null, // Initialize transaction PIN hash
          'biometricEnabled': false, // Initialize biometric status for transaction passcode
          'loginPasscodeSet': false, // Initialize login passcode status to false
          'loginPasscodeHash': null, // Initialize login passcode hash to null
          'createdAt': FieldValue.serverTimestamp(), // Timestamp of creation
        }, SetOptions(merge: true)); // Use merge: true to avoid overwriting existing fields

        _logger.i('Personal info saved successfully for UID: $uid');

        // Navigate to PinSetupPage for transaction PIN
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/pin_setup', // Navigate to PinSetupPage (for transaction PIN)
          (route) => false, // Clear previous routes
          arguments: {
            'name': firstName, // Pass name for SuccessPage
            'phoneNumber': currentUser.phoneNumber, // Pass phone number for HomeScreen
            'initialBalance': 0.0, // Pass initial balance for HomeScreen
          },
        );
      } on FirebaseException catch (e) {
        _logger.e('Firestore Error saving personal info: ${e.message}');
        if (!mounted) return;
        _showMessageBox(context, 'Error saving info: ${e.message}');
      } catch (e) {
        _logger.e('An unexpected error occurred saving personal info: $e');
        if (!mounted) return;
        _showMessageBox(context, 'An unexpected error occurred. Please try again.');
      } finally {
        setState(() {
          _isLoading = false;
        });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Personal Information',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Please provide your personal details.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 30),
            FormBuilder(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                children: [
                  _buildTextField(
                    name: 'first_name',
                    hintText: 'First Name',
                    controller: _firstNameController,
                    validator: FormBuilderValidators.required(),
                  ),
                  const SizedBox(height: 15),
                  _buildTextField(
                    name: 'last_name',
                    hintText: 'Last Name',
                    controller: _lastNameController,
                    validator: FormBuilderValidators.required(),
                  ),
                  const SizedBox(height: 15),
                  _buildTextField(
                    name: 'email',
                    hintText: 'Email Address',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: FormBuilderValidators.compose([
                      FormBuilderValidators.required(),
                      FormBuilderValidators.email(),
                    ]),
                  ),
                  const SizedBox(height: 15),
                  // Date of Birth field
                  FormBuilderTextField(
                    name: 'date_of_birth',
                    controller: _dobController,
                    readOnly: true, // Make it read-only so user taps to select date
                    decoration: InputDecoration(
                      hintText: 'Date of Birth (YYYY-MM-DD)',
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: const Color(0xFF2C2C2E),
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
                        borderSide: const BorderSide(color: Color(0xFF007AFF), width: 2.0),
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.calendar_today, color: Colors.white54),
                        onPressed: () => _selectDate(context),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    style: const TextStyle(color: Colors.white),
                    validator: FormBuilderValidators.required(),
                    onTap: () => _selectDate(context), // Allow tapping the field to open date picker
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _savePersonalInfo,
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
                        'Save and Continue',
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

  Widget _buildTextField({
    required String name,
    required String hintText,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return FormBuilderTextField(
      name: name,
      controller: controller,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: const Color(0xFF2C2C2E),
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
          borderSide: const BorderSide(color: Color(0xFF007AFF), width: 2.0),
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
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      validator: validator,
    );
  }
}
