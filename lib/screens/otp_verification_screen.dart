import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:logger/logger.dart';

class OtpVerificationPage extends StatefulWidget {
  const OtpVerificationPage({super.key});

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  final _otpFormKey = GlobalKey<FormBuilderState>();
  final List<TextEditingController> _otpControllers =
      List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(6, (index) => FocusNode());

  final Logger _logger = Logger();

  String? _phone;
  String? _expectedOtp; // This would typically come from the backend
  String? _name; // New: to store name from previous screen
  String? _email; // New: to store email from previous screen

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      _phone = args['phone'];
      _expectedOtp = args['otp']; // Mock OTP for demonstration
      _name = args['name']; // Extract name
      _email = args['email']; // Extract email
      _logger.d('OTP screen received phone: $_phone, mock OTP: $_expectedOtp, Name: $_name, Email: $_email');
    }
  }

  // Helper function to format phone number for display (e.g., +23480... -> 080...)
  String _formatPhoneNumberForDisplay(String? phoneNumber) {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      return 'N/A';
    }
    // Check if it's a Nigerian number and format it
    if (phoneNumber.startsWith('+234') && phoneNumber.length >= 14) {
      // Assuming typical +23480... format, show as 080...
      return '0${phoneNumber.substring(4)}';
    }
    // For other formats or non-Nigerian numbers, return as is
    return phoneNumber;
  }

  void _onOtpFieldChanged(int index, String value) {
    if (value.isNotEmpty) {
      if (index < _otpControllers.length - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus(); // Unfocus last field
      }
    } else if (value.isEmpty) {
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
    }
  }

  void _verifyOtp() {
    String enteredOtp = _otpControllers.map((controller) => controller.text).join();
    _logger.d('Entered OTP: $enteredOtp');

    if (enteredOtp == _expectedOtp) {
      _logger.i('OTP Verified Successfully!');
      if (mounted) {
        // Navigate to the PasscodeSetupPage, passing the phone number and other user info
        Navigator.pushNamed(
          context,
          '/passcode', // Navigate to passcode setup
          arguments: {
            'phoneNumber': _phone,
            'name': _name, // Pass name
            'email': _email, // Pass email
          },
        );
      }
    } else {
      _logger.w('OTP Verification Failed: Invalid OTP');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid OTP. Please try again.')),
        );
        // Clear OTP fields and reset focus
        for (var controller in _otpControllers) {
          controller.clear();
        }
        _focusNodes[0].requestFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'OTP Verification',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: FormBuilder(
          key: _otpFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Verify your phone number',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              RichText(
                text: TextSpan(
                  text: 'Enter the 6-digit code sent to ',
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).textTheme.bodyMedium!.color,
                  ),
                  children: <TextSpan>[
                    TextSpan(
                      text: _formatPhoneNumberForDisplay(_phone),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge!.color,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 50,
                    height: 50,
                    child: FormBuilderTextField(
                      name: 'otp_field_$index',
                      controller: _otpControllers[index],
                      focusNode: _focusNodes[index],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(1),
                      ],
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Theme.of(context).inputDecorationTheme.fillColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
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
                      ),
                      onChanged: (value) => _onOtpFieldChanged(index, value!),
                      validator: FormBuilderValidators.compose([
                        FormBuilderValidators.required(),
                      ]),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 30),
              Center(
                child: TextButton(
                  onPressed: () {
                    // Resend OTP logic here
                    _logger.d('Resend OTP button pressed. New mock OTP: $_expectedOtp');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('OTP resent')),
                    );
                    for (var controller in _otpControllers) {
                      controller.clear();
                    }
                    _focusNodes[0].requestFocus();
                  },
                  child: const Text('Didn\'t get the code? Resend OTP'),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Proceed',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }
}