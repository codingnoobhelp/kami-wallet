import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for TextInputFormatter
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:logger/logger.dart';
import 'dart:math'; // For generating OTP

class PhoneEntryPage extends StatefulWidget {
  const PhoneEntryPage({super.key});

  @override
  State<PhoneEntryPage> createState() => _PhoneEntryPageState();
}

class _PhoneEntryPageState extends State<PhoneEntryPage> {
  final _formKey = GlobalKey<FormBuilderState>();
  String _selectedCountryCode = '+234'; // Default to Nigeria
  final TextEditingController _phoneController = TextEditingController();

  final Logger _logger = Logger();

  // Define a map for standard phone number digit limits per country code
  final Map<String, int> _countryDigitLimits = {
    '+234': 10, // Nigeria: 10 digits (e.g., 8060330199 for +234)
    '+1': 10,   // USA/Canada: 10 digits
    '+44': 10,  // UK: (mostly) 10 digits after +44
  };

  late int _maxPhoneDigits;

  @override
  void initState() {
    super.initState();
    _maxPhoneDigits = _countryDigitLimits[_selectedCountryCode] ?? 10;
  }

  void _onCountryCodeChanged(CountryCode countryCode) {
    setState(() {
      _selectedCountryCode = countryCode.dialCode ?? '+234';
      _maxPhoneDigits = _countryDigitLimits[_selectedCountryCode] ?? 10;
      _phoneController.clear(); // Clear phone number when country code changes
      _logger.d('Country code changed to: $_selectedCountryCode, max digits: $_maxPhoneDigits');
    });
  }

  void _submitPhoneNumber() {
    if (_formKey.currentState!.saveAndValidate()) {
      final String fullPhoneNumber = _selectedCountryCode + _phoneController.text;
      _logger.d('Submitting phone number: $fullPhoneNumber');

      if (mounted) {
        // Navigate to PersonalInfoPage, passing the phone number
        Navigator.pushNamed(
          context,
          '/personal', // Navigate to personal info first
          arguments: {
            'phoneNumber': fullPhoneNumber,
          },
        );
      }
    }
  }

  void _onLoginPressed() {
    _logger.i('Login button pressed on PhoneEntryPage');
    if (mounted) {
      // You can navigate to a dedicated login screen if it exists
      // For now, we'll just log or show a snackbar as a placeholder
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login functionality not yet implemented.')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create Account',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your phone number',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'We will send a verification code to this number.',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).textTheme.bodyMedium!.color,
              ),
            ),
            const SizedBox(height: 30),
            FormBuilder(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                children: [
                  Row(
                    children: [
                      CountryCodePicker(
                        onChanged: _onCountryCodeChanged,
                        initialSelection: 'NG', // Default to Nigeria
                        favorite: const ['+234', 'NG'], // Favorite countries
                        showCountryOnly: false,
                        showOnlyCountryWhenClosed: false,
                        alignLeft: false,
                        flagWidth: 24, // Adjust flag size
                        padding: EdgeInsets.zero, // Remove default padding
                        textStyle: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).textTheme.bodyMedium!.color,
                        ),
                        dialogTextStyle: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium!.color,
                        ),
                        searchStyle: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium!.color,
                        ),
                        dialogBackgroundColor: Theme.of(context).scaffoldBackgroundColor, // Adapt dialog background
                        boxDecoration: BoxDecoration(
                          color: Theme.of(context).inputDecorationTheme.fillColor, // Adapt text field background
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Theme.of(context).dividerColor), // Adapt border color
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FormBuilderTextField(
                          name: 'phone_number',
                          controller: _phoneController,
                          decoration: InputDecoration(
                            hintText: 'Phone number',
                            filled: true,
                            fillColor: Theme.of(context).inputDecorationTheme.fillColor,
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
                              borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2.0),
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
                            hintStyle: TextStyle(color: Theme.of(context).hintColor),
                          ),
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(_maxPhoneDigits),
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your phone number';
                            }
                            // Check if the length matches the expected digits for the country
                            if (value.length != _maxPhoneDigits) {
                              return 'Phone number must be $_maxPhoneDigits digits long';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _submitPhoneNumber,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Proceed',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account? ',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium!.color,
                      fontSize: 16,
                    ),
                  ),
                  GestureDetector(
                    onTap: _onLoginPressed,
                    child: Text(
                      'Login',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium!.color,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }
}