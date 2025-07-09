import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:logger/logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert'; // Import for utf8.encode
import 'package:crypto/crypto.dart'; // Import for hashing

// This screen is for setting up the 4-digit Transaction PIN
class PinSetupPage extends StatefulWidget {
  const PinSetupPage({super.key});

  @override
  State<PinSetupPage> createState() => _PinSetupPageState();
}

class _PinSetupPageState extends State<PinSetupPage> {
  final Logger _logger = Logger();
  final TextEditingController _transactionPinController = TextEditingController(); // Renamed for clarity
  bool _isLoading = false;

  // Pinput themes adjusted for white background
  final defaultPinTheme = PinTheme(
    width: 60,
    height: 60,
    textStyle: const TextStyle(
      fontSize: 24,
      color: Colors.black, // Text color for white background
      fontWeight: FontWeight.w600,
    ),
    decoration: BoxDecoration(
      color: Colors.grey[200], // Light grey background for input fields
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
  void dispose() {
    _transactionPinController.dispose(); // Dispose the renamed controller
    super.dispose();
  }

  // Function to hash the PIN using SHA-256
  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _setupTransactionPin() async { // Renamed for clarity
    if (_transactionPinController.text.length != 4) { // 4-digit PIN for transactions
      _showMessageBox(context, 'Please enter a 4-digit transaction PIN.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _logger.e('No authenticated user found to set transaction PIN.');
      _showMessageBox(context, 'Error: No authenticated user. Please try logging in again.');
      setState(() { _isLoading = false; });
      return;
    }

    final String uid = currentUser.uid;
    final String hashedPin = _hashPin(_transactionPinController.text);
    _logger.i('Attempting to save hashed transaction PIN for UID: $uid');

    try {
      // Update the user document with the transaction PIN details
      // This makes the transaction PIN universal for the user, regardless of account type (user/merchant)
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {
          'transactionPinHash': hashedPin, // Save as transaction PIN hash
          'transactionPinSet': true, // Indicate transaction PIN has been set
        },
        SetOptions(merge: true), // Use merge to only update specified fields
      );

      _logger.i('Transaction PIN set successfully for UID: $uid');

      // Retrieve arguments to pass to the SuccessPage
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      final String? phoneNumber = args?['phoneNumber'] as String?;
      final double? initialBalance = args?['initialBalance'] as double?;
      final String? name = args?['name'] as String?;

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/success',
        (route) => false,
        arguments: {
          'phoneNumber': phoneNumber,
          'initialBalance': initialBalance,
          'name': name,
        },
      );
    } on FirebaseException catch (e) {
      _logger.e('Firestore Error saving transaction PIN: ${e.message}');
      if (mounted) _showMessageBox(context, 'Error saving transaction PIN: ${e.message}');
    } catch (e) {
      _logger.e('An unexpected error occurred saving transaction PIN: $e');
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

  // Function to handle digit presses on the custom keypad
  void _onDigitPressed(String digit) {
    if (_transactionPinController.text.length < 4) { // 4-digit PIN
      _transactionPinController.text += digit;
    }
    _logger.d('Transaction PIN input: ${_transactionPinController.text}');
  }

  // Function to handle backspace press
  void _onBackspacePressed() {
    if (_transactionPinController.text.isNotEmpty) {
      _transactionPinController.text = _transactionPinController.text.substring(0, _transactionPinController.text.length - 1);
    }
    _logger.d('Transaction PIN input: ${_transactionPinController.text}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).textTheme.bodyLarge?.color),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.headphones, color: Theme.of(context).textTheme.bodyLarge?.color),
            onPressed: () {
              _showMessageBox(context, 'Support / Help clicked!');
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set up your Transaction PIN', // Updated text
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Please setup a 4-digit PIN for transactions.', // Updated text
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 30),
            Center(
              child: Pinput(
                controller: _transactionPinController, // Use renamed controller
                length: 4, // 4-digit PIN
                defaultPinTheme: defaultPinTheme,
                focusedPinTheme: focusedPinTheme,
                submittedPinTheme: submittedPinTheme,
                obscureText: true,
                onCompleted: (pin) {
                  _logger.d('Transaction PIN entered: $pin');
                  _setupTransactionPin(); // Call renamed function
                },
                onChanged: (value) {
                  _logger.d('Transaction PIN input changed: $value');
                },
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
              ),
            ),
            const Spacer(),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.5,
              ),
              itemCount: 12,
              itemBuilder: (context, index) {
                if (index < 9) {
                  return _buildKeypadButton('${index + 1}', () => _onDigitPressed('${index + 1}'));
                } else if (index == 10) {
                  return _buildKeypadButton('0', () => _onDigitPressed('0'));
                } else if (index == 11) {
                  return _buildKeypadButton(
                    '',
                    _onBackspacePressed,
                    icon: Icons.arrow_back,
                    buttonColor: Colors.red,
                    iconColor: Colors.white,
                  );
                } else {
                  return Container();
                }
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypadButton(String text, VoidCallback onPressed, {IconData? icon, Color? buttonColor, Color? iconColor}) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        decoration: BoxDecoration(
          color: buttonColor ?? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C2E) : Colors.grey[100]),
          borderRadius: BorderRadius.circular(50),
        ),
        alignment: Alignment.center,
        child: icon != null
            ? Icon(icon, size: 30, color: iconColor ?? Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.8))
            : Text(
                text,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
      ),
    );
  }
}
