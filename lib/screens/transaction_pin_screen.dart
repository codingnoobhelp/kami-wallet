import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:logger/logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:intl/intl.dart'; // For currency formatting in success screen arguments

class TransactionPinScreen extends StatefulWidget {
  final String recipientName;
  final String recipientPhoneNumber;
  final String recipientUid;
  final String bankName;
  final double amount;
  final String description;

  const TransactionPinScreen({
    super.key,
    required this.recipientName,
    required this.recipientPhoneNumber,
    required this.recipientUid,
    required this.bankName,
    required this.amount,
    required this.description,
  });

  @override
  State<TransactionPinScreen> createState() => _TransactionPinScreenState();
}

class _TransactionPinScreenState extends State<TransactionPinScreen> {
  final Logger _logger = Logger();
  final TextEditingController _pinController = TextEditingController();
  bool _isLoading = false;

  // Pinput themes (similar to your other PIN screens)
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
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  // Function to hash the PIN using SHA-256 (reused from PinSetupPage)
  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Main function to verify PIN and execute transfer
  Future<void> _verifyPinAndExecuteTransfer() async {
    if (_pinController.text.length != 4) {
      _showMessageBox(context, 'Please enter your 4-digit transaction PIN.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _logger.e('No authenticated user found for transfer.');
      _showMessageBox(context, 'Error: No authenticated user. Please log in again.');
      setState(() { _isLoading = false; });
      return;
    }

    final String enteredPinHash = _hashPin(_pinController.text);
    final String senderUid = currentUser.uid;

    try {
      // 1. Fetch user's stored transaction PIN hash
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(senderUid).get();

      if (!userDoc.exists || userDoc.data() == null) {
        throw Exception("User document not found.");
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final String? storedTransactionPinHash = userData['transactionPinHash'];
      final bool transactionPinSet = userData['transactionPinSet'] ?? false;

      if (!transactionPinSet || storedTransactionPinHash == null) {
        _showMessageBox(context, 'Transaction PIN is not set. Please set it up in Account Settings.');
        setState(() { _isLoading = false; });
        return;
      }

      // 2. Verify entered PIN
      if (enteredPinHash != storedTransactionPinHash) {
        _showMessageBox(context, 'Incorrect transaction PIN. Please try again.');
        _pinController.clear(); // Clear PIN input on failure
        setState(() { _isLoading = false; });
        return;
      }

      _logger.i('Transaction PIN verified. Proceeding with transfer...');

      // 3. Execute the actual money transfer (logic from TransferConfirmationScreen)
      final senderDocRef = FirebaseFirestore.instance.collection('users').doc(senderUid);
      final recipientDocRef = FirebaseFirestore.instance.collection('users').doc(widget.recipientUid);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final senderSnapshot = await transaction.get(senderDocRef);
        final recipientSnapshot = await transaction.get(recipientDocRef);

        if (!senderSnapshot.exists) {
          throw Exception("Sender account not found during transaction.");
        }
        if (!recipientSnapshot.exists) {
          throw Exception("Recipient account not found during transaction.");
        }

        double senderBalance = (senderSnapshot.data()?['accountBalance'] as num?)?.toDouble() ?? 0.0;
        double recipientBalance = (recipientSnapshot.data()?['accountBalance'] as num?)?.toDouble() ?? 0.0;

        if (senderBalance < widget.amount) {
          throw Exception("Insufficient balance. Transfer cancelled.");
        }

        // Update balances
        transaction.update(senderDocRef, {'accountBalance': senderBalance - widget.amount});
        transaction.update(recipientDocRef, {'accountBalance': recipientBalance + widget.amount});

        // Get sender's name from the senderSnapshot within the transaction
        final senderFirstName = senderSnapshot.data()?['firstName'] ?? '';
        final senderLastName = senderSnapshot.data()?['lastName'] ?? '';
        final senderName = '$senderFirstName $senderLastName'.trim();

        // Record transaction within the transaction block for atomicity
        final newTransactionRef = FirebaseFirestore.instance.collection('transactions').doc();
        transaction.set(newTransactionRef, {
          'amount': widget.amount,
          'description': widget.description.isNotEmpty ? widget.description : 'Wallet Transfer',
          'timestamp': FieldValue.serverTimestamp(),
          'senderUid': senderUid,
          'receiverUid': widget.recipientUid,
          'senderPhoneNumber': currentUser.phoneNumber,
          'receiverPhoneNumber': widget.recipientPhoneNumber,
          'senderName': senderName,
          'receiverName': widget.recipientName,
        });

        _logger.i('Firestore transaction completed successfully.');
      });

      // 4. Navigate to success screen
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/transfer_success',
          (route) => false,
          arguments: {
            'amount': widget.amount,
            'recipientName': widget.recipientName,
            'recipientPhoneNumber': widget.recipientPhoneNumber,
            'bankName': widget.bankName,
          },
        );
      }
    } on FirebaseException catch (e) {
      _logger.e('Firestore Error during PIN verification or transfer: ${e.message}');
      if (mounted) _showMessageBox(context, 'Transfer failed: ${e.message}');
    } catch (e) {
      _logger.e('An unexpected error occurred during PIN verification or transfer: $e');
      if (mounted) _showMessageBox(context, 'Transfer failed: ${e.toString()}');
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
    if (_pinController.text.length < 4) { // 4-digit PIN
      _pinController.text += digit;
    }
    _logger.d('PIN input: ${_pinController.text}');
  }

  // Function to handle backspace press
  void _onBackspacePressed() {
    if (_pinController.text.isNotEmpty) {
      _pinController.text = _pinController.text.substring(0, _pinController.text.length - 1);
    }
    _logger.d('PIN input: ${_pinController.text}');
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final hintColor = isDarkMode ? Colors.white70 : Colors.black54;

    // Format amount for display
    final NumberFormat currencyFormatter = NumberFormat.currency(locale: 'en_NG', symbol: '₦');
    final String formattedAmount = currencyFormatter.format(widget.amount);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Enter Transaction PIN', style: TextStyle(color: textColor)),
        centerTitle: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: textColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: textColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Confirm transfer of $formattedAmount to ${widget.recipientName}',
              style: TextStyle(
                color: textColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Please enter your 4-digit transaction PIN to complete the transfer.',
              style: TextStyle(
                color: hintColor,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 30),
            Center(
              child: Pinput(
                controller: _pinController,
                length: 4,
                defaultPinTheme: defaultPinTheme,
                focusedPinTheme: focusedPinTheme,
                submittedPinTheme: submittedPinTheme,
                obscureText: true,
                onCompleted: (pin) {
                  _logger.d('PIN input completed: $pin');
                  _verifyPinAndExecuteTransfer();
                },
                onChanged: (value) {
                  _logger.d('PIN input changed: $value');
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
                    icon: Icons.backspace_outlined, // Changed to backspace icon
                    buttonColor: Colors.red,
                    iconColor: Colors.white,
                  );
                } else {
                  return Container();
                }
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _verifyPinAndExecuteTransfer,
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
                        'Confirm Transfer',
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
